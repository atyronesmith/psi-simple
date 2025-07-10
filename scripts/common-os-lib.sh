#!/bin/bash
# Common OS detection and compatibility library
# Source this file in all scripts for cross-platform compatibility

# Strict mode
set -euo pipefail

# OS Detection Variables
OS_TYPE=""
OS_DISTRO=""
OS_VERSION=""
OS_ARCH=""

# Detect operating system
detect_os() {
    local kernel_name
    kernel_name="$(uname -s)"

    case "${kernel_name}" in
        Darwin*)
            OS_TYPE="macos"
            OS_DISTRO="macos"
            OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo "unknown")"
            OS_ARCH="$(uname -m)"
            ;;
        Linux*)
            OS_TYPE="linux"
            OS_ARCH="$(uname -m)"

            # Detect Linux distribution
            if [[ -f /etc/os-release ]]; then
                # shellcheck disable=SC1091
                source /etc/os-release
                OS_DISTRO="${ID:-unknown}"
                OS_VERSION="${VERSION_ID:-unknown}"
            elif [[ -f /etc/redhat-release ]]; then
                if grep -q "Fedora" /etc/redhat-release; then
                    OS_DISTRO="fedora"
                    OS_VERSION="$(grep -oE '[0-9]+' /etc/redhat-release | head -1)"
                elif grep -q "Red Hat Enterprise Linux" /etc/redhat-release; then
                    OS_DISTRO="rhel"
                    OS_VERSION="$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)"
                fi
            else
                OS_DISTRO="unknown"
                OS_VERSION="unknown"
            fi
            ;;
        *)
            OS_TYPE="unknown"
            OS_DISTRO="unknown"
            OS_VERSION="unknown"
            OS_ARCH="unknown"
            ;;
    esac
}

# Initialize OS detection
detect_os

# Platform-specific command wrappers

# sed in-place editing (handles macOS vs Linux differences)
sed_inplace() {
    if [[ "${OS_TYPE}" == "macos" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# base64 decoding (handles macOS vs Linux differences)
base64_decode() {
    if [[ "${OS_TYPE}" == "macos" ]]; then
        base64 -D "$@"
    else
        base64 -d "$@"
    fi
}

# Get number of CPU cores
get_cpu_cores() {
    if [[ "${OS_TYPE}" == "macos" ]]; then
        sysctl -n hw.ncpu 2>/dev/null || echo "1"
    else
        nproc 2>/dev/null || grep -c processor /proc/cpuinfo 2>/dev/null || echo "1"
    fi
}

# Check if running with sudo/root
is_root() {
    [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

# Get appropriate package manager
get_package_manager() {
    case "${OS_DISTRO}" in
        macos)
            if command -v brew >/dev/null 2>&1; then
                echo "brew"
            else
                echo "none"
            fi
            ;;
        fedora|rhel)
            if command -v dnf >/dev/null 2>&1; then
                echo "dnf"
            elif command -v yum >/dev/null 2>&1; then
                echo "yum"
            else
                echo "none"
            fi
            ;;
        *)
            echo "none"
            ;;
    esac
}

# Install package using appropriate package manager
install_package() {
    local package="$1"
    local pkg_manager
    pkg_manager="$(get_package_manager)"

    case "${pkg_manager}" in
        brew)
            brew install "${package}"
            ;;
        dnf)
            sudo dnf install -y "${package}"
            ;;
        yum)
            sudo yum install -y "${package}"
            ;;
        *)
            echo "Error: No supported package manager found" >&2
            return 1
            ;;
    esac
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get appropriate grep command (GNU grep vs BSD grep)
get_grep_cmd() {
    if [[ "${OS_TYPE}" == "macos" ]]; then
        # Check if GNU grep is installed
        if command -v ggrep >/dev/null 2>&1; then
            echo "ggrep"
        else
            echo "grep"
        fi
    else
        echo "grep"
    fi
}

# Get appropriate sed command (GNU sed vs BSD sed)
get_sed_cmd() {
    if [[ "${OS_TYPE}" == "macos" ]]; then
        # Check if GNU sed is installed
        if command -v gsed >/dev/null 2>&1; then
            echo "gsed"
        else
            echo "sed"
        fi
    else
        echo "sed"
    fi
}

# Get appropriate readlink command
get_readlink_cmd() {
    if [[ "${OS_TYPE}" == "macos" ]]; then
        # Check if GNU readlink is installed
        if command -v greadlink >/dev/null 2>&1; then
            echo "greadlink -f"
        else
            # macOS readlink doesn't support -f, use alternative
            echo "python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))'"
        fi
    else
        echo "readlink -f"
    fi
}

# Get real path of a file/directory
get_realpath() {
    local path="$1"
    local readlink_cmd
    readlink_cmd="$(get_readlink_cmd)"

    if [[ "${readlink_cmd}" == "python3"* ]]; then
        eval "${readlink_cmd} '${path}'"
    else
        ${readlink_cmd} "${path}"
    fi
}

