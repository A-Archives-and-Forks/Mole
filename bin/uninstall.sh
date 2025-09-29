#!/bin/bash
# Mole - Uninstall Module
# Interactive application uninstaller with keyboard navigation
#
# Usage:
#   uninstall.sh          # Launch interactive uninstaller
#   uninstall.sh --help   # Show help information

set -euo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/paginated_menu.sh"
source "$SCRIPT_DIR/../lib/app_selector.sh"
source "$SCRIPT_DIR/../lib/batch_uninstall.sh"

# Note: Bundle preservation logic is now in lib/common.sh

# Help information
show_help() {
    echo "App Uninstaller"
    echo "==============="
    echo ""
    echo "Uninstall applications and clean their data completely."
    echo ""
    echo "Controls:"
    echo "  ↑/↓     Navigate"
    echo "  SPACE   Select/deselect"
    echo "  ENTER   Confirm"
    echo "  Q       Quit"
    echo ""
    echo "Usage:"
    echo "  ./uninstall.sh          Launch interactive uninstaller"
    echo "  ./uninstall.sh --help   Show this help message"
    echo ""
    echo "What gets cleaned:"
    echo "  • Application bundle"
    echo "  • Application Support data"
    echo "  • Cache files"
    echo "  • Preference files"
    echo "  • Log files"
    echo "  • Saved application state"
    echo "  • Container data (sandboxed apps)"
    echo ""
}

# Parse arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# Initialize global variables
selected_apps=()  # Global array for app selection
declare -a apps_data=()
declare -a selection_state=()
current_line=0
total_items=0
files_cleaned=0
total_size_cleaned=0

# Get app last used date in human readable format
get_app_last_used() {
    local app_path="$1"
    local last_used=$(mdls -name kMDItemLastUsedDate -raw "$app_path" 2>/dev/null)

    if [[ "$last_used" == "(null)" || -z "$last_used" ]]; then
        echo "Never"
    else
        local last_used_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$last_used" "+%s" 2>/dev/null)
        local current_epoch=$(date "+%s")
        local days_ago=$(( (current_epoch - last_used_epoch) / 86400 ))

        if [[ $days_ago -eq 0 ]]; then
            echo "Today"
        elif [[ $days_ago -eq 1 ]]; then
            echo "Yesterday"
        elif [[ $days_ago -lt 30 ]]; then
            echo "${days_ago} days ago"
        elif [[ $days_ago -lt 365 ]]; then
            local months_ago=$(( days_ago / 30 ))
            echo "${months_ago} month(s) ago"
        else
            local years_ago=$(( days_ago / 365 ))
            echo "${years_ago} year(s) ago"
        fi
    fi
}

