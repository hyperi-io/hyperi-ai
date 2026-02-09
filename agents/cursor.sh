#!/usr/bin/env bash
# Project:   HyperI AI
# File:      agents/cursor.sh
# Purpose:   Setup Cursor IDE configuration for a project
#
# License:   FSL-1.1-ALv2
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# Usage: ./agents/cursor.sh [--help] [--dry-run] [--force] [--path PATH] [--verbose]
#
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agents/common.sh
source "${SCRIPT_DIR}/common.sh"

# Global variables
DRY_RUN=false
FORCE=false
VERBOSE=false
AI_ROOT=""
PROJECT_ROOT=""

# CLI command for this agent
AGENT_CLI="agent"
AGENT_NAME="Cursor"

# Detect script location and project root
detect_paths() {
    # AI_ROOT = parent of agents/ directory
    AI_ROOT="$(dirname "$SCRIPT_DIR")"

    # PROJECT_ROOT = parent directory (default)
    # Can be overridden with --path
    if [ -z "$PROJECT_ROOT" ]; then
        PROJECT_ROOT="$(dirname "$AI_ROOT")"
    fi

    if [ "$VERBOSE" = "true" ]; then
        agent_log_info "AI_ROOT: $AI_ROOT"
        agent_log_info "PROJECT_ROOT: $PROJECT_ROOT"
    fi
}

# Check if Cursor CLI is installed
check_agent_cli() {
    if ! agent_installed "$AGENT_CLI"; then
        agent_log_info "${AGENT_NAME} CLI '${AGENT_CLI}' not installed (skipping)"
        exit $EXIT_NOT_INSTALLED
    fi
    if [ "$VERBOSE" = "true" ]; then
        agent_log_info "${AGENT_NAME} CLI found: $(command -v "$AGENT_CLI")"
    fi
}

# Check prerequisites
check_prerequisites() {
    if [ ! -f "$PROJECT_ROOT/STATE.md" ]; then
        agent_log_error "STATE.md not found in project root"
        agent_log_info "Run attach.sh first: ./ai/attach.sh"
        exit $EXIT_ERROR
    fi

    if [ "$VERBOSE" = "true" ]; then
        agent_log_info "Prerequisites check passed"
    fi
}

# Create .cursor directory structure
setup_cursor_dir() {
    local cursor_dir="$PROJECT_ROOT/.cursor"
    local rules_dir="$cursor_dir/rules"

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would create: $cursor_dir/"
        echo "Would create: $rules_dir/"
        return 0
    fi

    mkdir -p "$rules_dir"

    if [ "$VERBOSE" = "true" ]; then
        agent_log_info "Created: $cursor_dir/"
        agent_log_info "Created: $rules_dir/"
    fi
}

# Deploy cli.json (preserve existing unless --force)
deploy_cli_json() {
    local src="$AI_ROOT/templates/cursor/cli.json"
    local dst="$PROJECT_ROOT/.cursor/cli.json"

    if [ ! -f "$src" ]; then
        agent_log_error "Template not found: $src"
        exit $EXIT_ERROR
    fi

    if [ "$DRY_RUN" = "true" ]; then
        if [ ! -f "$dst" ] || [ "$FORCE" = "true" ]; then
            echo "Would deploy: $dst"
        else
            echo "Would skip (preserving existing): $dst"
        fi
        return 0
    fi

    if [ ! -f "$dst" ] || [ "$FORCE" = "true" ]; then
        cp "$src" "$dst"
        agent_log_success "Deployed: $dst"
    else
        agent_log_info "Skipped (preserving existing): $dst"
        if [ "$VERBOSE" = "true" ]; then
            agent_log_info "  Use --force to overwrite custom settings"
        fi
    fi
}

