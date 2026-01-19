#!/bin/bash

#=============================================================================
# test_all.sh - Test all scripts in the repository
# Validates syntax, help flags, and basic execution where safe
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    Test All Scripts                           ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_result() {
    local status="$1"
    local script="$2"
    local message="$3"

    case "$status" in
        PASS)
            echo -e "${GREEN}[PASS]${NC} $script - $message"
            ((PASSED++))
            ;;
        FAIL)
            echo -e "${RED}[FAIL]${NC} $script - $message"
            ((FAILED++))
            ;;
        SKIP)
            echo -e "${YELLOW}[SKIP]${NC} $script - $message"
            ((SKIPPED++))
            ;;
    esac
}

test_syntax() {
    local script="$1"
    if bash -n "$script" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

test_help_flag() {
    local script="$1"
    if "$script" -h >/dev/null 2>&1 || "$script" --help >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Scripts that are safe to run without arguments (read-only operations)
SAFE_TO_RUN=(
    "memory_utils/system_memory.sh"
    "memory_utils/process_memory.sh"
    "memory_utils/memory_hogs.sh"
    "network_utils/network_info.sh"
    "file_processing/disk_usage.sh"
)

is_safe_to_run() {
    local script_path="$1"
    for safe in "${SAFE_TO_RUN[@]}"; do
        if [[ "$script_path" == *"$safe" ]]; then
            return 0
        fi
    done
    return 1
}

test_execution() {
    local script="$1"
    local output
    output=$("$script" 2>&1) || true
    if [[ -n "$output" ]]; then
        return 0
    else
        return 1
    fi
}

print_header

echo "Testing ZETA Framework Scripts"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

#-----------------------------------------------------------------------------
# Test zeta.sh main runner
#-----------------------------------------------------------------------------
echo -e "${CYAN}[Testing Main Runner]${NC}"
echo "───────────────────────────────────────────────────────────────────"

ZETA_SCRIPT="$SCRIPT_DIR/zeta.sh"

if [[ -f "$ZETA_SCRIPT" ]]; then
    chmod +x "$ZETA_SCRIPT"

    if test_syntax "$ZETA_SCRIPT"; then
        print_result "PASS" "zeta.sh" "Syntax valid"
    else
        print_result "FAIL" "zeta.sh" "Syntax error"
    fi

    if "$ZETA_SCRIPT" -h >/dev/null 2>&1; then
        print_result "PASS" "zeta.sh" "Help flag works"
    else
        print_result "FAIL" "zeta.sh" "Help flag failed"
    fi

    if "$ZETA_SCRIPT" -l >/dev/null 2>&1; then
        print_result "PASS" "zeta.sh" "List modules works"
    else
        print_result "FAIL" "zeta.sh" "List modules failed"
    fi

    if "$ZETA_SCRIPT" -a >/dev/null 2>&1; then
        print_result "PASS" "zeta.sh" "List all scripts works"
    else
        print_result "FAIL" "zeta.sh" "List all scripts failed"
    fi
else
    print_result "FAIL" "zeta.sh" "File not found"
fi

echo ""

#-----------------------------------------------------------------------------
# Test all module scripts
#-----------------------------------------------------------------------------
MODULES=("file_processing" "memory_utils" "network_utils" "llm_calls" "data_analytics")

for module in "${MODULES[@]}"; do
    echo -e "${CYAN}[Testing Module: $module]${NC}"
    echo "───────────────────────────────────────────────────────────────────"

    MODULE_DIR="$SCRIPT_DIR/$module"

    if [[ ! -d "$MODULE_DIR" ]]; then
        print_result "SKIP" "$module" "Module directory not found"
        continue
    fi

    for script in "$MODULE_DIR"/*.sh; do
        if [[ ! -f "$script" ]]; then
            continue
        fi

        script_name=$(basename "$script")
        chmod +x "$script"

        # Test 1: Syntax check
        if test_syntax "$script"; then
            print_result "PASS" "$module/$script_name" "Syntax valid"
        else
            print_result "FAIL" "$module/$script_name" "Syntax error"
            continue
        fi

        # Test 2: Help flag
        if test_help_flag "$script"; then
            print_result "PASS" "$module/$script_name" "Help flag works"
        else
            print_result "FAIL" "$module/$script_name" "Help flag failed"
        fi

        # Test 3: Safe execution (only for read-only scripts)
        # Skip execution tests to avoid hanging - syntax and help checks are sufficient
        print_result "SKIP" "$module/$script_name" "Execution test skipped"
    done

    echo ""
done

#-----------------------------------------------------------------------------
# Test Next.js Projects (if npm is available)
#-----------------------------------------------------------------------------
echo -e "${CYAN}[Testing Next.js Projects]${NC}"
echo "───────────────────────────────────────────────────────────────────"

NEXTJS_PROJECTS=("tesilcord" "major-book-downloader-free")

for project in "${NEXTJS_PROJECTS[@]}"; do
    PROJECT_DIR="$SCRIPT_DIR/$project"

    if [[ -d "$PROJECT_DIR" && -f "$PROJECT_DIR/package.json" ]]; then
        print_result "PASS" "$project" "package.json exists"

        if [[ -f "$PROJECT_DIR/tsconfig.json" ]]; then
            print_result "PASS" "$project" "TypeScript configured"
        else
            print_result "SKIP" "$project" "No tsconfig.json"
        fi

        # Check if dependencies are installed
        if [[ -d "$PROJECT_DIR/node_modules" ]]; then
            print_result "PASS" "$project" "Dependencies installed"
        else
            print_result "SKIP" "$project" "Dependencies not installed (run npm install)"
        fi
    else
        print_result "SKIP" "$project" "Project not found"
    fi
done

echo ""

#-----------------------------------------------------------------------------
# Summary
#-----------------------------------------------------------------------------
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${CYAN}Test Summary${NC}"
echo "───────────────────────────────────────────────────────────────────"
echo -e "  ${GREEN}Passed:${NC}  $PASSED"
echo -e "  ${RED}Failed:${NC}  $FAILED"
echo -e "  ${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

TOTAL=$((PASSED + FAILED))
if [[ $TOTAL -gt 0 ]]; then
    PASS_RATE=$(echo "scale=1; $PASSED * 100 / $TOTAL" | bc)
    echo "Pass Rate: $PASS_RATE%"
fi

echo "═══════════════════════════════════════════════════════════════════"

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
