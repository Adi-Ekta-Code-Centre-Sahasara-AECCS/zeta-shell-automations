#!/bin/bash

#=============================================================================
# ZETA - Shell Script Runner
# A modular shell script execution framework
#=============================================================================

set -e

ZETA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$ZETA_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Available modules
MODULES=("file_processing" "memory_utils" "network_utils" "llm_calls" "data_analytics")

#-----------------------------------------------------------------------------
# Helper Functions
#-----------------------------------------------------------------------------

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                     ZETA Script Runner                        ║"
    echo "║              Modular Shell Script Framework                   ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

#-----------------------------------------------------------------------------
# Usage and Help
#-----------------------------------------------------------------------------

show_usage() {
    print_banner
    echo "Usage: ./zeta.sh [OPTIONS] <module:script> [SCRIPT_ARGS...]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -l, --list              List all available modules"
    echo "  -m, --module <name>     List scripts in a specific module"
    echo "  -a, --all               List all scripts in all modules"
    echo "  -v, --version           Show version information"
    echo ""
    echo "Examples:"
    echo "  ./zeta.sh file_processing:find_files /path/to/dir"
    echo "  ./zeta.sh network_utils:trace_hops google.com"
    echo "  ./zeta.sh memory_utils:system_memory"
    echo "  ./zeta.sh -m file_processing"
    echo ""
    echo "Modules:"
    for module in "${MODULES[@]}"; do
        echo "  - $module"
    done
    echo ""
}

show_version() {
    echo "ZETA Script Runner v1.0.0"
    echo "A modular shell script execution framework"
}

#-----------------------------------------------------------------------------
# Module and Script Discovery
#-----------------------------------------------------------------------------

list_modules() {
    print_banner
    echo -e "${YELLOW}Available Modules:${NC}"
    echo ""
    for module in "${MODULES[@]}"; do
        local script_count
        script_count=$(find "$MODULES_DIR/$module" -maxdepth 1 -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
        echo -e "  ${GREEN}$module${NC} ($script_count scripts)"
    done
    echo ""
}

list_module_scripts() {
    local module="$1"

    if [[ ! -d "$MODULES_DIR/$module" ]]; then
        print_error "Module '$module' not found"
        return 1
    fi

    print_banner
    echo -e "${YELLOW}Scripts in module '${GREEN}$module${YELLOW}':${NC}"
    echo ""

    for script in "$MODULES_DIR/$module"/*.sh; do
        if [[ -f "$script" ]]; then
            local script_name
            script_name=$(basename "$script" .sh)
            local description=""

            # Try to extract description from script
            description=$(grep -m 1 "^# Description:" "$script" 2>/dev/null | sed 's/^# Description: //' || echo "No description available")

            echo -e "  ${CYAN}$module:$script_name${NC}"
            echo -e "    $description"
            echo ""
        fi
    done
}

list_all_scripts() {
    print_banner
    echo -e "${YELLOW}All Available Scripts:${NC}"
    echo ""

    for module in "${MODULES[@]}"; do
        if [[ -d "$MODULES_DIR/$module" ]]; then
            echo -e "${GREEN}[$module]${NC}"
            for script in "$MODULES_DIR/$module"/*.sh; do
                if [[ -f "$script" ]]; then
                    local script_name
                    script_name=$(basename "$script" .sh)
                    local description=""
                    description=$(grep -m 1 "^# Description:" "$script" 2>/dev/null | sed 's/^# Description: //' || echo "")
                    echo -e "  ${CYAN}$script_name${NC} - $description"
                fi
            done
            echo ""
        fi
    done
}

#-----------------------------------------------------------------------------
# Script Execution
#-----------------------------------------------------------------------------

find_script() {
    local script_ref="$1"
    local module=""
    local script_name=""

    # Check if format is module:script
    if [[ "$script_ref" == *":"* ]]; then
        module="${script_ref%%:*}"
        script_name="${script_ref#*:}"
    else
        # Search all modules for the script
        script_name="$script_ref"
        for m in "${MODULES[@]}"; do
            if [[ -f "$MODULES_DIR/$m/${script_name}.sh" ]]; then
                module="$m"
                break
            fi
        done
    fi

    if [[ -z "$module" ]]; then
        print_error "Script '$script_name' not found in any module"
        return 1
    fi

    local script_path="$MODULES_DIR/$module/${script_name}.sh"

    if [[ ! -f "$script_path" ]]; then
        print_error "Script '$script_path' not found"
        return 1
    fi

    echo "$script_path"
}

run_script() {
    local script_ref="$1"
    shift
    local script_args=("$@")

    local script_path
    script_path=$(find_script "$script_ref") || return 1

    if [[ ! -x "$script_path" ]]; then
        chmod +x "$script_path"
    fi

    print_info "Running: $script_path ${script_args[*]}"
    echo "─────────────────────────────────────────────────────────────────"

    # Execute the script
    "$script_path" "${script_args[@]}"
    local exit_code=$?

    echo "─────────────────────────────────────────────────────────────────"

    if [[ $exit_code -eq 0 ]]; then
        print_success "Script completed successfully"
    else
        print_error "Script exited with code $exit_code"
    fi

    return $exit_code
}

#-----------------------------------------------------------------------------
# Main Entry Point
#-----------------------------------------------------------------------------

main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -l|--list)
            list_modules
            exit 0
            ;;
        -m|--module)
            if [[ -z "$2" ]]; then
                print_error "Module name required"
                exit 1
            fi
            list_module_scripts "$2"
            exit 0
            ;;
        -a|--all)
            list_all_scripts
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            run_script "$@"
            exit $?
            ;;
    esac
}

main "$@"
