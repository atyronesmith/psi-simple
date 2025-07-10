#!/bin/bash

# ============================================================================
# OpenShift Cluster Cleanup by Signature Script
# ============================================================================
# This script searches for OpenStack resources associated with an OpenShift
# cluster by signature name and allows safe deletion of orphaned resources.
#
# Usage: ./cleanup-by-signature.sh [signature]
# Example: ./cleanup-by-signature.sh ff9fw
# If no signature is provided, it will be extracted from openshift-install/metadata.json
#
# Prerequisites:
# - Virtual environment activated: source ~/dev/venv/oc/bin/activate
# - OpenStack cloud configured: export OS_CLOUD=psi
# - OpenStack CLI tools available
# - jq installed for JSON processing
#
# The script searches for:
# - Instances: openshift-cluster-<signature>-*
# - Images: openshift-cluster-<signature>-rhcos, openshift-cluster-<signature>-ignition
# - Server groups: openshift-cluster-<signature>-*
# - Security groups: openshift-cluster-<signature>-*
# - Networks: openshift-cluster-<signature>-*
# - Ports: openshift-cluster-<signature>-*
# - Volumes: openshift-cluster-<signature>-*
# - Routers: *<signature>* (e.g., k8s-clusterapi-cluster-openshift-cluster-api-guests-openshift-cluster-ff9fw)
# ============================================================================

set -euo pipefail

# Get script directory and source common OS library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common-os-lib.sh
source "${SCRIPT_DIR}/common-os-lib.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global arrays to store found resources
declare -a instances=()
declare -a images=()
declare -a server_groups=()
declare -a security_groups=()
declare -a networks=()
declare -a subnets=()
declare -a ports=()
declare -a volumes=()
declare -a floating_ips=()
declare -a routers=()

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

