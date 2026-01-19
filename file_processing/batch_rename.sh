#!/bin/bash

# Description: Batch rename files with pattern matching and replacement
# Usage: batch_rename.sh <directory> --find <pattern> --replace <string> [--dry-run]

set -e

DIRECTORY=""
FIND_PATTERN=""
REPLACE_STRING=""
DRY_RUN=false
RECURSIVE=false

show_help() {
    echo "Batch Rename - Rename multiple files using patterns"
    echo ""
    echo "Usage: batch_rename.sh <directory> --find <pattern> --replace <string> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f, --find <pattern>     Pattern to find in filenames"
    echo "  -r, --replace <string>   String to replace with"
    echo "  -d, --dry-run            Preview changes without renaming"
    echo "  -R, --recursive          Rename files in subdirectories"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  batch_rename.sh ./photos --find 'IMG_' --replace 'photo_'"
    echo "  batch_rename.sh . --find '.jpeg' --replace '.jpg' --dry-run"
    echo "  batch_rename.sh /data --find 'old' --replace 'new' -R"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--find)
            FIND_PATTERN="$2"
            shift 2
            ;;
        -r|--replace)
            REPLACE_STRING="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -R|--recursive)
            RECURSIVE=true
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

# Validate inputs
if [[ -z "$DIRECTORY" || -z "$FIND_PATTERN" ]]; then
    echo "Error: Directory and find pattern are required"
    show_help
    exit 1
fi

if [[ ! -d "$DIRECTORY" ]]; then
    echo "Error: Directory '$DIRECTORY' does not exist"
    exit 1
fi

echo "=== Batch Rename ==="
echo "Directory: $DIRECTORY"
echo "Find: '$FIND_PATTERN'"
echo "Replace: '$REPLACE_STRING'"
echo "Dry Run: $DRY_RUN"
echo ""

# Build find command
DEPTH=""
if [[ "$RECURSIVE" != "true" ]]; then
    DEPTH="-maxdepth 1"
fi

# Find matching files
RENAMED=0
SKIPPED=0

echo "Processing files..."
echo "─────────────────────────────────────────────────────────────"

find "$DIRECTORY" $DEPTH -type f -name "*${FIND_PATTERN}*" 2>/dev/null | while read -r file; do
    DIR=$(dirname "$file")
    FILENAME=$(basename "$file")
    NEW_FILENAME="${FILENAME//$FIND_PATTERN/$REPLACE_STRING}"
    NEW_PATH="$DIR/$NEW_FILENAME"

    if [[ "$FILENAME" == "$NEW_FILENAME" ]]; then
        continue
    fi

    if [[ -e "$NEW_PATH" ]]; then
        echo "[SKIP] $file -> $NEW_PATH (target exists)"
        continue
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[PREVIEW] $FILENAME -> $NEW_FILENAME"
    else
        if mv "$file" "$NEW_PATH" 2>/dev/null; then
            echo "[RENAMED] $FILENAME -> $NEW_FILENAME"
        else
            echo "[FAILED] $FILENAME"
        fi
    fi
done

echo "─────────────────────────────────────────────────────────────"

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "This was a dry run. No files were renamed."
    echo "Remove --dry-run to apply changes."
fi
