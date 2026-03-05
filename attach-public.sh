#!/usr/bin/env bash
# Project:      HyperI AI
# File:         attach-public.sh
# Purpose:      Attach AI standards to a PUBLIC repo (no submodule, gitignored)
# License:      Proprietary
# Copyright:    (c) 2026 HYPERI PTY LIMITED
#
# Use this for public/open-source repositories where you don't want to expose
# internal AI standards as a submodule. The ai/ directory is cloned locally
# and gitignored - it never appears in the public repo.
#
# The /load command (in .claude/commands/load.md) handles updating the ai/
# directory on each session start.
#
# Bash 3.2 compatible (macOS default)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
GITHUB_ORG="${GITHUB_ORG:-hyperi-io}"
AI_REPO_URL="${AI_REPO_URL:-https://github.com/${GITHUB_ORG}/hyperi-ai.git}"

# Global variables
PROJECT_ROOT=""

# Defaults
DRY_RUN=false
FORCE=false
RESET_STATE=false
VERBOSE=false

# Agent detection mode
SPECIFIC_AGENT=""
SETUP_ALL_AGENTS=false
NO_AGENT=false

# Agent priority order
AGENT_PRIORITY=(claude cursor gemini codex)

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_NOT_INSTALLED=2

# Colours
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info() { printf "%b\n" "${BLUE}[INFO]${NC} $*"; }
log_success() { printf "%b\n" "${GREEN}[OK]${NC} $*"; }
log_warn() { printf "%b\n" "${YELLOW}[WARN]${NC} $*"; }
log_error() { printf "%b\n" "${RED}[ERROR]${NC} $*" >&2; }

show_usage() {
    cat << 'EOF'
attach-public.sh - Attach HyperI AI to a PUBLIC repository

This script sets up AI standards WITHOUT creating a submodule. Use this for
public/open-source repos where you don't want to expose internal tooling.

WHAT IT DOES:
  1. Clones ai/ locally (keeps .git for manual updates via 'git -C ai pull')
  2. Adds ai/ to .gitignore (never committed to public repo)
  3. Creates .claude/commands/load.md to auto-update ai/ on /load
  4. Deploys STATE.md, TODO.md templates
  5. Sets up agent configuration (Claude, Cursor, etc.)

Usage: ./attach-public.sh [OPTIONS]

OPTIONS:
  --help, -h       Show this help message
  --dry-run        Show what would be done without making changes
  --force          Overwrite existing files
  --path PATH      Specify custom project root (default: current directory)
  --verbose        Enable verbose output

AGENT SETUP:
  --agent NAME     Setup specific agent (claude, cursor, gemini, codex)
  --all-agents     Setup all installed agents
  --no-agent       Skip agent detection entirely

EXAMPLES:
  # Run from project root (downloads ai/ first time)
  curl -sL https://raw.githubusercontent.com/hyperi-io/hyperi-ai/main/attach-public.sh | bash

  # Or if hyperi-ai/ already exists locally
  ./hyperi-ai/attach-public.sh

  # Setup specific agent
  ./hyperi-ai/attach-public.sh --agent claude

  # Preview changes
  ./hyperi-ai/attach-public.sh --dry-run

EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h)
                show_usage
                exit 0
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --reset-state)
                RESET_STATE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --path)
                if [ -z "${2:-}" ]; then
                    log_error "--path requires an argument"
                    exit 1
                fi
                PROJECT_ROOT="$2"
                shift 2
                ;;
            --agent)
                if [ -z "${2:-}" ]; then
                    log_error "--agent requires a name (claude, cursor, gemini, codex)"
                    exit 1
                fi
                SPECIFIC_AGENT="$2"
                shift 2
                ;;
            --all-agents)
                SETUP_ALL_AGENTS=true
                shift
                ;;
            --no-agent)
                NO_AGENT=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Try '$0 --help' for more information"
                exit 1
                ;;
        esac
    done

    # Validate mutually exclusive options
    local mode_count=0
    [ -n "$SPECIFIC_AGENT" ] && mode_count=$((mode_count + 1))
    [ "$SETUP_ALL_AGENTS" = true ] && mode_count=$((mode_count + 1))
    [ "$NO_AGENT" = true ] && mode_count=$((mode_count + 1))

    if [ $mode_count -gt 1 ]; then
        log_error "Options --agent, --all-agents, and --no-agent are mutually exclusive"
        exit 1
    fi
}

