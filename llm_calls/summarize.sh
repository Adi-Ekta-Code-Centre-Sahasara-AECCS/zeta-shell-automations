#!/bin/bash

# Description: Summarize text or file content using LLM
# Usage: summarize.sh <file|text> [--provider <openai|anthropic|ollama>]

set -e

INPUT=""
PROVIDER="ollama"
MAX_LENGTH="medium"

show_help() {
    echo "Summarize - Summarize text or files using LLM"
    echo ""
    echo "Usage: summarize.sh <file|text> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --provider <name>    LLM provider: openai, anthropic, ollama (default: ollama)"
    echo "  -l, --length <size>      Summary length: short, medium, long (default: medium)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Environment (depending on provider):"
    echo "  OPENAI_API_KEY           Required for OpenAI"
    echo "  ANTHROPIC_API_KEY        Required for Anthropic"
    echo ""
    echo "Examples:"
    echo "  summarize.sh document.txt"
    echo "  summarize.sh \"Long text to summarize...\" --provider openai"
    echo "  summarize.sh article.md --length short"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        -l|--length)
            MAX_LENGTH="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            INPUT="$1"
            shift
            ;;
    esac
done

# Check for input
if [[ -z "$INPUT" ]]; then
    echo "Error: Input file or text is required"
    show_help
    exit 1
fi

# Get content (from file or direct text)
if [[ -f "$INPUT" ]]; then
    echo "Reading file: $INPUT"
    CONTENT=$(cat "$INPUT")
    SOURCE="File: $INPUT"
else
    CONTENT="$INPUT"
    SOURCE="Direct input"
fi

# Set length instruction
case "$MAX_LENGTH" in
    short)
        LENGTH_INSTRUCTION="Provide a very brief summary in 2-3 sentences."
        ;;
    medium)
        LENGTH_INSTRUCTION="Provide a concise summary in about 1 paragraph."
        ;;
    long)
        LENGTH_INSTRUCTION="Provide a detailed summary covering all main points."
        ;;
    *)
        LENGTH_INSTRUCTION="Provide a concise summary in about 1 paragraph."
        ;;
esac

PROMPT="Please summarize the following text. $LENGTH_INSTRUCTION

Text to summarize:
$CONTENT"

echo "=== Text Summarization ==="
echo "Provider: $PROVIDER"
echo "Length: $MAX_LENGTH"
echo "Source: $SOURCE"
echo "Content length: ${#CONTENT} characters"
echo ""
echo "─────────────────────────────────────────────────────────────"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$PROVIDER" in
    openai)
        if [[ -z "$OPENAI_API_KEY" ]]; then
            echo "Error: OPENAI_API_KEY not set"
            exit 1
        fi
        "$SCRIPT_DIR/openai_chat.sh" "$PROMPT" --model gpt-4o-mini --max-tokens 500
        ;;
    anthropic)
        if [[ -z "$ANTHROPIC_API_KEY" ]]; then
            echo "Error: ANTHROPIC_API_KEY not set"
            exit 1
        fi
        "$SCRIPT_DIR/anthropic_chat.sh" "$PROMPT" --max-tokens 500
        ;;
    ollama)
        "$SCRIPT_DIR/ollama_chat.sh" "$PROMPT"
        ;;
    *)
        echo "Error: Unknown provider '$PROVIDER'"
        echo "Use: openai, anthropic, or ollama"
        exit 1
        ;;
esac
