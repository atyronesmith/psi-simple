# Cleanup by Signature Script - Enhancements and Implementation Details

## Overview
The `cleanup-by-signature.sh` script is designed to clean up orphaned OpenStack resources from failed or abandoned OpenShift cluster deployments. It identifies resources by their cluster signature (a 5-character alphanumeric identifier).

## Recent Enhancements

### 1. Auto-Detection of Cluster Signature
**Feature**: The script can now automatically extract the cluster signature from `openshift-install/metadata.json` if no signature is provided.

**Implementation**:
- Extracts the `infraID` field from metadata.json using `jq`
- The infraID format is typically: `openshift-cluster-<signature>`
- Extracts the last 5 characters after the final dash as the signature
- Falls back to manual input if metadata.json doesn't exist

**Usage**:
```bash
# Auto-detect from metadata.json
make cleanup-by-signature

# Manual override
make cleanup-by-signature SIGNATURE=ff9fw

# Direct script usage
./scripts/cleanup-by-signature.sh        # Auto-detect
./scripts/cleanup-by-signature.sh ff9fw  # Manual
```

### 2. Fixed Array Scoping Issue
**Problem**: Arrays declared with `declare -a` inside functions were not accessible in other functions.

**Solution**:
- Declare arrays globally at the top of the script
- Remove `declare -a` from inside functions
- Use consistent lowercase variable names throughout
- Arrays are now properly shared between `search_resources()` and `delete_resources()` functions

### 3. Enhanced Router Deletion
**Problem**: Routers with attached interfaces couldn't be deleted, causing "Router still has ports" errors.

**Solution Implemented**:
1. **Pre-deletion cleanup**:
   - Clear external gateways: `openstack router unset --external-gateway`
   - Find router interface ports: `openstack port list --device-id "$router_id" | jq '.[] | select(.device_owner | startswith("network:router_interface"))'`
   - Remove subnet interfaces: `openstack router remove subnet`
   - Fallback to direct port deletion if subnet removal fails

2. **Retry logic**:
   - Up to 3 deletion attempts
   - Between retries, finds and deletes any remaining ports
   - 2-second delay between attempts

3. **Improved deletion order**:
   - Routers are now deleted after ports/subnets but before networks

## Resource Types Handled

The script searches for and deletes the following resource types:

1. **Instances**: `openshift-cluster-<signature>-*`
2. **Images**:
   - `openshift-cluster-<signature>-rhcos`
   - `openshift-cluster-<signature>-ignition`
3. **Server Groups**: `openshift-cluster-<signature>-*`
4. **Security Groups**: `openshift-cluster-<signature>-*`
5. **Networks**: `openshift-cluster-<signature>-*`
6. **Subnets**: `openshift-cluster-<signature>-*`
7. **Ports**: `openshift-cluster-<signature>-*`
8. **Volumes**: `openshift-cluster-<signature>-*`
9. **Floating IPs**: With description containing the pattern
10. **Routers**: Names containing the signature (broader search pattern)

## Deletion Order

The deletion order is critical for avoiding dependency conflicts:

1. **Instances** (may depend on other resources)
2. **Volumes**
3. **Router preparation** (clear gateways, remove interfaces)
4. **Ports**
5. **Subnets**
6. **Routers** (must be after ports/subnets, before networks)
7. **Networks**
8. **Security Groups**
9. **Server Groups**
10. **Images**
11. **Floating IPs**

## Performance Optimizations

1. **Image search**: Uses direct `openstack image show` for known image names instead of listing all images
2. **Floating IP search**: Single JSON API call with jq filtering instead of multiple API calls
3. **Prerequisites**: Checks for `jq` availability for JSON processing

## Error Handling

- All OpenStack commands use `|| true` to prevent script exit on failures
- Detailed error messages with troubleshooting guidance
- Retry logic for transient failures
- Clear status messages with color coding

## Makefile Integration

The Makefile target supports both manual and auto-detect modes:
```makefile
# Clean up OpenStack resources by signature
cleanup-by-signature:
    @if [ -n "$(SIGNATURE)" ]; then \
        echo "Using provided signature: $(SIGNATURE)"; \
        ./scripts/cleanup-by-signature.sh $(SIGNATURE); \
    else \
        echo "No signature provided, will attempt to extract from openshift-install/metadata.json"; \
        ./scripts/cleanup-by-signature.sh; \
    fi
```

## Tab Completion Support

The bash and zsh completion scripts have been updated to indicate that SIGNATURE is optional:
- Bash: `make cleanup-by-signature <TAB>` → Suggests 'SIGNATURE=' (optional)
- Zsh: Shows message indicating auto-detection from metadata.json

## Testing

A test script (`scripts/test-router-cleanup.sh`) is available to verify router interface detection without actually deleting resources.