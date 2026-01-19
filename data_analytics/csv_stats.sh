#!/bin/bash

# Description: Analyze CSV files with statistics and summaries
# Usage: csv_stats.sh <file.csv> [--column <name>] [--delimiter <char>]

set -e

CSV_FILE=""
COLUMN=""
DELIMITER=","
SHOW_PREVIEW=true

show_help() {
    echo "CSV Stats - Analyze CSV file statistics"
    echo ""
    echo "Usage: csv_stats.sh <file.csv> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --column <name>      Analyze specific column"
    echo "  -d, --delimiter <char>   Field delimiter (default: ,)"
    echo "  --no-preview             Don't show data preview"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  csv_stats.sh data.csv"
    echo "  csv_stats.sh sales.csv --column revenue"
    echo "  csv_stats.sh data.tsv --delimiter $'\\t'"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--column)
            COLUMN="$2"
            shift 2
            ;;
        -d|--delimiter)
            DELIMITER="$2"
            shift 2
            ;;
        --no-preview)
            SHOW_PREVIEW=false
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            CSV_FILE="$1"
            shift
            ;;
    esac
done

# Check for file
if [[ -z "$CSV_FILE" ]]; then
    echo "Error: CSV file is required"
    show_help
    exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
    echo "Error: File '$CSV_FILE' not found"
    exit 1
fi

echo "=== CSV Statistics ==="
echo "File: $CSV_FILE"
echo "Delimiter: '$DELIMITER'"
echo ""

# Get basic file info
FILE_SIZE=$(wc -c < "$CSV_FILE" | tr -d ' ')
ROW_COUNT=$(wc -l < "$CSV_FILE" | tr -d ' ')
HEADER=$(head -1 "$CSV_FILE")
COL_COUNT=$(echo "$HEADER" | awk -F"$DELIMITER" '{print NF}')

echo "=== File Overview ==="
echo "─────────────────────────────────────────────────────────────"
echo "File size: $FILE_SIZE bytes"
echo "Total rows: $ROW_COUNT (including header)"
echo "Data rows: $((ROW_COUNT - 1))"
echo "Columns: $COL_COUNT"
echo ""

echo "=== Column Names ==="
echo "─────────────────────────────────────────────────────────────"
IFS="$DELIMITER" read -ra COLUMNS <<< "$HEADER"
for i in "${!COLUMNS[@]}"; do
    echo "  $((i + 1)). ${COLUMNS[$i]}"
done
echo ""

# Show data preview
if [[ "$SHOW_PREVIEW" == "true" ]]; then
    echo "=== Data Preview (first 5 rows) ==="
    echo "─────────────────────────────────────────────────────────────"
    head -6 "$CSV_FILE" | column -t -s"$DELIMITER" 2>/dev/null || head -6 "$CSV_FILE"
    echo ""
fi

# Column-specific analysis
if [[ -n "$COLUMN" ]]; then
    # Find column index
    COL_INDEX=0
    for i in "${!COLUMNS[@]}"; do
        if [[ "${COLUMNS[$i]}" == "$COLUMN" ]]; then
            COL_INDEX=$((i + 1))
            break
        fi
    done

    if [[ $COL_INDEX -eq 0 ]]; then
        echo "Error: Column '$COLUMN' not found"
        exit 1
    fi

    echo "=== Column Analysis: $COLUMN ==="
    echo "─────────────────────────────────────────────────────────────"

    # Extract column data (skip header)
    COLUMN_DATA=$(tail -n +2 "$CSV_FILE" | awk -F"$DELIMITER" "{print \$$COL_INDEX}")

    # Count non-empty values
    NON_EMPTY=$(echo "$COLUMN_DATA" | grep -c -v "^$" || echo 0)
    EMPTY=$((ROW_COUNT - 1 - NON_EMPTY))

    echo "Non-empty values: $NON_EMPTY"
    echo "Empty values: $EMPTY"

    # Check if numeric
    NUMERIC_COUNT=$(echo "$COLUMN_DATA" | grep -cE "^-?[0-9]+\.?[0-9]*$" || echo 0)

    if [[ $NUMERIC_COUNT -gt $((NON_EMPTY / 2)) ]]; then
        echo ""
        echo "Numeric Statistics:"

        # Calculate statistics using awk
        echo "$COLUMN_DATA" | grep -E "^-?[0-9]+\.?[0-9]*$" | awk '
        BEGIN { min = ""; max = ""; sum = 0; count = 0 }
        {
            if (min == "" || $1 < min) min = $1
            if (max == "" || $1 > max) max = $1
            sum += $1
            count++
            values[count] = $1
        }
        END {
            if (count > 0) {
                mean = sum / count

                # Sort for median
                for (i = 1; i <= count; i++) {
                    for (j = i + 1; j <= count; j++) {
                        if (values[i] > values[j]) {
                            temp = values[i]
                            values[i] = values[j]
                            values[j] = temp
                        }
                    }
                }

                if (count % 2 == 1) {
                    median = values[int(count/2) + 1]
                } else {
                    median = (values[count/2] + values[count/2 + 1]) / 2
                }

                printf "  Min: %.4f\n", min
                printf "  Max: %.4f\n", max
                printf "  Sum: %.4f\n", sum
                printf "  Mean: %.4f\n", mean
                printf "  Median: %.4f\n", median
                printf "  Count: %d\n", count
            }
        }'
    else
        echo ""
        echo "Value Frequency (top 10):"
        echo "$COLUMN_DATA" | sort | uniq -c | sort -rn | head -10 | while read -r count value; do
            printf "  %6d  %s\n" "$count" "$value"
        done
    fi
else
    # Quick stats for all columns
    echo "=== Column Type Summary ==="
    echo "─────────────────────────────────────────────────────────────"

    for i in "${!COLUMNS[@]}"; do
        COL_NAME="${COLUMNS[$i]}"
        COL_INDEX=$((i + 1))

        # Sample first 100 values
        SAMPLE=$(tail -n +2 "$CSV_FILE" | head -100 | awk -F"$DELIMITER" "{print \$$COL_INDEX}")
        NUMERIC_COUNT=$(echo "$SAMPLE" | grep -cE "^-?[0-9]+\.?[0-9]*$" || echo 0)
        TOTAL_SAMPLE=$(echo "$SAMPLE" | grep -c -v "^$" || echo 0)

        if [[ $TOTAL_SAMPLE -gt 0 ]]; then
            PCT=$((NUMERIC_COUNT * 100 / TOTAL_SAMPLE))
            if [[ $PCT -gt 80 ]]; then
                TYPE="numeric"
            else
                TYPE="text"
            fi
        else
            TYPE="empty"
        fi

        printf "  %-30s %s\n" "$COL_NAME" "($TYPE)"
    done
fi

echo ""
echo "Analysis complete."
