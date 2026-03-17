---
name: bash-standards
description: Bash scripting standards using shellcheck, strict mode, and portable patterns. Use when writing shell scripts, reviewing bash, or automating with shell.
rule_paths:
  - "**/*.sh"
  - "**/*.bats"
detect_markers:
  - "glob:*.sh"
  - "glob:*.bats"
  - "deep_glob:*.sh"
paths:
  - "**/*.sh"
  - "**/*.bats"
---

# Bash Standards for HyperI Projects

**Shell scripting standards for CI/CD, automation, and infrastructure scripts**

---

## Quick Reference

**Lint:** `shellcheck script.sh`
**Portability:** `macbash script.sh` (checks for macOS/BSD incompatibilities)
**Test:** `bats tests/`
**Debug:** `bash -x script.sh`

**Non-negotiable:**

- ShellCheck with zero warnings
- macbash with zero warnings (macOS/BSD portability)
- BATS for all scripts > 50 lines
- Bash 3.2+ compatibility (macOS support)
- Always use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Quote all variables: `"${var}"`

---

## Strict Mode (Required)

**Every script must start with:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Optional: trace mode for debugging
# set -x
```

**What strict mode does:**

| Flag | Meaning |
|------|---------|
| `-e` (errexit) | Exit immediately on command failure |
| `-u` (nounset) | Error on undefined variables |
| `-o pipefail` | Catch errors in pipelines |

**Example failure scenarios:**

```bash
# Without -e: script continues after failure
false
echo "This runs anyway"  # BAD

# Without -u: undefined variable expands to empty
rm -rf "${UNDEFINED_VAR}/"*  # Dangerous!

# Without pipefail: only checks last command
cat missing_file | grep pattern  # Exit 0 (grep succeeds)
```

---

## Bash 3.2 Compatibility (macOS)

macOS ships with Bash 3.2. All scripts must avoid Bash 4+ features.

### Must Avoid

```bash
# ❌ Associative arrays (Bash 4+)
declare -A mymap

# ❌ Case modification (Bash 4+)
${var^^}  # Uppercase
${var,,}  # Lowercase

# ❌ &> redirection (Bash 4+)
command &> /dev/null

# ❌ coproc (Bash 4+)
coproc myproc { command; }

# ❌ mapfile/readarray (Bash 4+)
mapfile -t lines < file.txt
```

### Safe Alternatives

```bash
# ✅ Use tr for case conversion
upper=$(echo "${var}" | tr '[:lower:]' '[:upper:]')
lower=$(echo "${var}" | tr '[:upper:]' '[:lower:]')

# ✅ Use 2>&1 for combined redirection
command > /dev/null 2>&1

# ✅ Use while read for reading arrays
while IFS= read -r line; do
    lines+=("${line}")
done < file.txt
```

### Safe to Use (Bash 3.2)

```bash
# Indexed arrays
my_array=("one" "two" "three")

# Command substitution
result=$(command)

