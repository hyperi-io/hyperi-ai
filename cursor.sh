#!/usr/bin/env bash
#
# cursor.sh - Setup Cursor IDE configuration
#
# Usage: ./cursor.sh [--help] [--dry-run] [--force] [--path PATH] [--verbose]
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
        echo "Created: $cursor_dir/"
        echo "Created: $rules_dir/"
    fi
}

# Deploy cli.json (preserve existing unless --force)
deploy_cli_json() {
    local src="$AI_ROOT/templates/cursor/cli.json"
    local dst="$PROJECT_ROOT/.cursor/cli.json"

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

# Deploy rules (always overwrite - these are versioned)
deploy_rules() {
    local src_dir="$AI_ROOT/templates/cursor/rules"
    local dst_dir="$PROJECT_ROOT/.cursor/rules"

    if [ ! -d "$src_dir" ]; then
        echo "ERROR: Rules directory not found: $src_dir"
        exit 1
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

    echo "Deployed: $dst_dir/standards.mdc"
    echo "Deployed: $dst_dir/session-start.mdc"
    echo "Deployed: $dst_dir/session-save.mdc"

    if [ "$VERBOSE" = "true" ]; then
        echo "  Rules are always updated (versioned templates)"
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
    echo "Cursor IDE Setup Summary"
    echo "================================"
    echo "AI Root: $AI_ROOT"
    echo "Project Root: $PROJECT_ROOT"

    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        echo "DRY RUN - No files were modified"
    else
        echo ""
        echo "Cursor IDE setup complete!"
        echo ""
        echo "Configuration:"
        echo "  .cursor/cli.json              - Cursor permissions"
        echo "  .cursor/rules/standards.mdc   - Always-attached: Standards loading"
        echo "  .cursor/rules/session-start.mdc - Auto-attached: Session initialization"
        echo "  .cursor/rules/session-save.mdc   - Manual: Session save instructions"
        echo "  CURSOR.md -> STATE.md         - Project state symlink"
        echo ""
        echo "Next steps:"
        echo "  1. Open project in Cursor IDE"
        echo "  2. Rules will be automatically loaded based on their categories"
        echo "  3. Review CURSOR.md (links to STATE.md)"
        echo ""
        echo "Note: Rules are categorized as:"
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
  - Requires STATE.md (run install.sh first)
  - Preserves existing cli.json by default
  - Always updates rules (versioned templates)
  - Creates CURSOR.md -> STATE.md symlink
  - Uses modern .cursor/rules/ directory (not legacy .cursorrules)

Examples:
  # Basic usage (setup in parent directory)
  ./cursor.sh

  # Preview changes without modifying files
  ./cursor.sh --dry-run

  # Force overwrite cli.json
  ./cursor.sh --force

  # Setup for custom project
  ./cursor.sh --path /path/to/project

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

