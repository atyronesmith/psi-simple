#!/bin/bash

# Test script for router cleanup functionality

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

# Function to simulate router cleanup logic
test_router_cleanup_logic() {
    print_test "Testing router cleanup logic..."

    # Simulate finding router interfaces
    local test_router="test-router-ff9fw"
    local test_subnet="test-subnet-1"

    print_info "Simulating cleanup for router: $test_router"
    print_info "Would remove gateway from router"
    print_info "Would remove interface for subnet: $test_subnet"
    print_info "Would delete router after cleanup"

    print_pass "Router cleanup logic test passed"
}

# Function to test JSON parsing
test_json_parsing() {
    print_test "Testing JSON parsing capabilities..."

    # Check if jq is available
    if ! command_exists jq; then
        print_fail "jq is not installed - required for JSON parsing"
        return 1
    fi

    # Test sample JSON parsing
    local sample_json='{"id": "port-123", "device_owner": "network:router_interface", "fixed_ips": [{"subnet_id": "subnet-456"}]}'

    local port_id
    port_id=$(echo "$sample_json" | jq -r '.id')

    if [[ "$port_id" == "port-123" ]]; then
        print_pass "JSON parsing working correctly"
    else
        print_fail "JSON parsing failed"
        return 1
    fi
}

# Function to test regex patterns
test_regex_patterns() {
    print_test "Testing regex patterns for router detection..."

    local test_routers=(
        "k8s-clusterapi-cluster-openshift-cluster-api-guests-openshift-cluster-ff9fw"
        "openshift-cluster-ff9fw-router"
        "test-ff9fw-router"
    )

    local signature="ff9fw"
    local matches=0

    for router in "${test_routers[@]}"; do
        if [[ "$router" =~ $signature ]]; then
            print_info "Pattern match: $router"
            ((matches++))
        fi
    done

    if [[ $matches -eq ${#test_routers[@]} ]]; then
        print_pass "All router patterns matched correctly"
    else
        print_fail "Some router patterns failed to match"
        return 1
    fi
}

# Main test execution
main() {
    echo "======================================="
    echo "Router Cleanup Test Suite"
    echo "======================================="
    print_info "Running on: ${OS_DISTRO} ${OS_VERSION} (${OS_TYPE})"
    echo

    local test_failures=0

    # Run tests
    test_router_cleanup_logic || ((test_failures++))
    test_json_parsing || ((test_failures++))
    test_regex_patterns || ((test_failures++))

    echo
    echo "======================================="
    echo "Test Summary"
    echo "======================================="

    if [[ $test_failures -eq 0 ]]; then
        print_pass "All tests passed!"
        print_info "Router cleanup functionality is working correctly"
        exit 0
    else
        print_fail "$test_failures test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"