#!/bin/bash

# Description: Display comprehensive network interface information
# Usage: network_info.sh [--interface <name>] [--external]

set -e

INTERFACE=""
SHOW_EXTERNAL=false

show_help() {
    echo "Network Info - Display network interface details"
    echo ""
    echo "Usage: network_info.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --interface <name>  Show info for specific interface"
    echo "  -e, --external          Also fetch external IP address"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  network_info.sh"
    echo "  network_info.sh --interface en0"
    echo "  network_info.sh --external"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -e|--external)
            SHOW_EXTERNAL=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            shift
            ;;
    esac
done

echo "=== Network Information ==="
echo "Hostname: $(hostname)"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Get external IP if requested
if [[ "$SHOW_EXTERNAL" == "true" ]]; then
    echo "Fetching external IP..."
    EXTERNAL_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "Unable to fetch")
    echo "External IP: $EXTERNAL_IP"
    echo ""
fi

echo "=== Network Interfaces ==="
echo "─────────────────────────────────────────────────────────────────────────"

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    INTERFACES=$(networksetup -listallhardwareports | grep "Device:" | awk '{print $2}')

    for iface in $INTERFACES; do
        if [[ -n "$INTERFACE" && "$iface" != "$INTERFACE" ]]; then
            continue
        fi

        # Get interface info
        INFO=$(ifconfig "$iface" 2>/dev/null)
        if [[ -z "$INFO" ]]; then
            continue
        fi

        # Check if interface is up
        if echo "$INFO" | grep -q "status: active\|RUNNING"; then
            STATUS="UP"
        else
            STATUS="DOWN"
        fi

        # Get IP address
        IP=$(echo "$INFO" | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
        NETMASK=$(echo "$INFO" | grep "inet " | head -1 | awk '{print $4}')

        # Get MAC address
        MAC=$(echo "$INFO" | grep "ether" | awk '{print $2}')

        # Get IPv6 if available
        IPV6=$(echo "$INFO" | grep "inet6" | grep -v "fe80" | head -1 | awk '{print $2}')

        echo ""
        echo "Interface: $iface"
        echo "  Status:    $STATUS"
        if [[ -n "$MAC" ]]; then
            echo "  MAC:       $MAC"
        fi
        if [[ -n "$IP" ]]; then
            echo "  IPv4:      $IP"
            echo "  Netmask:   $NETMASK"
        fi
        if [[ -n "$IPV6" ]]; then
            echo "  IPv6:      $IPV6"
        fi
    done
else
    # Linux
    INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')

    for iface in $INTERFACES; do
        if [[ -n "$INTERFACE" && "$iface" != "$INTERFACE" ]]; then
            continue
        fi

        # Get interface info
        INFO=$(ip addr show "$iface" 2>/dev/null)
        if [[ -z "$INFO" ]]; then
            continue
        fi

        # Check if interface is up
        if echo "$INFO" | grep -q "state UP"; then
            STATUS="UP"
        else
            STATUS="DOWN"
        fi

        # Get IP address
        IP=$(echo "$INFO" | grep "inet " | head -1 | awk '{print $2}')
        MAC=$(echo "$INFO" | grep "link/ether" | awk '{print $2}')
        IPV6=$(echo "$INFO" | grep "inet6" | grep -v "fe80" | head -1 | awk '{print $2}')

        echo ""
        echo "Interface: $iface"
        echo "  Status:    $STATUS"
        if [[ -n "$MAC" ]]; then
            echo "  MAC:       $MAC"
        fi
        if [[ -n "$IP" ]]; then
            echo "  IPv4:      $IP"
        fi
        if [[ -n "$IPV6" ]]; then
            echo "  IPv6:      $IPV6"
        fi
    done
fi

echo ""
echo "─────────────────────────────────────────────────────────────────────────"

# Show default gateway
echo ""
echo "=== Routing Information ==="
if [[ "$(uname)" == "Darwin" ]]; then
    GATEWAY=$(netstat -rn | grep "default" | head -1 | awk '{print $2}')
else
    GATEWAY=$(ip route | grep "default" | head -1 | awk '{print $3}')
fi
echo "Default Gateway: ${GATEWAY:-Not set}"

# Show DNS servers
echo ""
echo "=== DNS Servers ==="
if [[ "$(uname)" == "Darwin" ]]; then
    scutil --dns 2>/dev/null | grep "nameserver\[" | head -5 | awk '{print "  "$3}'
else
    grep "nameserver" /etc/resolv.conf 2>/dev/null | awk '{print "  "$2}'
fi
