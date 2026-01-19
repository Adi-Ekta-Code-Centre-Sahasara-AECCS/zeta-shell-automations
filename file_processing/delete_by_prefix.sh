#!/bin/bash

# Description: Delete files starting with a specific prefix or pattern
# Usage: delete_by_prefix.sh <directory> <prefix> [--dry-run] [--recursive]

set -e

DIRECTORY=""
PREFIX=""
DRY_RUN=false
RECURSIVE=false
FORCE=false

show_help() {
    echo "Delete By Prefix - Remove files matching a prefix"
    echo ""
    echo "Usage: delete_by_prefix.sh <directory> <prefix> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --dry-run      Show what would be deleted without removing"
    echo "  -r, --recursive    Delete recursively in subdirectories"
    echo "  -f, --force        Don't ask for confirmation"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  delete_by_prefix.sh /tmp temp_"
    echo "  delete_by_prefix.sh . .DS_Store --recursive"
    echo "  delete_by_prefix.sh /var/log old_ --dry-run"
}

# Parse arguments
POSITIONAL=()
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
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Set positional arguments
if [[ ${#POSITIONAL[@]} -lt 2 ]]; then
    echo "Error: Directory and prefix are required"
    show_help
    exit 1
fi

DIRECTORY="${POSITIONAL[0]}"
PREFIX="${POSITIONAL[1]}"

# Validate directory
if [[ ! -d "$DIRECTORY" ]]; then
    echo "Error: Directory '$DIRECTORY' does not exist"
    exit 1
fi

echo "=== Delete By Prefix ==="
echo "Directory: $DIRECTORY"
echo "Prefix: $PREFIX"
echo "Recursive: $RECURSIVE"
echo "Dry Run: $DRY_RUN"
echo ""

# Build find command
FIND_DEPTH="-maxdepth 1"
if [[ "$RECURSIVE" == "true" ]]; then
    FIND_DEPTH=""
fi

# Find matching files
mapfile -t FILES < <(find "$DIRECTORY" $FIND_DEPTH -type f -name "${PREFIX}*" 2>/dev/null)

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "No files found matching prefix '$PREFIX'"
    exit 0
fi

echo "Files matching '${PREFIX}*':"
echo "─────────────────────────────────────────────────────────────"

TOTAL_SIZE=0
for file in "${FILES[@]}"; do
    if [[ "$(uname)" == "Darwin" ]]; then
        SIZE=$(stat -f%z "$file" 2>/dev/null || echo 0)
    else
        SIZE=$(stat -c%s "$file" 2>/dev/null || echo 0)
    fi
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE))

    if [[ $SIZE -ge 1048576 ]]; then
        HR_SIZE=$(echo "scale=2; $SIZE / 1048576" | bc)M
    elif [[ $SIZE -ge 1024 ]]; then
        HR_SIZE=$(echo "scale=2; $SIZE / 1024" | bc)K
    else
        HR_SIZE="${SIZE}B"
    fi

    printf "  %-60s %10s\n" "$file" "$HR_SIZE"
done

echo "─────────────────────────────────────────────────────────────"
echo "Total files: ${#FILES[@]}"
echo "Total size: $TOTAL_SIZE bytes"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] No files were deleted"
    exit 0
fi

# Confirm deletion
if [[ "$FORCE" != "true" ]]; then
    read -p "Delete ${#FILES[@]} files? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 0
    fi
fi

# Delete files
DELETED=0
for file in "${FILES[@]}"; do
    if rm "$file" 2>/dev/null; then
        DELETED=$((DELETED + 1))
        echo "Deleted: $file"
    else
        echo "Failed to delete: $file"
    fi
done

echo ""
echo "Successfully deleted $DELETED of ${#FILES[@]} files"
