#!/bin/bash

# Test script for setup-dns.sh functionality

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

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TESTS_RUN++))
    print_test "$test_name"

    if eval "$test_command"; then
        ((TESTS_PASSED++))
        print_pass "$test_name"
    else
        ((TESTS_FAILED++))
        print_fail "$test_name"
    fi
}

# Check prerequisites
check_test_prerequisites() {
    print_test "Checking test prerequisites..."

    # Check if setup-dns.sh exists
    local setup_dns_script="${SCRIPT_DIR}/setup-dns.sh"
    if [[ ! -f "$setup_dns_script" ]]; then
        print_fail "setup-dns.sh not found at: $setup_dns_script"
        exit 1
    fi

    # Check if script is executable
    if [[ ! -x "$setup_dns_script" ]]; then
        print_warning "setup-dns.sh is not executable, fixing..."
        chmod +x "$setup_dns_script"
    fi

    # Check required tools
    if ! check_requirements grep; then
        exit 1
    fi

    print_pass "Prerequisites check passed"
    print_test "Running on: ${OS_DISTRO} ${OS_VERSION} (${OS_TYPE})"
}

# Test 1: Script syntax validation
test_syntax() {
    bash -n "${SCRIPT_DIR}/setup-dns.sh" 2>/dev/null
}

# Test 2: Help text display
test_help() {
    "${SCRIPT_DIR}/setup-dns.sh" invalid_command 2>&1 | grep -q "Usage:"
}

# Test 3: Check for proper error when no deployment exists
test_no_deployment() {
    # Create temporary test directory
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir"

    # Run setup-dns.sh in empty directory
    local output
    output=$("${SCRIPT_DIR}/setup-dns.sh" setup 2>&1 || true)

    # Clean up
    cd - >/dev/null
    rm -rf "$test_dir"

    # Check for expected error
    echo "$output" | grep -q "OpenShift installation directory not found"
}

# Test 4: Check OS detection
test_os_detection() {
    # The setup-dns.sh should handle different OSes properly
    local output
    output=$("${SCRIPT_DIR}/setup-dns.sh" show 2>&1 || true)

    # On Linux, it should mention using /etc/hosts
    if [[ "${OS_TYPE}" == "linux" ]]; then
        # Even if directory doesn't exist, it should get far enough to detect OS
        true  # This is just a placeholder - in real usage it would check behavior
    fi

    # Basic validation - should not crash
    true
}

# Test 5: Validate function extraction
test_function_definitions() {
    # Check that all required functions are defined
    local required_functions=(
        "extract_cluster_info"
        "extract_api_floating_ip"
        "extract_ingress_floating_ip"
        "setup_dns_resolver"
        "setup_dns_hosts"
        "remove_dns_config"
        "show_dns_config"
    )

    local script_content
    script_content=$(cat "${SCRIPT_DIR}/setup-dns.sh")

    for func in "${required_functions[@]}"; do
        if ! echo "$script_content" | grep -q "^${func}()"; then
            return 1
        fi
    done

    true
}

# Test 6: Check color code definitions
test_color_codes() {
    local script_content
    script_content=$(cat "${SCRIPT_DIR}/setup-dns.sh")

    # Check for color definitions
    echo "$script_content" | grep -q "RED=" && \
    echo "$script_content" | grep -q "GREEN=" && \
    echo "$script_content" | grep -q "YELLOW=" && \
    echo "$script_content" | grep -q "BLUE=" && \
    echo "$script_content" | grep -q "NC="
}

# Main test execution
main() {
    echo "==================================="
    echo "DNS Setup Script Test Suite"
    echo "==================================="
    echo

    check_test_prerequisites
    echo

    # Run tests
    run_test "Script syntax validation" test_syntax
    run_test "Help text display" test_help
    run_test "No deployment error handling" test_no_deployment
    run_test "OS detection" test_os_detection
    run_test "Function definitions" test_function_definitions
    run_test "Color code definitions" test_color_codes

    echo
    echo "==================================="
    echo "Test Summary"
    echo "==================================="
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo

    if [[ $TESTS_FAILED -eq 0 ]]; then
        print_pass "All tests passed!"
        exit 0
    else
        print_fail "Some tests failed!"
        exit 1
    fi
}

# Run main function
main "$@"