# String manipulation
${var#pattern}   # Remove prefix
${var%pattern}   # Remove suffix
${var:-default}  # Default value
${var:+value}    # Alternate value

# Here documents
cat <<EOF
Multi-line content
EOF

# [[ ]] conditionals (with proper quoting)
[[ -f "${file}" ]]
```

---

## Variable Handling

### Always Quote Variables

```bash
# ✅ Good - quoted
file="${input_path}"
cp "${src}" "${dst}"
if [[ -f "${config_file}" ]]; then

# ❌ Bad - unquoted
file=$input_path
cp $src $dst
if [[ -f $config_file ]]; then
```

### Variable Naming

```bash
# Local variables: lowercase with underscores
local file_path
local user_count=0

# Constants/exports: UPPERCASE
readonly MAX_RETRIES=3
export DATABASE_URL

# Function-local: declare with local
my_function() {
    local result
    local -r readonly_var="immutable"
}
```

### Default Values

```bash
# Default if unset
name="${1:-default_name}"

# Error if unset
name="${1:?'Name required'}"

# Assign default if unset
: "${CONFIG_PATH:=/etc/myapp/config}"
```

---

## Conditionals

### Use `[[` Instead of `[`

```bash
# ✅ Good - [[ handles spaces, globs, regex
if [[ -f "${file}" ]]; then
if [[ "${var}" == "value" ]]; then
if [[ "${var}" =~ ^[0-9]+$ ]]; then

# ❌ Bad - [ requires careful quoting
if [ -f "$file" ]; then
if [ "$var" = "value" ]; then
```

### Common Tests

```bash
# File tests
[[ -f "${path}" ]]   # Regular file exists
[[ -d "${path}" ]]   # Directory exists
[[ -e "${path}" ]]   # Any file exists
[[ -r "${path}" ]]   # Readable
[[ -w "${path}" ]]   # Writable
[[ -x "${path}" ]]   # Executable
[[ -s "${path}" ]]   # Non-empty file

# String tests
[[ -z "${var}" ]]    # Empty string
[[ -n "${var}" ]]    # Non-empty string
[[ "${a}" == "${b}" ]]  # Equal
[[ "${a}" != "${b}" ]]  # Not equal
[[ "${a}" < "${b}" ]]   # Lexicographic less than

# Numeric comparisons
(( count > 0 ))
(( count == 5 ))
[[ "${count}" -gt 0 ]]  # Alternative
```

---

## Functions

### Function Definition

```bash
# ✅ Preferred style
my_function() {
    local arg1="${1}"
    local arg2="${2:-default}"

    # Function body
}

# ❌ Avoid function keyword (less portable)
function my_function {
}
```

### Helper-First Ordering

**Place helper functions at the top, main function at the bottom:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Helper functions first
validate_input() {
    [[ -n "${1:-}" ]] || return 1
}

process_file() {
    local file="${1}"
    echo "Processing: ${file}"
}

cleanup() {
    rm -rf "${TEMP_DIR:-}"
}

# Main function uses helpers (defined above)
main() {
    local input="${1:-}"

    validate_input "${input}" || {
        echo "Error: Input required" >&2
        exit 1
    }

    trap cleanup EXIT
    process_file "${input}"
}

# Entry point at very end
main "$@"
```

**Why helper-first:** Easy to cut/paste functions, reading top-to-bottom follows "zoom in" pattern.

### Return Values

```bash
# Return status (0 = success, non-zero = error)
validate_input() {
    local input="${1}"
    if [[ -z "${input}" ]]; then
        return 1
    fi
    return 0
}

# Capture output
get_timestamp() {
    date +%Y%m%d_%H%M%S
}
timestamp=$(get_timestamp)

# Return data via global (use sparingly)
parse_config() {
    PARSED_RESULT="..."
}
```

### Error Handling in Functions

```bash
die() {
    echo "ERROR: ${1}" >&2
    exit "${2:-1}"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${1}" >&2
}

require_command() {
    command -v "${1}" >/dev/null 2>&1 || die "${1} not found"
}
```

---

## Input Validation

### Command Arguments

```bash
main() {
    # Require minimum arguments
    if [[ $# -lt 2 ]]; then
        echo "Usage: ${0} <input_file> <output_dir>" >&2
        exit 1
    fi

    local input_file="${1}"
    local output_dir="${2}"

    # Validate file exists
    [[ -f "${input_file}" ]] || die "Input file not found: ${input_file}"

    # Validate directory
    [[ -d "${output_dir}" ]] || mkdir -p "${output_dir}"
}

main "$@"
```

### Option Parsing

```bash
# Simple option parsing
while [[ $# -gt 0 ]]; do
    case "${1}" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -o|--output)
            OUTPUT="${2}"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "Unknown option: ${1}"
            ;;
        *)
            break
            ;;
    esac
done
```

---

## Configuration Cascade (HyperI Standard)

Bash scripts follow the 7-layer config cascade:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration Cascade (HyperI Standard)
# Priority: CLI > ENV > .env > config.{env}.sh > config.sh > defaults > hardcoded

# 1. Hardcoded defaults (lowest priority)
DEFAULT_HOST="localhost"
DEFAULT_PORT="8080"
DEFAULT_LOG_LEVEL="INFO"

# 2. Source defaults file (if exists)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/defaults.sh" ]] && source "${SCRIPT_DIR}/defaults.sh"

# 3. Source base config (if exists)
[[ -f "${SCRIPT_DIR}/config.sh" ]] && source "${SCRIPT_DIR}/config.sh"

# 4. Source environment-specific config
APP_ENV="${APP_ENV:-development}"
[[ -f "${SCRIPT_DIR}/config.${APP_ENV}.sh" ]] && source "${SCRIPT_DIR}/config.${APP_ENV}.sh"

# 5. Source .env file (local secrets, gitignored)
[[ -f "${SCRIPT_DIR}/.env" ]] && source "${SCRIPT_DIR}/.env"

# 6. ENV variables override (deployment)
HOST="${MYAPP_HOST:-${HOST:-${DEFAULT_HOST}}}"
PORT="${MYAPP_PORT:-${PORT:-${DEFAULT_PORT}}}"
LOG_LEVEL="${LOG_LEVEL:-${DEFAULT_LOG_LEVEL}}"

# 7. CLI args override (highest priority) - in main()
```

### CLI Argument Override Pattern

```bash
main() {
    # Parse CLI args (highest priority)
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --host=*) HOST="${1#*=}"; shift ;;
            --port=*) PORT="${1#*=}"; shift ;;
            --log-level=*) LOG_LEVEL="${1#*=}"; shift ;;
            -h|--help) usage; exit 0 ;;
            *) break ;;
        esac
    done

    log_info "Starting with HOST=${HOST} PORT=${PORT}"
}
```

---

## Logging (HyperI Standard)

### RFC 3339 Timestamps

```bash
# RFC 3339 format (required for production logs)
log_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"
}

