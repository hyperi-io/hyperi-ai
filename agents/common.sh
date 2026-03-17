#!/usr/bin/env bash
# Project:   HyperI AI
# File:      agents/common.sh
# Purpose:   Shared functions for agent setup scripts
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# Bash 3.2 compatible (macOS default)
# Source this file from agent scripts: source "${SCRIPT_DIR}/common.sh"

# Exit codes for agent scripts
# These allow attach.sh to distinguish between errors and "not installed"
# shellcheck disable=SC2034  # Used by sourcing scripts (attach.sh, tests)
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_NOT_INSTALLED=2

# Colours (if terminal supports it)
if [ -t 1 ]; then
    _RED='\033[0;31m'
    _GREEN='\033[0;32m'
    _YELLOW='\033[0;33m'
    _BLUE='\033[0;34m'
    _NC='\033[0m'
else
    _RED=''
    _GREEN=''
    _YELLOW=''
    _BLUE=''
    _NC=''
fi

# Logging functions (prefixed to avoid conflicts)
agent_log_info() { printf "%b\n" "${_BLUE}[INFO]${_NC} $*"; }
agent_log_success() { printf "%b\n" "${_GREEN}[OK]${_NC} $*"; }
agent_log_warn() { printf "%b\n" "${_YELLOW}[WARN]${_NC} $*"; }
agent_log_error() { printf "%b\n" "${_RED}[ERROR]${_NC} $*" >&2; }

# Check if a CLI command is available
# Usage: agent_installed <command>
# Returns: 0 if installed, 1 if not
agent_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Check if agent CLI is installed, exit with appropriate code if not
# Usage: require_agent_cli <cli_command> <agent_display_name>
# Exit: EXIT_NOT_INSTALLED (2) if not found
require_agent_cli() {
    local cli_cmd="$1"
    local display_name="$2"

    if ! agent_installed "$cli_cmd"; then
        agent_log_info "${display_name} CLI '${cli_cmd}' not installed (skipping)"
        exit $EXIT_NOT_INSTALLED
    fi
}

# Check prerequisites common to all agent scripts
# Requires: PROJECT_ROOT to be set
# Exit: EXIT_ERROR (1) if STATE.md not found
check_common_prerequisites() {
    if [ -z "${PROJECT_ROOT:-}" ]; then
        agent_log_error "PROJECT_ROOT not set"
        exit $EXIT_ERROR
    fi

    if [ ! -f "$PROJECT_ROOT/STATE.md" ]; then
        agent_log_error "STATE.md not found in project root"
        agent_log_info "Run attach.sh first: ./hyperi-ai/attach.sh"
        exit $EXIT_ERROR
    fi
}

# Detect paths for agent scripts
# Sets: AI_ROOT, PROJECT_ROOT (if not already set)
# Usage: detect_agent_paths
detect_agent_paths() {
    # AI_ROOT = parent of agents/ directory (the hyperi-ai/ repo root)
    if [ -z "${AI_ROOT:-}" ]; then
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
        AI_ROOT="$(dirname "$script_dir")"
    fi

    # PROJECT_ROOT = parent of AI_ROOT (default)
    if [ -z "${PROJECT_ROOT:-}" ]; then
        PROJECT_ROOT="$(dirname "$AI_ROOT")"
    fi
}

# Create symlink for AGENT.md -> STATE.md
# Usage: create_agent_symlink <AGENT_NAME>
# Example: create_agent_symlink "CLAUDE" creates CLAUDE.md -> STATE.md
create_agent_symlink() {
    local agent_name="$1"
    local link="$PROJECT_ROOT/${agent_name}.md"
    local target="STATE.md"
    local dry_run="${DRY_RUN:-false}"

    if [ "$dry_run" = "true" ]; then
        if [ -L "$link" ]; then
            echo "Would skip (exists): $link -> $(readlink "$link")"
        else
            echo "Would create: $link -> $target"
        fi
        return 0
    fi

    if [ -L "$link" ]; then
        local existing_target
        existing_target="$(readlink "$link")"
        agent_log_info "Skipped (exists): $link -> $existing_target"
    elif [ -f "$link" ]; then
        agent_log_warn "$link exists as a regular file"
        agent_log_info "Delete it manually to create symlink, or use --force"
    else
        ln -s "$target" "$link"
        agent_log_success "Created: $link -> $target"
    fi
}

# Validate that project directory exists and is writable
# Requires: PROJECT_ROOT to be set
validate_project_environment() {
    if [ ! -d "$PROJECT_ROOT" ]; then
        agent_log_error "Project directory does not exist: $PROJECT_ROOT"
        exit $EXIT_ERROR
    fi

    if [ ! -w "$PROJECT_ROOT" ]; then
        agent_log_error "Project directory is not writable: $PROJECT_ROOT"
        exit $EXIT_ERROR
    fi
}

# ── Technology Detection ──────────────────────────────────────────────

