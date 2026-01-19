#!/bin/bash

# Description: Query and analyze JSON files using jq-like syntax
# Usage: json_query.sh <file.json> [--query <path>] [--format]

set -e

JSON_FILE=""
QUERY=""
FORMAT=false
STATS=false

show_help() {
    echo "JSON Query - Query and analyze JSON files"
    echo ""
    echo "Usage: json_query.sh <file.json> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -q, --query <path>     JSON path query (e.g., '.data.items')"
    echo "  -f, --format           Pretty print the output"
    echo "  -s, --stats            Show statistics about the JSON structure"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Query Examples:"
    echo "  .                      Root object"
    echo "  .key                   Value of 'key'"
    echo "  .key.nested            Nested value"
    echo "  .array[0]              First array element"
    echo "  .array[]               All array elements"
    echo "  .array[].name          'name' from each array element"
    echo ""
    echo "Examples:"
    echo "  json_query.sh data.json"
    echo "  json_query.sh config.json --query '.settings'"
    echo "  json_query.sh api_response.json --query '.data.items[]' --format"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -q|--query)
            QUERY="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT=true
            shift
            ;;
        -s|--stats)
            STATS=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            JSON_FILE="$1"
            shift
            ;;
    esac
done

# Check for file
if [[ -z "$JSON_FILE" ]]; then
    echo "Error: JSON file is required"
    show_help
    exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
    echo "Error: File '$JSON_FILE' not found"
    exit 1
fi

echo "=== JSON Query ==="
echo "File: $JSON_FILE"
echo ""

# Check for jq
if ! command -v jq &>/dev/null; then
    echo "Note: jq not installed, using Python fallback"
    USE_JQ=false
else
    USE_JQ=true
fi

# Get file stats
FILE_SIZE=$(wc -c < "$JSON_FILE" | tr -d ' ')
echo "File size: $FILE_SIZE bytes"
echo ""

if [[ "$STATS" == "true" ]]; then
    echo "=== JSON Structure Analysis ==="
    echo "─────────────────────────────────────────────────────────────"

    python3 << EOF
import json
import sys

def analyze_structure(obj, prefix="", depth=0, stats=None):
    if stats is None:
        stats = {"keys": set(), "arrays": 0, "objects": 0, "strings": 0, "numbers": 0, "booleans": 0, "nulls": 0, "max_depth": 0}

    if depth > stats["max_depth"]:
        stats["max_depth"] = depth

    if isinstance(obj, dict):
        stats["objects"] += 1
        for key, value in obj.items():
            full_key = f"{prefix}.{key}" if prefix else key
            stats["keys"].add(full_key)
            analyze_structure(value, full_key, depth + 1, stats)
    elif isinstance(obj, list):
        stats["arrays"] += 1
        for i, item in enumerate(obj[:10]):  # Sample first 10
            analyze_structure(item, f"{prefix}[]", depth + 1, stats)
    elif isinstance(obj, str):
        stats["strings"] += 1
    elif isinstance(obj, (int, float)):
        stats["numbers"] += 1
    elif isinstance(obj, bool):
        stats["booleans"] += 1
    elif obj is None:
        stats["nulls"] += 1

    return stats

try:
    with open("$JSON_FILE", "r") as f:
        data = json.load(f)

    stats = analyze_structure(data)

    print(f"Root type: {type(data).__name__}")
    print(f"Max depth: {stats['max_depth']}")
    print(f"Objects: {stats['objects']}")
    print(f"Arrays: {stats['arrays']}")
    print(f"Strings: {stats['strings']}")
    print(f"Numbers: {stats['numbers']}")
    print(f"Booleans: {stats['booleans']}")
    print(f"Nulls: {stats['nulls']}")
    print(f"Unique keys: {len(stats['keys'])}")
    print("")
    print("Top-level keys:" if isinstance(data, dict) else f"Array length: {len(data)}")

    if isinstance(data, dict):
        for key in list(data.keys())[:20]:
            val_type = type(data[key]).__name__
            if isinstance(data[key], list):
                val_type = f"array[{len(data[key])}]"
            elif isinstance(data[key], dict):
                val_type = f"object({len(data[key])} keys)"
            print(f"  .{key}: {val_type}")
    elif isinstance(data, list) and len(data) > 0:
        print(f"  First element type: {type(data[0]).__name__}")
        if isinstance(data[0], dict):
            print("  Sample element keys:")
            for key in list(data[0].keys())[:10]:
                print(f"    .{key}")

except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON - {e}")
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
EOF
    echo ""
fi

if [[ -n "$QUERY" ]]; then
    echo "=== Query Result ==="
    echo "Query: $QUERY"
    echo "─────────────────────────────────────────────────────────────"

    if [[ "$USE_JQ" == "true" ]]; then
        if [[ "$FORMAT" == "true" ]]; then
            jq "$QUERY" "$JSON_FILE"
        else
            jq -c "$QUERY" "$JSON_FILE"
        fi
    else
        # Python fallback
        python3 << EOF
import json
import sys

def query_json(data, path):
    if not path or path == ".":
        return data

    # Remove leading dot
    if path.startswith("."):
        path = path[1:]

    parts = []
    current = ""
    in_bracket = False

    for char in path:
        if char == "[":
            if current:
                parts.append(("key", current))
                current = ""
            in_bracket = True
        elif char == "]":
            if current:
                if current.isdigit():
                    parts.append(("index", int(current)))
                elif current == "":
                    parts.append(("all", None))
                current = ""
            in_bracket = False
        elif char == "." and not in_bracket:
            if current:
                parts.append(("key", current))
                current = ""
        else:
            current += char

    if current:
        parts.append(("key", current))

    result = data
    for part_type, part_value in parts:
        if part_type == "key":
            if isinstance(result, dict):
                result = result.get(part_value)
            else:
                return None
        elif part_type == "index":
            if isinstance(result, list) and part_value < len(result):
                result = result[part_value]
            else:
                return None
        elif part_type == "all":
            if isinstance(result, list):
                # Return all elements
                pass
            else:
                return None

    return result

try:
    with open("$JSON_FILE", "r") as f:
        data = json.load(f)

    result = query_json(data, "$QUERY")

    if "$FORMAT" == "true":
        print(json.dumps(result, indent=2))
    else:
        print(json.dumps(result))

except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON - {e}")
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
EOF
    fi
else
    # Show preview
    echo "=== Data Preview ==="
    echo "─────────────────────────────────────────────────────────────"

    if [[ "$USE_JQ" == "true" ]]; then
        jq '.' "$JSON_FILE" | head -50
    else
        python3 -c "import json; print(json.dumps(json.load(open('$JSON_FILE')), indent=2))" | head -50
    fi

    LINE_COUNT=$(wc -l < "$JSON_FILE" | tr -d ' ')
    if [[ $LINE_COUNT -gt 50 ]]; then
        echo ""
        echo "... (truncated, showing first 50 lines)"
    fi
fi

echo ""
echo "Query complete."
