#!/bin/bash

# Description: Perform DNS lookups with multiple record types
# Usage: dns_lookup.sh <domain> [--type <record>] [--server <dns>]

set -e

DOMAIN=""
RECORD_TYPE="A"
DNS_SERVER=""
ALL_RECORDS=false

show_help() {
    echo "DNS Lookup - Query DNS records for a domain"
    echo ""
    echo "Usage: dns_lookup.sh <domain> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type <record>    Record type: A, AAAA, MX, NS, TXT, CNAME, SOA"
    echo "                         Default: A"
    echo "  -s, --server <dns>     DNS server to query (e.g., 8.8.8.8)"
    echo "  -a, --all              Query all common record types"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  dns_lookup.sh google.com"
    echo "  dns_lookup.sh github.com --type MX"
    echo "  dns_lookup.sh example.com --all"
    echo "  dns_lookup.sh cloudflare.com --server 1.1.1.1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--type)
            RECORD_TYPE="$2"
            shift 2
            ;;
        -s|--server)
            DNS_SERVER="$2"
            shift 2
            ;;
        -a|--all)
            ALL_RECORDS=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            DOMAIN="$1"
            shift
            ;;
    esac
done

if [[ -z "$DOMAIN" ]]; then
    echo "Error: Domain is required"
    show_help
    exit 1
fi

echo "=== DNS Lookup ==="
echo "Domain: $DOMAIN"
if [[ -n "$DNS_SERVER" ]]; then
    echo "DNS Server: $DNS_SERVER"
fi
echo ""

# Function to query DNS
query_dns() {
    local domain="$1"
    local type="$2"

    echo "─────────────────────────────────────────────────────────────"
    echo "Record Type: $type"
    echo "─────────────────────────────────────────────────────────────"

    if command -v dig &>/dev/null; then
        # Use dig
        if [[ -n "$DNS_SERVER" ]]; then
            dig +noall +answer "$domain" "$type" "@$DNS_SERVER" 2>/dev/null
        else
            dig +noall +answer "$domain" "$type" 2>/dev/null
        fi
    elif command -v nslookup &>/dev/null; then
        # Use nslookup
        if [[ -n "$DNS_SERVER" ]]; then
            nslookup -type="$type" "$domain" "$DNS_SERVER" 2>/dev/null | grep -v "^$" | tail -n +4
        else
            nslookup -type="$type" "$domain" 2>/dev/null | grep -v "^$" | tail -n +4
        fi
    elif command -v host &>/dev/null; then
        # Use host
        if [[ -n "$DNS_SERVER" ]]; then
            host -t "$type" "$domain" "$DNS_SERVER" 2>/dev/null
        else
            host -t "$type" "$domain" 2>/dev/null
        fi
    else
        echo "Error: No DNS query tool available (dig, nslookup, or host)"
        exit 1
    fi

    echo ""
}

if [[ "$ALL_RECORDS" == "true" ]]; then
    # Query all common record types
    RECORD_TYPES=("A" "AAAA" "MX" "NS" "TXT" "CNAME" "SOA")

    for type in "${RECORD_TYPES[@]}"; do
        query_dns "$DOMAIN" "$type"
    done
else
    query_dns "$DOMAIN" "$RECORD_TYPE"
fi

# Additional info with dig
if command -v dig &>/dev/null; then
    echo "=== Query Statistics ==="
    echo "─────────────────────────────────────────────────────────────"

    if [[ -n "$DNS_SERVER" ]]; then
        STATS=$(dig "$DOMAIN" "@$DNS_SERVER" 2>/dev/null | grep -E "Query time:|SERVER:|WHEN:")
    else
        STATS=$(dig "$DOMAIN" 2>/dev/null | grep -E "Query time:|SERVER:|WHEN:")
    fi

    echo "$STATS"
fi

echo ""
echo "Lookup complete."
