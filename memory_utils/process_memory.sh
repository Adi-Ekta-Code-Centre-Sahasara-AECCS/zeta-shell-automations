#!/bin/bash

# Description: Display memory usage by process with sorting options
# Usage: process_memory.sh [--top <n>] [--filter <pattern>] [--sort <field>]

set -e

TOP=15
FILTER=""
SORT_FIELD="mem"

show_help() {
    echo "Process Memory - Display memory usage by process"
    echo ""
    echo "Usage: process_memory.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --top <n>         Show top N processes (default: 15)"
    echo "  -f, --filter <pattern> Filter processes by name"
    echo "  -s, --sort <field>    Sort by: mem, cpu, pid (default: mem)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  process_memory.sh"
    echo "  process_memory.sh --top 20"
    echo "  process_memory.sh --filter chrome"
    echo "  process_memory.sh --sort cpu"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--top)
            TOP="$2"
            shift 2
            ;;
        -f|--filter)
            FILTER="$2"
            shift 2
            ;;
        -s|--sort)
            SORT_FIELD="$2"
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

echo "=== Process Memory Usage ==="
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Determine sort column
case "$SORT_FIELD" in
    mem)  SORT_KEY=4 ;;
    cpu)  SORT_KEY=3 ;;
    pid)  SORT_KEY=2 ;;
    *)    SORT_KEY=4 ;;
esac

echo "─────────────────────────────────────────────────────────────────────────"
printf "%-8s  %8s  %8s  %12s  %s\n" "PID" "CPU%" "MEM%" "RSS" "COMMAND"
echo "─────────────────────────────────────────────────────────────────────────"

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    PS_CMD="ps aux"
else
    # Linux
    PS_CMD="ps aux --sort=-rss"
fi

if [[ -n "$FILTER" ]]; then
    $PS_CMD | grep -i "$FILTER" | grep -v "grep" | head -n "$((TOP + 1))" | tail -n "$TOP" | while read -r user pid cpu mem vsz rss tty stat start time command; do
        # Convert RSS from KB to human readable
        RSS_KB=$rss
        if [[ $RSS_KB -ge 1048576 ]]; then
            RSS_HR=$(echo "scale=1; $RSS_KB / 1048576" | bc)G
        elif [[ $RSS_KB -ge 1024 ]]; then
            RSS_HR=$(echo "scale=1; $RSS_KB / 1024" | bc)M
        else
            RSS_HR="${RSS_KB}K"
        fi

        # Truncate command if too long
        CMD_SHORT="${command:0:40}"

        printf "%-8s  %8s  %8s  %12s  %s\n" "$pid" "$cpu" "$mem" "$RSS_HR" "$CMD_SHORT"
    done
else
    $PS_CMD | tail -n +2 | sort -k${SORT_KEY} -rn | head -n "$TOP" | while read -r user pid cpu mem vsz rss tty stat start time command; do
        # Convert RSS from KB to human readable
        RSS_KB=$rss
        if [[ $RSS_KB -ge 1048576 ]]; then
            RSS_HR=$(echo "scale=1; $RSS_KB / 1048576" | bc)G
        elif [[ $RSS_KB -ge 1024 ]]; then
            RSS_HR=$(echo "scale=1; $RSS_KB / 1024" | bc)M
        else
            RSS_HR="${RSS_KB}K"
        fi

        # Truncate command if too long
        CMD_SHORT="${command:0:40}"

        printf "%-8s  %8s  %8s  %12s  %s\n" "$pid" "$cpu" "$mem" "$RSS_HR" "$CMD_SHORT"
    done
fi

echo "─────────────────────────────────────────────────────────────────────────"

# Summary
TOTAL_PROCESSES=$(ps aux | wc -l | tr -d ' ')
echo ""
echo "Total running processes: $((TOTAL_PROCESSES - 1))"
