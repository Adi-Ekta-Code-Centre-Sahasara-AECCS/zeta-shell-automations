#!/bin/bash

# Description: Identify and optionally kill memory-hogging processes
# Usage: memory_hogs.sh [--threshold <percent>] [--kill]

set -e

THRESHOLD=10
KILL_MODE=false

show_help() {
    echo "Memory Hogs - Find processes using excessive memory"
    echo ""
    echo "Usage: memory_hogs.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --threshold <percent>  Memory threshold (default: 10%)"
    echo "  -k, --kill                 Interactively kill memory hogs"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  memory_hogs.sh"
    echo "  memory_hogs.sh --threshold 5"
    echo "  memory_hogs.sh --threshold 15 --kill"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        -k|--kill)
            KILL_MODE=true
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

echo "=== Memory Hogs Detection ==="
echo "Threshold: ${THRESHOLD}%"
echo "Kill Mode: $KILL_MODE"
echo ""

# Find processes above threshold
echo "Processes using more than ${THRESHOLD}% memory:"
echo "─────────────────────────────────────────────────────────────────────────"
printf "%-8s  %8s  %12s  %s\n" "PID" "MEM%" "RSS" "COMMAND"
echo "─────────────────────────────────────────────────────────────────────────"

HOGS=()

while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $2}')
    mem=$(echo "$line" | awk '{print $4}')
    rss=$(echo "$line" | awk '{print $6}')
    cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')

    # Check if memory is above threshold
    if (( $(echo "$mem > $THRESHOLD" | bc -l) )); then
        HOGS+=("$pid")

        # Convert RSS
        if [[ $rss -ge 1048576 ]]; then
            RSS_HR=$(echo "scale=1; $rss / 1048576" | bc)G
        elif [[ $rss -ge 1024 ]]; then
            RSS_HR=$(echo "scale=1; $rss / 1024" | bc)M
        else
            RSS_HR="${rss}K"
        fi

        CMD_SHORT="${cmd:0:45}"
        printf "%-8s  %8s  %12s  %s\n" "$pid" "$mem" "$RSS_HR" "$CMD_SHORT"
    fi
done < <(ps aux | tail -n +2 | sort -k4 -rn)

echo "─────────────────────────────────────────────────────────────────────────"
echo ""
echo "Found ${#HOGS[@]} memory hog(s)"

if [[ ${#HOGS[@]} -eq 0 ]]; then
    echo "No processes found above ${THRESHOLD}% memory threshold"
    exit 0
fi

if [[ "$KILL_MODE" == "true" && ${#HOGS[@]} -gt 0 ]]; then
    echo ""
    echo "Kill mode enabled. Select processes to terminate:"
    echo ""

    for pid in "${HOGS[@]}"; do
        PROC_NAME=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        MEM=$(ps -p "$pid" -o %mem= 2>/dev/null | tr -d ' ' || echo "?")

        read -p "Kill $PROC_NAME (PID: $pid, MEM: ${MEM}%)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if kill "$pid" 2>/dev/null; then
                echo "  Killed process $pid"
            else
                echo "  Failed to kill $pid (try with sudo)"
            fi
        else
            echo "  Skipped $pid"
        fi
    done
fi

echo ""
echo "Done."
