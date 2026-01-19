#!/bin/bash

# Description: Send chat requests to local Ollama instance
# Usage: ollama_chat.sh "prompt" [--model <model>] [--host <url>]

set -e

PROMPT=""
MODEL="llama3.2"
HOST="http://localhost:11434"
STREAM=false

show_help() {
    echo "Ollama Chat - Send requests to local Ollama instance"
    echo ""
    echo "Usage: ollama_chat.sh \"<prompt>\" [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --model <model>    Model to use (default: llama3.2)"
    echo "  --host <url>           Ollama host URL (default: http://localhost:11434)"
    echo "  --stream               Stream the response"
    echo "  -l, --list             List available models"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  ollama_chat.sh \"What is the capital of France?\""
    echo "  ollama_chat.sh \"Explain quantum computing\" --model mistral"
    echo "  ollama_chat.sh --list"
}

list_models() {
    echo "=== Available Ollama Models ==="
    echo ""

    RESPONSE=$(curl -s "$HOST/api/tags" 2>/dev/null)

    if [[ $? -ne 0 ]] || [[ -z "$RESPONSE" ]]; then
        echo "Error: Could not connect to Ollama at $HOST"
        echo "Make sure Ollama is running: ollama serve"
        exit 1
    fi

    echo "$RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    models = d.get('models', [])
    if not models:
        print('No models installed. Pull a model: ollama pull llama3.2')
    else:
        print(f'Found {len(models)} model(s):')
        print('')
        for m in models:
            name = m.get('name', 'unknown')
            size = m.get('size', 0)
            size_gb = size / (1024**3)
            print(f'  {name:30} {size_gb:.2f} GB')
except Exception as e:
    print(f'Error parsing response: {e}')
" 2>/dev/null

    exit 0
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
        --host)
            HOST="$2"
            shift 2
            ;;
        --stream)
            STREAM=true
            shift
            ;;
        -l|--list)
            list_models
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

# Check for prompt
if [[ -z "$PROMPT" ]]; then
    echo "Error: Prompt is required"
    show_help
    exit 1
fi

echo "=== Ollama Chat ==="
echo "Model: $MODEL"
echo "Host: $HOST"
echo ""
echo "Prompt: $PROMPT"
echo ""
echo "─────────────────────────────────────────────────────────────"
echo "Sending request..."

# Escape special characters in prompt for JSON
ESCAPED_PROMPT=$(echo "$PROMPT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Build request body
REQUEST_BODY=$(cat <<EOF
{
  "model": "$MODEL",
  "prompt": "$ESCAPED_PROMPT",
  "stream": $STREAM
}
EOF
)

if [[ "$STREAM" == "true" ]]; then
    # Streaming mode
    echo ""
    echo "=== Response ==="
    echo "─────────────────────────────────────────────────────────────"

    curl -s -X POST "$HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "$REQUEST_BODY" | while read -r line; do
        if [[ -n "$line" ]]; then
            echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('response',''), end='')" 2>/dev/null
        fi
    done
    echo ""
else
    # Non-streaming mode
    RESPONSE=$(curl -s -X POST "$HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "$REQUEST_BODY" 2>/dev/null)

    if [[ $? -ne 0 ]] || [[ -z "$RESPONSE" ]]; then
        echo "Error: Could not connect to Ollama at $HOST"
        echo "Make sure Ollama is running: ollama serve"
        exit 1
    fi

    # Check for errors
    if echo "$RESPONSE" | grep -q '"error"'; then
        echo "Error from Ollama:"
        echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error','Unknown error'))" 2>/dev/null || echo "$RESPONSE"
        exit 1
    fi

    # Extract and display response
    echo ""
    echo "=== Response ==="
    echo "─────────────────────────────────────────────────────────────"

    CONTENT=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('response',''))" 2>/dev/null)

    if [[ -n "$CONTENT" ]]; then
        echo "$CONTENT"
    else
        echo "Failed to parse response"
        echo "$RESPONSE"
    fi

    echo ""
    echo "─────────────────────────────────────────────────────────────"

    # Show timing info
    echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
total_duration = d.get('total_duration', 0) / 1e9
eval_count = d.get('eval_count', 0)
print(f'Generation time: {total_duration:.2f}s ({eval_count} tokens)')
" 2>/dev/null
fi
