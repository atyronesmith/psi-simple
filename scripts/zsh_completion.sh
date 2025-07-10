#!/bin/bash
# Zsh tab completion setup for the project Makefile

# Get script directory and source common OS library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common-os-lib.sh
source "${SCRIPT_DIR}/common-os-lib.sh" 2>/dev/null || true

# Create the Zsh completion function
cat << 'EOF'
#compdef make

# Zsh completion for OpenShift Compact Cluster Project Makefile

_make_openshift() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    # Find project root by looking for Makefile
    local dir="${PWD}"
    local makefile=""

    while [[ "${dir}" != "/" ]]; do
        if [[ -f "${dir}/Makefile" ]] && grep -q "OpenShift Compact Cluster Deployment" "${dir}/Makefile" 2>/dev/null; then
            makefile="${dir}/Makefile"
            break
        fi
        dir="${dir:h}"  # dirname in zsh
    done

    # If we're not in the project directory, use default completion
    if [[ -z "${makefile}" ]]; then
        _default
        return
    fi

    # Extract targets from Makefile
    local -a targets
    targets=(${(f)"$(grep -E '^[a-zA-Z0-9_-]+:' "${makefile}" 2>/dev/null | cut -d: -f1 | grep -v '^\.PHONY' | sort -u)"})

    # Check if we're completing a parameter
    if [[ "${words[CURRENT-1]}" == "cleanup-by-signature" ]]; then
        _message "SIGNATURE=<5-char-signature> (optional - auto-detects from metadata.json if not provided)"
        return
    fi

    if [[ "${words[CURRENT-1]}" == "fip-cleanup" ]]; then
        _values 'parameter' 'FIP_DELETE=true' 'FIP_DELETE=false'
        return
    fi

    # Check if current word contains '='
    if [[ "${words[CURRENT]}" == *=* ]]; then
        local param="${words[CURRENT]%%=*}"
        case "$param" in
            FIP_DELETE)
                _values 'value' 'true' 'false'
                return
                ;;
            SIGNATURE)
                _message "5-character signature (e.g., ff9fw)"
                return
                ;;
        esac
    fi

    # Offer targets
    _describe -t targets 'make targets' targets
}

# Only override completion when in project directory
_make_wrapper() {
    if [[ -f "Makefile" ]] && [[ -f "deploy.yml" ]]; then
        _make_openshift "$@"
    else
        # Use default make completion
        _default
    fi
}

compdef _make_wrapper make
EOF