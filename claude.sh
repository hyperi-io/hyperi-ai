#!/usr/bin/env bash
#
# claude-code.sh - Setup Claude Code configuration
#
# Usage: ./claude-code.sh [--help] [--dry-run] [--force] [--path PATH] [--verbose]
#
set -euo pipefail

# Global variables
DRY_RUN=false
FORCE=false
VERBOSE=false
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

# Calculate relative path from one directory to another
# Usage: relative_path <from_dir> <to_file>
relative_path() {
    local from_dir="$1"
    local to_file="$2"

    # Use Python for reliable relative path calculation (available on all platforms)
    python3 -c "import os.path; print(os.path.relpath('$to_file', '$from_dir'))"
}

# Deploy settings.json as symlink (preserve existing unless --force)
deploy_settings() {
    local src="$AI_ROOT/templates/claude-code/settings.json"
    local dst="$PROJECT_ROOT/.claude/settings.json"
    local dst_dir="$PROJECT_ROOT/.claude"

    if [ ! -f "$src" ]; then
        echo "ERROR: Template not found: $src"
        exit 1
    fi

    # Calculate relative path from .claude/ to template
    local rel_path
    rel_path="$(relative_path "$dst_dir" "$src")"

    if [ "$DRY_RUN" = "true" ]; then
        if [ ! -e "$dst" ] || [ "$FORCE" = "true" ]; then
            echo "Would symlink: $dst -> $rel_path"
        else
            echo "Would skip (preserving existing): $dst"
        fi
        return 0
    fi

    if [ ! -e "$dst" ] || [ "$FORCE" = "true" ]; then
        # Remove existing file/symlink if forcing
        [ -e "$dst" ] || [ -L "$dst" ] && rm -f "$dst"
        ln -s "$rel_path" "$dst"
        echo "Symlinked: $dst -> $rel_path"
    else
        echo "Skipped (preserving existing): $dst"
        if [ "$VERBOSE" = "true" ]; then
            echo "  Use --force to overwrite with symlink"
        fi
    fi
}

# Deploy slash commands as symlinks (preserve existing unless --force)
deploy_commands() {
    local src_dir="$AI_ROOT/templates/claude-code/commands"
    local dst_dir="$PROJECT_ROOT/.claude/commands"

    if [ ! -d "$src_dir" ]; then
        echo "ERROR: Commands directory not found: $src_dir"
        exit 1
    fi

    # Calculate relative paths
    local rel_load rel_save
    rel_load="$(relative_path "$dst_dir" "$src_dir/load.md")"
    rel_save="$(relative_path "$dst_dir" "$src_dir/save.md")"

    local load_dst="$dst_dir/load.md"
    local save_dst="$dst_dir/save.md"

    if [ "$DRY_RUN" = "true" ]; then
        if [ ! -e "$load_dst" ] || [ "$FORCE" = "true" ]; then
            echo "Would symlink: $load_dst -> $rel_load"
        else
            echo "Would skip (preserving existing): $load_dst"
        fi
        if [ ! -e "$save_dst" ] || [ "$FORCE" = "true" ]; then
            echo "Would symlink: $save_dst -> $rel_save"
        else
            echo "Would skip (preserving existing): $save_dst"
        fi
        [ -e "$dst_dir/start.md" ] && echo "Would remove: $dst_dir/start.md (deprecated)"
        return 0
    fi

    # Deploy load.md
    if [ ! -e "$load_dst" ] || [ "$FORCE" = "true" ]; then
        [ -e "$load_dst" ] || [ -L "$load_dst" ] && rm -f "$load_dst"
        ln -s "$rel_load" "$load_dst"
        echo "Symlinked: $load_dst -> $rel_load"
    else
        echo "Skipped (preserving existing): $load_dst"
    fi

    # Deploy save.md
    if [ ! -e "$save_dst" ] || [ "$FORCE" = "true" ]; then
        [ -e "$save_dst" ] || [ -L "$save_dst" ] && rm -f "$save_dst"
        ln -s "$rel_save" "$save_dst"
        echo "Symlinked: $save_dst -> $rel_save"
    else
        echo "Skipped (preserving existing): $save_dst"
    fi

    # Remove deprecated start.md if it exists
    if [ -e "$dst_dir/start.md" ]; then
        rm -f "$dst_dir/start.md"
        echo "Removed: $dst_dir/start.md (deprecated, replaced by load.md)"
    fi

    if [ "$VERBOSE" = "true" ]; then
        echo "  Use --force to overwrite with symlinks"
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
        echo "Configuration (symlinked to ai/templates/claude-code/):"
        echo "  .claude/settings.json     -> settings.json"
        echo "  .claude/commands/load.md  -> commands/load.md"
        echo "  .claude/commands/save.md  -> commands/save.md"
        echo "  CLAUDE.md -> STATE.md"
        echo ""
        echo "Next steps:"
        echo "  1. Open project in Claude Code"
        echo "  2. Run /load to initialize session"
        echo "  3. Review CLAUDE.md (links to STATE.md)"
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
  --force         Remove existing files and replace with symlinks
  --path PATH     Specify custom project root (default: parent of ai/)
  --verbose       Enable verbose output
  -h              Same as --help

Notes:
  - Requires STATE.md (run install.sh first)
  - Creates symlinks to templates (not copies)
  - Preserves ALL existing files by default (use --force to replace)
  - Creates CLAUDE.md -> STATE.md symlink

Examples:
  # Basic usage (setup in parent directory)
  ./claude-code.sh

  # Preview changes without modifying files
  ./claude-code.sh --dry-run

  # Force overwrite settings
  ./claude-code.sh --force

  # Setup for custom project
  ./claude-code.sh --path /path/to/project

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
    print_summary
}

# Run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
