#!/bin/bash

# Description: Send chat requests to OpenAI GPT API
# Usage: openai_chat.sh "prompt" [--model <model>] [--max-tokens <n>]

set -e

PROMPT=""
MODEL="gpt-4o-mini"
MAX_TOKENS=1000
TEMPERATURE=0.7
SYSTEM_PROMPT="You are a helpful assistant."

show_help() {
    echo "OpenAI Chat - Send requests to OpenAI GPT API"
    echo ""
    echo "Usage: openai_chat.sh \"<prompt>\" [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --model <model>       Model to use (default: gpt-4o-mini)"
    echo "                            Options: gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo"
    echo "  -t, --max-tokens <n>      Maximum tokens in response (default: 1000)"
    echo "  --temperature <n>         Temperature 0-2 (default: 0.7)"
    echo "  -s, --system <prompt>     System prompt"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Environment:"
    echo "  OPENAI_API_KEY            Required: Your OpenAI API key"
    echo ""
    echo "Examples:"
    echo "  openai_chat.sh \"What is the capital of France?\""
    echo "  openai_chat.sh \"Explain quantum computing\" --model gpt-4o"
    echo "  openai_chat.sh \"Write a haiku\" --max-tokens 50"
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
        --temperature)
            TEMPERATURE="$2"
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
if [[ -z "$OPENAI_API_KEY" ]]; then
    echo "Error: OPENAI_API_KEY environment variable not set"
    echo "Export your API key: export OPENAI_API_KEY='your-key-here'"
    exit 1
fi

# Check for prompt
if [[ -z "$PROMPT" ]]; then
    echo "Error: Prompt is required"
    show_help
    exit 1
fi

echo "=== OpenAI Chat ==="
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
  "messages": [
    {"role": "system", "content": "$ESCAPED_SYSTEM"},
    {"role": "user", "content": "$ESCAPED_PROMPT"}
  ],
  "max_tokens": $MAX_TOKENS,
  "temperature": $TEMPERATURE
}
EOF
)

# Make API request
RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$REQUEST_BODY")

# Check for errors
if echo "$RESPONSE" | grep -q '"error"'; then
    echo "Error from API:"
    echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',{}).get('message','Unknown error'))" 2>/dev/null || echo "$RESPONSE"
    exit 1
fi

# Extract and display response
echo ""
echo "=== Response ==="
echo "─────────────────────────────────────────────────────────────"

# Extract the content using python for reliable JSON parsing
CONTENT=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])" 2>/dev/null)

if [[ -n "$CONTENT" ]]; then
    echo "$CONTENT"
else
    echo "Failed to parse response"
    echo "$RESPONSE"
fi

echo ""
echo "─────────────────────────────────────────────────────────────"

# Show usage info
USAGE=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); u=d.get('usage',{}); print(f\"Tokens: {u.get('prompt_tokens',0)} prompt + {u.get('completion_tokens',0)} completion = {u.get('total_tokens',0)} total\")" 2>/dev/null)
echo "$USAGE"
