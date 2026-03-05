#!/usr/bin/env bash
# Project:      HyperI AI
# File:         attach.sh
# Purpose:      Attach AI standards to a project
# License:      Proprietary
# Copyright:    (c) 2026 HYPERI PTY LIMITED
#
# Bash 3.2 compatible (macOS default)

set -euo pipefail

# Get script directory for loading config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to load org config from CI submodule (if available)
# This provides GITHUB_ORG, CI_REPO_URL, AI_REPO_URL, etc.
if [ -f "${SCRIPT_DIR}/../ci/config/org.sh" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/../ci/config/org.sh"
fi

# Fallback defaults if org.sh not available
GITHUB_ORG="${GITHUB_ORG:-hyperi-io}"
CI_REPO_URL="${CI_REPO_URL:-https://github.com/${GITHUB_ORG}/ci.git}"
AI_REPO_URL="${AI_REPO_URL:-https://github.com/${GITHUB_ORG}/ai.git}"

# Global variables
AI_ROOT=""
PROJECT_ROOT=""
AI_DIR="ai"

# Defaults
DRY_RUN=false
FORCE=false
VERBOSE=false
PIN_SUBMODULE=false

# Agent detection mode
SPECIFIC_AGENT=""           # Set when --agent <name> is used
SETUP_ALL_AGENTS=false      # Set when --all-agents is used
NO_AGENT=false              # Set when --no-agent is used

# Agent priority order (first installed wins by default)
AGENT_PRIORITY=(claude cursor gemini codex)

# Exit codes from agent scripts
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_NOT_INSTALLED=2

# Colours (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log_info() { printf "%b\n" "${BLUE}[INFO]${NC} $*"; }
log_success() { printf "%b\n" "${GREEN}[OK]${NC} $*"; }
log_warn() { printf "%b\n" "${YELLOW}[WARN]${NC} $*"; }
log_error() { printf "%b\n" "${RED}[ERROR]${NC} $*" >&2; }

# Show usage information
show_usage() {
    cat << 'EOF'
attach.sh - Attach HyperI AI standards to your project

Usage: ./attach.sh [OPTIONS]

OPTIONS:
  --help, -h       Show this help message
  --dry-run        Show what would be done without making changes
  --force          Overwrite existing files
  --path PATH      Specify custom project root (default: parent of ai/)
  --verbose        Enable verbose output

  --pin            Pin submodule version (disable auto-update from upstream)
                   Use this for projects requiring fixed AI versions

AGENT SETUP (default: auto-detect first installed agent):
  --agent NAME     Setup specific agent (claude, cursor, gemini, codex)
  --all-agents     Setup all installed agents (don't stop on first)
  --no-agent       Skip agent detection entirely

  By default, attach.sh runs agent detection in priority order:
    claude -> cursor -> gemini -> codex
  and stops when the first installed agent CLI is found.

EXAMPLES:
  # Basic usage (deploy + auto-detect agent)
  ./ai/attach.sh

  # Skip agent detection
  ./ai/attach.sh --no-agent

  # Setup specific agent
  ./ai/attach.sh --agent claude

  # Setup all installed agents
  ./ai/attach.sh --all-agents

  # Preview changes without modifying files
  ./ai/attach.sh --dry-run

  # Force overwrite existing files
  ./ai/attach.sh --force

  # Pin submodule version (no auto-update)
  ./ai/attach.sh --pin

EOF
}

# Parse command-line arguments
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
            --pin)
                PIN_SUBMODULE=true
                shift
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
            # Deprecated flags - show warning and map to new behaviour
            --claude)
                log_warn "--claude is deprecated, use --agent claude"
                SPECIFIC_AGENT="claude"
                shift
                ;;
            --cursor)
                log_warn "--cursor is deprecated, use --agent cursor"
                SPECIFIC_AGENT="cursor"
                shift
                ;;
            --gemini)
                log_warn "--gemini is deprecated, use --agent gemini"
                SPECIFIC_AGENT="gemini"
                shift
                ;;
            --copilot)
                log_error "--copilot has been removed. Use --agent codex instead."
                exit 1
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Try '$0 --help' for more information"
                exit 1
                ;;
        esac
    done

    # Validate agent mode options are mutually exclusive
    local mode_count=0
    [ -n "$SPECIFIC_AGENT" ] && mode_count=$((mode_count + 1))
    [ "$SETUP_ALL_AGENTS" = true ] && mode_count=$((mode_count + 1))
    [ "$NO_AGENT" = true ] && mode_count=$((mode_count + 1))

    if [ $mode_count -gt 1 ]; then
        log_error "Options --agent, --all-agents, and --no-agent are mutually exclusive"
        exit 1
    fi
}

