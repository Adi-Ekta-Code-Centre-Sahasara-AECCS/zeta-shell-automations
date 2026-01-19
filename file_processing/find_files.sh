#!/bin/bash

# Description: Find all files in a directory and calculate total size
# Usage: find_files.sh <directory> [--pattern <pattern>] [--min-size <size>] [--max-size <size>]

set -e

# Defaults
DIRECTORY="."
PATTERN="*"
MIN_SIZE=""
MAX_SIZE=""
SHOW_HIDDEN=false

show_help() {
    echo "Find Files - Locate files and calculate sizes"
    echo ""
    echo "Usage: find_files.sh <directory> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --pattern <pattern>   File pattern to match (default: *)"
    echo "  --min-size <size>         Minimum file size (e.g., 1k, 1M, 1G)"
    echo "  --max-size <size>         Maximum file size (e.g., 1k, 1M, 1G)"
    echo "  -a, --all                 Include hidden files"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  find_files.sh /home/user"
    echo "  find_files.sh . --pattern '*.txt'"
    echo "  find_files.sh /var/log --min-size 1M"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--pattern)
            PATTERN="$2"
            shift 2
            ;;
        --min-size)
            MIN_SIZE="$2"
            shift 2
            ;;
        --max-size)
            MAX_SIZE="$2"
            shift 2
            ;;
        -a|--all)
            SHOW_HIDDEN=true
            shift
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

echo "=== File Search Results ==="
echo "Directory: $DIRECTORY"
echo "Pattern: $PATTERN"
echo ""

# Build find command
FIND_CMD="find \"$DIRECTORY\""

if [[ "$SHOW_HIDDEN" == "false" ]]; then
    FIND_CMD="$FIND_CMD -not -path '*/\.*'"
fi

FIND_CMD="$FIND_CMD -type f -name \"$PATTERN\""

if [[ -n "$MIN_SIZE" ]]; then
    FIND_CMD="$FIND_CMD -size +$MIN_SIZE"
fi

if [[ -n "$MAX_SIZE" ]]; then
    FIND_CMD="$FIND_CMD -size -$MAX_SIZE"
fi

# Execute and display results
echo "Files Found:"
echo "─────────────────────────────────────────────────────────────"

FILE_COUNT=0
TOTAL_SIZE=0

while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        FILE_COUNT=$((FILE_COUNT + 1))

        # Get file size
        if [[ "$(uname)" == "Darwin" ]]; then
            SIZE=$(stat -f%z "$file" 2>/dev/null || echo 0)
        else
            SIZE=$(stat -c%s "$file" 2>/dev/null || echo 0)
        fi

        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))

        # Human readable size
        if [[ $SIZE -ge 1073741824 ]]; then
            HR_SIZE=$(echo "scale=2; $SIZE / 1073741824" | bc)G
        elif [[ $SIZE -ge 1048576 ]]; then
            HR_SIZE=$(echo "scale=2; $SIZE / 1048576" | bc)M
        elif [[ $SIZE -ge 1024 ]]; then
            HR_SIZE=$(echo "scale=2; $SIZE / 1024" | bc)K
        else
            HR_SIZE="${SIZE}B"
        fi

        printf "  %-60s %10s\n" "$file" "$HR_SIZE"
    fi
done < <(eval "$FIND_CMD" 2>/dev/null)

echo "─────────────────────────────────────────────────────────────"

# Human readable total size
if [[ $TOTAL_SIZE -ge 1073741824 ]]; then
    HR_TOTAL=$(echo "scale=2; $TOTAL_SIZE / 1073741824" | bc)G
elif [[ $TOTAL_SIZE -ge 1048576 ]]; then
    HR_TOTAL=$(echo "scale=2; $TOTAL_SIZE / 1048576" | bc)M
elif [[ $TOTAL_SIZE -ge 1024 ]]; then
    HR_TOTAL=$(echo "scale=2; $TOTAL_SIZE / 1024" | bc)K
else
    HR_TOTAL="${TOTAL_SIZE}B"
fi

echo ""
echo "Summary:"
echo "  Total Files: $FILE_COUNT"
echo "  Total Size:  $HR_TOTAL ($TOTAL_SIZE bytes)"
