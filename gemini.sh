#!/usr/bin/env bash
#
# gemini.sh - Setup Gemini Code configuration
#
# Usage: ./gemini.sh [--help] [--dry-run] [--force] [--path PATH] [--verbose]
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
        echo "Created: $gemini_dir/"
        echo "Created: $commands_dir/"
    fi
}

# Deploy settings.json (preserve existing unless --force)
deploy_settings() {
    local src="$AI_ROOT/templates/gemini/settings.json"
    local dst="$PROJECT_ROOT/.gemini/settings.json"

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
    local src_dir="$AI_ROOT/templates/gemini/commands"
    local dst_dir="$PROJECT_ROOT/.gemini/commands"

    if [ ! -d "$src_dir" ]; then
        echo "ERROR: Commands directory not found: $src_dir"
        exit 1
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would deploy: $dst_dir/local.md"
        echo "Would deploy: $dst_dir/save.md"
        return 0
    fi

    # Always overwrite commands (they're versioned templates)
    cp "$src_dir/local.md" "$dst_dir/"
    cp "$src_dir/save.md" "$dst_dir/"

    echo "Deployed: $dst_dir/local.md"
    echo "Deployed: $dst_dir/save.md"

    if [ "$VERBOSE" = "true" ]; then
        echo "  Commands are always updated (versioned templates)"
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
    echo "Gemini Code Setup Summary"
    echo "================================"
    echo "AI Root: $AI_ROOT"
    echo "Project Root: $PROJECT_ROOT"

    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        echo "DRY RUN - No files were modified"
    else
        echo ""
        echo "Gemini Code setup complete!"
        echo ""
        echo "Configuration:"
        echo "  .gemini/settings.json      - Gemini Code settings"
        echo "  .gemini/commands/local.md  - /load command"
        echo "  .gemini/commands/save.md   - /save command"
        echo "  GEMINI.md -> STATE.md      - Project state symlink"
        echo ""
        echo "Next steps:"
        echo "  1. Open project in your Gemini environment"
        echo "  2. Run /load to initialize session"
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
  - Requires STATE.md (run install.sh first)
  - Preserves existing settings.json by default
  - Always updates slash commands (versioned templates)
  - Creates GEMINI.md -> STATE.md symlink

Examples:
  # Basic usage (setup in parent directory)
  ./gemini.sh

  # Preview changes without modifying files
  ./gemini.sh --dry-run

  # Force overwrite settings
  ./gemini.sh --force

  # Setup for custom project
  ./gemini.sh --path /path/to/project

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