# Scan applications and collect information
scan_applications() {
    local temp_file=$(mktemp)

    echo -n "Scanning... " >&2

    # Pre-cache current epoch to avoid repeated calls
    local current_epoch=$(date "+%s")

    # First pass: quickly collect all valid app paths and bundle IDs
    local -a app_data_tuples=()
    while IFS= read -r -d '' app_path; do
        if [[ ! -e "$app_path" ]]; then continue; fi

        local app_name=$(basename "$app_path" .app)

        # Try to get English name from bundle info, fallback to folder name
        local bundle_id="unknown"
        local display_name="$app_name"
        if [[ -f "$app_path/Contents/Info.plist" ]]; then
            bundle_id=$(defaults read "$app_path/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo "unknown")

            # Try to get English name from bundle info
            local bundle_executable=$(defaults read "$app_path/Contents/Info.plist" CFBundleExecutable 2>/dev/null)

            # Smart display name selection - prefer descriptive names over generic ones
            local candidates=()
            
            # Get all potential names
            local bundle_display_name=$(plutil -extract CFBundleDisplayName raw "$app_path/Contents/Info.plist" 2>/dev/null)
            local bundle_name=$(plutil -extract CFBundleName raw "$app_path/Contents/Info.plist" 2>/dev/null)
            
            # Check if executable name is generic/technical (should be avoided)
            local is_generic_executable=false
            if [[ -n "$bundle_executable" ]]; then
                case "$bundle_executable" in
                    "pake"|"Electron"|"electron"|"nwjs"|"node"|"helper"|"main"|"app"|"binary")
                        is_generic_executable=true
                        ;;
                esac
            fi
            
            # Priority order for name selection:
            # 1. App folder name (if ASCII and descriptive) - often the most complete name
            if [[ "$app_name" =~ ^[A-Za-z0-9\ ._-]+$ && ${#app_name} -gt 3 ]]; then
                candidates+=("$app_name")
            fi
            
            # 2. CFBundleDisplayName (if meaningful and ASCII)
            if [[ -n "$bundle_display_name" && "$bundle_display_name" =~ ^[A-Za-z0-9\ ._-]+$ ]]; then
                candidates+=("$bundle_display_name")
            fi
            
            # 3. CFBundleName (if meaningful and ASCII)  
            if [[ -n "$bundle_name" && "$bundle_name" =~ ^[A-Za-z0-9\ ._-]+$ && "$bundle_name" != "$bundle_display_name" ]]; then
                candidates+=("$bundle_name")
            fi
            
            # 4. CFBundleExecutable (only if not generic and ASCII)
            if [[ -n "$bundle_executable" && "$bundle_executable" =~ ^[A-Za-z0-9._-]+$ && "$is_generic_executable" == false ]]; then
                candidates+=("$bundle_executable")
            fi
            
            # 5. Fallback to non-ASCII names if no ASCII found
            if [[ ${#candidates[@]} -eq 0 ]]; then
                [[ -n "$bundle_display_name" ]] && candidates+=("$bundle_display_name")
                [[ -n "$bundle_name" && "$bundle_name" != "$bundle_display_name" ]] && candidates+=("$bundle_name")
                candidates+=("$app_name")
            fi
            
            # Select the first (best) candidate
            display_name="${candidates[0]:-$app_name}"
            
            # Brand name mapping for better user recognition (post-process)
            case "$display_name" in
                "qiyimac"|"爱奇艺") display_name="iQiyi" ;;
                "wechat"|"微信") display_name="WeChat" ;;
                "QQ"|"QQ") display_name="QQ" ;;
                "VooV Meeting"|"腾讯会议") display_name="VooV Meeting" ;;
                "dingtalk"|"钉钉") display_name="DingTalk" ;;
                "NeteaseMusic"|"网易云音乐") display_name="NetEase Music" ;;
                "BaiduNetdisk"|"百度网盘") display_name="Baidu NetDisk" ;;
                "alipay"|"支付宝") display_name="Alipay" ;;
                "taobao"|"淘宝") display_name="Taobao" ;;
                "futunn"|"富途牛牛") display_name="Futu NiuNiu" ;;
                "tencent lemon"|"Tencent Lemon Cleaner") display_name="Tencent Lemon" ;;
                "keynote"|"Keynote") display_name="Keynote" ;;
                "pages"|"Pages") display_name="Pages" ;;
                "numbers"|"Numbers") display_name="Numbers" ;;
            esac
        fi

        # Skip protected system apps early
        if should_preserve_bundle "$bundle_id"; then
            continue
        fi

        # Store tuple: app_path|app_name|bundle_id|display_name
        app_data_tuples+=("${app_path}|${app_name}|${bundle_id}|${display_name}")
    done < <(find /Applications -name "*.app" -maxdepth 1 -print0 2>/dev/null)

    # Second pass: process each app with accurate size calculation
    local app_count=0
    local total_apps=${#app_data_tuples[@]}

    for app_data_tuple in "${app_data_tuples[@]}"; do
        IFS='|' read -r app_path app_name bundle_id display_name <<< "$app_data_tuple"

        # Show progress every few items
        ((app_count++))
        if (( app_count % 5 == 0 )) || [[ $app_count -eq $total_apps ]]; then
            echo -ne "\rScanning... $app_count/$total_apps" >&2
        fi

        # Accurate size calculation - this is what takes time but user wants it
        local app_size="N/A"
        if [[ -d "$app_path" ]]; then
            app_size=$(du -sh "$app_path" 2>/dev/null | cut -f1 || echo "N/A")
        fi

        # Get real last used date from macOS metadata
        local last_used="Never"
        local last_used_epoch=0

        if [[ -d "$app_path" ]]; then
            local metadata_date=$(mdls -name kMDItemLastUsedDate -raw "$app_path" 2>/dev/null)

            if [[ "$metadata_date" != "(null)" && -n "$metadata_date" ]]; then
                # Convert macOS date format to epoch
                last_used_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$metadata_date" "+%s" 2>/dev/null || echo "0")

                if [[ $last_used_epoch -gt 0 ]]; then
                    local days_ago=$(( (current_epoch - last_used_epoch) / 86400 ))

                    if [[ $days_ago -eq 0 ]]; then
                        last_used="Today"
                    elif [[ $days_ago -eq 1 ]]; then
                        last_used="Yesterday"
                    elif [[ $days_ago -lt 7 ]]; then
                        last_used="${days_ago} days ago"
                    elif [[ $days_ago -lt 30 ]]; then
                        local weeks_ago=$(( days_ago / 7 ))
                        if [[ $weeks_ago -eq 1 ]]; then
                            last_used="1 week ago"
                        else
                            last_used="${weeks_ago} weeks ago"
                        fi
                    elif [[ $days_ago -lt 365 ]]; then
                        local months_ago=$(( days_ago / 30 ))
                        if [[ $months_ago -eq 1 ]]; then
                            last_used="1 month ago"
                        else
                            last_used="${months_ago} months ago"
                        fi
                    else
                        local years_ago=$(( days_ago / 365 ))
                        if [[ $years_ago -eq 1 ]]; then
                            last_used="1 year ago"
                        else
                            last_used="${years_ago} years ago"
                        fi
                    fi
                fi
            else
                # Fallback to file modification time if no usage metadata
                last_used_epoch=$(stat -f%m "$app_path" 2>/dev/null || echo "0")
                if [[ $last_used_epoch -gt 0 ]]; then
                    local days_ago=$(( (current_epoch - last_used_epoch) / 86400 ))
                    if [[ $days_ago -lt 30 ]]; then
                        last_used="Recent"
                    elif [[ $days_ago -lt 365 ]]; then
                        last_used="This year"
                    else
                        last_used="Old"
                    fi
                fi
            fi
        fi

        # Format: epoch|app_path|display_name|bundle_id|size|last_used_display
        echo "${last_used_epoch}|${app_path}|${display_name}|${bundle_id}|${app_size}|${last_used}" >> "$temp_file"
    done

    echo -e "\rFound $app_count applications ✓" >&2

    # Check if we found any applications
    if [[ ! -s "$temp_file" ]]; then
        rm -f "$temp_file"
        return 1
    fi

    # Sort by last used (oldest first) and return the temp file path
    sort -t'|' -k1,1n "$temp_file" > "${temp_file}.sorted"
    rm -f "$temp_file"
    echo "${temp_file}.sorted"
}