# Detect script location and project root
detect_paths() {
    # AI_ROOT = directory containing this script
    AI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    AI_DIR="$(basename "$AI_ROOT")"

    # PROJECT_ROOT = parent directory (default)
    # Can be overridden with --path
    if [ -z "$PROJECT_ROOT" ]; then
        PROJECT_ROOT="$(dirname "$AI_ROOT")"
    fi

    if [ "$VERBOSE" = true ]; then
        log_info "AI_ROOT: $AI_ROOT"
        log_info "PROJECT_ROOT: $PROJECT_ROOT"
    fi
}

# Validate environment
validate_environment() {
    # Check if project root exists
    if [ ! -d "$PROJECT_ROOT" ]; then
        log_error "Project directory does not exist: $PROJECT_ROOT"
        exit 1
    fi

    # Check if project root is writable
    if [ ! -w "$PROJECT_ROOT" ]; then
        log_error "Project directory is not writable: $PROJECT_ROOT"
        exit 1
    fi
}

# Detect usage mode (submodule, clone, standalone)
detect_mode() {
    local mode="unknown"

    if [ -f "$AI_ROOT/.git" ]; then
        mode="submodule"
    elif [ -d "$AI_ROOT/.git" ]; then
        mode="clone"
    else
        mode="standalone"
    fi

    if [ "$VERBOSE" = true ]; then
        log_info "Detected mode: $mode"
    fi

    echo "$mode"
}

# Configure submodule settings (auto-update from upstream, read-only locally)
# All settings stored in .gitmodules so they propagate to clones
configure_submodule_settings() {
    # Configure AI submodule
    configure_single_submodule "ai" "$AI_DIR"

    # Also configure CI submodule if present
    if git -C "$PROJECT_ROOT" config --file .gitmodules --get "submodule.ci.url" > /dev/null 2>&1; then
        configure_single_submodule "ci" "ci"
    fi
}

# Configure a single submodule's settings
configure_single_submodule() {
    local submodule_name="$1"
    local submodule_path="$2"

    if [ "$DRY_RUN" = true ]; then
        log_info "Would configure ${submodule_name} submodule"
        return
    fi

    # Auto-fetch submodule on clone (propagates to clones)
    git -C "$PROJECT_ROOT" config -f .gitmodules "submodule.${submodule_name}.fetchRecurseSubmodules" true

    if [ "$PIN_SUBMODULE" = true ]; then
        # Pinned mode: no auto-update (user must manually update)
        git -C "$PROJECT_ROOT" config -f .gitmodules "submodule.${submodule_name}.update" none
        log_info "  ${submodule_name}: pinned (update=none, manual updates only)"
    else
        # Default: auto-update from upstream on git submodule update
        git -C "$PROJECT_ROOT" config -f .gitmodules "submodule.${submodule_name}.update" rebase
        log_info "  ${submodule_name}: auto-update (update=rebase in .gitmodules)"
    fi

    # Block pushes to upstream (local only - hook handles new clones)
    local full_path="${PROJECT_ROOT}/${submodule_path}"
    if [ -d "$full_path" ]; then
        git -C "$full_path" remote set-url --push origin no-push 2>/dev/null || true
        log_info "  ${submodule_name}: push protection enabled (read-only)"
    fi
}

