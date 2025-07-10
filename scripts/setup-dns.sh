#!/bin/bash

# setup-dns.sh - Setup DNS resolution for OpenShift cluster
# This script extracts the API floating IP from OpenShift deployment files
# and configures DNS resolution

set -euo pipefail

# Get script directory and source common OS library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common-os-lib.sh
source "${SCRIPT_DIR}/common-os-lib.sh"

# Configuration
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="$PROJECT_DIR/openshift-install"
INSTALL_CONFIG="$INSTALL_DIR/install-config.yaml"
METADATA_FILE="$INSTALL_DIR/metadata.json"
LOG_FILE="$INSTALL_DIR/.openshift_install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to execute sudo command with password prompting
execute_sudo() {
    local cmd="$1"
    local description="$2"

    print_info "$description"

    # Try without password first
    if eval "$cmd" 2>/dev/null; then
        return 0
    fi

    # If that failed, try with password prompt
    print_warning "Sudo access required. Please enter your password:"
    if eval "$cmd"; then
        return 0
    else
        print_error "Failed to execute: $description"
        return 1
    fi
}

# Function to extract cluster information
extract_cluster_info() {
    local cluster_name=""
    local base_domain=""

    # Check if any required files exist
    if [[ ! -f "$INSTALL_CONFIG" && ! -f "$METADATA_FILE" ]]; then
        print_error "No cluster configuration files found"
        print_info "Expected files:"
        print_info "  - $INSTALL_CONFIG"
        print_info "  - $METADATA_FILE"
        print_info "Please run 'make deploy' first to create the cluster"
        return 1
    fi

    # Try to extract from install-config.yaml if it exists
    if [[ -f "$INSTALL_CONFIG" ]]; then
        cluster_name=$(grep -A1 "clusterName:" "$INSTALL_CONFIG" | tail -1 | sed 's/^[[:space:]]*//' | tr -d '"')
        base_domain=$(grep -A1 "baseDomain:" "$INSTALL_CONFIG" | tail -1 | sed 's/^[[:space:]]*//' | tr -d '"')
    fi

    # Fallback to metadata.json if install-config.yaml doesn't exist or is incomplete
    if [[ -z "$cluster_name" || -z "$base_domain" ]] && [[ -f "$METADATA_FILE" ]]; then
        if command -v jq >/dev/null 2>&1; then
            cluster_name=${cluster_name:-$(jq -r '.clusterName // empty' "$METADATA_FILE")}
            base_domain=${base_domain:-$(jq -r '.baseDomain // empty' "$METADATA_FILE")}
        else
            print_warning "jq not found, cannot parse metadata.json"
        fi
    fi

    # Final fallback to group_vars/all.yml for base domain
    if [[ -z "$base_domain" ]]; then
        local group_vars_file="$PROJECT_DIR/group_vars/all.yml"
        if [[ -f "$group_vars_file" ]]; then
            base_domain=$(grep -E "^openshift_base_domain:" "$group_vars_file" | cut -d'"' -f2 | head -1)
        fi
    fi

    if [[ -z "$cluster_name" || -z "$base_domain" ]]; then
        print_error "Could not extract cluster name or base domain from deployment files"
        print_info "Files checked:"
        if [[ -f "$INSTALL_CONFIG" ]]; then
            print_info "  ✅ $INSTALL_CONFIG"
        else
            print_info "  ❌ $INSTALL_CONFIG"
        fi
        if [[ -f "$METADATA_FILE" ]]; then
            print_info "  ✅ $METADATA_FILE"
        else
            print_info "  ❌ $METADATA_FILE"
        fi
        if [[ -f "$PROJECT_DIR/group_vars/all.yml" ]]; then
            print_info "  ✅ $PROJECT_DIR/group_vars/all.yml"
        else
            print_info "  ❌ $PROJECT_DIR/group_vars/all.yml"
        fi
        return 1
    fi

    echo "$cluster_name $base_domain"
}