detect_paths() {
    # If script is run from within ai/, PROJECT_ROOT is parent
    if [ -z "$PROJECT_ROOT" ]; then
        if [[ "$SCRIPT_DIR" == */ai ]]; then
            PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
        else
            PROJECT_ROOT="$(pwd)"
        fi
    fi

    if [ "$VERBOSE" = true ]; then
        log_info "PROJECT_ROOT: $PROJECT_ROOT"
    fi
}

validate_environment() {
    if [ ! -d "$PROJECT_ROOT" ]; then
        log_error "Project directory does not exist: $PROJECT_ROOT"
        exit 1
    fi

    if [ ! -w "$PROJECT_ROOT" ]; then
        log_error "Project directory is not writable: $PROJECT_ROOT"
        exit 1
    fi

    # Must be a git repo
    if ! git -C "$PROJECT_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository: $PROJECT_ROOT"
        log_info "Run 'git init' first"
        exit 1
    fi
}

# Clone or update ai/ directory (keeps .git for manual updates)
setup_ai_directory() {
    local ai_dir="$PROJECT_ROOT/ai"

    log_info "Setting up ai/ directory..."

    if [ "$DRY_RUN" = true ]; then
        if [ -d "$ai_dir" ]; then
            log_info "Would update: $ai_dir"
        else
            log_info "Would clone: $ai_dir"
        fi
        return
    fi

    if [ -d "$ai_dir/.git" ]; then
        # Has .git - pull updates
        log_info "Updating ai/ from upstream..."
        git -C "$ai_dir" pull --rebase --quiet 2>/dev/null || true
        log_success "Updated: ai/"
    elif [ -d "$ai_dir" ]; then
        # Directory exists but no .git - remove and re-clone
        log_info "Re-cloning ai/ (was not a git repo)..."
        rm -rf "$ai_dir"
        git clone --depth 1 --quiet "$AI_REPO_URL" "$ai_dir" 2>/dev/null
        log_success "Re-cloned: ai/"
    else
        # No directory - clone fresh
        log_info "Cloning ai/ from $AI_REPO_URL..."
        git clone --depth 1 --quiet "$AI_REPO_URL" "$ai_dir" 2>/dev/null
        log_success "Cloned: ai/"
    fi
}

# Ensure ai/ is in .gitignore
setup_gitignore() {
    local gitignore="$PROJECT_ROOT/.gitignore"

    log_info "Checking .gitignore..."

    if [ "$DRY_RUN" = true ]; then
        if [ -f "$gitignore" ] && grep -q "^ai/$" "$gitignore" 2>/dev/null; then
            log_info "ai/ already in .gitignore"
        else
            log_info "Would add ai/ to .gitignore"
        fi
        return
    fi

    # Check if ai/ is already ignored
    if [ -f "$gitignore" ] && grep -q "^ai/$" "$gitignore" 2>/dev/null; then
        log_info "ai/ already in .gitignore"
        return
    fi

    # Add ai/ to .gitignore
    if [ -f "$gitignore" ]; then
        # Check if there's an AI section, add to it
        if grep -q "# AI assistant" "$gitignore" 2>/dev/null; then
            # Insert ai/ after the comment
            sed -i'' -e '/# AI assistant/a\
ai/' "$gitignore"
        else
            # Add new section
            {
                echo ""
                echo "# AI assistant work files - never commit (local only, public repo)"
                echo "ai/"
                echo ".claude/"
                echo "STATE.md"
                echo "TODO.md"
                echo "CLAUDE.md"
            } >> "$gitignore"
        fi
    else
        # Create .gitignore
        cat > "$gitignore" << 'GITIGNORE'
# AI assistant work files - never commit (local only, public repo)
ai/
.claude/
STATE.md
TODO.md
CLAUDE.md
GITIGNORE
    fi

    log_success "Updated .gitignore"
}

# Remove any submodule config that might exist
remove_submodule_config() {
    local gitmodules="$PROJECT_ROOT/.gitmodules"

    # Remove from .gitmodules if present
    if [ -f "$gitmodules" ] && grep -q "submodule.ai" "$gitmodules" 2>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Would remove ai submodule from .gitmodules"
            return
        fi

        log_info "Removing ai submodule config..."
        git -C "$PROJECT_ROOT" config -f .gitmodules --remove-section "submodule.ai" 2>/dev/null || true

        # If .gitmodules is now empty, remove it
        if [ ! -s "$gitmodules" ] || ! grep -q "\[submodule" "$gitmodules" 2>/dev/null; then
            rm -f "$gitmodules"
        fi

        log_success "Removed submodule config"
    fi

    # Remove local git config for submodule
    git -C "$PROJECT_ROOT" config --local --remove-section "submodule.ai" 2>/dev/null || true
}