# Handle /etc/hosts modifications
modify_etc_hosts() {
    local action="$1"  # add or remove
    local ip="$2"
    local hostname="$3"

    # Check permissions
    if [[ ! -w /etc/hosts ]] && ! is_root; then
        echo "Error: Need sudo permissions to modify /etc/hosts" >&2
        echo "Please run with sudo or as root" >&2
        return 1
    fi

    case "${action}" in
        add)
            # Remove any existing entries first
            if [[ "${OS_TYPE}" == "macos" ]]; then
                sudo sed -i '' "/[[:space:]]${hostname}$/d" /etc/hosts
            else
                sudo sed -i "/[[:space:]]${hostname}$/d" /etc/hosts
            fi
            # Add new entry
            echo "${ip} ${hostname}" | sudo tee -a /etc/hosts >/dev/null
            ;;
        remove)
            if [[ "${OS_TYPE}" == "macos" ]]; then
                sudo sed -i '' "/[[:space:]]${hostname}$/d" /etc/hosts
            else
                sudo sed -i "/[[:space:]]${hostname}$/d" /etc/hosts
            fi
            ;;
        *)
            echo "Error: Invalid action. Use 'add' or 'remove'" >&2
            return 1
            ;;
    esac
}

# Get appropriate timeout command
get_timeout_cmd() {
    if [[ "${OS_TYPE}" == "macos" ]]; then
        # Check if GNU timeout is installed
        if command -v gtimeout >/dev/null 2>&1; then
            echo "gtimeout"
        elif command -v timeout >/dev/null 2>&1; then
            echo "timeout"
        else
            # No timeout command available
            echo ""
        fi
    else
        echo "timeout"
    fi
}

# Run command with timeout
run_with_timeout() {
    local timeout_seconds="$1"
    shift
    local timeout_cmd
    timeout_cmd="$(get_timeout_cmd)"

    if [[ -z "${timeout_cmd}" ]]; then
        # No timeout command available, run without timeout
        "$@"
    else
        "${timeout_cmd}" "${timeout_seconds}" "$@"
    fi
}

# Check for required commands and suggest installation
check_requirements() {
    local requirements=("$@")
    local missing=()
    local pkg_manager
    pkg_manager="$(get_package_manager)"

    for cmd in "${requirements[@]}"; do
        if ! command_exists "${cmd}"; then
            missing+=("${cmd}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing required commands: ${missing[*]}" >&2
        echo "" >&2

        # Provide installation suggestions
        case "${OS_DISTRO}" in
            macos)
                echo "To install missing commands on macOS:" >&2
                for cmd in "${missing[@]}"; do
                    case "${cmd}" in
                        jq) echo "  brew install jq" >&2 ;;
                        python3) echo "  brew install python3" >&2 ;;
                        openstack) echo "  pip3 install python-openstackclient" >&2 ;;
                        ansible-lint) echo "  pip3 install ansible-lint" >&2 ;;
                        shellcheck) echo "  brew install shellcheck" >&2 ;;
                        *) echo "  brew install ${cmd} (or search: brew search ${cmd})" >&2 ;;
                    esac
                done
                ;;
            fedora)
                echo "To install missing commands on Fedora:" >&2
                for cmd in "${missing[@]}"; do
                    case "${cmd}" in
                        jq) echo "  sudo dnf install -y jq" >&2 ;;
                        python3) echo "  sudo dnf install -y python3" >&2 ;;
                        openstack) echo "  pip3 install python-openstackclient" >&2 ;;
                        ansible-lint) echo "  pip3 install ansible-lint" >&2 ;;
                        shellcheck) echo "  sudo dnf install -y ShellCheck" >&2 ;;
                        *) echo "  sudo dnf install -y ${cmd}" >&2 ;;
                    esac
                done
                ;;
            rhel)
                echo "To install missing commands on RHEL:" >&2
                for cmd in "${missing[@]}"; do
                    case "${cmd}" in
                        jq) echo "  sudo dnf install -y jq" >&2 ;;
                        python3) echo "  sudo dnf install -y python3" >&2 ;;
                        openstack) echo "  pip3 install python-openstackclient" >&2 ;;
                        ansible-lint) echo "  pip3 install ansible-lint" >&2 ;;
                        shellcheck) echo "  sudo dnf install -y ShellCheck" >&2 ;;
                        *) echo "  sudo dnf install -y ${cmd}" >&2 ;;
                    esac
                done
                ;;
        esac

        return 1
    fi

    return 0
}

# Export functions for use in sourcing scripts
export -f sed_inplace
export -f base64_decode
export -f get_cpu_cores
export -f is_root
export -f get_package_manager
export -f install_package
export -f command_exists
export -f get_grep_cmd
export -f get_sed_cmd
export -f get_readlink_cmd
export -f get_realpath
export -f modify_etc_hosts
export -f get_timeout_cmd
export -f run_with_timeout
export -f check_requirements

# Print OS detection results if running directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "OS Detection Results:"
    echo "  OS Type: ${OS_TYPE}"
    echo "  Distribution: ${OS_DISTRO}"
    echo "  Version: ${OS_VERSION}"
    echo "  Architecture: ${OS_ARCH}"
    echo "  Package Manager: $(get_package_manager)"
fi