# Example: 2025-01-20T14:30:00.123Z
```

### Logging Functions

```bash
# Log levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Level priority for filtering (Bash 3.2 compatible - no associative arrays)
get_log_priority() {
    case "${1}" in
        DEBUG)    echo 0 ;;
        INFO)     echo 1 ;;
        WARNING)  echo 2 ;;
        ERROR)    echo 3 ;;
        CRITICAL) echo 4 ;;
        *)        echo 1 ;;
    esac
}

should_log() {
    local level="${1}"
    local current
    local requested
    current=$(get_log_priority "${LOG_LEVEL}")
    requested=$(get_log_priority "${level}")
    [[ ${requested} -ge ${current} ]]
}

log_message() {
    local level="${1}"
    local message="${2}"
    shift 2

    should_log "${level}" || return 0

    # RFC 3339 timestamp
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

    # Structured output (JSON for containers, human for console)
    if [[ -t 2 ]]; then
        # Console: human-friendly with colour
        case "${level}" in
            DEBUG)    printf "\033[90m%s [DEBUG] %s\033[0m\n" "${timestamp}" "${message}" >&2 ;;
            INFO)     printf "\033[34m%s [INFO]  %s\033[0m\n" "${timestamp}" "${message}" >&2 ;;
            WARNING)  printf "\033[33m%s [WARN]  %s\033[0m\n" "${timestamp}" "${message}" >&2 ;;
            ERROR)    printf "\033[31m%s [ERROR] %s\033[0m\n" "${timestamp}" "${message}" >&2 ;;
            CRITICAL) printf "\033[91m%s [FATAL] %s\033[0m\n" "${timestamp}" "${message}" >&2 ;;
        esac
    else
        # Container/pipe: JSON for log aggregators
        printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' \
            "${timestamp}" "${level}" "${message}" >&2
    fi
}

# Convenience functions
log_debug()    { log_message "DEBUG" "$*"; }
log_info()     { log_message "INFO" "$*"; }
log_warning()  { log_message "WARNING" "$*"; }
log_error()    { log_message "ERROR" "$*"; }
log_critical() { log_message "CRITICAL" "$*"; }
```

### Log Output Modes

```bash
# Detect container vs console
if [[ -t 2 ]]; then
    LOG_MODE="console"  # Human-friendly, colours
else
    LOG_MODE="json"     # Machine-readable, no colours
fi
```

---

## Error Handling

### Trap for Cleanup

```bash
cleanup() {
    local exit_code=$?
    # Cleanup temp files
    rm -rf "${TEMP_DIR:-}"
    exit "${exit_code}"
}
trap cleanup EXIT

# Create temp dir safely
TEMP_DIR=$(mktemp -d)
```

### Error Messages to stderr

```bash
# ✅ Good - errors to stderr
echo "ERROR: Something failed" >&2
log_error() { echo "ERROR: ${1}" >&2; }

# ❌ Bad - errors to stdout
echo "ERROR: Something failed"  # Mixed with normal output
```

---

## Command Execution

### Safe Command Substitution

```bash
# ✅ Good - $() is nestable and clearer
result=$(command arg1 arg2)
nested=$(echo "$(date)")

