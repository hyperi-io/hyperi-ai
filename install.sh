#!/usr/bin/env bash
#
# install.sh - Deploy AI assistant templates to project
#
# Usage: ./install.sh [--help] [--dry-run] [--force] [--path PATH] [--verbose]
#
set -euo pipefail

# Global variables
VERSION="0.1.0"
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

    if [ "$VERBOSE" = "true" ]; then
        echo "Detected mode: $mode"
    fi

    echo "$mode"
}

# Copy file if it doesn't exist (or if --force)
copy_if_missing() {
    local src="$1"
    local dst="$2"

    if [ ! -f "$src" ]; then
        echo "ERROR: Template not found: $src"
        exit 1
    fi

    if [ "$DRY_RUN" = "true" ]; then
        if [ ! -f "$dst" ] || [ "$FORCE" = "true" ]; then
            echo "Would deploy: $dst"
        else
            echo "Would skip (exists): $dst"
        fi
        return 0
    fi

    if [ ! -f "$dst" ] || [ "$FORCE" = "true" ]; then
        cp "$src" "$dst"
        echo "Deployed: $dst"
    else
        echo "Skipped (exists): $dst"
        if [ "$VERBOSE" = "true" ]; then
            echo "  Use --force to overwrite"
        fi
    fi
}

# Deploy templates to project root
deploy_templates() {
    local templates_dir="$AI_ROOT/templates"

    if [ ! -d "$templates_dir" ]; then
        echo "ERROR: Templates directory not found: $templates_dir"
        exit 1
    fi

    if [ "$VERBOSE" = "true" ]; then
        echo "Deploying templates from: $templates_dir"
    fi

    # Deploy STATE.md
    copy_if_missing "$templates_dir/STATE.md" "$PROJECT_ROOT/STATE.md"

    # Deploy TODO.md
    copy_if_missing "$templates_dir/TODO.md" "$PROJECT_ROOT/TODO.md"
}

# Print summary
print_summary() {
    local mode
    mode="$(detect_mode)"

    echo ""
    echo "================================"
    echo "Installation Summary"
    echo "================================"
    echo "Mode: $mode"
    echo "AI Root: $AI_ROOT"
    echo "Project Root: $PROJECT_ROOT"

    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        echo "DRY RUN - No files were modified"
    else
        echo ""
        echo "Templates deployed successfully!"
        echo ""
        echo "Next steps:"
        echo "  1. Review STATE.md and TODO.md in your project root"
        echo "  2. Run ./ai/claude-code.sh to setup Claude Code (optional)"
    fi
    echo "================================"
}

# Show usage information
show_usage() {
    cat << EOF
install.sh - Deploy AI assistant templates to project

Usage: $0 [OPTIONS]

Options:
  --help          Show this help message
  --dry-run       Show what would be done without making changes
  --force         Overwrite existing files
  --path PATH     Specify custom project root (default: parent of ai/)
  --verbose       Enable verbose output
  -h              Same as --help

Examples:
  # Basic usage (deploy to parent directory)
  ./install.sh

  # Preview changes without modifying files
  ./install.sh --dry-run

  # Force overwrite existing files
  ./install.sh --force

  # Deploy to custom location
  ./install.sh --path /path/to/project

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
    deploy_templates
    print_summary
}

# Run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
