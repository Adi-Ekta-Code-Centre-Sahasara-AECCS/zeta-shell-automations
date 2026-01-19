#!/bin/bash

# Description: Analyze log files for patterns, errors, and statistics
# Usage: log_analyzer.sh <logfile> [--errors] [--time-range <start> <end>]

set -e

LOG_FILE=""
ERRORS_ONLY=false
SHOW_STATS=true
TIME_START=""
TIME_END=""
PATTERN=""

show_help() {
    echo "Log Analyzer - Analyze log files for patterns and errors"
    echo ""
    echo "Usage: log_analyzer.sh <logfile> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --errors              Show only error/warning lines"
    echo "  -p, --pattern <pattern>   Filter by regex pattern"
    echo "  -t, --top <n>             Show top N frequent messages (default: 10)"
    echo "  --no-stats                Don't show statistics summary"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  log_analyzer.sh /var/log/syslog"
    echo "  log_analyzer.sh app.log --errors"
    echo "  log_analyzer.sh server.log --pattern 'timeout'"
}

TOP_N=10

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -e|--errors)
            ERRORS_ONLY=true
            shift
            ;;
        -p|--pattern)
            PATTERN="$2"
            shift 2
            ;;
        -t|--top)
            TOP_N="$2"
            shift 2
            ;;
        --no-stats)
            SHOW_STATS=false
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            LOG_FILE="$1"
            shift
            ;;
    esac
done

# Check for file
if [[ -z "$LOG_FILE" ]]; then
    echo "Error: Log file is required"
    show_help
    exit 1
fi

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: File '$LOG_FILE' not found"
    exit 1
fi

echo "=== Log Analyzer ==="
echo "File: $LOG_FILE"
echo ""

# Basic file info
FILE_SIZE=$(wc -c < "$LOG_FILE" | tr -d ' ')
TOTAL_LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')

# Human readable size
if [[ $FILE_SIZE -ge 1073741824 ]]; then
    SIZE_HR=$(echo "scale=2; $FILE_SIZE / 1073741824" | bc)GB
elif [[ $FILE_SIZE -ge 1048576 ]]; then
    SIZE_HR=$(echo "scale=2; $FILE_SIZE / 1048576" | bc)MB
elif [[ $FILE_SIZE -ge 1024 ]]; then
    SIZE_HR=$(echo "scale=2; $FILE_SIZE / 1024" | bc)KB
else
    SIZE_HR="${FILE_SIZE}B"
fi

echo "=== File Overview ==="
echo "─────────────────────────────────────────────────────────────"
echo "File size: $SIZE_HR ($FILE_SIZE bytes)"
echo "Total lines: $TOTAL_LINES"
echo ""

if [[ "$SHOW_STATS" == "true" ]]; then
    echo "=== Log Level Statistics ==="
    echo "─────────────────────────────────────────────────────────────"

    # Count log levels (case insensitive)
    ERRORS=$(grep -ciE "(error|fatal|critical|exception|fail)" "$LOG_FILE" 2>/dev/null || echo 0)
    WARNINGS=$(grep -ciE "(warn|warning)" "$LOG_FILE" 2>/dev/null || echo 0)
    INFO=$(grep -ciE "(info)" "$LOG_FILE" 2>/dev/null || echo 0)
    DEBUG=$(grep -ciE "(debug|trace)" "$LOG_FILE" 2>/dev/null || echo 0)

    printf "%-15s %8d  " "ERRORS:" "$ERRORS"
    if [[ $ERRORS -gt 0 ]]; then
        echo "(!!!)"
    else
        echo ""
    fi
    printf "%-15s %8d\n" "WARNINGS:" "$WARNINGS"
    printf "%-15s %8d\n" "INFO:" "$INFO"
    printf "%-15s %8d\n" "DEBUG:" "$DEBUG"
    echo ""

    # Error percentage
    if [[ $TOTAL_LINES -gt 0 ]]; then
        ERROR_PCT=$(echo "scale=2; $ERRORS * 100 / $TOTAL_LINES" | bc)
        echo "Error rate: ${ERROR_PCT}%"
    fi
    echo ""
fi

if [[ "$ERRORS_ONLY" == "true" ]]; then
    echo "=== Error and Warning Lines ==="
    echo "─────────────────────────────────────────────────────────────"

    grep -iE "(error|fatal|critical|exception|fail|warn)" "$LOG_FILE" 2>/dev/null | head -50

    ERROR_COUNT=$(grep -ciE "(error|fatal|critical|exception|fail|warn)" "$LOG_FILE" 2>/dev/null || echo 0)
    if [[ $ERROR_COUNT -gt 50 ]]; then
        echo ""
        echo "... (showing first 50 of $ERROR_COUNT matches)"
    fi
    echo ""
fi

if [[ -n "$PATTERN" ]]; then
    echo "=== Pattern Matches: '$PATTERN' ==="
    echo "─────────────────────────────────────────────────────────────"

    MATCHES=$(grep -c "$PATTERN" "$LOG_FILE" 2>/dev/null || echo 0)
    echo "Found $MATCHES matches"
    echo ""

    grep -n "$PATTERN" "$LOG_FILE" 2>/dev/null | head -30

    if [[ $MATCHES -gt 30 ]]; then
        echo ""
        echo "... (showing first 30 matches)"
    fi
    echo ""
fi

echo "=== Most Frequent Messages ==="
echo "─────────────────────────────────────────────────────────────"

# Extract message part (after timestamp/level) and count
# This attempts to normalize log messages
cat "$LOG_FILE" | \
    sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}[T ][0-9:.]*[Z ]*//g' | \
    sed 's/^[A-Za-z]\{3\} [0-9 ]\{1,2\} [0-9:]*//g' | \
    sed 's/^\[[^]]*\]//g' | \
    sed 's/^[A-Z]*://g' | \
    sed 's/[0-9]\{1,\}/N/g' | \
    sort | uniq -c | sort -rn | head -"$TOP_N" | while read -r count msg; do
    if [[ -n "$msg" ]]; then
        # Truncate long messages
        MSG_SHORT="${msg:0:60}"
        if [[ ${#msg} -gt 60 ]]; then
            MSG_SHORT="${MSG_SHORT}..."
        fi
        printf "%8d  %s\n" "$count" "$MSG_SHORT"
    fi
done

echo ""

echo "=== Timeline ==="
echo "─────────────────────────────────────────────────────────────"

# Try to extract first and last timestamp
FIRST_LINE=$(head -1 "$LOG_FILE")
LAST_LINE=$(tail -1 "$LOG_FILE")

# Common timestamp patterns
FIRST_TS=$(echo "$FIRST_LINE" | grep -oE "^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9:.]+|^[A-Za-z]{3} [0-9 ]{1,2} [0-9:]+")
LAST_TS=$(echo "$LAST_LINE" | grep -oE "^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9:.]+|^[A-Za-z]{3} [0-9 ]{1,2} [0-9:]+")

if [[ -n "$FIRST_TS" ]]; then
    echo "First entry: $FIRST_TS"
fi
if [[ -n "$LAST_TS" ]]; then
    echo "Last entry:  $LAST_TS"
fi

echo ""
echo "Analysis complete."