# ❌ Bad - backticks harder to read/nest
result=`command arg1 arg2`
```

### Checking Command Success

```bash
# ✅ Good - explicit check
if ! command -v docker >/dev/null 2>&1; then
    die "Docker not installed"
fi

# ✅ Good - capture and check
if output=$(some_command 2>&1); then
    echo "Success: ${output}"
else
    die "Failed: ${output}"
fi

# ❌ Bad - ignoring failures
some_command  # May fail silently
```

### Running Commands with Arguments

```bash
# ✅ Good - array for arguments with spaces
args=(-f "${config_file}" --output "${output_dir}")
some_command "${args[@]}"

# ❌ Bad - string concatenation
args="-f ${config_file} --output ${output_dir}"
some_command ${args}  # Word splitting issues
```

---

## Loops and Iteration

**Prefer modern CLI tools over bash loops** - Use `fd`, `parallel`, `xargs -0` instead of hand-written loops. See `$AI_ROOT/standards/code-assistant/COMMON.md` for full CLI utility preferences.

### Loop Over Files

```bash
# ✅ Best - use fd with -x/-X for batch operations
fd -e txt -x process {}              # One process per file
fd -e txt -X process                 # All files as arguments

# ✅ Best - GNU parallel for complex processing
fd -e txt | parallel process {}

# ✅ Best - use xargs -0 with find for complex filters
find "${dir}" -name "*.txt" -print0 | xargs -0 process

