#!/bin/bash

# Description: Test network bandwidth by downloading test files
# Usage: bandwidth_test.sh [--size <small|medium|large>]

set -e

SIZE="medium"

# Get test URL for given size
get_test_url() {
    case "$1" in
        small)  echo "https://speed.cloudflare.com/__down?bytes=1000000" ;;   # 1MB
        medium) echo "https://speed.cloudflare.com/__down?bytes=10000000" ;;  # 10MB
        large)  echo "https://speed.cloudflare.com/__down?bytes=100000000" ;; # 100MB
        *)      echo "" ;;
    esac
}

# Get human-readable size for given size key
get_test_size() {
    case "$1" in
        small)  echo "1 MB" ;;
        medium) echo "10 MB" ;;
        large)  echo "100 MB" ;;
        *)      echo "" ;;
    esac
}

show_help() {
    echo "Bandwidth Test - Measure network download speed"
    echo ""
    echo "Usage: bandwidth_test.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --size <size>   Test file size: small (1MB), medium (10MB), large (100MB)"
    echo "                      Default: medium"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  bandwidth_test.sh"
    echo "  bandwidth_test.sh --size small"
    echo "  bandwidth_test.sh --size large"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--size)
            SIZE="$2"
            shift 2
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

# Validate size
TEST_URL=$(get_test_url "$SIZE")
if [[ -z "$TEST_URL" ]]; then
    echo "Error: Invalid size '$SIZE'. Use: small, medium, or large"
    exit 1
fi

echo "=== Network Bandwidth Test ==="
echo "Test Size: $(get_test_size "$SIZE")"
echo ""

# Check for curl
if ! command -v curl &>/dev/null; then
    echo "Error: curl is required but not installed"
    exit 1
fi

echo "Starting download test..."
echo "─────────────────────────────────────────────────────────────"

URL="$TEST_URL"

# Perform the download test
START_TIME=$(date +%s.%N)

# Download with progress
RESULT=$(curl -w "%{time_total},%{speed_download},%{size_download}" \
    -o /dev/null -s "$URL" 2>&1)

END_TIME=$(date +%s.%N)

# Parse results
TIME_TOTAL=$(echo "$RESULT" | cut -d',' -f1)
SPEED_BPS=$(echo "$RESULT" | cut -d',' -f2)
SIZE_DOWNLOADED=$(echo "$RESULT" | cut -d',' -f3)

# Convert speed to human readable
SPEED_KBPS=$(echo "scale=2; $SPEED_BPS / 1024" | bc)
SPEED_MBPS=$(echo "scale=2; $SPEED_BPS / 1048576" | bc)
SPEED_MBITS=$(echo "scale=2; $SPEED_BPS * 8 / 1000000" | bc)

# Convert downloaded size
if [[ $(echo "$SIZE_DOWNLOADED >= 1048576" | bc) -eq 1 ]]; then
    SIZE_HR=$(echo "scale=2; $SIZE_DOWNLOADED / 1048576" | bc)MB
elif [[ $(echo "$SIZE_DOWNLOADED >= 1024" | bc) -eq 1 ]]; then
    SIZE_HR=$(echo "scale=2; $SIZE_DOWNLOADED / 1024" | bc)KB
else
    SIZE_HR="${SIZE_DOWNLOADED}B"
fi

echo ""
echo "=== Download Results ==="
echo "─────────────────────────────────────────────────────────────"
printf "%-25s %s\n" "Downloaded:" "$SIZE_HR"
printf "%-25s %s\n" "Time:" "${TIME_TOTAL}s"
echo "─────────────────────────────────────────────────────────────"
printf "%-25s %s\n" "Speed (MB/s):" "$SPEED_MBPS"
printf "%-25s %s\n" "Speed (Mbps):" "$SPEED_MBITS"
printf "%-25s %s\n" "Speed (KB/s):" "$SPEED_KBPS"
echo "─────────────────────────────────────────────────────────────"

# Quality assessment
echo ""
echo "=== Connection Quality ==="
if (( $(echo "$SPEED_MBITS >= 100" | bc -l) )); then
    echo "Rating: Excellent (100+ Mbps)"
elif (( $(echo "$SPEED_MBITS >= 50" | bc -l) )); then
    echo "Rating: Very Good (50-100 Mbps)"
elif (( $(echo "$SPEED_MBITS >= 25" | bc -l) )); then
    echo "Rating: Good (25-50 Mbps)"
elif (( $(echo "$SPEED_MBITS >= 10" | bc -l) )); then
    echo "Rating: Fair (10-25 Mbps)"
elif (( $(echo "$SPEED_MBITS >= 5" | bc -l) )); then
    echo "Rating: Slow (5-10 Mbps)"
else
    echo "Rating: Very Slow (<5 Mbps)"
fi

echo ""
echo "Test completed."