# Remediate and migrate submodule settings
# Handles:
#   - Old settings migration (local config → .gitmodules)
#   - Uninitialized submodules (init + update)
#   - Missing push protection
#   - Incorrect update policy
migrate_submodule_settings() {
    local any_migrated=false
    local any_initialized=false

    # Check for uninitialized submodules first
    if [ -f "${PROJECT_ROOT}/.gitmodules" ]; then
        # AI submodule
        if git -C "$PROJECT_ROOT" config --file .gitmodules --get "submodule.${AI_DIR}.url" > /dev/null 2>&1; then
            if ! is_submodule_initialized "$AI_DIR"; then
                log_info "Initializing AI submodule..."
                git -C "$PROJECT_ROOT" submodule update --init "$AI_DIR"
                any_initialized=true
            fi
            if migrate_single_submodule "ai" "$AI_DIR"; then
                any_migrated=true
            fi
        fi

        # CI submodule if present
        if git -C "$PROJECT_ROOT" config --file .gitmodules --get "submodule.ci.url" > /dev/null 2>&1; then
            if ! is_submodule_initialized "ci"; then
                log_info "Initializing CI submodule..."
                git -C "$PROJECT_ROOT" submodule update --init "ci"
                any_initialized=true
            fi
            if migrate_single_submodule "ci" "ci"; then
                any_migrated=true
            fi
        fi
    fi

    if [ "$any_initialized" = true ]; then
        log_success "Submodule(s) initialized"
    fi
    if [ "$any_migrated" = true ]; then
        log_success "Submodule settings remediated"
    fi
}

# Check if a submodule is properly initialized
is_submodule_initialized() {
    local submodule_path="$1"
    local full_path="${PROJECT_ROOT}/${submodule_path}"

    # Submodule directory must exist and contain files
    if [ ! -d "$full_path" ]; then
        return 1
    fi

    # Check if directory has content (not just empty from clone)
    if [ -z "$(ls -A "$full_path" 2>/dev/null)" ]; then
        return 1
    fi

    # Check if it's a valid git repo
    if ! git -C "$full_path" rev-parse --git-dir > /dev/null 2>&1; then
        return 1
    fi

    return 0
}

# Migrate a single submodule's settings, returns 0 if migration was needed
migrate_single_submodule() {
    local submodule_name="$1"
    local submodule_path="$2"

    # First, migrate any local config to .gitmodules (old attach.sh behaviour)
    local local_update
    local_update=$(git -C "$PROJECT_ROOT" config --local --get "submodule.${submodule_name}.update" 2>/dev/null || echo "")
    if [ -n "$local_update" ]; then
        log_info "Migrating ${submodule_name} local config to .gitmodules..."
        git -C "$PROJECT_ROOT" config --local --unset "submodule.${submodule_name}.update" 2>/dev/null || true
    fi

    # Get current settings from .gitmodules
    local current_update
    current_update=$(git -C "$PROJECT_ROOT" config -f .gitmodules --get "submodule.${submodule_name}.update" 2>/dev/null || echo "")
    local current_fetch_recurse
    current_fetch_recurse=$(git -C "$PROJECT_ROOT" config -f .gitmodules --get "submodule.${submodule_name}.fetchRecurseSubmodules" 2>/dev/null || echo "")
    local current_ignore
    current_ignore=$(git -C "$PROJECT_ROOT" config -f .gitmodules --get "submodule.${submodule_name}.ignore" 2>/dev/null || echo "")
    local current_branch
    current_branch=$(git -C "$PROJECT_ROOT" config -f .gitmodules --get "submodule.${submodule_name}.branch" 2>/dev/null || echo "")
    local current_url
    current_url=$(git -C "$PROJECT_ROOT" config -f .gitmodules --get "submodule.${submodule_name}.url" 2>/dev/null || echo "")
    local current_push_url=""
    local full_path="${PROJECT_ROOT}/${submodule_path}"
    if [ -d "$full_path" ]; then
        current_push_url=$(git -C "$full_path" remote get-url --push origin 2>/dev/null || echo "")
    fi

    local needs_migration=false
    local migration_reasons=""

    # Check for deprecated/wrong repo URLs (warn only, don't auto-fix)
    check_submodule_url "$submodule_name" "$current_url"

    # Determine expected update mode
    local expected_update="rebase"
    if [ "$PIN_SUBMODULE" = true ]; then
        expected_update="none"
    fi

    # Check if update mode matches expected (also fix 'checkout' which is problematic)
    if [ "$current_update" != "$expected_update" ]; then
        needs_migration=true
        if [ -n "$current_update" ]; then
            migration_reasons="update=${current_update}→${expected_update}"
        else
            migration_reasons="adding update=${expected_update}"
        fi
    fi

    # Check fetchRecurseSubmodules
    if [ "$current_fetch_recurse" != "true" ]; then
        needs_migration=true
        if [ -n "$migration_reasons" ]; then
            migration_reasons="${migration_reasons}, +fetchRecurseSubmodules"
        else
            migration_reasons="+fetchRecurseSubmodules"
        fi
    fi

    # Remove 'ignore = all' (hides submodule status changes)
    if [ -n "$current_ignore" ]; then
        needs_migration=true
        if [ -n "$migration_reasons" ]; then
            migration_reasons="${migration_reasons}, -ignore"
        else
            migration_reasons="-ignore"
        fi
        git -C "$PROJECT_ROOT" config -f .gitmodules --unset "submodule.${submodule_name}.ignore" 2>/dev/null || true
    fi

    # Remove 'branch = main' (unnecessary, can cause sync issues)
    if [ -n "$current_branch" ]; then
        needs_migration=true
        if [ -n "$migration_reasons" ]; then
            migration_reasons="${migration_reasons}, -branch"
        else
            migration_reasons="-branch"
        fi
        git -C "$PROJECT_ROOT" config -f .gitmodules --unset "submodule.${submodule_name}.branch" 2>/dev/null || true
    fi

    # Check push protection
    if [ -d "$full_path" ] && [ "$current_push_url" != "no-push" ]; then
        needs_migration=true
        if [ -n "$migration_reasons" ]; then
            migration_reasons="${migration_reasons}, +push-protection"
        else
            migration_reasons="+push-protection"
        fi
    fi

    if [ "$needs_migration" = true ]; then
        log_info "Migrating ${submodule_name} submodule (${migration_reasons})..."
        configure_single_submodule "$submodule_name" "$submodule_path"
        return 0
    fi

    return 1
}

