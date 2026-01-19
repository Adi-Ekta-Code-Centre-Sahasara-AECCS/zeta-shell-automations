#!/bin/bash

# Description: Display detailed system memory usage statistics
# Usage: system_memory.sh [--watch] [--interval <seconds>]

set -e

WATCH=false
INTERVAL=2

show_help() {
    echo "System Memory - Display memory usage statistics"
    echo ""
    echo "Usage: system_memory.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -w, --watch              Continuously monitor memory"
    echo "  -i, --interval <sec>     Update interval in seconds (default: 2)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  system_memory.sh"
    echo "  system_memory.sh --watch"
    echo "  system_memory.sh --watch --interval 5"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -w|--watch)
            WATCH=true
            shift
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
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

format_bytes() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
    elif [[ $bytes -ge 1024 ]]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc) KB"
    else
        echo "$bytes B"
    fi
}

display_memory() {
    clear 2>/dev/null || true
    echo "=== System Memory Usage ==="
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        PAGE_SIZE=$(sysctl -n hw.pagesize)

        # Get memory pages
        VM_STAT=$(vm_stat)
        PAGES_FREE=$(echo "$VM_STAT" | grep "Pages free" | awk '{print $3}' | tr -d '.')
        PAGES_ACTIVE=$(echo "$VM_STAT" | grep "Pages active" | awk '{print $3}' | tr -d '.')
        PAGES_INACTIVE=$(echo "$VM_STAT" | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
        PAGES_SPECULATIVE=$(echo "$VM_STAT" | grep "Pages speculative" | awk '{print $3}' | tr -d '.')
        PAGES_WIRED=$(echo "$VM_STAT" | grep "Pages wired down" | awk '{print $4}' | tr -d '.')
        PAGES_COMPRESSED=$(echo "$VM_STAT" | grep "Pages stored in compressor" | awk '{print $5}' | tr -d '.')

        FREE=$((PAGES_FREE * PAGE_SIZE))
        ACTIVE=$((PAGES_ACTIVE * PAGE_SIZE))
        INACTIVE=$((PAGES_INACTIVE * PAGE_SIZE))
        SPECULATIVE=$((PAGES_SPECULATIVE * PAGE_SIZE))
        WIRED=$((PAGES_WIRED * PAGE_SIZE))
        COMPRESSED=${PAGES_COMPRESSED:-0}
        COMPRESSED=$((COMPRESSED * PAGE_SIZE))

        TOTAL=$(sysctl -n hw.memsize)
        USED=$((TOTAL - FREE - INACTIVE - SPECULATIVE))

        echo "─────────────────────────────────────────────────────────────"
        printf "%-20s %15s\n" "Total Memory:" "$(format_bytes $TOTAL)"
        printf "%-20s %15s\n" "Used:" "$(format_bytes $USED)"
        printf "%-20s %15s\n" "Free:" "$(format_bytes $FREE)"
        echo "─────────────────────────────────────────────────────────────"
        printf "%-20s %15s\n" "Active:" "$(format_bytes $ACTIVE)"
        printf "%-20s %15s\n" "Inactive:" "$(format_bytes $INACTIVE)"
        printf "%-20s %15s\n" "Wired:" "$(format_bytes $WIRED)"
        printf "%-20s %15s\n" "Compressed:" "$(format_bytes $COMPRESSED)"
        echo "─────────────────────────────────────────────────────────────"

        # Usage percentage
        USAGE_PCT=$(echo "scale=1; $USED * 100 / $TOTAL" | bc)
        echo ""
        echo "Memory Usage: $USAGE_PCT%"

        # Visual bar
        BAR_WIDTH=50
        FILLED=$(echo "scale=0; $USAGE_PCT * $BAR_WIDTH / 100" | bc)
        printf "["
        for ((i=0; i<FILLED; i++)); do printf "#"; done
        for ((i=FILLED; i<BAR_WIDTH; i++)); do printf "-"; done
        printf "]\n"

    else
        # Linux
        MEM_INFO=$(cat /proc/meminfo)

        TOTAL=$(echo "$MEM_INFO" | grep "^MemTotal:" | awk '{print $2}')
        FREE=$(echo "$MEM_INFO" | grep "^MemFree:" | awk '{print $2}')
        AVAILABLE=$(echo "$MEM_INFO" | grep "^MemAvailable:" | awk '{print $2}')
        BUFFERS=$(echo "$MEM_INFO" | grep "^Buffers:" | awk '{print $2}')
        CACHED=$(echo "$MEM_INFO" | grep "^Cached:" | awk '{print $2}')
        SWAP_TOTAL=$(echo "$MEM_INFO" | grep "^SwapTotal:" | awk '{print $2}')
        SWAP_FREE=$(echo "$MEM_INFO" | grep "^SwapFree:" | awk '{print $2}')

        # Convert to bytes (values are in KB)
        TOTAL=$((TOTAL * 1024))
        FREE=$((FREE * 1024))
        AVAILABLE=$((AVAILABLE * 1024))
        BUFFERS=$((BUFFERS * 1024))
        CACHED=$((CACHED * 1024))
        SWAP_TOTAL=$((SWAP_TOTAL * 1024))
        SWAP_FREE=$((SWAP_FREE * 1024))

        USED=$((TOTAL - FREE - BUFFERS - CACHED))
        SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))

        echo "─────────────────────────────────────────────────────────────"
        printf "%-20s %15s\n" "Total Memory:" "$(format_bytes $TOTAL)"
        printf "%-20s %15s\n" "Used:" "$(format_bytes $USED)"
        printf "%-20s %15s\n" "Free:" "$(format_bytes $FREE)"
        printf "%-20s %15s\n" "Available:" "$(format_bytes $AVAILABLE)"
        echo "─────────────────────────────────────────────────────────────"
        printf "%-20s %15s\n" "Buffers:" "$(format_bytes $BUFFERS)"
        printf "%-20s %15s\n" "Cached:" "$(format_bytes $CACHED)"
        echo "─────────────────────────────────────────────────────────────"
        printf "%-20s %15s\n" "Swap Total:" "$(format_bytes $SWAP_TOTAL)"
        printf "%-20s %15s\n" "Swap Used:" "$(format_bytes $SWAP_USED)"
        printf "%-20s %15s\n" "Swap Free:" "$(format_bytes $SWAP_FREE)"
        echo "─────────────────────────────────────────────────────────────"

        # Usage percentage
        USAGE_PCT=$(echo "scale=1; $USED * 100 / $TOTAL" | bc)
        echo ""
        echo "Memory Usage: $USAGE_PCT%"

        # Visual bar
        BAR_WIDTH=50
        FILLED=$(echo "scale=0; $USAGE_PCT * $BAR_WIDTH / 100" | bc)
        printf "["
        for ((i=0; i<FILLED; i++)); do printf "#"; done
        for ((i=FILLED; i<BAR_WIDTH; i++)); do printf "-"; done
        printf "]\n"
    fi
}

# Main execution
if [[ "$WATCH" == "true" ]]; then
    echo "Monitoring memory (Ctrl+C to stop)..."
    while true; do
        display_memory
        sleep "$INTERVAL"
    done
else
    display_memory
fi
