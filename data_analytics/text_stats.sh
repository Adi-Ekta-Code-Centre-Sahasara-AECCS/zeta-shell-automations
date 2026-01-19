#!/bin/bash

# Description: Analyze text files for word count, frequency, and readability
# Usage: text_stats.sh <file> [--top <n>] [--ngrams <n>]

set -e

TEXT_FILE=""
TOP_N=20
NGRAM_SIZE=1

show_help() {
    echo "Text Stats - Analyze text file statistics"
    echo ""
    echo "Usage: text_stats.sh <file> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --top <n>        Show top N frequent words (default: 20)"
    echo "  -n, --ngrams <n>     Analyze n-grams (default: 1 for words)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  text_stats.sh document.txt"
    echo "  text_stats.sh article.md --top 50"
    echo "  text_stats.sh book.txt --ngrams 2"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--top)
            TOP_N="$2"
            shift 2
            ;;
        -n|--ngrams)
            NGRAM_SIZE="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            TEXT_FILE="$1"
            shift
            ;;
    esac
done

# Check for file
if [[ -z "$TEXT_FILE" ]]; then
    echo "Error: Text file is required"
    show_help
    exit 1
fi

if [[ ! -f "$TEXT_FILE" ]]; then
    echo "Error: File '$TEXT_FILE' not found"
    exit 1
fi

echo "=== Text Statistics ==="
echo "File: $TEXT_FILE"
echo ""

# Basic counts
CHAR_COUNT=$(wc -c < "$TEXT_FILE" | tr -d ' ')
WORD_COUNT=$(wc -w < "$TEXT_FILE" | tr -d ' ')
LINE_COUNT=$(wc -l < "$TEXT_FILE" | tr -d ' ')

# Sentence count (approximate)
SENTENCE_COUNT=$(grep -oE '[.!?]+' "$TEXT_FILE" | wc -l | tr -d ' ')
if [[ $SENTENCE_COUNT -eq 0 ]]; then
    SENTENCE_COUNT=1
fi

# Paragraph count (blank line separated)
PARA_COUNT=$(grep -c "^$" "$TEXT_FILE" || echo 0)
PARA_COUNT=$((PARA_COUNT + 1))

echo "=== Basic Counts ==="
echo "─────────────────────────────────────────────────────────────"
printf "%-20s %10d\n" "Characters:" "$CHAR_COUNT"
printf "%-20s %10d\n" "Words:" "$WORD_COUNT"
printf "%-20s %10d\n" "Lines:" "$LINE_COUNT"
printf "%-20s %10d\n" "Sentences:" "$SENTENCE_COUNT"
printf "%-20s %10d\n" "Paragraphs:" "$PARA_COUNT"
echo ""

# Average calculations
if [[ $WORD_COUNT -gt 0 && $SENTENCE_COUNT -gt 0 ]]; then
    AVG_WORD_LENGTH=$(echo "scale=2; $CHAR_COUNT / $WORD_COUNT" | bc)
    AVG_SENTENCE_LENGTH=$(echo "scale=2; $WORD_COUNT / $SENTENCE_COUNT" | bc)
    WORDS_PER_LINE=$(echo "scale=2; $WORD_COUNT / $LINE_COUNT" | bc)

    echo "=== Averages ==="
    echo "─────────────────────────────────────────────────────────────"
    printf "%-25s %8s\n" "Avg word length:" "$AVG_WORD_LENGTH chars"
    printf "%-25s %8s\n" "Avg sentence length:" "$AVG_SENTENCE_LENGTH words"
    printf "%-25s %8s\n" "Avg words per line:" "$WORDS_PER_LINE"
    echo ""

    # Readability metrics
    # Flesch Reading Ease approximation
    # 206.835 - 1.015 * (words/sentences) - 84.6 * (syllables/words)
    # Simplified: using avg chars per word as proxy for syllables
    SYLLABLES_PER_WORD=$(echo "scale=2; $AVG_WORD_LENGTH / 3" | bc)
    FLESCH=$(echo "scale=1; 206.835 - (1.015 * $AVG_SENTENCE_LENGTH) - (84.6 * $SYLLABLES_PER_WORD)" | bc)

    echo "=== Readability ==="
    echo "─────────────────────────────────────────────────────────────"
    echo "Flesch Reading Ease: $FLESCH"

    # Interpret score
    if (( $(echo "$FLESCH >= 90" | bc -l) )); then
        echo "Level: Very Easy (5th grade)"
    elif (( $(echo "$FLESCH >= 80" | bc -l) )); then
        echo "Level: Easy (6th grade)"
    elif (( $(echo "$FLESCH >= 70" | bc -l) )); then
        echo "Level: Fairly Easy (7th grade)"
    elif (( $(echo "$FLESCH >= 60" | bc -l) )); then
        echo "Level: Standard (8th-9th grade)"
    elif (( $(echo "$FLESCH >= 50" | bc -l) )); then
        echo "Level: Fairly Difficult (10th-12th grade)"
    elif (( $(echo "$FLESCH >= 30" | bc -l) )); then
        echo "Level: Difficult (College)"
    else
        echo "Level: Very Difficult (Graduate)"
    fi
    echo ""
fi

echo "=== Word Frequency (Top $TOP_N) ==="
echo "─────────────────────────────────────────────────────────────"

if [[ $NGRAM_SIZE -eq 1 ]]; then
    # Single words
    cat "$TEXT_FILE" | \
        tr '[:upper:]' '[:lower:]' | \
        tr -cs '[:alpha:]' '\n' | \
        grep -v "^$" | \
        sort | uniq -c | sort -rn | \
        head -"$TOP_N" | while read -r count word; do
        if [[ -n "$word" ]]; then
            printf "%8d  %s\n" "$count" "$word"
        fi
    done
else
    # N-grams
    echo "(Showing $NGRAM_SIZE-grams)"
    echo ""

    cat "$TEXT_FILE" | \
        tr '[:upper:]' '[:lower:]' | \
        tr -cs '[:alpha:]' ' ' | \
        awk -v n="$NGRAM_SIZE" '
        {
            split($0, words)
            for (i = 1; i <= length(words) - n + 1; i++) {
                ngram = words[i]
                for (j = 1; j < n; j++) {
                    ngram = ngram " " words[i + j]
                }
                print ngram
            }
        }
        ' | sort | uniq -c | sort -rn | head -"$TOP_N" | while read -r count ngram; do
        if [[ -n "$ngram" ]]; then
            printf "%8d  %s\n" "$count" "$ngram"
        fi
    done
fi

echo ""

# Unique word count
UNIQUE_WORDS=$(cat "$TEXT_FILE" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alpha:]' '\n' | grep -v "^$" | sort -u | wc -l | tr -d ' ')
VOCABULARY_RICHNESS=$(echo "scale=2; $UNIQUE_WORDS * 100 / $WORD_COUNT" | bc)

echo "=== Vocabulary ==="
echo "─────────────────────────────────────────────────────────────"
printf "%-25s %8d\n" "Unique words:" "$UNIQUE_WORDS"
printf "%-25s %8s%%\n" "Vocabulary richness:" "$VOCABULARY_RICHNESS"

echo ""
echo "Analysis complete."
