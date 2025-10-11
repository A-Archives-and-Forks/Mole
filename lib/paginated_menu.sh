#!/bin/bash
# Paginated menu with arrow key navigation

set -euo pipefail

# Terminal control functions
enter_alt_screen() { tput smcup 2>/dev/null || true; }
leave_alt_screen() { tput rmcup 2>/dev/null || true; }

# Main paginated multi-select menu function
paginated_multi_select() {
    local title="$1"
    shift
    local -a items=("$@")
    local external_alt_screen=false
    if [[ "${MOLE_MANAGED_ALT_SCREEN:-}" == "1" || "${MOLE_MANAGED_ALT_SCREEN:-}" == "true" ]]; then
        external_alt_screen=true
    fi

    # Validation
    if [[ ${#items[@]} -eq 0 ]]; then
        echo "No items provided" >&2
        return 1
    fi

    local total_items=${#items[@]}
    local items_per_page=15
    local total_pages=$(( (total_items + items_per_page - 1) / items_per_page ))
    local current_page=0
    local cursor_pos=0
    local -a selected=()

    # Initialize selection array
    for ((i = 0; i < total_items; i++)); do
        selected[i]=false
    done

    if [[ -n "${MOLE_PRESELECTED_INDICES:-}" ]]; then
        local cleaned_preselect="${MOLE_PRESELECTED_INDICES//[[:space:]]/}"
        local -a initial_indices=()
        IFS=',' read -ra initial_indices <<< "$cleaned_preselect"
        for idx in "${initial_indices[@]}"; do
            if [[ "$idx" =~ ^[0-9]+$ && $idx -ge 0 && $idx -lt $total_items ]]; then
                selected[idx]=true
            fi
        done
    fi

    # Preserve original TTY settings so we can restore them reliably
    local original_stty=""
    if [[ -t 0 ]] && command -v stty >/dev/null 2>&1; then
        original_stty=$(stty -g 2>/dev/null || echo "")
    fi

    restore_terminal() {
        show_cursor
        if [[ -n "${original_stty-}" ]]; then
            stty "${original_stty}" 2>/dev/null || stty sane 2>/dev/null || stty echo icanon 2>/dev/null || true
        else
            stty sane 2>/dev/null || stty echo icanon 2>/dev/null || true
        fi
        if [[ "${external_alt_screen:-false}" == false ]]; then
            leave_alt_screen
        fi
    }

    # Cleanup function
    cleanup() {
        trap - EXIT INT TERM
        restore_terminal
    }

    # Interrupt handler
    handle_interrupt() {
        cleanup
        exit 130  # Standard exit code for Ctrl+C
    }

    trap cleanup EXIT
    trap handle_interrupt INT TERM

    # Setup terminal - preserve interrupt character
    stty -echo -icanon intr ^C 2>/dev/null || true
    if [[ $external_alt_screen == false ]]; then
        enter_alt_screen
        # Clear screen once on entry to alt screen
        printf "\033[2J\033[H" >&2
    else
        printf "\033[H" >&2
    fi
    hide_cursor

    # Helper functions
    print_line() { printf "\r\033[2K%s\n" "$1" >&2; }

    render_item() {
        local idx=$1 is_current=$2
        local checkbox="[ ]"
        [[ ${selected[idx]} == true ]] && checkbox="[x]"

        if [[ $is_current == true ]]; then
            printf "\r\033[2K${BLUE}> %s %s${NC}\n" "$checkbox" "${items[idx]}" >&2
        else
            printf "\r\033[2K  %s %s\n" "$checkbox" "${items[idx]}" >&2
        fi
    }

    # Draw the complete menu
    draw_menu() {
        # Move to home position without clearing (reduces flicker)
        printf "\033[H" >&2
        
        # Clear each line as we go instead of clearing entire screen
        local clear_line="\r\033[2K"

        # Header - compute underline length without external seq dependency
        local title_clean="${title//[^[:print:]]/}"
        local underline_len=${#title_clean}
        [[ $underline_len -lt 10 ]] && underline_len=10
        # Build underline robustly (no seq); printf width then translate spaces to '='
        local underline
        underline=$(printf '%*s' "$underline_len" '' | tr ' ' '=')
        printf "${clear_line}${PURPLE}%s${NC}\n" "$title" >&2
        printf "${clear_line}%s\n" "$underline" >&2

        # Status
        local selected_count=0
        for ((i = 0; i < total_items; i++)); do
            [[ ${selected[i]} == true ]] && ((selected_count++))
        done
        printf "${clear_line}Page %d/%d │ Total: %d │ Selected: %d\n\n" \
            $((current_page + 1)) $total_pages $total_items $selected_count >&2

        # Items for current page
        local start_idx=$((current_page * items_per_page))
        local end_idx=$((start_idx + items_per_page - 1))
        [[ $end_idx -ge $total_items ]] && end_idx=$((total_items - 1))

        for ((i = start_idx; i <= end_idx; i++)); do
            local is_current=false
            [[ $((i - start_idx)) -eq $cursor_pos ]] && is_current=true
            render_item $i $is_current
        done

        # Fill empty slots to clear previous content
        local items_shown=$((end_idx - start_idx + 1))
        for ((i = items_shown; i < items_per_page; i++)); do
            printf "${clear_line}\n" >&2
        done

        # Clear any remaining lines at bottom
        printf "${clear_line}\n" >&2
        printf "${clear_line}${GRAY}↑/↓${NC} Navigate  ${GRAY}|${NC}  ${GRAY}Space${NC} Select  ${GRAY}|${NC}  ${GRAY}Enter${NC} Confirm  ${GRAY}|${NC}  ${GRAY}Q/ESC${NC} Quit\n" >&2
        
        # Clear one more line to ensure no artifacts
        printf "${clear_line}" >&2
    }

    # Show help screen
    show_help() {
        printf "\033[H\033[J" >&2
        cat >&2 << 'EOF'
Help - Navigation Controls
==========================

  ↑ / ↓      Navigate up/down
  Space      Select/deselect item
  Enter      Confirm selection
  Q / ESC    Exit

Press any key to continue...
EOF
        read -n 1 -s >&2
    }

    # Main interaction loop
    while true; do
        draw_menu
        local key=$(read_key)

        case "$key" in
            "QUIT")
                cleanup
                return 1
                ;;
            "UP")
                if [[ $cursor_pos -gt 0 ]]; then
                    ((cursor_pos--))
                elif [[ $current_page -gt 0 ]]; then
                    ((current_page--))
                    # Calculate cursor position for new page
                    local start_idx=$((current_page * items_per_page))
                    local items_on_page=$((total_items - start_idx))
                    [[ $items_on_page -gt $items_per_page ]] && items_on_page=$items_per_page
                    cursor_pos=$((items_on_page - 1))
                fi
                ;;
            "DOWN")
                local start_idx=$((current_page * items_per_page))
                local items_on_page=$((total_items - start_idx))
                [[ $items_on_page -gt $items_per_page ]] && items_on_page=$items_per_page

                if [[ $cursor_pos -lt $((items_on_page - 1)) ]]; then
                    ((cursor_pos++))
                elif [[ $current_page -lt $((total_pages - 1)) ]]; then
                    ((current_page++))
                    cursor_pos=0
                fi
                ;;
            "SPACE")
                local idx=$((current_page * items_per_page + cursor_pos))
                if [[ $idx -lt $total_items ]]; then
                    if [[ ${selected[idx]} == true ]]; then
                        selected[idx]=false
                    else
                        selected[idx]=true
                    fi
                fi
                ;;
            "ALL")
                for ((i = 0; i < total_items; i++)); do
                    selected[i]=true
                done
                ;;
            "NONE")
                for ((i = 0; i < total_items; i++)); do
                    selected[i]=false
                done
                ;;
            "HELP") show_help ;;
            "ENTER")
                # Auto-select current item if nothing selected
                local has_selection=false
                for ((i = 0; i < total_items; i++)); do
                    if [[ ${selected[i]} == true ]]; then
                        has_selection=true
                        break
                    fi
                done

                if [[ $has_selection == false ]]; then
                    local idx=$((current_page * items_per_page + cursor_pos))
                    [[ $idx -lt $total_items ]] && selected[idx]=true
                fi

                # Store result in global variable instead of returning via stdout
                local -a selected_indices=()
                for ((i = 0; i < total_items; i++)); do
                    if [[ ${selected[i]} == true ]]; then
                        selected_indices+=("$i")
                    fi
                done

                local final_result=""
                if [[ ${#selected_indices[@]} -gt 0 ]]; then
                    local IFS=','
                    final_result="${selected_indices[*]}"
                fi
                
                # Remove the trap to avoid cleanup on normal exit
                trap - EXIT INT TERM

                # Store result in global variable
                MOLE_SELECTION_RESULT="$final_result"

                # Manually cleanup terminal before returning
                restore_terminal

                return 0
                ;;
        esac
    done
}

# Export function for external use
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This is a library file. Source it from other scripts." >&2
    exit 1
fi
