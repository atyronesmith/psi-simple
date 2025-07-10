#!/bin/bash

# cleanup-floating-ips.sh - Clean up unassociated floating IPs
# This script lists and optionally deletes unassociated floating IPs in OpenStack

set -euo pipefail

# Get script directory and source common OS library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common-os-lib.sh
source "${SCRIPT_DIR}/common-os-lib.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check required tools
    if ! check_requirements openstack; then
        exit 1
    fi

    # Check if OS_CLOUD is set
    if [[ -z "${OS_CLOUD:-}" ]]; then
        print_error "OS_CLOUD environment variable is not set."
        print_info "Please run: export OS_CLOUD=psi"
        exit 1
    fi

    # Test OpenStack connectivity
    if ! openstack token issue &> /dev/null; then
        print_error "Cannot connect to OpenStack. Please check your credentials and OS_CLOUD setting."
        exit 1
    fi

    print_success "Prerequisites check passed"
    print_info "Running on: ${OS_DISTRO} ${OS_VERSION} (${OS_TYPE})"
}

# Function to list OpenShift floating IPs
list_openshift_fips() {
    local cluster_name="${1:-openshift-cluster}"
    local base_domain="${2:-example.com}"
    local status_filter="${3:-DOWN}"

    openstack floating ip list --long --format json | \
    jq -r --arg cluster "$cluster_name" --arg domain "$base_domain" --arg status "$status_filter" '
    .[] |
    select(.Description == ("API " + $cluster + "." + $domain) or .Description == ("Ingress " + $cluster + "." + $domain)) |
    select(.Status == $status) |
    [.ID, .["Floating IP Address"], .Description, .Status] | @tsv'
}

# Function to delete floating IPs
delete_floating_ips() {
    local cluster_name="${1:-openshift-cluster}"
    local base_domain="${2:-example.com}"
    local dry_run="${3:-true}"

    print_info "Finding unused OpenShift floating IPs..."

    local fips_to_delete
    fips_to_delete=$(list_openshift_fips "$cluster_name" "$base_domain" "DOWN")

    if [[ -z "$fips_to_delete" ]]; then
        print_success "No unused floating IPs found for $cluster_name.$base_domain"
        return 0
    fi

    print_info "Found unused floating IPs:"
    echo "$fips_to_delete" | while IFS=$'\t' read -r id ip description status; do
        echo "  - $ip ($id): $description [$status]"
    done

    local count
    count=$(echo "$fips_to_delete" | wc -l)
    print_warning "Found $count unused floating IP(s) to delete"

    if [[ "$dry_run" == "true" ]]; then
        print_info "DRY RUN: Use --delete to actually remove these floating IPs"
        return 0
    fi

    # Confirm deletion
    echo
    read -rp "Are you sure you want to delete these $count floating IP(s)? [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "Deletion cancelled"
        return 0
    fi

    # Delete floating IPs
    echo "$fips_to_delete" | while IFS=$'\t' read -r id ip description status; do
        print_info "Deleting floating IP: $ip ($description)"
        if openstack floating ip delete "$id"; then
            print_success "Deleted: $ip"
        else
            print_error "Failed to delete: $ip"
        fi
    done

    print_success "Cleanup completed!"
}

# Function to show floating IP usage
show_fip_usage() {
    local cluster_name="${1:-openshift-cluster}"
    local base_domain="${2:-example.com}"

    print_info "OpenShift Floating IP Usage for $cluster_name.$base_domain:"
    echo

    # Show API floating IPs
    print_info "API Floating IPs:"
    openstack floating ip list --long --format json | \
    jq -r --arg cluster "$cluster_name" --arg domain "$base_domain" '
    .[] |
    select(.Description == ("API " + $cluster + "." + $domain)) |
    "  " + .["Floating IP Address"] + " (" + .Status + ")" +
    (if .["Fixed IP Address"] != null then " -> " + .["Fixed IP Address"] else " [UNUSED]" end)'

    echo

    # Show Ingress floating IPs
    print_info "Ingress Floating IPs:"
    openstack floating ip list --long --format json | \
    jq -r --arg cluster "$cluster_name" --arg domain "$base_domain" '
    .[] |
    select(.Description == ("Ingress " + $cluster + "." + $domain)) |
    "  " + .["Floating IP Address"] + " (" + .Status + ")" +
    (if .["Fixed IP Address"] != null then " -> " + .["Fixed IP Address"] else " [UNUSED]" end)'

    echo

    # Summary
    local api_count api_unused ingress_count ingress_unused
    api_count=$(openstack floating ip list --long --format json | jq --arg cluster "$cluster_name" --arg domain "$base_domain" '[.[] | select(.Description == ("API " + $cluster + "." + $domain))] | length')
    api_unused=$(openstack floating ip list --long --format json | jq --arg cluster "$cluster_name" --arg domain "$base_domain" '[.[] | select(.Description == ("API " + $cluster + "." + $domain) and .Status == "DOWN")] | length')
    ingress_count=$(openstack floating ip list --long --format json | jq --arg cluster "$cluster_name" --arg domain "$base_domain" '[.[] | select(.Description == ("Ingress " + $cluster + "." + $domain))] | length')
    ingress_unused=$(openstack floating ip list --long --format json | jq --arg cluster "$cluster_name" --arg domain "$base_domain" '[.[] | select(.Description == ("Ingress " + $cluster + "." + $domain) and .Status == "DOWN")] | length')

    print_info "Summary:"
    echo "  - API floating IPs: $api_count total, $api_unused unused"
    echo "  - Ingress floating IPs: $ingress_count total, $ingress_unused unused"
    echo "  - Total unused: $((api_unused + ingress_unused))"
}

# Main function
main() {
    local command="${1:-show}"
    local cluster_name="${2:-openshift-cluster}"
    local base_domain="${3:-example.com}"
    local delete_flag="${4:-false}"

    check_prerequisites

    case "$command" in
        "show")
            show_fip_usage "$cluster_name" "$base_domain"
            ;;
        "list")
            list_openshift_fips "$cluster_name" "$base_domain" "DOWN" | \
            while IFS=$'\t' read -r id ip description status; do
                echo "$ip ($id): $description [$status]"
            done
            ;;
        "cleanup")
            if [[ "$delete_flag" == "--delete" ]]; then
                delete_floating_ips "$cluster_name" "$base_domain" "false"
            else
                delete_floating_ips "$cluster_name" "$base_domain" "true"
            fi
            ;;
        *)
            echo "Usage: $0 {show|list|cleanup} [cluster_name] [base_domain] [--delete]"
            echo
            echo "Commands:"
            echo "  show    - Show floating IP usage summary (default)"
            echo "  list    - List unused floating IPs"
            echo "  cleanup - Clean up unused floating IPs (dry run unless --delete specified)"
            echo
            echo "Arguments:"
            echo "  cluster_name - OpenShift cluster name (default: openshift-cluster)"
            echo "  base_domain  - Base domain (default: example.com)"
            echo "  --delete     - Actually delete floating IPs (for cleanup command)"
            echo
            echo "Examples:"
            echo "  $0 show                                    # Show usage for default cluster"
            echo "  $0 show my-cluster my-domain.com          # Show usage for specific cluster"
            echo "  $0 list                                    # List unused floating IPs"
            echo "  $0 cleanup                                 # Dry run cleanup"
            echo "  $0 cleanup openshift-cluster example.com --delete  # Actually delete unused IPs"
            echo
            echo "Environment:"
            echo "  OS_CLOUD must be set (e.g., export OS_CLOUD=psi)"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"