# Check and fix submodule URL for deprecated repos
# Auto-fixes: hyperci/hs-ci → ci, hs-ai/standards → ai, hypersec-io → hyperi-io
# Warns only: missing .git suffix
check_submodule_url() {
    local submodule_name="$1"
    local url="$2"
    local new_url=""
    local org="${GITHUB_ORG:-hyperi-io}"

    # Check for old/deprecated repo names and auto-fix
    case "$url" in
        # CI repo deprecated names
        *"${org}/hyperci.git"|*"${org}/hyperci")
            new_url="${CI_REPO_URL}"
            log_info "${submodule_name}: Updating deprecated 'hyperci' URL → ci.git"
            ;;
        *"${org}/hs-ci.git"|*"${org}/hs-ci")
            new_url="${CI_REPO_URL}"
            log_info "${submodule_name}: Updating deprecated 'hs-ci' URL → ci.git"
            ;;
        # AI repo deprecated names
        *"${org}/hs-ai.git"|*"${org}/hs-ai")
            new_url="${AI_REPO_URL}"
            log_info "${submodule_name}: Updating deprecated 'hs-ai' URL → ai.git"
            ;;
        *"${org}/standards.git"|*"${org}/standards")
            new_url="${AI_REPO_URL}"
            log_info "${submodule_name}: Updating deprecated 'standards' URL → ai.git"
            ;;
        *"${org}/hypersec-ai.git"|*"${org}/hypersec-ai")
            new_url="${AI_REPO_URL}"
            log_info "${submodule_name}: Updating deprecated 'hypersec-ai' URL → ai.git"
            ;;
    esac

    # Check for old GitHub org name (hypersec-io → hyperi-io)
    if [ -z "$new_url" ]; then
        case "$url" in
            *"github.com/hypersec-io/"*)
                new_url="${url//hypersec-io/hyperi-io}"
                log_info "${submodule_name}: Updating deprecated 'hypersec-io' org → hyperi-io"
                ;;
        esac
    fi

    # Auto-fix deprecated URL if detected
    if [ -n "$new_url" ]; then
        git -C "$PROJECT_ROOT" config -f .gitmodules "submodule.${submodule_name}.url" "$new_url"
        # Also update the remote in the submodule itself if it exists
        local full_path="${PROJECT_ROOT}/${submodule_name}"
        if [ -d "$full_path" ]; then
            git -C "$full_path" remote set-url origin "$new_url" 2>/dev/null || true
        fi
        log_success "${submodule_name}: URL updated to ${new_url}"
    fi

    # Warn about missing .git suffix (don't auto-fix, might be intentional)
    if [[ "$url" =~ github\.com && ! "$url" =~ \.git$ ]]; then
        log_warn "${submodule_name}: URL missing .git suffix (may cause issues)"
        log_warn "  Current: ${url}"
        log_warn "  To fix: git submodule set-url ${submodule_name} ${url}.git"
    fi
}