# Function to extract API floating IP
extract_api_floating_ip() {
    local api_ip=""

    # Method 1: Try to extract from install-config.yaml
    if [[ -f "$INSTALL_CONFIG" ]]; then
        api_ip=$(grep -A1 "apiFloatingIP:" "$INSTALL_CONFIG" 2>/dev/null | tail -1 | sed 's/^[[:space:]]*//' | tr -d '"' || true)
    fi

    # Method 2: Try to extract from metadata.json
    if [[ -z "$api_ip" && -f "$METADATA_FILE" ]]; then
        if command -v jq >/dev/null 2>&1; then
            api_ip=$(jq -r '.apiFloatingIP // empty' "$METADATA_FILE" 2>/dev/null || true)
        fi
    fi

    # Method 3: Try to extract from OpenShift installer log
    if [[ -z "$api_ip" && -f "$LOG_FILE" ]]; then
        # Look for API floating IP in the log file
        api_ip=$(grep -i "api.*floating.*ip" "$LOG_FILE" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -1 || true)
    fi

    # Method 4: Try to extract from Ansible output if available
    if [[ -z "$api_ip" ]]; then
        # Check if we have Ansible facts or variables files
        local facts_file="$PROJECT_DIR/.ansible/facts.d/openshift.fact"
        if [[ -f "$facts_file" ]]; then
            api_ip=$(grep -E "api_floating_ip|apiFloatingIP" "$facts_file" | cut -d'=' -f2 | tr -d '"' || true)
        fi
    fi

    # Method 5: Try to extract from OpenStack directly
    if [[ -z "$api_ip" ]]; then
        # Check if we have OpenStack credentials available
        if [[ -n "${OS_CLOUD:-}" ]] && command -v openstack >/dev/null 2>&1; then
            # Look for active API floating IP with description containing "API openshift-cluster.example.com"
            api_ip=$(openstack floating ip list --long --status ACTIVE -f value -c "Floating IP Address" -c "Description" | grep -i "api.*openshift-cluster.example.com" | head -1 | cut -d' ' -f1 || true)
        fi
    fi

    if [[ -z "$api_ip" ]]; then
        print_error "Could not extract API floating IP from deployment files"
        return 1
    fi

    # Validate IP address format
    if ! [[ "$api_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_error "Invalid IP address format: $api_ip"
        return 1
    fi

    echo "$api_ip"
}

# Function to extract Ingress floating IP
extract_ingress_floating_ip() {
    local ingress_ip=""

    # Try to extract from OpenStack directly
    if [[ -n "${OS_CLOUD:-}" ]] && command -v openstack >/dev/null 2>&1; then
        # Look for active Ingress floating IP with description containing "Ingress openshift-cluster.example.com"
        ingress_ip=$(openstack floating ip list --long --status ACTIVE -f value -c "Floating IP Address" -c "Description" | grep -i "ingress.*openshift-cluster.example.com" | head -1 | cut -d' ' -f1 || true)
    fi

    if [[ -z "$ingress_ip" ]]; then
        print_error "Could not extract Ingress floating IP from OpenStack"
        return 1
    fi

    # Validate IP address format
    if ! [[ "$ingress_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_error "Invalid Ingress IP address format: $ingress_ip"
        return 1
    fi

    echo "$ingress_ip"
}

# Function to setup DNS using /etc/resolver (macOS only)
setup_dns_resolver() {
    local cluster_name="$1"
    local base_domain="$2"
    local api_ip="$3"

    # Check if we're on macOS
    if [[ "${OS_TYPE}" != "macos" ]]; then
        print_warning "/etc/resolver is macOS-specific, falling back to /etc/hosts method"
        # Extract Ingress floating IP for /etc/hosts approach
        print_info "Extracting Ingress floating IP..."
        local ingress_ip
        ingress_ip=$(extract_ingress_floating_ip)
        print_info "Ingress Floating IP: $ingress_ip"
        setup_dns_hosts "$cluster_name" "$base_domain" "$api_ip" "$ingress_ip"
        return
    fi

    local full_domain="${cluster_name}.${base_domain}"
    local resolver_file="/etc/resolver/${full_domain}"

    print_info "Setting up DNS resolver for domain: $full_domain"
    print_info "API IP address: $api_ip"

    # Create resolver directory if it doesn't exist
    if ! execute_sudo "sudo mkdir -p /etc/resolver" "Creating /etc/resolver directory"; then
        return 1
    fi

    # Create resolver file content
    local resolver_content
    resolver_content="# OpenShift cluster DNS resolver
# Generated by setup-dns.sh on $(date)
# Cluster: $cluster_name
# Domain: $base_domain
# API IP: $api_ip

nameserver $api_ip
domain $full_domain"

    # Create resolver file
    if ! execute_sudo "echo '$resolver_content' | sudo tee '$resolver_file' > /dev/null" "Creating DNS resolver file: $resolver_file"; then
        return 1
    fi

    print_status "Created DNS resolver file: $resolver_file"

    # Test DNS resolution
    print_info "Testing DNS resolution..."

    local api_hostname="api.${full_domain}"
    if nslookup "$api_hostname" >/dev/null 2>&1; then
        print_status "DNS resolution test successful for $api_hostname"
    else
        print_warning "DNS resolution test failed for $api_hostname"
        print_info "This may be normal if the cluster is not yet fully deployed"
    fi
}

# Function to setup DNS using /etc/hosts as fallback
setup_dns_hosts() {
    local cluster_name="$1"
    local base_domain="$2"
    local api_ip="$3"
    local ingress_ip="$4"

    local full_domain="${cluster_name}.${base_domain}"

    print_info "Setting up DNS entries in /etc/hosts"
    print_info "API IP: $api_ip"
    print_info "Ingress IP: $ingress_ip"

    # Remove existing entries and add new ones
    local hostnames=(
        "api.${full_domain}"
        "console-openshift-console.apps.${full_domain}"
        "oauth-openshift.apps.${full_domain}"
        "grafana-openshift-monitoring.apps.${full_domain}"
        "prometheus-k8s-openshift-monitoring.apps.${full_domain}"
        "integrated-oauth-server-openshift-authentication.apps.${full_domain}"
    )

    # Remove existing entries
    for hostname in "${hostnames[@]}"; do
        modify_etc_hosts "remove" "" "$hostname" 2>/dev/null || true
    done

    # Add API entry
    if ! modify_etc_hosts "add" "$api_ip" "api.${full_domain}"; then
        print_error "Failed to add API entry to /etc/hosts"
        return 1
    fi

    # Add Ingress entries
    for i in {1..5}; do
        if ! modify_etc_hosts "add" "$ingress_ip" "${hostnames[$i]}"; then
            print_error "Failed to add ${hostnames[$i]} to /etc/hosts"
            return 1
        fi
    done

    print_status "Added DNS entries to /etc/hosts"

    # Test DNS resolution
    print_info "Testing DNS resolution..."
    local api_hostname="api.${full_domain}"
    if ping -c 1 "$api_hostname" >/dev/null 2>&1; then
        print_status "DNS resolution test successful for $api_hostname"
    else
        print_warning "DNS resolution test failed for $api_hostname"
        print_info "This may be normal if the cluster is not yet fully deployed"
    fi
}

# Function to remove DNS configuration
remove_dns_config() {
    local cluster_name="$1"
    local base_domain="$2"

    local full_domain="${cluster_name}.${base_domain}"

    print_info "Removing DNS configuration for $full_domain"

    # Remove resolver file (macOS only)
    if [[ "${OS_TYPE}" == "macos" ]]; then
        local resolver_file="/etc/resolver/${full_domain}"
        if [[ -f "$resolver_file" ]]; then
            if execute_sudo "sudo rm -f '$resolver_file'" "Removing DNS resolver file: $resolver_file"; then
                print_status "Removed DNS resolver file: $resolver_file"
            else
                print_warning "Could not remove DNS resolver file: $resolver_file"
            fi
        fi
    fi

    # Remove hosts entries
    local hostnames=(
        "api.${full_domain}"
        "console-openshift-console.apps.${full_domain}"
        "oauth-openshift.apps.${full_domain}"
        "grafana-openshift-monitoring.apps.${full_domain}"
        "prometheus-k8s-openshift-monitoring.apps.${full_domain}"
        "integrated-oauth-server-openshift-authentication.apps.${full_domain}"
    )

    for hostname in "${hostnames[@]}"; do
        modify_etc_hosts "remove" "" "$hostname" 2>/dev/null || true
    done

    print_status "DNS configuration removal completed for $full_domain"
}

# Function to display current DNS configuration
show_dns_config() {
    local cluster_name="$1"
    local base_domain="$2"

    local full_domain="${cluster_name}.${base_domain}"

    print_info "Current DNS configuration for $full_domain:"

    # Show resolver file (macOS only)
    if [[ "${OS_TYPE}" == "macos" ]]; then
        local resolver_file="/etc/resolver/${full_domain}"
        if [[ -f "$resolver_file" ]]; then
            echo
            echo "Resolver file ($resolver_file):"
            cat "$resolver_file"
        fi
    fi

    # Show hosts entries
    echo
    echo "Hosts file entries:"
    local api_hostname="api.${full_domain}"
    if grep -q "$api_hostname" /etc/hosts 2>/dev/null; then
        grep "${full_domain}" /etc/hosts || true
    else
        print_warning "No hosts entries found for $full_domain"
    fi
}

# Main function
main() {
    local command="${1:-setup}"
    local use_hosts="${2:-false}"

    # Check requirements
    if ! check_requirements jq; then
        exit 1
    fi

    # Print OS information
    print_info "Running on: ${OS_DISTRO} ${OS_VERSION} (${OS_TYPE})"

    # On Linux, always use /etc/hosts method
    if [[ "${OS_TYPE}" == "linux" ]]; then
        use_hosts="true"
        if [[ "$command" == "setup" ]]; then
            print_info "Linux detected, using /etc/hosts method"
        fi
    fi

    # Check if deployment directory exists
    if [[ ! -d "$INSTALL_DIR" ]]; then
        print_error "OpenShift installation directory not found: $INSTALL_DIR"
        print_info "Please run 'make deploy' first to create the cluster"
        exit 1
    fi

    # Extract cluster information
    print_info "Extracting cluster information..."
    local cluster_info
    set +e  # Temporarily disable exit on error
    cluster_info=$(extract_cluster_info 2>&1)
    local exit_code=$?
    set -e  # Re-enable exit on error

    if [[ $exit_code -ne 0 ]]; then
        echo "$cluster_info" >&2
        exit 1
    fi
    read -r cluster_name base_domain <<< "$cluster_info"

    print_info "Cluster: $cluster_name"
    print_info "Domain: $base_domain"

    case "$command" in
        "setup")
            # Extract API floating IP
            print_info "Extracting API floating IP..."
            local api_ip
            api_ip=$(extract_api_floating_ip)

            print_info "API Floating IP: $api_ip"

            # Setup DNS
            if [[ "$use_hosts" == "true" ]]; then
                # Extract Ingress floating IP for /etc/hosts approach
                print_info "Extracting Ingress floating IP..."
                local ingress_ip
                ingress_ip=$(extract_ingress_floating_ip)

                print_info "Ingress Floating IP: $ingress_ip"

                setup_dns_hosts "$cluster_name" "$base_domain" "$api_ip" "$ingress_ip"
            else
                setup_dns_resolver "$cluster_name" "$base_domain" "$api_ip"
            fi

            print_status "DNS setup completed successfully!"
            echo
            print_info "You can now access your OpenShift cluster at:"
            echo "  - API: https://api.${cluster_name}.${base_domain}:6443"
            echo "  - Console: https://console-openshift-console.apps.${cluster_name}.${base_domain}"
            ;;
        "remove")
            remove_dns_config "$cluster_name" "$base_domain"
            ;;
        "show")
            show_dns_config "$cluster_name" "$base_domain"
            ;;
        *)
            echo "Usage: $0 {setup|remove|show} [use_hosts]"
            echo
            echo "Commands:"
            echo "  setup      - Setup DNS configuration (default)"
            echo "  remove     - Remove DNS configuration"
            echo "  show       - Show current DNS configuration"
            echo
            echo "Options:"
            echo "  use_hosts  - Use /etc/hosts instead of /etc/resolver (default: false on macOS, true on Linux)"
            echo
            echo "Examples:"
            echo "  $0 setup           # Setup DNS (auto-detects best method)"
            echo "  $0 setup true      # Force DNS using /etc/hosts"
            echo "  $0 remove          # Remove DNS configuration"
            echo "  $0 show            # Show current configuration"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"