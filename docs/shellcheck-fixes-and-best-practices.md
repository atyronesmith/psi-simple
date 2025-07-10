# ShellCheck Fixes and Best Practices

## Overview
This document captures the shellcheck fixes applied to the project scripts and provides best practices for writing shell scripts that pass shellcheck validation while maintaining compatibility with older bash versions (particularly bash 3.2 on macOS).

## Common ShellCheck Issues and Fixes

### 1. SC2162: read without -r will mangle backslashes
**Issue**: Using `read` without the `-r` flag can cause backslashes to be interpreted as escape characters.

**Bad:**
```bash
read -p "Are you sure? " confirm
```

**Good:**
```bash
read -rp "Are you sure? " confirm
```

**Files Fixed:**
- `cleanup-by-signature.sh`
- `cleanup-floating-ips.sh`

### 2. SC2015: Note that A && B || C is not if-then-else
**Issue**: The pattern `A && B || C` doesn't work as expected when B can fail.

**Bad:**
```bash
[[ -f "$file" ]] && echo "✅ Found" || echo "❌ Not found"
```

**Good:**
```bash
if [[ -f "$file" ]]; then
    echo "✅ Found"
else
    echo "❌ Not found"
fi
```

**Files Fixed:**
- `setup-dns.sh`

### 3. SC2155: Declare and assign separately to avoid masking return values
**Issue**: Combining declaration and command substitution can mask the command's exit status.

**Bad:**
```bash
local content="$(some_command)"
```

**Good:**
```bash
local content
content="$(some_command)"
```

**Files Fixed:**
- `setup-dns.sh`

### 4. SC2034: Variable appears unused
**Issue**: Variables declared but never used should be removed.

**Bad:**
```bash
local RED='\033[0;31m'  # Never used
local opts              # Never used
```

**Good:**
```bash
# Simply remove unused variables
```

**Files Fixed:**
- `test-router-cleanup.sh` (removed unused `RED`)
- `bash_completion.sh` (removed unused `opts`)

### 5. SC2207: Prefer mapfile or read -a to split command output
**Issue**: Using `array=($(command))` is unsafe as it's subject to word splitting and globbing.

**Bad:**
```bash
targets=($(grep -E '^[a-zA-Z0-9_-]+:' Makefile | cut -d: -f1))
COMPREPLY=($(compgen -W "$words" -- "$cur"))
```

**Good (bash 4.0+):**
```bash
mapfile -t targets < <(grep -E '^[a-zA-Z0-9_-]+:' Makefile | cut -d: -f1)
mapfile -t COMPREPLY < <(compgen -W "$words" -- "$cur")
```

**Good (bash 3.2+ compatible):**
```bash
IFS=$'\n' read -d '' -r -a targets < <(grep -E '^[a-zA-Z0-9_-]+:' Makefile | cut -d: -f1)
IFS=$'\n' read -d '' -r -a COMPREPLY < <(compgen -W "$words" -- "$cur") || true
```

**Files Fixed:**
- `bash_completion.sh`
- `test-completion.sh`

## macOS Bash Compatibility

### The bash 3.2 Challenge
macOS ships with bash 3.2 (from 2007) due to licensing issues. Many modern bash features are not available:

**Features NOT available in bash 3.2:**
- `mapfile` / `readarray` (introduced in bash 4.0)
- Associative arrays (bash 4.0)
- `${var^^}` and `${var,,}` for case conversion (bash 4.0)
- `+=` for array appending in some contexts

### Compatible Array Assignment Patterns

**Pattern 1: Reading lines into array**
```bash
# bash 4.0+ only
mapfile -t array < <(command)

# bash 3.2+ compatible
IFS=$'\n' read -d '' -r -a array < <(command) || true
```

**Pattern 2: Appending to arrays**
```bash
# bash 4.0+ only
mapfile -t -O "${#array[@]}" array < <(command)

# bash 3.2+ compatible
local additional
IFS=$'\n' read -d '' -r -a additional < <(command) || true
array+=("${additional[@]}")
```

**Pattern 3: Simple array building**
```bash
# Always safe
array=()
array+=("element1")
array+=("element2")
```

## Best Practices for Shell Scripts

### 1. Always Use Strict Mode
```bash
set -euo pipefail
```
- `-e`: Exit on error
- `-u`: Exit on undefined variable
- `-o pipefail`: Exit on pipe failure

### 2. Proper Error Handling
```bash
# Use || true when failure is acceptable
some_command || true

# Check return codes explicitly
if some_command; then
    echo "Success"
else
    echo "Failed with code: $?"
fi
```

### 3. Safe Variable Expansion
```bash
# Always quote variables
echo "$variable"

# Use default values
echo "${variable:-default}"

# Check if variable is set
if [[ -n "${variable:-}" ]]; then
    echo "Variable is set"
fi
```

### 4. Array Handling
```bash
# Check array length
if [[ ${#array[@]} -gt 0 ]]; then
    echo "Array has elements"
fi

# Safe array expansion
for element in "${array[@]}"; do
    echo "$element"
done
```

### 5. Command Substitution
```bash
# Prefer $() over backticks
result=$(command)

# Capture both output and exit code
output=$(command 2>&1) || exit_code=$?
```

## ShellCheck Integration

### Running ShellCheck
```bash
# Check single file
shellcheck script.sh

# Check all scripts
find . -name "*.sh" -type f | xargs shellcheck

# Check with specific shell
shellcheck -s bash script.sh
```

### Ignoring False Positives
```bash
# Disable specific check for next line
# shellcheck disable=SC2034
unused_var="needed for something external"

# Disable for entire file (add at top)
# shellcheck disable=SC1090,SC1091
```

### Common Suppressions
- `SC1090`: Can't follow non-constant source
- `SC1091`: Not following sourced files
- `SC2034`: Variable appears unused (when used externally)

## Testing Scripts

### Syntax Checking
```bash
# Basic syntax check
bash -n script.sh

# Check all scripts
for script in scripts/*.sh; do
    echo -n "Checking $script: "
    bash -n "$script" && echo "✅ OK" || echo "❌ FAIL"
done
```

### Compatibility Testing
```bash
# Test with specific bash version
docker run -v "$PWD:/scripts" bash:3.2 bash /scripts/script.sh
```

## Zsh Completion Special Case
Zsh completion scripts have different syntax and should not be checked with shellcheck:

```bash
# Add at top of zsh completion scripts
# shellcheck disable=SC1000-SC9999
```

## Summary of Key Points

1. **Always use `-r` with `read` commands**
2. **Avoid `A && B || C` pattern - use proper if-then-else**
3. **Separate variable declaration from assignment when using command substitution**
4. **Remove unused variables**
5. **Use bash 3.2 compatible array assignment on macOS**
6. **Always quote variables**
7. **Use `set -euo pipefail` for strict error handling**
8. **Test scripts with both shellcheck and bash -n**

## References

- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [Bash Pitfalls](http://mywiki.wooledge.org/BashPitfalls)
- [Bash FAQ](http://mywiki.wooledge.org/BashFAQ)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)