# Deploy rules (always overwrite - these are versioned)
deploy_rules() {
    local src_dir="$AI_ROOT/templates/cursor/rules"
    local dst_dir="$PROJECT_ROOT/.cursor/rules"

    if [ ! -d "$src_dir" ]; then
        agent_log_error "Rules directory not found: $src_dir"
        exit $EXIT_ERROR
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would deploy: $dst_dir/standards.mdc"
        echo "Would deploy: $dst_dir/session-start.mdc"
        echo "Would deploy: $dst_dir/session-save.mdc"
        return 0
    fi

    # Always overwrite rules (they're versioned templates)
    cp "$src_dir/standards.mdc" "$dst_dir/"
    cp "$src_dir/session-start.mdc" "$dst_dir/"
    cp "$src_dir/session-save.mdc" "$dst_dir/"

    agent_log_success "Deployed: $dst_dir/standards.mdc"
    agent_log_success "Deployed: $dst_dir/session-start.mdc"
    agent_log_success "Deployed: $dst_dir/session-save.mdc"

    if [ "$VERBOSE" = "true" ]; then
        agent_log_info "  Rules are always updated (versioned templates)"
    fi
}

# Create CURSOR.md symlink to STATE.md
create_symlink() {
    local link="$PROJECT_ROOT/CURSOR.md"
    local target="STATE.md"

    if [ "$DRY_RUN" = "true" ]; then
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
        agent_log_info "  Delete it manually to create symlink, or use --force"
    else
        ln -s "$target" "$link"
        agent_log_success "Created: $link -> $target"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "================================"
    echo "Cursor IDE Setup Summary"
    echo "================================"
    echo "AI Root: $AI_ROOT"
    echo "Project Root: $PROJECT_ROOT"

    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        echo "DRY RUN - No files were modified"
    else
        echo ""
        agent_log_success "Cursor IDE setup complete!"
        echo ""
        echo "Configuration:"
        echo "  .cursor/cli.json              - Cursor permissions"
        echo "  .cursor/rules/standards.mdc   - Always-attached: Standards loading"
        echo "  .cursor/rules/session-start.mdc - Auto-attached: Session initialisation"
        echo "  .cursor/rules/session-save.mdc   - Manual: Session save instructions"
        echo "  CURSOR.md -> STATE.md         - Project state symlink"
        echo ""
        echo "Next steps:"
        echo "  1. Open project in Cursor IDE"
        echo "  2. Rules will be automatically loaded based on their categories"
        echo "  3. Review CURSOR.md (links to STATE.md)"
        echo ""
        echo "Note: Rules are categorised as:"
        echo "  - standards.mdc: Always (always loaded)"
        echo "  - session-start.mdc: Auto Attached (loaded when relevant)"
        echo "  - session-save.mdc: Manual (invoke when needed)"
    fi
    echo "================================"
}

# Show usage information
show_usage() {
    cat << EOF
cursor.sh - Setup Cursor IDE configuration

Usage: $0 [OPTIONS]

Options:
  --help          Show this help message
  --dry-run       Show what would be done without making changes
  --force         Overwrite existing cli.json
  --path PATH     Specify custom project root (default: parent of ai/)
  --verbose       Enable verbose output
  -h              Same as --help

Notes:
  - Requires Cursor CLI ('agent') to be installed
  - Requires STATE.md (run attach.sh first)
  - Preserves existing cli.json by default
  - Always updates rules (versioned templates)
  - Creates CURSOR.md -> STATE.md symlink
  - Uses modern .cursor/rules/ directory (not legacy .cursorrules)

Examples:
  # Basic usage (setup in parent directory)
  ./agents/cursor.sh

  # Preview changes without modifying files
  ./agents/cursor.sh --dry-run

  # Force overwrite cli.json
  ./agents/cursor.sh --force

  # Setup for custom project
  ./agents/cursor.sh --path /path/to/project

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
                    agent_log_error "--path requires an argument"
                    exit $EXIT_ERROR
                fi
                PROJECT_ROOT="$2"
                shift 2
                ;;
            *)
                agent_log_error "Unknown option: $1"
                echo "Try '$0 --help' for more information"
                exit $EXIT_ERROR
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    # Check if project root exists
    if [ ! -d "$PROJECT_ROOT" ]; then
        agent_log_error "Project directory does not exist: $PROJECT_ROOT"
        exit $EXIT_ERROR
    fi

    # Check if project root is writable
    if [ ! -w "$PROJECT_ROOT" ]; then
        agent_log_error "Project directory is not writable: $PROJECT_ROOT"
        exit $EXIT_ERROR
    fi
}

# Main execution
main() {
    parse_args "$@"
    detect_paths
    check_agent_cli
    validate_environment
    check_prerequisites
    setup_cursor_dir
    deploy_cli_json
    deploy_rules
    create_symlink
    print_summary
}

# Run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
