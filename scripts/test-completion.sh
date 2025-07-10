#!/bin/bash

# Test script for tab completion functionality

set -euo pipefail

# Get script directory and source common OS library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common-os-lib.sh
source "${SCRIPT_DIR}/common-os-lib.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to extract targets from Makefile
extract_targets() {
    local makefile="$1"
    local grep_cmd
    grep_cmd="$(get_grep_cmd)"

    ${grep_cmd} -E '^[a-zA-Z0-9_-]+:' "$makefile" 2>/dev/null | \
        ${grep_cmd} -v '^\.PHONY' | \
        cut -d: -f1 | \
        sort -u
}

# Test bash completion
test_bash_completion() {
    print_test "Testing Bash completion script..."

    local completion_script="${SCRIPT_DIR}/bash_completion.sh"

    # Check if script exists
    if [[ ! -f "$completion_script" ]]; then
        print_fail "Bash completion script not found"
        return 1
    fi

    # Check syntax
    if bash -n "$completion_script" 2>/dev/null; then
        print_pass "Bash completion script syntax is valid"
    else
        print_fail "Bash completion script has syntax errors"
        return 1
    fi

    # Source the script in a subshell and check for errors
    if (source "$completion_script" 2>/dev/null); then
        print_pass "Bash completion script can be sourced"
    else
        print_fail "Failed to source Bash completion script"
        return 1
    fi

    return 0
}

# Test zsh completion
test_zsh_completion() {
    print_test "Testing Zsh completion script..."

    local completion_script="${SCRIPT_DIR}/zsh_completion.sh"

    # Check if script exists
    if [[ ! -f "$completion_script" ]]; then
        print_fail "Zsh completion script not found"
        return 1
    fi

    # Check syntax
    if bash -n "$completion_script" 2>/dev/null; then
        print_pass "Zsh completion script syntax is valid"
    else
        print_fail "Zsh completion script has syntax errors"
        return 1
    fi

    return 0
}

# Test Makefile targets extraction
test_makefile_targets() {
    print_test "Testing Makefile target extraction..."

    # Find the Makefile
    local makefile="${SCRIPT_DIR}/../Makefile"

    if [[ ! -f "$makefile" ]]; then
        print_fail "Makefile not found at: $makefile"
        return 1
    fi

    # Extract targets
    local targets
    targets=$(extract_targets "$makefile")

    if [[ -z "$targets" ]]; then
        print_fail "No targets extracted from Makefile"
        return 1
    fi

    # Check for expected targets
    local expected_targets=("deploy" "destroy" "status" "help" "clean")
    local missing_targets=()

    for target in "${expected_targets[@]}"; do
        if ! echo "$targets" | grep -q "^${target}$"; then
            missing_targets+=("$target")
        fi
    done

    if [[ ${#missing_targets[@]} -eq 0 ]]; then
        print_pass "All expected targets found in Makefile"
        echo "   Found targets: $(echo "$targets" | tr '\n' ' ')"
    else
        print_fail "Missing expected targets: ${missing_targets[*]}"
        return 1
    fi

    return 0
}

# Main test execution
main() {
    echo "======================================="
    echo "Tab Completion Test Suite"
    echo "======================================="
    print_info "Running on: ${OS_DISTRO} ${OS_VERSION} (${OS_TYPE})"
    echo

    local test_failures=0

    # Run tests
    test_bash_completion || ((test_failures++))
    test_zsh_completion || ((test_failures++))
    test_makefile_targets || ((test_failures++))

    echo
    echo "======================================="
    echo "Test Summary"
    echo "======================================="

    if [[ $test_failures -eq 0 ]]; then
        print_pass "All tests passed!"
        print_info "Tab completion is ready to use"
        print_info "Install with: make install-completion"
        exit 0
    else
        print_fail "$test_failures test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"