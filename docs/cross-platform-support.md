# Cross-Platform Support Implementation

## Overview
This document describes the implementation of cross-platform support for macOS, Fedora 42, and RHEL 9 in the OpenShift Compact Cluster deployment project.

## Common OS Library

### Location
`scripts/common-os-lib.sh`

### Purpose
Provides a centralized library for OS detection and cross-platform compatibility functions that all scripts can source.

### Key Features

#### OS Detection
```bash
# Automatically populated variables:
OS_TYPE       # "macos" or "linux"
OS_DISTRO     # "macos", "fedora", "rhel", or "unknown"
OS_VERSION    # Version string (e.g., "15.5", "42", "9.0")
OS_ARCH       # Architecture (e.g., "arm64", "x86_64")
```

#### Cross-Platform Functions

1. **sed_inplace()** - Handles sed -i differences
   ```bash
   # macOS: sed -i ''
   # Linux: sed -i
   sed_inplace 's/old/new/g' file.txt
   ```

2. **base64_decode()** - Handles base64 differences
   ```bash
   # macOS: base64 -D
   # Linux: base64 -d
   base64_decode < encoded.txt
   ```

3. **get_package_manager()** - Returns appropriate package manager
   ```bash
   # Returns: "brew", "dnf", "yum", or "none"
   pkg_manager=$(get_package_manager)
   ```

4. **check_requirements()** - Validates required tools with OS-specific installation instructions
   ```bash
   check_requirements jq openstack python3
   ```

5. **modify_etc_hosts()** - Cross-platform /etc/hosts management
   ```bash
   modify_etc_hosts "add" "10.0.0.1" "hostname.example.com"
   modify_etc_hosts "remove" "" "hostname.example.com"
   ```

## Updated Components

### 1. Shell Scripts
All scripts in `scripts/` now:
- Source `common-os-lib.sh` for OS detection
- Use cross-platform functions instead of OS-specific commands
- Provide appropriate error messages and installation instructions per OS

### 2. Makefile
Updated to detect OS and provide platform-specific instructions:
- ShellCheck installation instructions vary by platform
- Tab completion installation detects appropriate directories
- DNS operations work on all platforms

### 3. Ansible Roles

#### openshift-install Role
- Detects OS type and downloads appropriate binaries (mac/linux)
- DNS setup works on all platforms (not just macOS)
- Uses Ansible facts for OS detection

Example:
```yaml
- name: Set OpenShift binary URLs based on OS
  ansible.builtin.set_fact:
    installer_url: "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/{{ openshift_version }}/openshift-install-{{ 'mac' if os_type == 'darwin' else 'linux' }}.tar.gz"
    client_url: "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/{{ openshift_version }}/openshift-client-{{ 'mac' if os_type == 'darwin' else 'linux' }}.tar.gz"
```

## Platform-Specific Behaviors

### macOS (Darwin)
- Uses Homebrew for package management
- Supports `/etc/resolver` for DNS (preferred method)
- BSD command variants handled (sed, base64, etc.)
- Tab completion installed to Homebrew directories

### Fedora 42
- Uses dnf package manager
- Only `/etc/hosts` for DNS configuration
- GNU command variants
- Tab completion installed to system directories

### RHEL 9
- Uses dnf (or falls back to yum) package manager
- Only `/etc/hosts` for DNS configuration
- GNU command variants
- Tab completion installed to system directories

## Testing

### Manual Testing
Test the OS detection:
```bash
./scripts/common-os-lib.sh
```

Output example:
```
OS Detection Results:
  OS Type: macos
  Distribution: macos
  Version: 15.5
  Architecture: arm64
  Package Manager: brew
```

### Script Validation
All scripts pass ShellCheck validation:
```bash
make shellcheck
```

## Benefits

1. **Single Codebase**: No need for separate scripts per platform
2. **Automatic Detection**: Scripts adapt to the running environment
3. **Consistent Experience**: Same commands work across all platforms
4. **Better Error Messages**: Platform-specific installation instructions
5. **Maintainability**: Centralized OS-specific logic in one library

## Future Enhancements

1. **Additional Platforms**: Easy to add support for Ubuntu, Debian, etc.
2. **Container Support**: Detect if running in containers
3. **WSL Support**: Handle Windows Subsystem for Linux
4. **Architecture Detection**: Handle ARM vs x86_64 differences