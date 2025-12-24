#!/usr/bin/env bash
# Project:      HyperSec AI
# File:         claude.sh
# Purpose:      Setup Claude Code configuration for a project
# License:      LicenseRef-HyperSec-EULA
# Copyright:    (c) 2025 HyperSec Pty Ltd
#
# Usage: ./claude.sh [--help] [--dry-run] [--force] [--no-managed] [--path PATH] [--verbose]
#
set -euo pipefail

# Global variables
DRY_RUN=false
FORCE=false
VERBOSE=false
NO_MANAGED=false
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
        echo "Please run attach.sh first:"
        echo "  ./ai/attach.sh"
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
    local skills_dir="$claude_dir/skills"

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would create: $claude_dir/"
        echo "Would create: $commands_dir/"
        echo "Would create: $skills_dir/"
        return 0
    fi

    mkdir -p "$commands_dir"
    mkdir -p "$skills_dir"

    if [ "$VERBOSE" = "true" ]; then
        echo "Created: $claude_dir/"
        echo "Created: $commands_dir/"
        echo "Created: $skills_dir/"
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

# Deploy skills (standards as Claude Code skills)
# Creates skill directories with SKILL.md that symlinks to the original standards file
# This is SSOT - the original .md files are the source of truth
# Core: STANDARDS.md + code-assistant/* (always deployed)
# Per-language: Detected from project config files
# Per-infra: Detected from project IaC files
deploy_skills() {
    local skills_dir="$PROJECT_ROOT/.claude/skills"
    local standards_dir="$AI_ROOT/standards"

    # Helper to create a skill with SKILL.md symlinked to source
    # Usage: create_skill <skill-name> <source-md-path>
    create_skill() {
        local name="$1"
        local src_file="$2"
        local skill_dir="$skills_dir/$name"
        local skill_md="$skill_dir/SKILL.md"

        if [ ! -f "$src_file" ]; then
            [ "$VERBOSE" = "true" ] && echo "Skill source not found: $src_file"
            return 0
        fi

        local rel_path
        rel_path="$(relative_path "$skill_dir" "$src_file")"

        if [ "$DRY_RUN" = "true" ]; then
            if [ ! -e "$skill_dir" ] || [ "$FORCE" = "true" ]; then
                echo "Would create skill: $name/ with SKILL.md -> $rel_path"
            else
                echo "Would skip skill (exists): $name/"
            fi
            return 0
        fi

        if [ ! -e "$skill_dir" ] || [ "$FORCE" = "true" ]; then
            [ -e "$skill_dir" ] && rm -rf "$skill_dir"
            mkdir -p "$skill_dir"
            ln -s "$rel_path" "$skill_md"
            [ "$VERBOSE" = "true" ] && echo "Created skill: $name/ with SKILL.md -> $rel_path"
        fi
    }

    echo "Deploying skills..."

    # Core skills (always deployed)
    create_skill "standards" "$standards_dir/STANDARDS.md"
    create_skill "ai-guidelines" "$standards_dir/code-assistant/AI-GUIDELINES.md"
    create_skill "ai-common" "$standards_dir/code-assistant/COMMON.md"
    echo "  Core: standards, ai-guidelines, ai-common"

    # Detect languages from project root config files
    # Python
    if [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/setup.py" ] || \
       [ -f "$PROJECT_ROOT/requirements.txt" ] || [ -f "$PROJECT_ROOT/uv.lock" ]; then
        create_skill "python" "$standards_dir/languages/PYTHON.md"
        echo "  Detected: Python"
    fi

    # Go
    if [ -f "$PROJECT_ROOT/go.mod" ]; then
        create_skill "golang" "$standards_dir/languages/GOLANG.md"
        echo "  Detected: Go"
    fi

    # TypeScript/JavaScript
    if [ -f "$PROJECT_ROOT/tsconfig.json" ] || [ -f "$PROJECT_ROOT/package.json" ]; then
        create_skill "typescript" "$standards_dir/languages/TYPESCRIPT.md"
        echo "  Detected: TypeScript"
    fi

    # Rust
    if [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
        create_skill "rust" "$standards_dir/languages/RUST.md"
        echo "  Detected: Rust"
    fi

    # Bash (check for .sh files in root, excluding submodules)
    if find "$PROJECT_ROOT" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | grep -q .; then
        create_skill "bash" "$standards_dir/languages/BASH.md"
        echo "  Detected: Bash"
    fi

    # Detect infrastructure
    # Docker
    if [ -f "$PROJECT_ROOT/Dockerfile" ] || [ -f "$PROJECT_ROOT/docker-compose.yaml" ] || \
       [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        create_skill "docker" "$standards_dir/infrastructure/DOCKER.md"
        echo "  Detected: Docker"
    fi

    # Kubernetes/Helm
    if [ -f "$PROJECT_ROOT/Chart.yaml" ] || [ -d "$PROJECT_ROOT/charts" ] || \
       [ -f "$PROJECT_ROOT/values.yaml" ]; then
        create_skill "k8s" "$standards_dir/infrastructure/K8S.md"
        echo "  Detected: Kubernetes"
    fi

    # Terraform
    if find "$PROJECT_ROOT" -maxdepth 1 -name "*.tf" -type f 2>/dev/null | grep -q .; then
        create_skill "terraform" "$standards_dir/infrastructure/TERRAFORM.md"
        echo "  Detected: Terraform"
    fi

    # Ansible
    if [ -f "$PROJECT_ROOT/ansible.cfg" ] || [ -f "$PROJECT_ROOT/playbook.yml" ] || \
       [ -d "$PROJECT_ROOT/playbooks" ]; then
        create_skill "ansible" "$standards_dir/infrastructure/ANSIBLE.md"
        echo "  Detected: Ansible"
    fi
}

# Install managed-settings.json to /etc/claude-code/ (requires sudo)
# This provides system-wide corporate defaults for Claude Code
install_managed_settings() {
    if [ "$NO_MANAGED" = "true" ]; then
        if [ "$VERBOSE" = "true" ]; then
            echo "Skipped: managed-settings.json (--no-managed)"
        fi
        return 0
    fi

    local src="$AI_ROOT/templates/claude-code/managed-settings.json"
    local dst_dir="/etc/claude-code"
    local dst="$dst_dir/managed-settings.json"

    if [ ! -f "$src" ]; then
        if [ "$VERBOSE" = "true" ]; then
            echo "Skipped: managed-settings.json template not found"
        fi
        return 0
    fi

    # Check if already installed and matches
    if [ -f "$dst" ]; then
        if cmp -s "$src" "$dst" 2>/dev/null; then
            echo "Managed settings already installed: $dst"
            return 0
        elif [ "$FORCE" != "true" ]; then
            echo "Skipped: $dst exists (use --force to update)"
            return 0
        fi
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would install: $dst (requires sudo)"
        return 0
    fi

    # Check if we can use sudo
    if ! command -v sudo >/dev/null 2>&1; then
        echo "Skipped: managed-settings.json (sudo not available)"
        if [ "$VERBOSE" = "true" ]; then
            echo "  To install manually: sudo mkdir -p $dst_dir && sudo cp $src $dst"
        fi
        return 0
    fi

    # Prompt user about what we're doing
    echo ""
    echo "Installing organisation-wide Claude Code settings..."
    echo "  Source: $src"
    echo "  Destination: $dst"
    echo ""
    echo "This configures Claude Code defaults for all projects on this machine:"
    echo "  - Disables telemetry and error reporting"
    echo "  - Removes co-authored-by attribution from commits"
    echo "  - Requires confirmation for reading sensitive files"
    echo ""
    echo "You may be prompted for your password (sudo required)."
    echo ""

    # Try to install with sudo
    if sudo mkdir -p "$dst_dir" && sudo cp "$src" "$dst" && sudo chmod 644 "$dst"; then
        echo "Installed: $dst"
    else
        echo "WARNING: Failed to install managed-settings.json"
        echo "  To install manually: sudo mkdir -p $dst_dir && sudo cp $src $dst"
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
        echo "  .claude/skills/           -> skills/ (auto-detected)"
        echo "  CLAUDE.md -> STATE.md"
        echo ""
        echo "Next steps:"
        echo "  1. Open project in Claude Code"
        echo "  2. Run /load to initialize session"
        echo "  3. Skills are auto-invoked by Claude based on context"
    fi
    echo "================================"
}

# Show usage information
show_usage() {
    cat << EOF
claude.sh - Setup Claude Code configuration

Usage: $0 [OPTIONS]

Options:
  --help          Show this help message
  --dry-run       Show what would be done without making changes
  --force         Remove existing files and replace with symlinks
  --no-managed    Skip system-wide managed-settings.json installation
  --path PATH     Specify custom project root (default: parent of ai/)
  --verbose       Enable verbose output
  -h              Same as --help

Notes:
  - Requires STATE.md (run attach.sh first)
  - Creates symlinks to templates (not copies)
  - Preserves ALL existing files by default (use --force to replace)
  - Creates CLAUDE.md -> STATE.md symlink
  - Deploys skills based on detected languages/infrastructure
  - Installs managed-settings.json to /etc/claude-code/ (requires sudo)
    Use --no-managed to skip this step

Examples:
  # Basic usage (setup in parent directory)
  ./claude.sh

  # Preview changes without modifying files
  ./claude.sh --dry-run

  # Force overwrite settings
  ./claude.sh --force

  # Setup for custom project
  ./claude.sh --path /path/to/project

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
            --no-managed)
                NO_MANAGED=true
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
    deploy_skills
    create_symlink
    install_managed_settings
    print_summary
}

# Run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
