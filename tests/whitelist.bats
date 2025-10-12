#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-whitelist-home.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

setup() {
    rm -rf "$HOME/.config"
    mkdir -p "$HOME"
    WHITELIST_PATH="$HOME/.config/mole/whitelist"
}

@test "patterns_equivalent treats paths with tilde expansion as equal" {
    local status
    if HOME="$HOME" bash --noprofile --norc -c "source '$PROJECT_ROOT/lib/whitelist_manager.sh'; patterns_equivalent '~/.cache/test' \"\$HOME/.cache/test\""; then
        status=0
    else
        status=$?
    fi
    [ "$status" -eq 0 ]
}

@test "patterns_equivalent distinguishes different paths" {
    local status
    if HOME="$HOME" bash --noprofile --norc -c "source '$PROJECT_ROOT/lib/whitelist_manager.sh'; patterns_equivalent '~/.cache/test' \"\$HOME/.cache/other\""; then
        status=0
    else
        status=$?
    fi
    [ "$status" -ne 0 ]
}

@test "save_whitelist_patterns keeps unique entries and preserves header" {
    HOME="$HOME" bash --noprofile --norc -c "source '$PROJECT_ROOT/lib/whitelist_manager.sh'; save_whitelist_patterns \"\$HOME/.cache/foo\" \"\$HOME/.cache/foo\" \"\$HOME/.cache/bar\""

    [[ -f "$WHITELIST_PATH" ]]

    lines=()
    while IFS= read -r line; do
        lines+=("$line")
    done < "$WHITELIST_PATH"
    # Header is at least two lines (comments), plus two unique patterns
    [ "${#lines[@]}" -ge 4 ]
    # Ensure duplicate was not written twice
    occurrences=$(grep -c "$HOME/.cache/foo" "$WHITELIST_PATH")
    [ "$occurrences" -eq 1 ]
}

@test "load_whitelist falls back to defaults when config missing" {
    rm -f "$WHITELIST_PATH"
    HOME="$HOME" bash --noprofile --norc -c "source '$PROJECT_ROOT/lib/whitelist_manager.sh'; rm -f \"\$HOME/.config/mole/whitelist\"; load_whitelist; printf '%s\n' \"\${CURRENT_WHITELIST_PATTERNS[@]}\"" > "$HOME/current_whitelist.txt"
    HOME="$HOME" bash --noprofile --norc -c "source '$PROJECT_ROOT/lib/whitelist_manager.sh'; printf '%s\n' \"\${DEFAULT_WHITELIST_PATTERNS[@]}\"" > "$HOME/default_whitelist.txt"

    current=()
    while IFS= read -r line; do
        current+=("$line")
    done < "$HOME/current_whitelist.txt"

    defaults=()
    while IFS= read -r line; do
        defaults+=("$line")
    done < "$HOME/default_whitelist.txt"

    [ "${#current[@]}" -eq "${#defaults[@]}" ]
    [ "${current[0]}" = "${defaults[0]/\$HOME/$HOME}" ]
}

@test "is_whitelisted matches saved patterns exactly" {
    local status
    if HOME="$HOME" bash --noprofile --norc -c "source '$PROJECT_ROOT/lib/whitelist_manager.sh'; save_whitelist_patterns \"\$HOME/.cache/unique-pattern\"; load_whitelist; is_whitelisted \"\$HOME/.cache/unique-pattern\""; then
        status=0
    else
        status=$?
    fi
    [ "$status" -eq 0 ]

    if HOME="$HOME" bash --noprofile --norc -c "source '$PROJECT_ROOT/lib/whitelist_manager.sh'; save_whitelist_patterns \"\$HOME/.cache/unique-pattern\"; load_whitelist; is_whitelisted \"\$HOME/.cache/other-pattern\""; then
        status=0
    else
        status=$?
    fi
    [ "$status" -ne 0 ]
}