# Deploy Claude Code commands (load.md, save.md)
deploy_claude_commands() {
    local claude_dir="$PROJECT_ROOT/.claude"
    local commands_dir="$claude_dir/commands"
    local ai_dir="$PROJECT_ROOT/ai"

    log_info "Deploying Claude Code commands..."

    if [ "$DRY_RUN" = true ]; then
        log_info "Would create: $commands_dir/load.md"
        log_info "Would create: $commands_dir/save.md"
        log_info "Would copy: $claude_dir/settings.json"
        return
    fi

    mkdir -p "$commands_dir"

    # Deploy load.md with public-repo sync logic
    cat > "$commands_dir/load.md" << 'LOADMD'
# Load Session

You are loading project context for a new work session or refreshing my memory.

## Step 1: Check AI Standards Directory (Silent)

**This project uses a gitignored `hyperi-ai/` directory for standards.**

Use the Glob tool to check if `hyperi-ai/standards/rules/UNIVERSAL.md` exists.

- If it exists: proceed to Step 2 (no action needed)
- If missing: tell the user to run `git clone --depth 1 https://github.com/hyperi-io/hyperi-ai.git hyperi-ai`

**Do NOT mention this check to the user unless hyperi-ai/ is missing.**

---

## Step 2: Read Project State

Read in this order:

1. [STATE.md](../../STATE.md) - Project state and session history
2. [TODO.md](../../TODO.md) - Current tasks and priorities

---

## Step 3: Load Universal Standards

Read the universal standards (cross-cutting rules for all code):

- [UNIVERSAL.md](../../hyperi-ai/standards/rules/UNIVERSAL.md)

---

## Step 4: Detect and Load Language Rules

Glob for config files in the project root (not subdirs, not `.venv/`, not `node_modules/`, not git submodules), then read the matching compact rule:

| Config File Found | Load Rule File |
|-------------------|----------------|
| `pyproject.toml`, `setup.py` | `ai/standards/rules/python.md` |
| `go.mod` | `ai/standards/rules/golang.md` |
| `package.json`, `tsconfig.json` | `ai/standards/rules/typescript.md` |
| `Cargo.toml` | `ai/standards/rules/rust.md` |
| `*.sh` only (no other lang) | `ai/standards/rules/bash.md` |

---

## Step 5: Check for Infrastructure Rules

| IaC Files Found | Load Rule File |
|-----------------|----------------|
| `Dockerfile`, `docker-compose.yaml` | `ai/standards/rules/docker.md` |
| `Chart.yaml`, `values.yaml` | `ai/standards/rules/k8s.md` |
| `*.tf` | `ai/standards/rules/terraform.md` |
| `ansible.cfg`, `playbook.yml` | `ai/standards/rules/ansible.md` |

Also read these universal rules: `ai/standards/rules/testing.md`, `ai/standards/rules/error-handling.md`, `ai/standards/rules/security.md`

For full reference, see `ai/standards/languages/` and `ai/standards/infrastructure/`.

---

## Step 6: Ready to Work

1. Check git status and recent commits
2. Be ready - no greetings, wait for the user's first task

---

## IMPORTANT: Proactive Saving

Run `/save` proactively throughout the session - context can compact without warning.

**Save when:**

- After completing any significant task
- Every 30-40 exchanges
- Before the user takes breaks
- When your responses get shorter (sign of context pressure)

**Signs you need to save NOW:**

- Responses getting truncated
- Forgetting earlier context
- Repeating questions already answered
- Uncertainty about what was discussed earlier
LOADMD

    # Deploy save.md from template
    if [ -f "$ai_dir/templates/claude-code/commands/save.md" ]; then
        cp "$ai_dir/templates/claude-code/commands/save.md" "$commands_dir/save.md"
    fi

    # Deploy settings.json from template
    if [ -f "$ai_dir/templates/claude-code/settings.json" ]; then
        if [ ! -f "$claude_dir/settings.json" ] || [ "$FORCE" = true ]; then
            cp "$ai_dir/templates/claude-code/settings.json" "$claude_dir/settings.json"
            log_success "Deployed: .claude/settings.json"
        else
            log_info "Skipped (exists): .claude/settings.json"
        fi
    fi

    log_success "Deployed: .claude/commands/"
}

