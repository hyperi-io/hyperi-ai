#!/usr/bin/env bash
# Project:   HyperI AI
# File:      agents/gemini.sh
# Purpose:   Setup Gemini Code configuration for a project
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# Usage: ./agents/gemini.sh [--help] [--dry-run] [--force] [--path PATH] [--verbose]
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
AGENT_CLI="gemini"
AGENT_NAME="Gemini Code"

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

# Check if Gemini CLI is installed
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
        agent_log_info "Run attach.sh first: ./hyperi-ai/attach.sh"
        exit $EXIT_ERROR
    fi

    if [ "$VERBOSE" = "true" ]; then
        agent_log_info "Prerequisites check passed"
    fi
}

# Create .gemini directory structure
setup_gemini_dir() {
    local gemini_dir="$PROJECT_ROOT/.gemini"
    local commands_dir="$gemini_dir/commands"

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would create: $gemini_dir/"
        echo "Would create: $commands_dir/"
        return 0
    fi

    mkdir -p "$commands_dir"

    if [ "$VERBOSE" = "true" ]; then
        agent_log_info "Created: $gemini_dir/"
        agent_log_info "Created: $commands_dir/"
    fi
}

# Deploy settings.json (preserve existing unless --force)
deploy_settings() {
    local src="$AI_ROOT/templates/gemini/settings.json"
    local dst="$PROJECT_ROOT/.gemini/settings.json"

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

# Deploy slash commands (always overwrite - these are versioned)
deploy_commands() {
    local src_dir="$AI_ROOT/templates/gemini/commands"
    local dst_dir="$PROJECT_ROOT/.gemini/commands"

    if [ ! -d "$src_dir" ]; then
        agent_log_error "Commands directory not found: $src_dir"
        exit $EXIT_ERROR
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would deploy: $dst_dir/load.md"
        echo "Would deploy: $dst_dir/save.md"
        [ -f "$dst_dir/start.md" ] && echo "Would remove: $dst_dir/start.md (deprecated)"
        return 0
    fi

    # Always overwrite commands (they're versioned templates)
    cp "$src_dir/load.md" "$dst_dir/"
    cp "$src_dir/save.md" "$dst_dir/"

    # Remove deprecated start.md if it exists
    if [ -f "$dst_dir/start.md" ]; then
        rm "$dst_dir/start.md"
        agent_log_info "Removed: $dst_dir/start.md (deprecated, replaced by load.md)"
    fi

    agent_log_success "Deployed: $dst_dir/load.md"
    agent_log_success "Deployed: $dst_dir/save.md"

    if [ "$VERBOSE" = "true" ]; then
        agent_log_info "  Commands are always updated (versioned templates)"
    fi
}

# Create GEMINI.md symlink to STATE.md
create_symlink() {
    local link="$PROJECT_ROOT/GEMINI.md"
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
    echo "Gemini Code Setup Summary"
    echo "================================"
    echo "AI Root: $AI_ROOT"
    echo "Project Root: $PROJECT_ROOT"

    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        echo "DRY RUN - No files were modified"
    else
        echo ""
        agent_log_success "Gemini Code setup complete!"
        echo ""
        echo "Configuration:"
        echo "  .gemini/settings.json     - Gemini Code settings"
        echo "  .gemini/commands/load.md  - /load command"
        echo "  .gemini/commands/save.md  - /save command"
        echo "  GEMINI.md -> STATE.md     - Project state symlink"
        echo ""
        echo "Next steps:"
        echo "  1. Open project in your Gemini environment"
        echo "  2. Run /load to initialise session"
        echo "  3. Review GEMINI.md (links to STATE.md)"
    fi
    echo "================================"
}

# Show usage information
show_usage() {
    cat << EOF
gemini.sh - Setup Gemini Code configuration

Usage: $0 [OPTIONS]

Options:
  --help          Show this help message
  --dry-run       Show what would be done without making changes
  --force         Overwrite existing settings.json
  --path PATH     Specify custom project root (default: parent of ai/)
  --verbose       Enable verbose output
  -h              Same as --help

Notes:
  - Requires Gemini CLI to be installed
  - Requires STATE.md (run attach.sh first)
  - Preserves existing settings.json by default
  - Always updates slash commands (versioned templates)
  - Creates GEMINI.md -> STATE.md symlink

Examples:
  # Basic usage (setup in parent directory)
  ./agents/gemini.sh

  # Preview changes without modifying files
  ./agents/gemini.sh --dry-run

  # Force overwrite settings
  ./agents/gemini.sh --force

  # Setup for custom project
  ./agents/gemini.sh --path /path/to/project

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
    setup_gemini_dir
    deploy_settings
    deploy_commands
    create_symlink
    print_summary
}

# Run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