# Detect project technologies from config file markers.
# Sets global arrays: DETECTED_LANGS, DETECTED_INFRA
# Requires: PROJECT_ROOT to be set
detect_project_technologies() {
    DETECTED_LANGS=()
    DETECTED_INFRA=()

    # Languages
    if [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/setup.py" ] || \
       [ -f "$PROJECT_ROOT/requirements.txt" ] || [ -f "$PROJECT_ROOT/uv.lock" ]; then
        DETECTED_LANGS+=("python")
    fi

    if [ -f "$PROJECT_ROOT/go.mod" ]; then
        DETECTED_LANGS+=("golang")
    fi

    if [ -f "$PROJECT_ROOT/tsconfig.json" ] || [ -f "$PROJECT_ROOT/package.json" ]; then
        DETECTED_LANGS+=("typescript")
    fi

    if [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
        DETECTED_LANGS+=("rust")
    fi

    if [ -f "$PROJECT_ROOT/CMakeLists.txt" ] || \
       find "$PROJECT_ROOT" -maxdepth 1 \( -name "*.cpp" -o -name "*.hpp" -o -name "*.cc" -o -name "*.h" \) -type f 2>/dev/null | grep -q .; then
        DETECTED_LANGS+=("cpp")
    fi

    if find "$PROJECT_ROOT" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | grep -q .; then
        DETECTED_LANGS+=("bash")
    fi

    if [ -f "$PROJECT_ROOT/clickhouse-server.xml" ] || \
       [ -f "$PROJECT_ROOT/clickhouse-client.xml" ] || \
       [ -f "$PROJECT_ROOT/config/clickhouse-server.xml" ] || \
       (find "$PROJECT_ROOT" -maxdepth 2 -name "*.sql" -type f -print0 2>/dev/null | \
        xargs -0 grep -l 'ENGINE.*MergeTree' 2>/dev/null | grep -q .); then
        DETECTED_LANGS+=("clickhouse-sql")
    fi

    # Infrastructure
    if [ -f "$PROJECT_ROOT/Dockerfile" ] || [ -f "$PROJECT_ROOT/docker-compose.yaml" ] || \
       [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        DETECTED_INFRA+=("docker")
    fi

    if [ -f "$PROJECT_ROOT/Chart.yaml" ] || [ -d "$PROJECT_ROOT/charts" ] || \
       [ -f "$PROJECT_ROOT/values.yaml" ]; then
        DETECTED_INFRA+=("k8s")
    fi

    if find "$PROJECT_ROOT" -maxdepth 1 -name "*.tf" -type f 2>/dev/null | grep -q .; then
        DETECTED_INFRA+=("terraform")
    fi

    if [ -f "$PROJECT_ROOT/ansible.cfg" ] || [ -f "$PROJECT_ROOT/playbook.yml" ] || \
       [ -d "$PROJECT_ROOT/playbooks" ]; then
        DETECTED_INFRA+=("ansible")
    fi

    if [ -d "$PROJECT_ROOT/certs" ] || [ -d "$PROJECT_ROOT/ssl" ] || \
       [ -d "$PROJECT_ROOT/pki" ] || [ -d "$PROJECT_ROOT/tls" ] || \
       find "$PROJECT_ROOT" -maxdepth 2 \( -name "*.crt" -o -name "*.pem" -o -name "*.key" -o -name "ssl*.xml" -o -name "*-tls.yaml" \) -type f 2>/dev/null | grep -q .; then
        DETECTED_INFRA+=("pki")
    fi
}

# ── Rule File Helpers ─────────────────────────────────────────────────

# Extract glob patterns from a rule file's YAML frontmatter.
# Returns comma-separated glob string, or empty if no frontmatter.
# Expects clean frontmatter (---/paths:/---) with no stray backticks.
# Usage: globs=$(extract_rule_globs <file>)
extract_rule_globs() {
    local file="$1"
    local result=""

    # Quick check: first non-blank line must be ---
    local first_line
    first_line="$(sed -n '/[^ ]/{ p; q; }' "$file")"
    if [ "$first_line" != "---" ]; then
        return 0
    fi

    # Extract paths between --- delimiters
    local in_fm=false
    while IFS= read -r line; do
        if [ "$line" = "---" ]; then
            if [ "$in_fm" = "true" ]; then
                break
            fi
            in_fm=true
            continue
        fi
        if [ "$in_fm" = "true" ]; then
            case "$line" in
                *'- "'*)
                    local glob
                    glob="${line#*\"}"
                    glob="${glob%\"*}"
                    if [ -n "$result" ]; then
                        result="${result},${glob}"
                    else
                        result="$glob"
                    fi
                    ;;
            esac
        fi
    done < "$file"

    printf '%s' "$result"
}

# Extract body content from a rule file (everything after frontmatter).
# For files without frontmatter, returns the entire file.
# Usage: extract_rule_body <file>
extract_rule_body() {
    local file="$1"

    # Quick check: does file have frontmatter?
    local first_line
    first_line="$(sed -n '/[^ ]/{ p; q; }' "$file")"
    if [ "$first_line" != "---" ]; then
        cat "$file"
        return 0
    fi

    # Skip everything up to and including the closing ---
    local past_fm=false
    local in_fm=false
    while IFS= read -r line; do
        if [ "$past_fm" = "true" ]; then
            printf '%s\n' "$line"
            continue
        fi
        if [ "$line" = "---" ]; then
            if [ "$in_fm" = "true" ]; then
                past_fm=true
            else
                in_fm=true
            fi
        fi
    done < "$file"
}

# Map a rule basename to its full standards source path.
# Returns path relative to standards/ directory.
# Usage: full_path=$(rule_to_full_standard <rule_name>)
rule_to_full_standard() {
    local name="$1"
    case "$name" in
        python)         echo "languages/PYTHON.md" ;;
        golang)         echo "languages/GOLANG.md" ;;
        typescript)     echo "languages/TYPESCRIPT.md" ;;
        rust)           echo "languages/RUST.md" ;;
        cpp)            echo "languages/CPP.md" ;;
        bash)           echo "languages/BASH.md" ;;
        clickhouse-sql) echo "languages/SQL-CLICKHOUSE.md" ;;
        docker)         echo "infrastructure/DOCKER.md" ;;
        k8s)            echo "infrastructure/K8S.md" ;;
        terraform)      echo "infrastructure/TERRAFORM.md" ;;
        ansible)        echo "infrastructure/ANSIBLE.md" ;;
        pki)            echo "common/PKI.md" ;;
        *)              echo "" ;;
    esac
}
