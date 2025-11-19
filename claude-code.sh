#!/usr/bin/env bash
#
# claude-code.sh - Setup Claude Code configuration
#
# Usage: ./claude-code.sh [--help] [--dry-run] [--force] [--path PATH] [--verbose]
#
set -euo pipefail

# Global variables
VERSION="0.1.0"
DRY_RUN=false
FORCE=false
VERBOSE=false
ENABLE_1M=false
AI_ROOT=""
PROJECT_ROOT=""

# Detect script location and project root
detect_paths() {
    # AI_ROOT = directory containing this script
    AI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # PROJECT_ROOT = parent directory (default)
    # Can be overridden with --path
    if [ -z "$PROJECT_ROOT" ]; then
        PROJECT_ROOT="$(dirname "$AI_ROOT")"
    fi

    if [ "$VERBOSE" = "true" ]; then
        echo "AI_ROOT: $AI_ROOT"
        echo "PROJECT_ROOT: $PROJECT_ROOT"
    fi
}

# Check prerequisites
check_prerequisites() {
    if [ ! -f "$PROJECT_ROOT/STATE.md" ]; then
        echo "ERROR: STATE.md not found in project root"
        echo "Please run install.sh first:"
        echo "  ./ai/install.sh"
        exit 1
    fi

    if [ "$VERBOSE" = "true" ]; then
        echo "Prerequisites check passed"
    fi
}

# Create .claude directory structure
setup_claude_dir() {
    local claude_dir="$PROJECT_ROOT/.claude"
    local commands_dir="$claude_dir/commands"

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would create: $claude_dir/"
        echo "Would create: $commands_dir/"
        return 0
    fi

    mkdir -p "$commands_dir"

    if [ "$VERBOSE" = "true" ]; then
        echo "Created: $claude_dir/"
        echo "Created: $commands_dir/"
    fi
}

# Deploy settings.json (preserve existing unless --force)
deploy_settings() {
    local src="$AI_ROOT/templates/claude-code/settings.json"
    local dst="$PROJECT_ROOT/.claude/settings.json"

    if [ ! -f "$src" ]; then
        echo "ERROR: Template not found: $src"
        exit 1
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
        echo "Deployed: $dst"
    else
        echo "Skipped (preserving existing): $dst"
        if [ "$VERBOSE" = "true" ]; then
            echo "  Use --force to overwrite custom settings"
        fi
    fi
}

# Deploy slash commands (always overwrite - these are versioned)
deploy_commands() {
    local src_dir="$AI_ROOT/templates/claude-code/commands"
    local dst_dir="$PROJECT_ROOT/.claude/commands"

    if [ ! -d "$src_dir" ]; then
        echo "ERROR: Commands directory not found: $src_dir"
        exit 1
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would deploy: $dst_dir/start.md"
        echo "Would deploy: $dst_dir/save.md"
        return 0
    fi

    # Always overwrite commands (they're versioned templates)
    cp "$src_dir/start.md" "$dst_dir/"
    cp "$src_dir/save.md" "$dst_dir/"

    echo "Deployed: $dst_dir/start.md"
    echo "Deployed: $dst_dir/save.md"

    if [ "$VERBOSE" = "true" ]; then
        echo "  Commands are always updated (versioned templates)"
    fi
}

# Create CLAUDE.md symlink to STATE.md
create_symlink() {
    local link="$PROJECT_ROOT/CLAUDE.md"
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
        echo "Skipped (exists): $link -> $existing_target"
    elif [ -f "$link" ]; then
        echo "WARNING: $link exists as a regular file"
        echo "  Delete it manually to create symlink, or use --force"
    else
        ln -s "$target" "$link"
        echo "Created: $link -> $target"
    fi
}

