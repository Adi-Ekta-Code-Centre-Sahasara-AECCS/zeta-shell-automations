#!/bin/bash

# Description: Find duplicate files based on content hash
# Usage: find_duplicates.sh <directory> [--delete] [--min-size <size>]

set -e

DIRECTORY="."
DELETE=false
MIN_SIZE="1"

show_help() {
    echo "Find Duplicates - Locate duplicate files by content"
    echo ""
    echo "Usage: find_duplicates.sh <directory> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --delete           Delete duplicate files (keeps first occurrence)"
    echo "  --min-size <size>  Minimum file size to check (default: 1 byte)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  find_duplicates.sh /home/user/photos"
    echo "  find_duplicates.sh . --min-size 1M"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --delete)
            DELETE=true
            shift
            ;;
        --min-size)
            MIN_SIZE="$2"
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

echo "=== Finding Duplicate Files ==="
echo "Directory: $DIRECTORY"
echo "Minimum Size: $MIN_SIZE"
echo ""
echo "Calculating file hashes..."

# Create temp file for hash storage
HASH_FILE=$(mktemp)
trap "rm -f $HASH_FILE" EXIT

# Find files and calculate hashes
find "$DIRECTORY" -type f -size +"$MIN_SIZE"c 2>/dev/null | while read -r file; do
    if [[ -f "$file" ]]; then
        if command -v md5sum &>/dev/null; then
            HASH=$(md5sum "$file" 2>/dev/null | awk '{print $1}')
        elif command -v md5 &>/dev/null; then
            HASH=$(md5 -q "$file" 2>/dev/null)
        else
            echo "Error: No MD5 command available"
            exit 1
        fi
        echo "$HASH|$file" >> "$HASH_FILE"
    fi
done

echo ""
echo "=== Duplicate Files Found ==="
echo "─────────────────────────────────────────────────────────────"

# Find duplicates
DUPLICATES=0
SAVED_SPACE=0

sort "$HASH_FILE" | uniq -d -w 32 | while read -r line; do
    HASH="${line%%|*}"

    echo ""
    echo "Hash: $HASH"

    FIRST=true
    grep "^$HASH|" "$HASH_FILE" | while IFS='|' read -r _ filepath; do
        if [[ "$(uname)" == "Darwin" ]]; then
            SIZE=$(stat -f%z "$filepath" 2>/dev/null || echo 0)
        else
            SIZE=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
        fi

        if [[ "$FIRST" == "true" ]]; then
            echo "  [KEEP] $filepath ($SIZE bytes)"
            FIRST=false
        else
            echo "  [DUP]  $filepath ($SIZE bytes)"
            DUPLICATES=$((DUPLICATES + 1))
            SAVED_SPACE=$((SAVED_SPACE + SIZE))

            if [[ "$DELETE" == "true" ]]; then
                rm "$filepath" && echo "         Deleted!"
            fi
        fi
    done
done

echo ""
echo "─────────────────────────────────────────────────────────────"

# Count duplicates from the hash file
DUP_COUNT=$(sort "$HASH_FILE" | cut -d'|' -f1 | uniq -d | wc -l | tr -d ' ')

if [[ "$DUP_COUNT" -eq 0 ]]; then
    echo "No duplicate files found"
else
    echo "Duplicate groups found: $DUP_COUNT"
    if [[ "$DELETE" == "true" ]]; then
        echo "Duplicate files were deleted"
    else
        echo "Use --delete to remove duplicates"
    fi
fi
