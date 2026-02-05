#!/usr/bin/env bash
# Project:   HyperSec AI
# File:      agents/common.sh
# Purpose:   Shared functions for agent setup scripts
#
# License:   FSL-1.1-ALv2
# Copyright: (c) 2026 HyperSec Pty Ltd
#
# Bash 3.2 compatible (macOS default)
# Source this file from agent scripts: source "${SCRIPT_DIR}/common.sh"

# Exit codes for agent scripts
# These allow attach.sh to distinguish between errors and "not installed"
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
agent_log_info() { echo -e "${_BLUE}[INFO]${_NC} $*"; }
agent_log_success() { echo -e "${_GREEN}[OK]${_NC} $*"; }
agent_log_warn() { echo -e "${_YELLOW}[WARN]${_NC} $*"; }
agent_log_error() { echo -e "${_RED}[ERROR]${_NC} $*" >&2; }

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
        agent_log_info "Run attach.sh first: ./ai/attach.sh"
        exit $EXIT_ERROR
    fi
}

# Detect paths for agent scripts
# Sets: AI_ROOT, PROJECT_ROOT (if not already set)
# Usage: detect_agent_paths
detect_agent_paths() {
    # AI_ROOT = parent of agents/ directory (the ai/ repo root)
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
