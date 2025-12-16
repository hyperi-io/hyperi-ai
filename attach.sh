#!/usr/bin/env bash
# Project:      HyperSec AI
# File:         attach.sh
# Purpose:      Attach AI standards to a project
# License:      LicenseRef-HyperSec-EULA
# Copyright:    (c) 2025 HyperSec Pty Ltd
#
# Bash 3.2 compatible (macOS default)

set -euo pipefail

# Global variables
AI_ROOT=""
PROJECT_ROOT=""
AI_DIR="ai"

# Defaults
DRY_RUN=false
FORCE=false
VERBOSE=false
PIN_SUBMODULE=false
INSTALL_HOOKS=true

# Assistant setup flags
SETUP_CLAUDE=false
SETUP_COPILOT=false
SETUP_CURSOR=false
SETUP_GEMINI=false

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

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Show usage information
show_usage() {
    cat << 'EOF'
attach.sh - Attach HyperSec AI standards to your project

Usage: ./attach.sh [OPTIONS]

OPTIONS:
  --help, -h       Show this help message
  --dry-run        Show what would be done without making changes
  --force          Overwrite existing files
  --path PATH      Specify custom project root (default: parent of ai/)
  --verbose        Enable verbose output

  --pin            Pin submodule version (disable auto-update from upstream)
                   Use this for projects requiring fixed AI versions

  --hooks          Install git hooks (default)
  --no-hooks       Skip git hook installation

ASSISTANT SETUP (runs assistant script after attach):
  --claude         Also configure Claude Code
  --copilot        Also configure GitHub Copilot
  --cursor         Also configure Cursor IDE
  --gemini         Also configure Gemini Code

EXAMPLES:
  # Basic usage (deploy to parent directory)
  ./ai/attach.sh

  # Attach and configure Claude Code
  ./ai/attach.sh --claude

  # Preview changes without modifying files
  ./ai/attach.sh --dry-run

  # Force overwrite existing files
  ./ai/attach.sh --force

  # Pin submodule version (no auto-update)
  ./ai/attach.sh --pin

  # Attach + Claude + pinned
  ./ai/attach.sh --claude --pin

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
            --hooks)
                INSTALL_HOOKS=true
                shift
                ;;
            --no-hooks)
                INSTALL_HOOKS=false
                shift
                ;;
            --claude)
                SETUP_CLAUDE=true
                shift
                ;;
            --copilot)
                SETUP_COPILOT=true
                shift
                ;;
            --cursor)
                SETUP_CURSOR=true
                shift
                ;;
            --gemini)
                SETUP_GEMINI=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Try '$0 --help' for more information"
                exit 1
                ;;
        esac
    done
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
    local current_push_url=""
    local full_path="${PROJECT_ROOT}/${submodule_path}"
    if [ -d "$full_path" ]; then
        current_push_url=$(git -C "$full_path" remote get-url --push origin 2>/dev/null || echo "")
    fi

    local needs_migration=false
    local migration_reasons=""

    # Determine expected update mode
    local expected_update="rebase"
    if [ "$PIN_SUBMODULE" = true ]; then
        expected_update="none"
    fi

    # Check if update mode matches expected
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

    # Deploy STATE.md
    copy_if_missing "$templates_dir/STATE.md" "$PROJECT_ROOT/STATE.md"

    # Deploy TODO.md
    copy_if_missing "$templates_dir/TODO.md" "$PROJECT_ROOT/TODO.md"
}

# Install git hooks (symlinks to ai/hooks/)
install_git_hooks() {
    local hooks_dir="${PROJECT_ROOT}/.git/hooks"

    # Check .git/hooks exists
    if [ ! -d "$hooks_dir" ]; then
        log_warn "Not a git repository (.git/hooks/ not found)"
        return
    fi

    # Check if CI hooks are already installed - defer to CI if present
    if [ -L "${hooks_dir}/pre-commit" ]; then
        local target
        target=$(readlink "${hooks_dir}/pre-commit" 2>/dev/null || echo "")
        case "$target" in
            *"ci/hooks"*)
                log_info "CI hooks already installed - skipping AI hooks"
                log_info "  (CI hooks handle both ci and ai submodules)"
                return
                ;;
        esac
    fi

    # Check if hook templates exist
    if [ ! -f "${AI_ROOT}/hooks/pre-commit" ]; then
        log_warn "Hook templates not found in ${AI_ROOT}/hooks/"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Would install git hooks from ${AI_DIR}/hooks/"
        return
    fi

    # Symlink hooks (relative paths so they work after clone)
    ln -sf "../../${AI_DIR}/hooks/commit-msg" "${hooks_dir}/commit-msg"
    ln -sf "../../${AI_DIR}/hooks/pre-commit" "${hooks_dir}/pre-commit"
    ln -sf "../../${AI_DIR}/hooks/post-checkout" "${hooks_dir}/post-checkout"

    log_success "Git hooks installed (symlinked from ${AI_DIR}/hooks/)"
    log_info "  pre-commit: validates branch naming"
    log_info "  commit-msg: removes AI attribution"
    log_info "  post-checkout: auto-updates submodules, ensures push protection"
}

# Run assistant setup scripts if requested
run_assistant_setup() {
    local force_flag=""
    local verbose_flag=""

    if [ "$FORCE" = true ]; then
        force_flag="--force"
    fi
    if [ "$VERBOSE" = true ]; then
        verbose_flag="--verbose"
    fi

    if [ "$SETUP_CLAUDE" = true ]; then
        log_info "Running Claude Code setup..."
        "${AI_ROOT}/claude.sh" $force_flag $verbose_flag || true
    fi

    if [ "$SETUP_COPILOT" = true ]; then
        log_info "Running GitHub Copilot setup..."
        "${AI_ROOT}/copilot.sh" $force_flag $verbose_flag || true
    fi

    if [ "$SETUP_CURSOR" = true ]; then
        log_info "Running Cursor IDE setup..."
        "${AI_ROOT}/cursor.sh" $force_flag $verbose_flag || true
    fi

    if [ "$SETUP_GEMINI" = true ]; then
        log_info "Running Gemini Code setup..."
        "${AI_ROOT}/gemini.sh" $force_flag $verbose_flag || true
    fi
}

# Print summary
print_summary() {
    local mode
    mode="$(detect_mode)"

    echo ""
    log_success "HyperSec AI attached successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Review STATE.md and TODO.md in your project root"
    if [ "$SETUP_CLAUDE" != true ] && [ "$SETUP_COPILOT" != true ] && \
       [ "$SETUP_CURSOR" != true ] && [ "$SETUP_GEMINI" != true ]; then
        echo "  2. Setup your AI assistant:"
        echo "       ./ai/claude.sh    # Claude Code"
        echo "       ./ai/copilot.sh   # GitHub Copilot"
        echo "       ./ai/cursor.sh    # Cursor IDE"
        echo "       ./ai/gemini.sh    # Gemini Code"
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
    echo "=== HyperSec AI Attach ==="
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

    # Install hooks (unless CI hooks present or --no-hooks)
    if [ "$INSTALL_HOOKS" = true ]; then
        install_git_hooks
    else
        log_info "Skipping git hooks (--no-hooks)"
    fi

    # Run assistant setup scripts if requested
    run_assistant_setup

    print_summary
}

# Run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