# ✅ OK - bash loop handles spaces in filenames (when tools unavailable)
for file in "${dir}"/*.txt; do
    [[ -f "${file}" ]] || continue  # Handle no matches
    process "${file}"
done

# ✅ OK - read lines from file
while IFS= read -r line; do
    echo "${line}"
done < "${input_file}"

# ❌ Bad - word splitting on spaces
for file in $(ls *.txt); do  # Breaks on spaces
```

### Process Substitution

```bash
# Compare two command outputs
diff <(sort file1) <(sort file2)

# Read from command output
while IFS= read -r line; do
    echo "${line}"
done < <(some_command)
```

---

## ShellCheck (Required)

### Running ShellCheck

```bash
# Check single file
shellcheck script.sh

# Check all scripts
shellcheck scripts/*.sh

# Specific shell dialect
shellcheck -s bash script.sh

# Output formats
shellcheck -f json script.sh   # JSON for CI
shellcheck -f gcc script.sh    # GCC-style
```

### Common ShellCheck Warnings

```bash
# SC2086: Double quote to prevent globbing
# ❌ Bad
echo $var
# ✅ Good
echo "${var}"

# SC2046: Quote command substitution
# ❌ Bad
files=$(ls *.txt)
# ✅ Good
files="$(ls *.txt)"

# SC2034: Variable appears unused
# Fix: export, use, or prefix with _
_unused_var="intentionally unused"

# SC2155: Declare and assign separately
# ❌ Bad
local var=$(command)
# ✅ Good
local var
var=$(command)
```

### Disabling Checks (Sparingly)

```bash
# Disable specific check for line
# shellcheck disable=SC2086
echo $intentionally_unquoted

# Disable for file (at top)
# shellcheck disable=SC2034,SC2086

# Better: Fix the issue instead
```

---

## macbash — macOS/BSD Portability Checker (Required)

[macbash](https://github.com/hyperi-io/macbash) detects GNU/Linux-specific constructs that break on macOS (BSD). Run alongside ShellCheck.

**Check availability first:** `command -v macbash` — if installed, zero warnings required before merge.

### Running macbash

```bash
# Check if installed
command -v macbash >/dev/null 2>&1 && macbash script.sh

# Check single file
macbash script.sh

# Check all scripts
macbash scripts/*.sh

# Auto-fix in place
macbash -w script.sh

# Preview fixes (dry-run)
macbash -w --dry-run script.sh
```

### Common Issues macbash Catches

| Issue | GNU/Linux | Portable Fix |
|-------|-----------|-------------|
| `echo -e` | Interprets escapes | `printf "%b\n"` |
| `sed -i ''` vs `sed -i''` | Different syntax | `sed -i'' -e '...'` |
| `readarray`/`mapfile` | Bash 4+ | `while IFS= read -r` loop |
| `${var,,}` / `${var^^}` | Bash 4+ | `tr '[:upper:]' '[:lower:]'` |
| `grep -P` | PCRE (GNU only) | `grep -E` (extended regex) |
| `date -d` | GNU date | Conditional per platform |

### CI Integration

Run both tools in your CI pipeline:

```bash
shellcheck scripts/*.sh
macbash scripts/*.sh
```

Both must pass with zero warnings before merge.

---

## BATS Testing

### Test File Structure

```bash
#!/usr/bin/env bats
# tests/example.bats

setup() {
    # Run before each test
    TEMP_DIR=$(mktemp -d)
    export TEMP_DIR
}

teardown() {
    # Run after each test
    rm -rf "${TEMP_DIR}"
}

@test "script runs without arguments" {
    run ./script.sh
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "script processes input file" {
    echo "test data" > "${TEMP_DIR}/input.txt"
    run ./script.sh "${TEMP_DIR}/input.txt"
    [ "$status" -eq 0 ]
    [ -f "${TEMP_DIR}/output.txt" ]
}
```

### Running BATS Tests

```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/example.bats

# Verbose output
bats --verbose-run tests/

# TAP output for CI
bats --tap tests/
```

### Test Helpers

```bash
# tests/test_helper.bash
load_script() {
    source "${BATS_TEST_DIRNAME}/../script.sh"
}

assert_file_exists() {
    [ -f "${1}" ] || {
        echo "File not found: ${1}" >&2
        return 1
    }
}

# In test file:
load test_helper

@test "helper function works" {
    load_script
    run my_function "arg"
    [ "$status" -eq 0 ]
}
```

---

## Script Organisation

### Standard Script Template

```bash
#!/usr/bin/env bash
#
# Project:   <NAME>
# File:      <FILENAME>
# Purpose:   <One sentence>
#
# License:   FSL-1.1-ALv2
# Copyright: (c) <YEAR> HYPERI PTY LIMITED

set -euo pipefail

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${0}")"

# Configuration
: "${LOG_LEVEL:=info}"
: "${DRY_RUN:=false}"

#######################################
# Logging functions
#######################################
log() { echo "[${SCRIPT_NAME}] ${1}" >&2; }
die() { log "ERROR: ${1}"; exit "${2:-1}"; }

#######################################
# Validate prerequisites
#######################################
check_requirements() {
    command -v jq >/dev/null 2>&1 || die "jq not found"
}

#######################################
# Main function
#######################################
main() {
    check_requirements

    if [[ $# -lt 1 ]]; then
        die "Usage: ${SCRIPT_NAME} <command>"
    fi

    local command="${1}"
    shift

    case "${command}" in
        build)  do_build "$@" ;;
        test)   do_test "$@" ;;
        *)      die "Unknown command: ${command}" ;;
    esac
}

main "$@"
```

### Portable Patterns (macOS + Linux)

```bash
# macOS date vs GNU date
if [[ "$(uname)" == "Darwin" ]]; then
    DATE_CMD="gdate"  # Install via: brew install coreutils
else
    DATE_CMD="date"
fi

# sed in-place (different on macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' 's/old/new/' file
else
    sed -i 's/old/new/' file
fi

# Portable readlink -f
realpath_portable() {
    cd "$(dirname "${1}")" && pwd -P
}
```

---

## Security

### Avoid Command Injection

```bash
# ❌ Bad - user input in command
user_input="${1}"
eval "echo ${user_input}"           # DANGEROUS
bash -c "echo ${user_input}"        # DANGEROUS

# ✅ Good - use arguments, not interpolation
echo "${user_input}"

# ✅ Good - explicit argument passing
grep -F -- "${user_input}" file.txt
```

### Temporary Files

```bash
# ✅ Good - secure temp file
TEMP_FILE=$(mktemp)
trap 'rm -f "${TEMP_FILE}"' EXIT

# ✅ Good - secure temp directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

# ❌ Bad - predictable path
TEMP_FILE="/tmp/myapp_$$"  # Race condition possible
```

### Password/Secret Handling

```bash
# ❌ Bad - password on command line (visible in ps)
mysql -p"${PASSWORD}" ...

# ✅ Good - use environment or file
export MYSQL_PWD="${PASSWORD}"
mysql ...

# ✅ Good - use config file with restricted permissions
chmod 600 ~/.my.cnf
mysql --defaults-file=~/.my.cnf
```

---

## CI Integration

### GitHub Actions Example

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          scandir: './scripts'

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install BATS
        run: |
          sudo apt-get update
          sudo apt-get install -y bats
      - name: Run tests
        run: bats tests/
```

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.6
    hooks:
      - id: shellcheck
        args: [-x]  # Follow sourced files
```

---

## Resources

- ShellCheck: <https://www.shellcheck.net/>
- BATS: <https://bats-core.readthedocs.io/>
- Google Shell Style Guide: <https://google.github.io/styleguide/shellguide.html>
- Bash Cheat Sheet: <https://bertvv.github.io/cheat-sheets/Bash.html>

---

## For AI Code Assistants

The following sections are specific guidance for AI code assistants working with Bash.

---

## AI Pitfalls to Avoid

**Before generating Bash code, check these patterns:**

### DO NOT Generate

```bash
# ❌ Missing strict mode
#!/bin/bash
# ... script without set -euo pipefail
# ✅ Always start with strict mode
#!/usr/bin/env bash
set -euo pipefail

# ❌ Unquoted variables
echo $variable
cp $file $dest
# ✅ Always quote variables
echo "${variable}"
cp "${file}" "${dest}"

# ❌ Using backticks
result=`command`
# ✅ Use $() for command substitution
result=$(command)

# ❌ Hardcoded temp paths (security risk)
temp="/tmp/myapp.txt"
# ✅ Use mktemp
temp=$(mktemp)
trap 'rm -f "${temp}"' EXIT

# ❌ eval with user input (command injection)
eval "${user_input}"
# ✅ Never eval user input, use arrays for commands
cmd=("${user_command}" "${user_args[@]}")
"${cmd[@]}"

# ❌ Bash 4+ features (breaks macOS)
declare -A assoc_array          # Associative arrays
${var^^}                        # Case modification
mapfile -t lines < file         # mapfile/readarray
# ✅ Bash 3.2 compatible alternatives
# Use case statement instead of associative array
# Use tr for case: $(echo "$var" | tr '[:lower:]' '[:upper:]')
# Use while read loop instead of mapfile

# ❌ function keyword (not POSIX)
function myfunction {
# ✅ POSIX function syntax
myfunction() {

# ❌ Using [ ] for complex tests
[ "$a" == "$b" ]  # == not portable
# ✅ Use [[ ]] for bash, = for POSIX
[[ "${a}" == "${b}" ]]  # Bash
[ "${a}" = "${b}" ]     # POSIX
```

### Variable Expansion Pitfalls

```bash
# ❌ No default value handling
value="${UNDEFINED_VAR}"  # Error with set -u
# ✅ Provide defaults
value="${UNDEFINED_VAR:-default}"
value="${UNDEFINED_VAR:?Error: VAR required}"

# ❌ Nested command substitution with backticks
result=\`echo \`date\`\`  # Impossible to read
# ✅ $() nests cleanly
result=$(echo "$(date)")
```

**Always run ShellCheck before accepting AI-generated Bash code.**
**If macbash is available** (`command -v macbash`), **run it too** — fix all warnings.

---

## Mock-Aware Testing Policy

**Mocks are scaffolding, not testing. Mock-only BATS tests ≠ production tested.**

For bash scripts:

- ❌ Don't stub internal functions with fake implementations
- ✅ Mock external commands (curl, kubectl, aws CLI) in BATS unit tests
- ✅ Integration tests must exercise real commands against test infrastructure

**Production scripts must be complete:** No `# TODO`, no `exit 0` without logic, no hardcoded example paths.

**Required:** Error handling, cleanup traps, idempotence, ShellCheck, BATS tests for scripts >50 lines.

---

## Source Guard Pattern

**Enable sourcing for testing while running normally:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Functions to test
validate_input() {
    [[ -n "${1:-}" ]] || return 1
}

main() {
    validate_input "${1:-}" || exit 1
    echo "Processing..."
}

# Only run main if not sourced (enables BATS testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

**In BATS test:**

```bash
setup() {
    source "${BATS_TEST_DIRNAME}/../script.sh"
}

@test "validate_input rejects empty" {
    run validate_input ""
    [ "$status" -eq 1 ]
}
```