# Load applications into arrays
load_applications() {
    local apps_file="$1"

    if [[ ! -f "$apps_file" || ! -s "$apps_file" ]]; then
        log_warning "No applications found for uninstallation"
        return 1
    fi

    # Clear arrays
    apps_data=()
    selection_state=()

    # Read apps into array
    while IFS='|' read -r epoch app_path app_name bundle_id size last_used; do
        apps_data+=("$epoch|$app_path|$app_name|$bundle_id|$size|$last_used")
        selection_state+=(false)
    done < "$apps_file"

    if [[ ${#apps_data[@]} -eq 0 ]]; then
        log_warning "No applications available for uninstallation"
        return 1
    fi

    return 0
}

# Old display_apps function removed - replaced by new menu system

# Read a single key with proper escape sequence handling
# This function has been replaced by the menu.sh library

# Note: App file discovery and size calculation functions moved to lib/common.sh
# Use find_app_files() and calculate_total_size() from common.sh

# Uninstall selected applications
uninstall_applications() {
    local total_size_freed=0

    log_header "Uninstalling selected applications"

    if [[ ${#selected_apps[@]} -eq 0 ]]; then
        log_warning "No applications selected for uninstallation"
        return 0
    fi

    for selected_app in "${selected_apps[@]}"; do
        IFS='|' read -r epoch app_path app_name bundle_id size last_used <<< "$selected_app"

        echo ""
        log_info "Processing: $app_name"

        # Check if app is running
        if pgrep -f "$app_name" >/dev/null 2>&1; then
            log_warning "$app_name is currently running"
            read -p "  Force quit $app_name? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                pkill -f "$app_name" 2>/dev/null || true
                sleep 2
            else
                log_warning "Skipping $app_name (still running)"
                continue
            fi
        fi

        # Find related files
        local related_files=$(find_app_files "$bundle_id" "$app_name")

        # Calculate total size
        local app_size_kb=$(du -sk "$app_path" 2>/dev/null | awk '{print $1}' || echo "0")
        local related_size_kb=$(calculate_total_size "$related_files")
        local total_kb=$((app_size_kb + related_size_kb))

        # Show what will be removed
        echo -e "  ${YELLOW}Files to be removed:${NC}"
        echo -e "  ${GREEN}✓${NC} Application: $(echo "$app_path" | sed "s|$HOME|~|")"

        while IFS= read -r file; do
            [[ -n "$file" && -e "$file" ]] && echo -e "  ${GREEN}✓${NC} $(echo "$file" | sed "s|$HOME|~|")"
        done <<< "$related_files"

        if [[ $total_kb -gt 1048576 ]]; then  # > 1GB
            local size_display=$(echo "$total_kb" | awk '{printf "%.2fGB", $1/1024/1024}')
        elif [[ $total_kb -gt 1024 ]]; then  # > 1MB
            local size_display=$(echo "$total_kb" | awk '{printf "%.1fMB", $1/1024}')
        else
            local size_display="${total_kb}KB"
        fi

        echo -e "  ${BLUE}Total size: $size_display${NC}"
        echo

        read -p "  Proceed with uninstalling $app_name? (y/N): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Remove the application
            if rm -rf "$app_path" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Removed application"
            else
                log_error "Failed to remove $app_path"
                continue
            fi

            # Remove related files
            while IFS= read -r file; do
                if [[ -n "$file" && -e "$file" ]]; then
                    if rm -rf "$file" 2>/dev/null; then
                        echo -e "  ${GREEN}✓${NC} Removed $(echo "$file" | sed "s|$HOME|~|" | xargs basename)"
                    fi
                fi
            done <<< "$related_files"

            ((total_size_freed += total_kb))
            ((files_cleaned++))
            ((total_items++))

            log_success "$app_name uninstalled successfully"
        else
            log_info "Skipped $app_name"
        fi
    done

    # Show final summary
    echo ""
    log_header "Uninstallation Summary"

    if [[ $total_size_freed -gt 0 ]]; then
        if [[ $total_size_freed -gt 1048576 ]]; then  # > 1GB
            local freed_display=$(echo "$total_size_freed" | awk '{printf "%.2fGB", $1/1024/1024}')
        elif [[ $total_size_freed -gt 1024 ]]; then  # > 1MB
            local freed_display=$(echo "$total_size_freed" | awk '{printf "%.1fMB", $1/1024}')
        else
            local freed_display="${total_size_freed}KB"
        fi

        log_success "Freed $freed_display of disk space"
    fi

    echo "📊 Applications uninstalled: $files_cleaned"
    ((total_size_cleaned += total_size_freed))
}

# Cleanup function - restore cursor and clean up
cleanup() {
    # Restore cursor using common function
    show_cursor
    exit "${1:-0}"
}

# Set trap for cleanup on exit
trap cleanup EXIT INT TERM

# Main function
main() {
    # Hide cursor during operation
    hide_cursor
    
    # Scan applications
    local apps_file=$(scan_applications)

    if [[ ! -f "$apps_file" ]]; then
        log_error "Failed to scan applications"
        return 1
    fi

    # Load applications
    if ! load_applications "$apps_file"; then
        rm -f "$apps_file"
        return 1
    fi

    # Interactive selection using paginated menu
    if ! select_apps_for_uninstall; then
        rm -f "$apps_file"
        return 0
    fi

    # Restore cursor for normal interaction after selection
    show_cursor
    clear
    echo "You selected ${#selected_apps[@]} application(s) for uninstallation:"

    if [[ ${#selected_apps[@]} -gt 0 ]]; then
        for selected_app in "${selected_apps[@]}"; do
            IFS='|' read -r epoch app_path app_name bundle_id size last_used <<< "$selected_app"
            echo "  • $app_name ($size)"
        done
    else
        echo "  No applications to uninstall."
    fi

    echo ""
    # 直接执行批量卸载，确认已在批量卸载函数中处理
    batch_uninstall_applications

    # Cleanup
    rm -f "$apps_file"
}

# Run main function
main "$@"