# Deploy STATE.md and TODO.md templates
deploy_templates() {
    local ai_dir="$PROJECT_ROOT/ai"
    local templates_dir="$ai_dir/templates"

    log_info "Deploying project templates..."

    if [ "$DRY_RUN" = true ]; then
        log_info "Would deploy: STATE.md"
        log_info "Would deploy: TODO.md"
        return
    fi

    # STATE.md and TODO.md — user content, only overwrite with --reset-state
    local state_force=false
    [ "$RESET_STATE" = true ] && state_force=true

    # STATE.md
    if [ ! -f "$PROJECT_ROOT/STATE.md" ] || [ "$state_force" = true ]; then
        if [ -f "$templates_dir/STATE.md" ]; then
            cp "$templates_dir/STATE.md" "$PROJECT_ROOT/STATE.md"
            log_success "Deployed: STATE.md"
        fi
    else
        log_info "Skipped (exists): STATE.md"
    fi

    # TODO.md
    if [ ! -f "$PROJECT_ROOT/TODO.md" ] || [ "$state_force" = true ]; then
        if [ -f "$templates_dir/TODO.md" ]; then
            cp "$templates_dir/TODO.md" "$PROJECT_ROOT/TODO.md"
            log_success "Deployed: TODO.md"
        fi
    else
        log_info "Skipped (exists): TODO.md"
    fi
}

# Run agent setup script
run_single_agent() {
    local agent="$1"
    local script="$PROJECT_ROOT/hyperi-ai/agents/${agent}.sh"
    local force_flag=""
    local verbose_flag=""

    [ "$FORCE" = true ] && force_flag="--force"
    [ "$VERBOSE" = true ] && verbose_flag="--verbose"

    if [ ! -f "$script" ]; then
        log_error "Unknown agent: $agent"
        return $EXIT_ERROR
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Would run: $script"
        return $EXIT_SUCCESS
    fi

    log_info "Running ${agent} setup..."
    # Capture exit code without triggering set -e
    local exit_code=0
    # shellcheck disable=SC2086
    "$script" $force_flag $verbose_flag || exit_code=$?
    return $exit_code
}

run_agent_detection() {
    if [ "$NO_AGENT" = true ]; then
        [ "$VERBOSE" = true ] && log_info "Agent detection skipped (--no-agent)"
        return 0
    fi

    echo ""
    log_info "=== Agent Detection ==="

    if [ -n "$SPECIFIC_AGENT" ]; then
        local exit_code=0
        run_single_agent "$SPECIFIC_AGENT" || exit_code=$?
        case $exit_code in
            "$EXIT_SUCCESS") log_success "Configured: $SPECIFIC_AGENT" ;;
            "$EXIT_NOT_INSTALLED") log_warn "${SPECIFIC_AGENT} CLI not installed" ;;
            *) return 1 ;;
        esac
        return 0
    fi

    if [ "$SETUP_ALL_AGENTS" = true ]; then
        local any_configured=false
        for agent in "${AGENT_PRIORITY[@]}"; do
            local exit_code=0
            run_single_agent "$agent" || exit_code=$?
            [ $exit_code -eq "$EXIT_SUCCESS" ] && any_configured=true
        done
        [ "$any_configured" = false ] && log_warn "No AI agent CLIs found"
        return 0
    fi

    # Default: first installed agent wins
    for agent in "${AGENT_PRIORITY[@]}"; do
        local exit_code=0
        run_single_agent "$agent" || exit_code=$?
        case $exit_code in
            "$EXIT_SUCCESS")
                log_success "Configured: $agent"
                return 0
                ;;
            "$EXIT_ERROR")
                return 1
                ;;
            "$EXIT_NOT_INSTALLED")
                continue
                ;;
        esac
    done

    log_warn "No AI agent CLIs found on system"
    return 0
}

print_summary() {
    echo ""
    log_success "HyperI AI attached (public repo mode)!"
    echo ""
    echo "What was set up:"
    echo "  - ai/ directory (gitignored, never committed)"
    echo "  - .claude/commands/load.md (auto-updates ai/ on /load)"
    echo "  - .claude/settings.json (corporate defaults)"
    echo "  - STATE.md, TODO.md templates"
    echo ""
    echo "The ai/ directory is LOCAL ONLY - it will not appear in the public repo."
    echo "Each developer runs this script once, or /load auto-clones it."
    echo ""
    echo "To manually update ai/: git -C ai pull"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN - No files were modified"
        echo ""
    fi
}

main() {
    echo ""
    echo "=== HyperI AI Attach (Public Repo Mode) ==="
    echo ""

    parse_args "$@"
    detect_paths
    validate_environment

    # Remove any existing submodule config
    remove_submodule_config

    # Clone/update ai/ directory
    setup_ai_directory

    # Ensure ai/ is gitignored
    setup_gitignore

    # Deploy Claude commands
    deploy_claude_commands

    # Deploy templates
    deploy_templates

    # Run agent detection
    run_agent_detection

    print_summary
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
