---
paths:
  - "**/*.sh"
  - "**/*.bats"
detect_markers:
  - "glob:*.sh"
  - "glob:*.bats"
  - "deep_glob:*.sh"
source: languages/BASH.md
---

<!-- override: manual -->
## Quick Reference

- **Lint:** `shellcheck script.sh`
- **Portability:** `macbash script.sh` ([macbash](https://github.com/hyperi-io/macbash))
- **Test:** `bats tests/`
- **Debug:** `bash -x script.sh`
- ShellCheck with zero warnings
- macbash with zero warnings
- BATS for all scripts > 50 lines
- Bash 3.2+ compatibility (macOS support)

## Strict Mode (Required)

- Every script starts with `#!/usr/bin/env bash` then `set -euo pipefail`
- `-e`: exit on failure; `-u`: error on undefined vars; `-o pipefail`: catch pipeline errors

## Bash 3.2 Compatibility

- Never use: `declare -A` (associative arrays), `${var^^}` / `${var,,}`, `&>`, `coproc`, `mapfile`/`readarray`
- Case conversion: `upper=$(echo "${var}" | tr '[:lower:]' '[:upper:]')`
- Combined redirect: `command > /dev/null 2>&1`
- Read lines: `while IFS= read -r line; do lines+=("${line}"); done < file.txt`

## Variable Handling

- Always quote: `"${var}"` — no exceptions
- ❌ `cp $src $dst` → ✅ `cp "${src}" "${dst}"`
- Local vars: `lowercase_underscores`; constants/exports: `UPPERCASE`
- Declare and assign separately: ❌ `local var=$(cmd)` → ✅ `local var; var=$(cmd)`
- Defaults: `"${1:-default}"`, error if unset: `"${1:?'Name required'}"`
- Assign default: `: "${CONFIG_PATH:=/etc/myapp/config}"`

## Conditionals

- Use `[[ ]]` not `[ ]` for all tests
- Use `(( ))` for arithmetic comparisons

## Functions

- Use `func_name() {` syntax — never `function` keyword
- All function variables must be `local`
- Helper functions at top, `main()` at bottom, `main "$@"` as last line
- Return status for success/failure; capture output via `$(func)`

## Error Handling

- Define `die() { echo "ERROR: ${1}" >&2; exit "${2:-1}"; }`
- Define `require_command() { command -v "${1}" >/dev/null 2>&1 || die "${1} not found"; }`
- All error/log messages to stderr (`>&2`)
- Always trap cleanup: `trap cleanup EXIT`
- Create temp files/dirs with `mktemp`: `TEMP_DIR=$(mktemp -d); trap 'rm -rf "${TEMP_DIR}"' EXIT`
- ❌ `TEMP_FILE="/tmp/myapp_$$"` → ✅ `TEMP_FILE=$(mktemp)`

## Command Execution

- Use `$()` not backticks for command substitution
- Use arrays for commands with arguments: `args=(-f "${file}"); cmd "${args[@]}"`
- ❌ `cmd ${args}` (word splitting) → ✅ `cmd "${args[@]}"`

## Loops and Iteration

- Prefer `fd`, `parallel`, `xargs -0` over bash loops
- Glob loops must handle no-match: `for f in "${dir}"/*.txt; do [[ -f "${f}" ]] || continue; done`
- ❌ `for file in $(ls *.txt)` — breaks on spaces

## Option Parsing

- Use `while [[ $# -gt 0 ]]; do case "${1}" in ...` pattern
- Always handle `-h|--help`, `--`, and unknown `-*` options
- Validate required args: `[[ $# -lt N ]] && die "Usage: ..."`

## Configuration Cascade

- Priority: CLI > ENV > .env > config.{env}.sh > config.sh > defaults > hardcoded
- Source configs conditionally: `[[ -f "${path}" ]] && source "${path}"`
- Get script dir: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`

## Logging

- Use RFC 3339 timestamps: `date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"`
- Levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
- Console (when `[[ -t 2 ]]`): human-friendly with colour
- Pipe/container: JSON to stderr for log aggregators
- Use `case` statement for level priority (no associative arrays)

## Portable Patterns (macOS + Linux)

- `sed -i`: macOS needs `sed -i ''`, Linux needs `sed -i` — detect with `uname`
- GNU date on macOS: use `gdate` (from `brew install coreutils`)

## ShellCheck

- Zero warnings required — fix issues rather than disabling checks
- Disable only when necessary: `# shellcheck disable=SC2086` with justification
- Common fixes: SC2086 (quote vars), SC2046 (quote substitution), SC2155 (separate declare/assign), SC2034 (prefix unused with `_`)

## macbash (macOS/BSD Portability)

- Check if installed first: `command -v macbash` — if available, zero warnings required
- Run: `macbash script.sh` before merging; auto-fix: `macbash -w script.sh`
- Key catches: `echo -e` → `printf "%b\n"`, `grep -P` → `grep -E`, `readarray` → `while read` loop
- Run both: `shellcheck script.sh && macbash script.sh`

## BATS Testing

- Required for scripts > 50 lines
- Use `setup()`/`teardown()` for temp dirs
- Test with `run ./script.sh; [ "$status" -eq 0 ]`
- Run: `bats tests/` or `bats --tap tests/` for CI

## Source Guard Pattern

- Enable sourcing for BATS testing:
```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Security

- Never use `eval` or `bash -c` with user input
- Use `--` to end option processing: `grep -F -- "${user_input}" file`
- Secrets: never on command line (visible in `ps`); use env vars or permission-restricted config files

## Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${0}")"
: "${LOG_LEVEL:=info}"

log() { echo "[${SCRIPT_NAME}] ${1}" >&2; }
die() { log "ERROR: ${1}"; exit "${2:-1}"; }

main() {
    [[ $# -ge 1 ]] || die "Usage: ${SCRIPT_NAME} <command>"
    local command="${1}"; shift
    case "${command}" in
        build) do_build "$@" ;;
        *)     die "Unknown command: ${command}" ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## AI-Specific Rules

- Always include strict mode — never omit
- Never generate Bash 4+ features
- Never use `function` keyword
- Never hardcode temp paths
- Never use backticks
- Always quote every variable expansion
- Run ShellCheck before finalising any generated bash
- If `macbash` is available (`command -v macbash`), run it too — fix all warnings
- In BATS: mock external commands (curl, kubectl, aws) only — never mock internal functions
- Scripts must be complete: no `# TODO`, no placeholder `exit 0`, no hardcoded example paths
- Every script must have error handling, cleanup traps, and be idempotent
