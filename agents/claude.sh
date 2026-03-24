#!/usr/bin/env bash
# Project:   HyperI AI
# File:      agents/claude.sh
# Purpose:   Setup Claude Code configuration for a project (thin wrapper)
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# All deploy logic lives in tools/deploy_claude.py (Python3+stdlib).
# This wrapper handles: CLI detection (exit code 2) and arg forwarding.
#
# Usage: ./agents/claude.sh [--help] [--dry-run] [--force] [--no-managed]
#                           [--no-superpowers] [--path PATH] [--self] [--verbose]
#
set -euo pipefail

# Source common functions (exit codes, agent_installed, logging)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agents/common.sh disable=SC1091
source "${SCRIPT_DIR}/common.sh"

AI_ROOT="${HYPERI_AI_ROOT:-$(dirname "$SCRIPT_DIR")}"
AGENT_CLI="claude"
DEPLOY_SCRIPT="$AI_ROOT/tools/deploy_claude.py"

# Fast path: --help doesn't require CLI check
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            exec python3 "$DEPLOY_SCRIPT" --ai-root "$AI_ROOT" --help
            ;;
    esac
done

# Check Claude Code CLI is installed (exit 2 if not)
if ! agent_installed "$AGENT_CLI"; then
    agent_log_info "Claude Code CLI '${AGENT_CLI}' not installed (skipping)"
    exit "$EXIT_NOT_INSTALLED"
fi

# Delegate all logic to Python
exec python3 "$DEPLOY_SCRIPT" \
    --ai-root "$AI_ROOT" \
    --agent-cli "$AGENT_CLI" \
    "$@"
