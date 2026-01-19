#!/bin/bash

# Description: Clear system caches and temporary files to free memory
# Usage: cache_clear.sh [--dry-run] [--all]

set -e

DRY_RUN=false
CLEAR_ALL=false

show_help() {
    echo "Cache Clear - Free up memory by clearing caches"
    echo ""
    echo "Usage: cache_clear.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --dry-run    Show what would be cleared without removing"
    echo "  -a, --all        Clear all caches (more aggressive)"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "This script clears:"
    echo "  - User cache directories"
    echo "  - Temporary files"
    echo "  - Thumbnail caches"
    echo "  - Application caches (with --all)"
    echo ""
    echo "Note: Some operations may require sudo for system caches"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -a|--all)
            CLEAR_ALL=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            shift
            ;;
    esac
done

echo "=== Cache Clear Utility ==="
echo "Dry Run: $DRY_RUN"
echo "Clear All: $CLEAR_ALL"
echo ""

TOTAL_FREED=0

calculate_size() {
    local path="$1"
    if [[ -e "$path" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            du -sk "$path" 2>/dev/null | awk '{print $1}' || echo 0
        else
            du -sk "$path" 2>/dev/null | awk '{print $1}' || echo 0
        fi
    else
        echo 0
    fi
}

clear_directory() {
    local path="$1"
    local name="$2"

    if [[ ! -d "$path" ]]; then
        echo "  [SKIP] $name - not found"
        return
    fi

    local size_kb
    size_kb=$(calculate_size "$path")

    if [[ $size_kb -ge 1024 ]]; then
        SIZE_HR=$(echo "scale=2; $size_kb / 1024" | bc)M
    else
        SIZE_HR="${size_kb}K"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [PREVIEW] $name: $SIZE_HR would be freed"
    else
        if rm -rf "$path"/* 2>/dev/null; then
            echo "  [CLEARED] $name: $SIZE_HR freed"
            TOTAL_FREED=$((TOTAL_FREED + size_kb))
        else
            echo "  [FAILED] $name: permission denied"
        fi
    fi
}

echo "Clearing caches..."
echo "─────────────────────────────────────────────────────────────"

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS caches
    clear_directory "$HOME/Library/Caches" "User Caches"
    clear_directory "/private/var/folders" "System Temp" 2>/dev/null || true
    clear_directory "$HOME/Library/Logs" "User Logs"

    if [[ "$CLEAR_ALL" == "true" ]]; then
        clear_directory "$HOME/Library/Application Support/Caches" "App Support Caches"
        clear_directory "/Library/Caches" "System Caches"

        # Clear DNS cache
        if [[ "$DRY_RUN" != "true" ]]; then
            echo "  [CLEAR] Flushing DNS cache..."
            sudo dscacheutil -flushcache 2>/dev/null && sudo killall -HUP mDNSResponder 2>/dev/null || true
        fi
    fi
else
    # Linux caches
    clear_directory "$HOME/.cache" "User Cache"
    clear_directory "/tmp" "Temp Directory"
    clear_directory "/var/tmp" "Var Temp"
    clear_directory "$HOME/.thumbnails" "Thumbnails"

    if [[ "$CLEAR_ALL" == "true" ]]; then
        clear_directory "/var/cache" "System Cache"

        # Clear page cache (requires root)
        if [[ "$DRY_RUN" != "true" ]]; then
            echo "  [CLEAR] Dropping page cache..."
            echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || echo "  [SKIP] Page cache - requires root"
        fi
    fi
fi

echo "─────────────────────────────────────────────────────────────"

if [[ $TOTAL_FREED -ge 1048576 ]]; then
    TOTAL_HR=$(echo "scale=2; $TOTAL_FREED / 1048576" | bc)G
elif [[ $TOTAL_FREED -ge 1024 ]]; then
    TOTAL_HR=$(echo "scale=2; $TOTAL_FREED / 1024" | bc)M
else
    TOTAL_HR="${TOTAL_FREED}K"
fi

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo "This was a dry run. No files were removed."
else
    echo "Total space freed: $TOTAL_HR"
fi
