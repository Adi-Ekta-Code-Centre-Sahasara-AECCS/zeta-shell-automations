#!/bin/bash

# Description: Analyze disk usage with detailed breakdown by directory
# Usage: disk_usage.sh [directory] [--depth <n>] [--top <n>]

set -e

DIRECTORY="."
DEPTH=1
TOP=10

show_help() {
    echo "Disk Usage Analyzer - Detailed directory size breakdown"
    echo ""
    echo "Usage: disk_usage.sh [directory] [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --depth <n>    Directory depth to analyze (default: 1)"
    echo "  -t, --top <n>      Show top N largest items (default: 10)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  disk_usage.sh /home/user"
    echo "  disk_usage.sh . --depth 2 --top 20"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--depth)
            DEPTH="$2"
            shift 2
            ;;
        -t|--top)
            TOP="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            DIRECTORY="$1"
            shift
            ;;
    esac
done

# Validate directory
if [[ ! -d "$DIRECTORY" ]]; then
    echo "Error: Directory '$DIRECTORY' does not exist"
    exit 1
fi

echo "=== Disk Usage Analysis ==="
echo "Directory: $DIRECTORY"
echo "Depth: $DEPTH"
echo ""

# Get total size
TOTAL=$(du -sh "$DIRECTORY" 2>/dev/null | cut -f1)
echo "Total Size: $TOTAL"
echo ""

echo "=== Top $TOP Largest Items (Depth: $DEPTH) ==="
echo "─────────────────────────────────────────────────────────────"
printf "%-12s  %s\n" "SIZE" "PATH"
echo "─────────────────────────────────────────────────────────────"

du -h -d "$DEPTH" "$DIRECTORY" 2>/dev/null | sort -rh | head -n "$TOP" | while read -r size path; do
    printf "%-12s  %s\n" "$size" "$path"
done

echo "─────────────────────────────────────────────────────────────"
echo ""

echo "=== File Type Breakdown ==="
echo "─────────────────────────────────────────────────────────────"
printf "%-12s  %-8s  %s\n" "SIZE" "COUNT" "EXTENSION"
echo "─────────────────────────────────────────────────────────────"

# Analyze by file extension
find "$DIRECTORY" -type f 2>/dev/null | while read -r file; do
    EXT="${file##*.}"
    if [[ "$EXT" == "$file" ]]; then
        EXT="(no ext)"
    fi
    if [[ "$(uname)" == "Darwin" ]]; then
        SIZE=$(stat -f%z "$file" 2>/dev/null || echo 0)
    else
        SIZE=$(stat -c%s "$file" 2>/dev/null || echo 0)
    fi
    echo "$EXT $SIZE"
done | awk '
{
    ext[$1] += $2
    count[$1]++
}
END {
    for (e in ext) {
        size = ext[e]
        if (size >= 1073741824) {
            hr = sprintf("%.2fG", size / 1073741824)
        } else if (size >= 1048576) {
            hr = sprintf("%.2fM", size / 1048576)
        } else if (size >= 1024) {
            hr = sprintf("%.2fK", size / 1024)
        } else {
            hr = sprintf("%dB", size)
        }
        printf "%-12s  %-8d  %s\n", hr, count[e], e
    }
}' | sort -rh | head -n 15

echo "─────────────────────────────────────────────────────────────"