# Function to validate signature format
validate_signature() {
    local signature="$1"
    if [[ ! "$signature" =~ ^[a-z0-9]{5}$ ]]; then
        print_error "Invalid signature format. Expected: 5 alphanumeric characters (e.g., ff9fw)"
        echo "Usage: $0 <signature>"
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check required tools using common library
    if ! check_requirements openstack jq; then
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

# Function to search for resources
search_resources() {
    local signature="$1"
    local pattern="openshift-cluster-${signature}"

    print_info "Searching for resources with signature: $signature"
    echo

    # Reset global arrays for new search
    instances=()
    images=()
    server_groups=()
    security_groups=()
    networks=()
    subnets=()
    ports=()
    volumes=()
    floating_ips=()
    routers=()

    # Search for instances
    print_info "Searching for instances..."
    while IFS= read -r instance; do
        if [[ -n "$instance" ]]; then
            instances+=("$instance")
        fi
    done < <(openstack server list -f value -c Name | grep -E "^${pattern}-" || true)

    # Search for images (check specific expected names directly)
    print_info "Searching for images..."
    # Check for RHCOS image
    local rhcos_image="${pattern}-rhcos"
    if openstack image show "$rhcos_image" &>/dev/null; then
        images+=("$rhcos_image")
    fi
    # Check for ignition image
    local ignition_image="${pattern}-ignition"
    if openstack image show "$ignition_image" &>/dev/null; then
        images+=("$ignition_image")
    fi

    # Search for server groups
    print_info "Searching for server groups..."
    while IFS= read -r group; do
        if [[ -n "$group" ]]; then
            server_groups+=("$group")
        fi
    done < <(openstack server group list -f value -c Name | grep -E "^${pattern}-" || true)

    # Search for security groups
    print_info "Searching for security groups..."
    while IFS= read -r sg; do
        if [[ -n "$sg" ]]; then
            security_groups+=("$sg")
        fi
    done < <(openstack security group list -f value -c Name | grep -E "^${pattern}-" || true)

    # Search for networks
    print_info "Searching for networks..."
    while IFS= read -r network; do
        if [[ -n "$network" ]]; then
            networks+=("$network")
        fi
    done < <(openstack network list -f value -c Name | grep -E "^${pattern}-" || true)

    # Search for subnets
    print_info "Searching for subnets..."
    while IFS= read -r subnet; do
        if [[ -n "$subnet" ]]; then
            subnets+=("$subnet")
        fi
    done < <(openstack subnet list -f value -c Name | grep -E "^${pattern}-" || true)

    # Search for ports
    print_info "Searching for ports..."
    while IFS= read -r port; do
        if [[ -n "$port" ]]; then
            ports+=("$port")
        fi
    done < <(openstack port list -f value -c Name | grep -E "^${pattern}-" || true)

    # Search for volumes
    print_info "Searching for volumes..."
    while IFS= read -r volume; do
        if [[ -n "$volume" ]]; then
            volumes+=("$volume")
        fi
    done < <(openstack volume list -f value -c Name | grep -E "^${pattern}-" || true)

    # Search for floating IPs with matching description
    print_info "Searching for floating IPs..."
    while IFS= read -r fip; do
        if [[ -n "$fip" ]]; then
            floating_ips+=("$fip")
        fi
    done < <(openstack floating ip list --long -f json 2>/dev/null | \
        jq -r --arg pattern "$pattern" '.[] | select(.Description and (.Description | contains($pattern))) | ."Floating IP Address"' 2>/dev/null || true)

    # Search for routers
    print_info "Searching for routers..."
    while IFS= read -r router; do
        if [[ -n "$router" ]]; then
            routers+=("$router")
        fi
    done < <(openstack router list -f value -c Name | grep -E "${pattern}" || true)

    # Display results
    echo
    print_info "=== SEARCH RESULTS FOR SIGNATURE: $signature ==="
    echo

    local total_found=0

    if [[ ${#instances[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🖥️  Instances (${#instances[@]}):${NC}"
        for instance in "${instances[@]}"; do
            echo "   - $instance"
            ((total_found++))
        done
        echo
    fi

    if [[ ${#images[@]} -gt 0 ]]; then
        echo -e "${YELLOW}💿 Images (${#images[@]}):${NC}"
        for image in "${images[@]}"; do
            echo "   - $image"
            ((total_found++))
        done
        echo
    fi

    if [[ ${#server_groups[@]} -gt 0 ]]; then
        echo -e "${YELLOW}👥 Server Groups (${#server_groups[@]}):${NC}"
        for group in "${server_groups[@]}"; do
            echo "   - $group"
            ((total_found++))
        done
        echo
    fi

    if [[ ${#security_groups[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🔒 Security Groups (${#security_groups[@]}):${NC}"
        for sg in "${security_groups[@]}"; do
            echo "   - $sg"
            ((total_found++))
        done
        echo
    fi

    if [[ ${#networks[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🌐 Networks (${#networks[@]}):${NC}"
        for network in "${networks[@]}"; do
            echo "   - $network"
            ((total_found++))
        done
        echo
    fi

    if [[ ${#subnets[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🔗 Subnets (${#subnets[@]}):${NC}"
        for subnet in "${subnets[@]}"; do
            echo "   - $subnet"
            ((total_found++))
        done
        echo
    fi

    if [[ ${#ports[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🔌 Ports (${#ports[@]}):${NC}"
        for port in "${ports[@]}"; do
            echo "   - $port"
            ((total_found++))
        done
        echo
    fi

    if [[ ${#volumes[@]} -gt 0 ]]; then
        echo -e "${YELLOW}💾 Volumes (${#volumes[@]}):${NC}"
        for volume in "${volumes[@]}"; do
            echo "   - $volume"
            ((total_found++))
        done
        echo
    fi

    if [[ ${#floating_ips[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🌍 Floating IPs (${#floating_ips[@]}):${NC}"
        for fip in "${floating_ips[@]}"; do
            echo "   - $fip"
            ((total_found++))
        done
        echo
    fi

    if [[ ${#routers[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🔀 Routers (${#routers[@]}):${NC}"
        for router in "${routers[@]}"; do
            echo "   - $router"
            ((total_found++))
        done
        echo
    fi

    if [[ $total_found -eq 0 ]]; then
        print_success "No resources found with signature: $signature"
        exit 0
    fi

    print_warning "Total resources found: $total_found"
    echo
}

# Function to delete resources
delete_resources() {
    local signature="$1"

    print_warning "⚠️  WARNING: This will permanently delete all listed resources!"
    print_warning "⚠️  This action cannot be undone!"
    echo

    read -rp "Are you sure you want to delete all these resources? Type 'yes' to confirm: " confirmation

    if [[ "$confirmation" != "yes" ]]; then
        print_info "Deletion cancelled by user."
        exit 0
    fi

    echo
    print_info "Starting resource deletion..."

    # Delete instances first (they may depend on other resources)
    if [[ ${#instances[@]} -gt 0 ]]; then
        print_info "Deleting instances..."
        for instance in "${instances[@]}"; do
            echo "   Deleting instance: $instance"
            if openstack server delete "$instance" --wait; then
                print_success "   ✅ Deleted instance: $instance"
            else
                print_error "   ❌ Failed to delete instance: $instance"
            fi
        done
    fi

    # Delete volumes
    if [[ ${#volumes[@]} -gt 0 ]]; then
        print_info "Deleting volumes..."
        for volume in "${volumes[@]}"; do
            echo "   Deleting volume: $volume"
            if openstack volume delete "$volume"; then
                print_success "   ✅ Deleted volume: $volume"
            else
                print_error "   ❌ Failed to delete volume: $volume"
            fi
        done
    fi

    # Clear router gateways and interfaces first (required before deleting networks)
    if [[ ${#routers[@]} -gt 0 ]]; then
        print_info "Preparing routers for deletion..."
        for router in "${routers[@]}"; do
            echo "   Processing router: $router"

            # Clear external gateway
            echo "   - Clearing external gateway..."
            if openstack router unset --external-gateway "$router" 2>/dev/null; then
                print_success "     ✅ Cleared external gateway"
            else
                print_warning "     ⚠️  No external gateway to clear"
            fi

                        # Remove all subnet interfaces
            echo "   - Removing subnet interfaces..."

            # Get all ports with device_owner starting with 'network:router_interface' for this router
            local router_id
            router_id=$(openstack router show "$router" -f value -c id 2>/dev/null || echo "$router")

            # Find router interface ports
            local interface_ports
            interface_ports=$(openstack port list --device-id "$router_id" -f json 2>/dev/null | \
                            jq -r '.[] | select(.device_owner | startswith("network:router_interface")) | .id' 2>/dev/null || true)

            if [[ -n "$interface_ports" ]]; then
                while IFS= read -r port_id; do
                    if [[ -n "$port_id" ]]; then
                        # Get subnet ID for this port
                        local subnet_id
                        subnet_id=$(openstack port show "$port_id" -f json 2>/dev/null | \
                                   jq -r '.fixed_ips[0].subnet_id // empty' 2>/dev/null || true)

                        if [[ -n "$subnet_id" ]]; then
                            echo "     - Removing interface for subnet: $subnet_id"
                            if openstack router remove subnet "$router" "$subnet_id" 2>/dev/null; then
                                print_success "       ✅ Removed interface"
                            else
                                # Try alternative: delete the port directly
                                if openstack port delete "$port_id" 2>/dev/null; then
                                    print_success "       ✅ Removed interface port directly"
                                else
                                    print_warning "       ⚠️  Failed to remove interface"
                                fi
                            fi
                        fi
                    fi
                done <<< "$interface_ports"
            else
                echo "     - No router interfaces found"
            fi
        done
    fi

    # Delete ports
    if [[ ${#ports[@]} -gt 0 ]]; then
        print_info "Deleting ports..."
        for port in "${ports[@]}"; do
            echo "   Deleting port: $port"
            if openstack port delete "$port"; then
                print_success "   ✅ Deleted port: $port"
            else
                print_error "   ❌ Failed to delete port: $port"
            fi
        done
    fi

    # Delete subnets
    if [[ ${#subnets[@]} -gt 0 ]]; then
        print_info "Deleting subnets..."
        for subnet in "${subnets[@]}"; do
            echo "   Deleting subnet: $subnet"
            if openstack subnet delete "$subnet"; then
                print_success "   ✅ Deleted subnet: $subnet"
            else
                print_error "   ❌ Failed to delete subnet: $subnet"
            fi
        done
    fi

    # Delete routers before networks but after subnets/ports
    if [[ ${#routers[@]} -gt 0 ]]; then
        print_info "Deleting routers..."
        for router in "${routers[@]}"; do
            echo "   Deleting router: $router"

            # Try to delete the router with retries
            local retry_count=0
            local max_retries=3
            local deleted=false

            while [[ $retry_count -lt $max_retries ]] && [[ "$deleted" == "false" ]]; do
                if openstack router delete "$router" 2>/dev/null; then
                    print_success "   ✅ Deleted router: $router"
                    deleted=true
                else
                    retry_count=$((retry_count + 1))
                    if [[ $retry_count -lt $max_retries ]]; then
                        print_warning "   ⚠️  Failed to delete router, retrying ($retry_count/$max_retries)..."

                        # Try to clean up any remaining ports
                        local router_id
                        router_id=$(openstack router show "$router" -f value -c id 2>/dev/null || echo "$router")

                        # Find and delete any remaining ports attached to this router
                        local remaining_ports
                        remaining_ports=$(openstack port list --device-id "$router_id" -f value -c ID 2>/dev/null || true)

                        if [[ -n "$remaining_ports" ]]; then
                            echo "     - Found remaining ports, attempting cleanup..."
                            while IFS= read -r port_id; do
                                if [[ -n "$port_id" ]]; then
                                    if openstack port delete "$port_id" 2>/dev/null; then
                                        echo "       ✅ Deleted port: $port_id"
                                    fi
                                fi
                            done <<< "$remaining_ports"
                        fi

                        sleep 2  # Wait a bit before retry
                    else
                        print_error "   ❌ Failed to delete router: $router (after $max_retries attempts)"
                    fi
                fi
            done
        done
    fi

    # Delete networks (after routers are deleted)
    if [[ ${#networks[@]} -gt 0 ]]; then
        print_info "Deleting networks..."
        for network in "${networks[@]}"; do
            echo "   Deleting network: $network"
            if openstack network delete "$network"; then
                print_success "   ✅ Deleted network: $network"
            else
                print_error "   ❌ Failed to delete network: $network"
            fi
        done
    fi
    if [[ ${#routers[@]} -gt 0 ]]; then
        print_info "Deleting routers..."
        for router in "${routers[@]}"; do
            echo "   Deleting router: $router"

            # Try to delete the router with retries
            local retry_count=0
            local max_retries=3
            local deleted=false

            while [[ $retry_count -lt $max_retries ]] && [[ "$deleted" == "false" ]]; do
                if openstack router delete "$router" 2>/dev/null; then
                    print_success "   ✅ Deleted router: $router"
                    deleted=true
                else
                    retry_count=$((retry_count + 1))
                    if [[ $retry_count -lt $max_retries ]]; then
                        print_warning "   ⚠️  Failed to delete router, retrying ($retry_count/$max_retries)..."

                        # Try to clean up any remaining ports
                        local router_id
                        router_id=$(openstack router show "$router" -f value -c id 2>/dev/null || echo "$router")

                        # Find and delete any remaining ports attached to this router
                        local remaining_ports
                        remaining_ports=$(openstack port list --device-id "$router_id" -f value -c ID 2>/dev/null || true)

                        if [[ -n "$remaining_ports" ]]; then
                            echo "     - Found remaining ports, attempting cleanup..."
                            while IFS= read -r port_id; do
                                if [[ -n "$port_id" ]]; then
                                    if openstack port delete "$port_id" 2>/dev/null; then
                                        echo "       ✅ Deleted port: $port_id"
                                    fi
                                fi
                            done <<< "$remaining_ports"
                        fi

                        sleep 2  # Wait a bit before retry
                    else
                        print_error "   ❌ Failed to delete router: $router (after $max_retries attempts)"
                    fi
                fi
            done
        done
    fi

    # Delete security groups
    if [[ ${#security_groups[@]} -gt 0 ]]; then
        print_info "Deleting security groups..."
        for sg in "${security_groups[@]}"; do
            echo "   Deleting security group: $sg"
            if openstack security group delete "$sg"; then
                print_success "   ✅ Deleted security group: $sg"
            else
                print_error "   ❌ Failed to delete security group: $sg"
            fi
        done
    fi

    # Delete server groups
    if [[ ${#server_groups[@]} -gt 0 ]]; then
        print_info "Deleting server groups..."
        for group in "${server_groups[@]}"; do
            echo "   Deleting server group: $group"
            if openstack server group delete "$group"; then
                print_success "   ✅ Deleted server group: $group"
            else
                print_error "   ❌ Failed to delete server group: $group"
            fi
        done
    fi

    # Delete images
    if [[ ${#images[@]} -gt 0 ]]; then
        print_info "Deleting images..."
        for image in "${images[@]}"; do
            echo "   Deleting image: $image"
            if openstack image delete "$image"; then
                print_success "   ✅ Deleted image: $image"
            else
                print_error "   ❌ Failed to delete image: $image"
            fi
        done
    fi

    # Delete floating IPs
    if [[ ${#floating_ips[@]} -gt 0 ]]; then
        print_info "Deleting floating IPs..."
        for fip in "${floating_ips[@]}"; do
            echo "   Deleting floating IP: $fip"
            if openstack floating ip delete "$fip"; then
                print_success "   ✅ Deleted floating IP: $fip"
            else
                print_error "   ❌ Failed to delete floating IP: $fip"
            fi
        done
    fi

    echo
    print_success "Resource deletion completed for signature: $signature"
}

# Function to extract signature from metadata.json
extract_signature_from_metadata() {
    local metadata_file="openshift-install/metadata.json"

    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi

    # Extract infraID from metadata.json
    local extracted_signature
    extracted_signature=$(jq -r '.infraID // empty' "$metadata_file" 2>/dev/null)

    if [[ -z "$extracted_signature" || "$extracted_signature" == "null" ]]; then
        return 1
    fi

    # The infraID is typically in format: openshift-cluster-<signature>
    # Extract the last part (signature) after the last dash
    local signature_part="${extracted_signature##*-}"

    # Validate it looks like a signature (5 alphanumeric characters)
    if [[ "$signature_part" =~ ^[a-z0-9]{5}$ ]]; then
        echo "$signature_part"
        return 0
    fi

    return 1
}

# Main script execution
main() {
    echo "============================================================================"
    echo "OpenShift Cluster Cleanup by Signature"
    echo "============================================================================"
    echo

    local signature=""

    # Check if signature is provided as argument
    if [[ $# -eq 1 ]]; then
        signature="$1"
        print_info "Using provided signature: $signature"
    elif [[ $# -eq 0 ]]; then
        # Try to extract signature from metadata.json
        print_info "No signature provided, checking for metadata.json..."

        if signature=$(extract_signature_from_metadata); then
            print_success "Found signature from metadata.json: $signature"
        else
            print_error "No signature provided and could not extract from metadata.json"
            print_info ""
            print_info "Usage options:"
            print_info "  1. Direct script:  $0 <signature>"
            print_info "     Example:        $0 ff9fw"
            print_info ""
            print_info "  2. Via Makefile:   make cleanup-by-signature SIGNATURE=<signature>"
            print_info "     Example:        make cleanup-by-signature SIGNATURE=ff9fw"
            print_info ""
            print_info "  3. Auto-detect:    Ensure openshift-install/metadata.json exists with valid infraID"
            print_info "     Then run:       make cleanup-by-signature"
            exit 1
        fi
    else
        print_error "Usage: $0 [signature]"
        print_info "Example: $0 ff9fw"
        print_info "If no signature is provided, it will be extracted from openshift-install/metadata.json"
        exit 1
    fi

    # Validate signature format
    validate_signature "$signature"

    # Check prerequisites
    check_prerequisites

    # Search for resources
    search_resources "$signature"

    # Delete resources if confirmed
    delete_resources "$signature"
}

# Run main function with all arguments
main "$@"