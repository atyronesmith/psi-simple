# ShellCheck Quick Reference

## Most Common Fixes

### 🔴 Always Add -r to read
```bash
# ❌ Bad
read -p "Continue? " answer

# ✅ Good
read -rp "Continue? " answer
```

### 🔴 Don't Use A && B || C
```bash
# ❌ Bad
[[ -f "$file" ]] && echo "exists" || echo "missing"

# ✅ Good
if [[ -f "$file" ]]; then
    echo "exists"
else
    echo "missing"
fi
```

### 🔴 Safe Array Assignment (macOS Compatible)
```bash
# ❌ Bad (unsafe)
array=($(command))

# ❌ Bad (bash 4.0+ only)
mapfile -t array < <(command)

# ✅ Good (bash 3.2+)
IFS=$'\n' read -d '' -r -a array < <(command) || true
```

### 🔴 Separate Declaration and Assignment
```bash
# ❌ Bad
local var="$(command)"

# ✅ Good
local var
var="$(command)"
```

### 🔴 Quote All Variables
```bash
# ❌ Bad
echo $variable
if [ $var = "test" ]; then

# ✅ Good
echo "$variable"
if [ "$var" = "test" ]; then
```

## Script Header Template
```bash
#!/bin/bash
# Description: Brief description of script purpose

set -euo pipefail

# Your script here
```

## Quick Validation Commands
```bash
# Check single script
shellcheck script.sh

# Check all scripts
find scripts -name "*.sh" -type f | xargs shellcheck

# Syntax check
bash -n script.sh

# Check bash version
bash --version
```

## Suppress False Positives
```bash
# Next line only
# shellcheck disable=SC2034
unused_but_needed="value"

# Entire file (add at top)
# shellcheck disable=SC1090
```

## Common Error Codes
- **SC2162**: read without -r
- **SC2015**: A && B || C pattern
- **SC2155**: Declare and assign separately
- **SC2034**: Unused variable
- **SC2207**: Unsafe array assignment
- **SC1090**: Can't follow source
- **SC2086**: Double quote variables