# Copy file if it doesn't exist (or if --force)
copy_if_missing() {
    local src="$1"
    local dst="$2"

    if [ ! -f "$src" ]; then
        log_error "Template not found: $src"
        exit 1
    fi

    if [ "$DRY_RUN" = true ]; then
        if [ ! -f "$dst" ] || [ "$FORCE" = true ]; then
            log_info "Would deploy: $dst"
        else
            log_info "Would skip (exists): $dst"
        fi
        return 0
    fi

    if [ ! -f "$dst" ] || [ "$FORCE" = true ]; then
        cp "$src" "$dst"
        log_success "Deployed: $dst"
    else
        log_info "Skipped (exists): $dst"
        if [ "$VERBOSE" = true ]; then
            log_info "  Use --force to overwrite"
        fi
    fi
}

# Check if STATE.md contains forbidden content (sessions, versions, progress)
# Returns: 0 if clean, 1 if has forbidden content
check_state_md_forbidden() {
    local file="$1"
    [ ! -f "$file" ] && return 0

    # Check for forbidden patterns
    if grep -qiE "(Current Session|Last Session|Version:|Status:|Last Updated:|Progress)" "$file" 2>/dev/null; then
        return 1
    fi
    return 0
}

# Migrate existing STATE.md/CLAUDE.md to new SSoT format
migrate_state_files() {
    local state_file="$PROJECT_ROOT/STATE.md"
    local claude_file="$PROJECT_ROOT/CLAUDE.md"
    local migrated=false

    # Check STATE.md
    if [ -f "$state_file" ] && ! check_state_md_forbidden "$state_file"; then
        log_warn "STATE.md contains forbidden content (sessions, versions, progress)"
        log_warn "  SSoT rules: Tasks go in TODO.md, versions from git"
        log_info "  Review and clean manually, or use --force to replace with template"
        migrated=true
    fi

    # Check CLAUDE.md (if not a symlink to STATE.md)
    if [ -f "$claude_file" ] && [ ! -L "$claude_file" ]; then
        if ! check_state_md_forbidden "$claude_file"; then
            log_warn "CLAUDE.md contains forbidden content"
            log_info "  Should be symlink to STATE.md or removed"
            migrated=true
        fi
    fi

    # Check for other AI assistant files
    for ai_file in "$PROJECT_ROOT/CURSOR.md" "$PROJECT_ROOT/GEMINI.md" "$PROJECT_ROOT/CODEX.md"; do
        if [ -f "$ai_file" ] && [ ! -L "$ai_file" ]; then
            if ! check_state_md_forbidden "$ai_file"; then
                local basename_file
                basename_file=$(basename "$ai_file")
                log_warn "$basename_file contains forbidden content"
                log_info "  Should be symlink to STATE.md or removed"
                migrated=true
            fi
        fi
    done

    if [ "$migrated" = true ]; then
        log_info ""
        log_info "Migration guidance:"
        log_info "  1. Move tasks/progress from STATE.md to TODO.md"
        log_info "  2. Remove 'Current Session', 'Last Session' sections"
        log_info "  3. Remove version numbers, dates, status updates"
        log_info "  4. Keep only: architecture, decisions, static context"
        log_info ""
    fi
}

# Deploy templates to project root
deploy_templates() {
    local templates_dir="$AI_ROOT/templates"

    if [ ! -d "$templates_dir" ]; then
        log_error "Templates directory not found: $templates_dir"
        exit 1
    fi

    if [ "$VERBOSE" = true ]; then
        log_info "Deploying templates from: $templates_dir"
    fi

    # Check for migration needs before deploying
    migrate_state_files

    # Deploy STATE.md
    copy_if_missing "$templates_dir/STATE.md" "$PROJECT_ROOT/STATE.md"

    # Deploy TODO.md
    copy_if_missing "$templates_dir/TODO.md" "$PROJECT_ROOT/TODO.md"
}

