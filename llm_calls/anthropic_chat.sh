#!/bin/bash

# Description: Send chat requests to Anthropic Claude API
# Usage: anthropic_chat.sh "prompt" [--model <model>] [--max-tokens <n>]

set -e

PROMPT=""
MODEL="claude-sonnet-4-20250514"
MAX_TOKENS=1000
SYSTEM_PROMPT="You are a helpful assistant."

show_help() {
    echo "Anthropic Chat - Send requests to Claude API"
    echo ""
    echo "Usage: anthropic_chat.sh \"<prompt>\" [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --model <model>       Model to use (default: claude-sonnet-4-20250514)"
    echo "                            Options: claude-opus-4-20250514, claude-sonnet-4-20250514"
    echo "  -t, --max-tokens <n>      Maximum tokens in response (default: 1000)"
    echo "  -s, --system <prompt>     System prompt"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Environment:"
    echo "  ANTHROPIC_API_KEY         Required: Your Anthropic API key"
    echo ""
    echo "Examples:"
    echo "  anthropic_chat.sh \"What is the capital of France?\""
    echo "  anthropic_chat.sh \"Explain quantum computing\" --model claude-opus-4-20250514"
    echo "  anthropic_chat.sh \"Write a haiku\" --max-tokens 50"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -t|--max-tokens)
            MAX_TOKENS="$2"
            shift 2
            ;;
        -s|--system)
            SYSTEM_PROMPT="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            PROMPT="$1"
            shift
            ;;
    esac
done

# Check for API key
if [[ -z "$ANTHROPIC_API_KEY" ]]; then
    echo "Error: ANTHROPIC_API_KEY environment variable not set"
    echo "Export your API key: export ANTHROPIC_API_KEY='your-key-here'"
    exit 1
fi

# Check for prompt
if [[ -z "$PROMPT" ]]; then
    echo "Error: Prompt is required"
    show_help
    exit 1
fi

echo "=== Anthropic Claude Chat ==="
echo "Model: $MODEL"
echo "Max Tokens: $MAX_TOKENS"
echo ""
echo "Prompt: $PROMPT"
echo ""
echo "─────────────────────────────────────────────────────────────"
echo "Sending request..."

# Escape special characters in prompts for JSON
ESCAPED_PROMPT=$(echo "$PROMPT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
ESCAPED_SYSTEM=$(echo "$SYSTEM_PROMPT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Build request body
REQUEST_BODY=$(cat <<EOF
{
  "model": "$MODEL",
  "max_tokens": $MAX_TOKENS,
  "system": "$ESCAPED_SYSTEM",
  "messages": [
    {"role": "user", "content": "$ESCAPED_PROMPT"}
  ]
}
EOF
)

# Make API request
RESPONSE=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "$REQUEST_BODY")

# Check for errors
if echo "$RESPONSE" | grep -q '"error"'; then
    echo "Error from API:"
    echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); e=d.get('error',{}); print(f\"{e.get('type','')}: {e.get('message','Unknown error')}\")" 2>/dev/null || echo "$RESPONSE"
    exit 1
fi

# Extract and display response
echo ""
echo "=== Response ==="
echo "─────────────────────────────────────────────────────────────"

# Extract the content using python for reliable JSON parsing
CONTENT=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); c=d.get('content',[]); print(c[0]['text'] if c else '')" 2>/dev/null)

if [[ -n "$CONTENT" ]]; then
    echo "$CONTENT"
else
    echo "Failed to parse response"
    echo "$RESPONSE"
fi

echo ""
echo "─────────────────────────────────────────────────────────────"

# Show usage info
USAGE=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); u=d.get('usage',{}); print(f\"Tokens: {u.get('input_tokens',0)} input + {u.get('output_tokens',0)} output\")" 2>/dev/null)
echo "$USAGE"
