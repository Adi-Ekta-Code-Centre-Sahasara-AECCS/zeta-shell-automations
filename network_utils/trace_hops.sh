#!/bin/bash

# Description: Trace network route to destination showing all hops
# Usage: trace_hops.sh <host> [--max-hops <n>] [--timeout <sec>]

set -e

HOST=""
MAX_HOPS=30
TIMEOUT=3

show_help() {
    echo "Trace Hops - Trace network route to destination"
    echo ""
    echo "Usage: trace_hops.sh <host> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --max-hops <n>     Maximum number of hops (default: 30)"
    echo "  -t, --timeout <sec>    Timeout per hop in seconds (default: 3)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  trace_hops.sh google.com"
    echo "  trace_hops.sh 8.8.8.8 --max-hops 20"
    echo "  trace_hops.sh github.com --timeout 5"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -m|--max-hops)
            MAX_HOPS="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            HOST="$1"
            shift
            ;;
    esac
done

if [[ -z "$HOST" ]]; then
    echo "Error: Host is required"
    show_help
    exit 1
fi

echo "=== Network Route Trace ==="
echo "Destination: $HOST"
echo "Max Hops: $MAX_HOPS"
echo "Timeout: ${TIMEOUT}s per hop"
echo ""

# Resolve hostname
echo "Resolving hostname..."
if command -v dig &>/dev/null; then
    RESOLVED_IP=$(dig +short "$HOST" | head -1)
elif command -v nslookup &>/dev/null; then
    RESOLVED_IP=$(nslookup "$HOST" 2>/dev/null | grep "Address" | tail -1 | awk '{print $2}')
else
    RESOLVED_IP="$HOST"
fi

if [[ -n "$RESOLVED_IP" ]]; then
    echo "Resolved IP: $RESOLVED_IP"
fi
echo ""

echo "Tracing route to $HOST..."
echo "─────────────────────────────────────────────────────────────────────────"
printf "%-4s  %-45s  %s\n" "HOP" "HOST" "RTT"
echo "─────────────────────────────────────────────────────────────────────────"

# Use traceroute or tracert depending on OS
if [[ "$(uname)" == "Darwin" ]] || [[ "$(uname)" == "Linux" ]]; then
    # Unix-like systems
    traceroute -m "$MAX_HOPS" -w "$TIMEOUT" "$HOST" 2>/dev/null | while IFS= read -r line; do
        # Skip the header
        if [[ "$line" == traceroute* ]]; then
            continue
        fi

        # Parse traceroute output
        HOP=$(echo "$line" | awk '{print $1}')
        if [[ "$HOP" =~ ^[0-9]+$ ]]; then
            REST=$(echo "$line" | cut -d' ' -f2-)

            # Check for asterisk (timeout)
            if [[ "$REST" == *"*"*"*"*"*"* ]]; then
                printf "%-4s  %-45s  %s\n" "$HOP" "*" "Request timed out"
            else
                HOSTNAME=$(echo "$REST" | awk '{print $1}')
                IP=$(echo "$REST" | grep -o '([^)]*)'| head -1 | tr -d '()')
                RTT=$(echo "$REST" | grep -o '[0-9.]*[[:space:]]*ms' | head -1)

                if [[ -n "$IP" ]]; then
                    printf "%-4s  %-45s  %s\n" "$HOP" "$HOSTNAME ($IP)" "$RTT"
                else
                    printf "%-4s  %-45s  %s\n" "$HOP" "$HOSTNAME" "$RTT"
                fi
            fi
        fi
    done
else
    echo "traceroute command not available"
    exit 1
fi

echo "─────────────────────────────────────────────────────────────────────────"
echo ""
echo "Trace complete."
