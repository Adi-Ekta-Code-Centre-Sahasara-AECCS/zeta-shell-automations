#!/bin/bash

# Description: Scan common ports on a host to check for open services
# Usage: port_scan.sh <host> [--ports <range>] [--timeout <sec>]

set -e

HOST=""
PORT_RANGE="22,80,443,8080,3000,5000"
TIMEOUT=2
FULL_SCAN=false

# Get service name for a given port
get_port_service() {
    case "$1" in
        21)    echo "FTP" ;;
        22)    echo "SSH" ;;
        23)    echo "Telnet" ;;
        25)    echo "SMTP" ;;
        53)    echo "DNS" ;;
        80)    echo "HTTP" ;;
        110)   echo "POP3" ;;
        143)   echo "IMAP" ;;
        443)   echo "HTTPS" ;;
        465)   echo "SMTPS" ;;
        587)   echo "SMTP" ;;
        993)   echo "IMAPS" ;;
        995)   echo "POP3S" ;;
        3000)  echo "Dev Server" ;;
        3306)  echo "MySQL" ;;
        3389)  echo "RDP" ;;
        5000)  echo "Flask/Dev" ;;
        5432)  echo "PostgreSQL" ;;
        5900)  echo "VNC" ;;
        6379)  echo "Redis" ;;
        8000)  echo "Dev Server" ;;
        8080)  echo "HTTP Alt" ;;
        8443)  echo "HTTPS Alt" ;;
        9000)  echo "PHP-FPM" ;;
        27017) echo "MongoDB" ;;
        *)     echo "" ;;
    esac
}

show_help() {
    echo "Port Scanner - Check for open ports on a host"
    echo ""
    echo "Usage: port_scan.sh <host> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --ports <range>    Ports to scan (comma-separated or range)"
    echo "                         Examples: 22,80,443 or 1-1000"
    echo "  -t, --timeout <sec>    Connection timeout (default: 2)"
    echo "  -f, --full             Scan common ports (1-1024)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  port_scan.sh localhost"
    echo "  port_scan.sh 192.168.1.1 --ports 22,80,443,8080"
    echo "  port_scan.sh server.com --ports 1-100"
    echo "  port_scan.sh 10.0.0.1 --full"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--ports)
            PORT_RANGE="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -f|--full)
            FULL_SCAN=true
            shift
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

echo "=== Port Scanner ==="
echo "Target: $HOST"
echo "Timeout: ${TIMEOUT}s"
echo ""

# Build port list
PORTS=()

if [[ "$FULL_SCAN" == "true" ]]; then
    for ((i=1; i<=1024; i++)); do
        PORTS+=("$i")
    done
elif [[ "$PORT_RANGE" == *"-"* ]]; then
    # Range format: start-end
    START=$(echo "$PORT_RANGE" | cut -d'-' -f1)
    END=$(echo "$PORT_RANGE" | cut -d'-' -f2)
    for ((i=START; i<=END; i++)); do
        PORTS+=("$i")
    done
else
    # Comma-separated format
    IFS=',' read -ra PORTS <<< "$PORT_RANGE"
fi

echo "Scanning ${#PORTS[@]} ports..."
echo "─────────────────────────────────────────────────────────────"
printf "%-8s  %-10s  %s\n" "PORT" "STATE" "SERVICE"
echo "─────────────────────────────────────────────────────────────"

OPEN_COUNT=0
CLOSED_COUNT=0

for port in "${PORTS[@]}"; do
    # Check if port is open using timeout and bash's /dev/tcp
    if timeout "$TIMEOUT" bash -c "echo >/dev/tcp/$HOST/$port" 2>/dev/null; then
        STATE="OPEN"
        OPEN_COUNT=$((OPEN_COUNT + 1))

        # Get service name
        SERVICE=$(get_port_service "$port")
        [[ -z "$SERVICE" ]] && SERVICE="unknown"

        printf "%-8s  \033[0;32m%-10s\033[0m  %s\n" "$port" "$STATE" "$SERVICE"
    else
        STATE="closed"
        CLOSED_COUNT=$((CLOSED_COUNT + 1))
        # Only show closed ports in verbose mode or small scans
        if [[ ${#PORTS[@]} -le 20 ]]; then
            SERVICE=$(get_port_service "$port")
            printf "%-8s  %-10s  %s\n" "$port" "$STATE" "$SERVICE"
        fi
    fi
done

echo "─────────────────────────────────────────────────────────────"
echo ""
echo "Scan Summary:"
echo "  Open ports: $OPEN_COUNT"
echo "  Closed ports: $CLOSED_COUNT"
echo "  Total scanned: ${#PORTS[@]}"