# Run a single agent setup script
# Returns: 0=success, 1=error, 2=not installed
run_single_agent() {
    local agent="$1"
    local script="$AI_ROOT/agents/${agent}.sh"
    local force_flag=""
    local verbose_flag=""

    if [ "$FORCE" = true ]; then
        force_flag="--force"
    fi
    if [ "$VERBOSE" = true ]; then
        verbose_flag="--verbose"
    fi

    if [ ! -f "$script" ]; then
        log_error "Unknown agent: $agent"
        log_info "Available agents: ${AGENT_PRIORITY[*]}"
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

# Run agent detection based on mode
# Default: Try agents in priority order, stop on first success
# --all-agents: Try all agents, don't stop on first
# --agent NAME: Try only specified agent
run_agent_detection() {
    if [ "$NO_AGENT" = true ]; then
        if [ "$VERBOSE" = true ]; then
            log_info "Agent detection skipped (--no-agent)"
        fi
        return 0
    fi

    echo ""
    log_info "=== Agent Detection ==="

    # Specific agent requested
    if [ -n "$SPECIFIC_AGENT" ]; then
        local exit_code=0
        run_single_agent "$SPECIFIC_AGENT" || exit_code=$?
        case $exit_code in
            "$EXIT_SUCCESS")
                log_success "Configured: $SPECIFIC_AGENT"
                return 0
                ;;
            "$EXIT_NOT_INSTALLED")
                log_warn "${SPECIFIC_AGENT} CLI not installed"
                return 0  # Not an error
                ;;
            *)
                return 1  # Propagate error
                ;;
        esac
    fi

    # All agents mode
    if [ "$SETUP_ALL_AGENTS" = true ]; then
        local any_configured=false
        for agent in "${AGENT_PRIORITY[@]}"; do
            local exit_code=0
            run_single_agent "$agent" || exit_code=$?
            if [ $exit_code -eq "$EXIT_SUCCESS" ]; then
                any_configured=true
            fi
        done
        if [ "$any_configured" = false ]; then
            log_warn "No AI agent CLIs found on system"
            log_info "Install one of: claude, agent (Cursor), gemini, codex"
        fi
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
                return 1  # Stop on error
                ;;
            "$EXIT_NOT_INSTALLED")
                continue  # Try next agent
                ;;
        esac
    done

    # No agents found
    log_warn "No AI agent CLIs found on system"
    log_info "Install one of: claude, agent (Cursor), gemini, codex"
    return 0  # Warning only, not an error
}

# Print summary
print_summary() {
    local mode
    mode="$(detect_mode)"

    echo ""
    log_success "HyperI AI attached successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Review STATE.md and TODO.md in your project root"
    if [ "$NO_AGENT" = true ]; then
        echo "  2. Setup your AI assistant manually:"
        echo "       ./ai/agents/claude.sh   # Claude Code"
        echo "       ./ai/agents/cursor.sh   # Cursor IDE"
        echo "       ./ai/agents/gemini.sh   # Gemini Code"
        echo "       ./ai/agents/codex.sh    # OpenAI Codex"
    fi
    echo ""

    if [ "$mode" = "submodule" ]; then
        if [ "$PIN_SUBMODULE" = true ]; then
            echo "AI submodule configured (pinned):"
            echo "  - Manual updates only"
            echo "  - To update: git -C ai fetch && git -C ai checkout <version>"
        else
            echo "AI submodule configured:"
            echo "  - Auto-updates from upstream"
            echo "  - To update: git submodule update --remote ai"
        fi
        echo "  - Read-only (pushes blocked)"
        echo ""
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN - No files were modified"
        echo ""
    fi
}

# Main execution
main() {
    echo ""
    echo "=== HyperI AI Attach ==="
    echo ""

    parse_args "$@"
    detect_paths
    validate_environment

    # Configure/migrate submodule if in submodule mode
    local mode
    mode="$(detect_mode)"
    if [ "$mode" = "submodule" ]; then
        migrate_submodule_settings
        configure_submodule_settings
    fi

    # Deploy templates (STATE.md, TODO.md)
    deploy_templates

    # Run agent detection
    run_agent_detection

    print_summary
}

# Run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
