#!/bin/bash
# Bash tab completion for the project Makefile

# Get script directory and source common OS library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common-os-lib.sh
source "${SCRIPT_DIR}/common-os-lib.sh" 2>/dev/null || true

# Function to extract available targets from Makefile
_extract_makefile_targets() {
    local makefile="$1"
    # Use appropriate grep command
    local grep_cmd
    grep_cmd="$(get_grep_cmd 2>/dev/null || echo "grep")"

    # Extract targets, excluding special targets starting with '.'
    ${grep_cmd} -E '^[a-zA-Z0-9_-]+:.*' "${makefile}" 2>/dev/null | \
        ${grep_cmd} -v '^\.' | \
        cut -d: -f1 | \
        sort -u
}

# Tab completion function
_make_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Find project root by looking for Makefile
    local dir="${PWD}"
    local makefile=""

    while [[ "${dir}" != "/" ]]; do
        if [[ -f "${dir}/Makefile" ]] && grep -q "OpenShift Compact Cluster Deployment" "${dir}/Makefile" 2>/dev/null; then
            makefile="${dir}/Makefile"
            break
        fi
        dir="$(dirname "${dir}")"
    done

    # If we're not in the project directory, don't provide completions
    if [[ -z "${makefile}" ]]; then
        return 0
    fi

    # Handle special cases based on the previous word
    case "${prev}" in
        # For cleanup-by-signature, suggest SIGNATURE= parameter
        cleanup-by-signature)
            if [[ "${cur}" != *=* ]]; then
                COMPREPLY=( "SIGNATURE=" )
                return 0
            fi
            ;;
        # For fip-cleanup, suggest FIP_DELETE parameter
        fip-cleanup)
            if [[ "${cur}" == FIP_DELETE=* ]]; then
                local prefix="FIP_DELETE="
                COMPREPLY=( "${prefix}true" "${prefix}false" )
                return 0
            elif [[ "${cur}" != *=* ]]; then
                COMPREPLY=( "FIP_DELETE=" )
                return 0
            fi
            ;;
    esac

    # If current word contains '=', don't complete
    if [[ "${cur}" == *=* ]]; then
        return 0
    fi

    # Get available targets from Makefile
    local targets
    IFS=$'\n' read -d '' -r -a targets < <(_extract_makefile_targets "${makefile}") || true

    # Generate completions
    local IFS=$'\n'
    COMPREPLY=($(compgen -W "${targets[*]}" -- "${cur}"))
}

# Register the completion function for 'make'
complete -F _make_completion make