# Enable 1M context window
enable_1m_context() {
    local bashrc="$HOME/.bashrc"
    local export_line='export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-4-5-20250929[1m]"'

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would add to ~/.bashrc:"
        echo "  $export_line"
        return 0
    fi

    # Check if already configured
    if grep -q "ANTHROPIC_DEFAULT_SONNET_MODEL.*\[1m\]" "$bashrc" 2>/dev/null; then
        echo "1M context window already enabled in ~/.bashrc"
        return 0
    fi

    # Add to bashrc
    echo "" >> "$bashrc"
    echo "# Claude Code 1M context window (added by ai/claude-code.sh)" >> "$bashrc"
    echo "$export_line" >> "$bashrc"

    echo "Added 1M context window configuration to ~/.bashrc"
    echo ""
    echo "IMPORTANT: Run 'source ~/.bashrc' or restart your terminal to apply"
}

# Print summary
print_summary() {
    echo ""
    echo "================================"
    echo "Claude Code Setup Summary"
    echo "================================"
    echo "AI Root: $AI_ROOT"
    echo "Project Root: $PROJECT_ROOT"

    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        echo "DRY RUN - No files were modified"
    else
        echo ""
        echo "Claude Code setup complete!"
        echo ""
        echo "Configuration:"
        echo "  .claude/settings.json      - Claude Code settings"
        echo "  .claude/commands/start.md  - /start command"
        echo "  .claude/commands/save.md   - /save command"
        echo "  CLAUDE.md -> STATE.md      - Project state symlink"

        if [ "$ENABLE_1M" = "true" ]; then
            echo "  ~/.bashrc                  - 1M context window enabled"
        fi

        echo ""
        echo "Next steps:"
        echo "  1. Open project in Claude Code"
        if [ "$ENABLE_1M" = "true" ]; then
            echo "  2. Run 'source ~/.bashrc' to enable 1M context"
            echo "  3. Run /start to initialize session"
        else
            echo "  2. Run /start to initialize session"
            echo "  3. Review CLAUDE.md (links to STATE.md)"
            echo ""
            echo "Optional: Run with --1m flag to enable 1M context window"
        fi
    fi
    echo "================================"
}

# Show usage information
show_usage() {
    cat << EOF
claude-code.sh - Setup Claude Code configuration

Usage: $0 [OPTIONS]

Options:
  --help          Show this help message
  --dry-run       Show what would be done without making changes
  --force         Overwrite existing settings.json
  --path PATH     Specify custom project root (default: parent of ai/)
  --verbose       Enable verbose output
  --1m            Enable 1M context window (modifies ~/.bashrc)
  -h              Same as --help

Notes:
  - Requires STATE.md (run install.sh first)
  - Preserves existing settings.json by default
  - Always updates slash commands (versioned templates)
  - Creates CLAUDE.md -> STATE.md symlink
  - --1m flag adds export to ~/.bashrc for 1M context window

Examples:
  # Basic usage (setup in parent directory)
  ./claude-code.sh

  # Enable 1M context window (will modify ~/.bashrc)
  ./claude-code.sh --1m

  # Preview changes including 1M setup
  ./claude-code.sh --1m --dry-run

  # Force overwrite settings
  ./claude-code.sh --force

  # Setup for custom project
  ./claude-code.sh --path /path/to/project

Version: $VERSION
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
            --1m)
                ENABLE_1M=true
                shift
                ;;
            --path)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --path requires an argument"
                    exit 1
                fi
                PROJECT_ROOT="$2"
                shift 2
                ;;
            *)
                echo "ERROR: Unknown option: $1"
                echo "Try '$0 --help' for more information"
                exit 1
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    # Check if project root exists
    if [ ! -d "$PROJECT_ROOT" ]; then
        echo "ERROR: Project directory does not exist: $PROJECT_ROOT"
        exit 1
    fi

    # Check if project root is writable
    if [ ! -w "$PROJECT_ROOT" ]; then
        echo "ERROR: Project directory is not writable: $PROJECT_ROOT"
        exit 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    detect_paths
    validate_environment
    check_prerequisites
    setup_claude_dir
    deploy_settings
    deploy_commands
    create_symlink

    # Enable 1M context window if requested
    if [ "$ENABLE_1M" = "true" ]; then
        enable_1m_context
    fi

    print_summary
}

# Run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
