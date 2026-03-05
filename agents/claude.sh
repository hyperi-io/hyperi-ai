#!/usr/bin/env bash
# Project:   HyperI AI
# File:      agents/claude.sh
# Purpose:   Setup Claude Code configuration for a project
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# Usage: ./agents/claude.sh [--help] [--dry-run] [--force] [--no-managed] [--path PATH] [--verbose]
#
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agents/common.sh disable=SC1091
source "${SCRIPT_DIR}/common.sh"

# Global variables
DRY_RUN=false
FORCE=false
VERBOSE=false
NO_MANAGED=false
AI_ROOT=""
PROJECT_ROOT=""

# CLI command for this agent
AGENT_CLI="claude"
AGENT_NAME="Claude Code"

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

# Check if Claude CLI is installed
check_agent_cli() {
    if ! agent_installed "$AGENT_CLI"; then
        agent_log_info "${AGENT_NAME} CLI '${AGENT_CLI}' not installed (skipping)"
        exit "$EXIT_NOT_INSTALLED"
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
        exit "$EXIT_ERROR"
    fi

    if [ "$VERBOSE" = "true" ]; then
        agent_log_info "Prerequisites check passed"
    fi
}

# Create .claude directory structure
setup_claude_dir() {
    local claude_dir="$PROJECT_ROOT/.claude"
    local commands_dir="$claude_dir/commands"
    local rules_dir="$claude_dir/rules"
    local skills_dir="$claude_dir/skills"
    local memory_dir="$claude_dir/memory"

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would create: $claude_dir/"
        echo "Would create: $commands_dir/"
        echo "Would create: $rules_dir/"
        echo "Would create: $skills_dir/"
        echo "Would create: $memory_dir/"
        return 0
    fi

    mkdir -p "$commands_dir"
    mkdir -p "$rules_dir"
    mkdir -p "$skills_dir"
    mkdir -p "$memory_dir"

    if [ "$VERBOSE" = "true" ]; then
        agent_log_info "Created: $claude_dir/"
        agent_log_info "Created: $commands_dir/"
        agent_log_info "Created: $rules_dir/"
        agent_log_info "Created: $skills_dir/"
        agent_log_info "Created: $memory_dir/"
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
        agent_log_error "Template not found: $src"
        exit "$EXIT_ERROR"
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
        agent_log_success "Symlinked: $dst -> $rel_path"
    else
        agent_log_info "Skipped (preserving existing): $dst"
        if [ "$VERBOSE" = "true" ]; then
            agent_log_info "  Use --force to overwrite with symlink"
        fi
    fi
}

# Deploy slash commands as symlinks (preserve existing unless --force)
deploy_commands() {
    local src_dir="$AI_ROOT/templates/claude-code/commands"
    local dst_dir="$PROJECT_ROOT/.claude/commands"

    if [ ! -d "$src_dir" ]; then
        agent_log_error "Commands directory not found: $src_dir"
        exit "$EXIT_ERROR"
    fi

    # Commands to deploy (add new commands here)
    local commands="load save review simplify standards"

    if [ "$DRY_RUN" = "true" ]; then
        for cmd in $commands; do
            echo "Would symlink: $dst_dir/${cmd}.md -> .../${cmd}.md"
        done
        [ -e "$dst_dir/start.md" ] && echo "Would remove: $dst_dir/start.md (deprecated)"
        return 0
    fi

    for cmd in $commands; do
        local src="$src_dir/${cmd}.md"
        local dst="$dst_dir/${cmd}.md"
        local rel
        rel="$(relative_path "$dst_dir" "$src")"

        # Commands are always re-deployed — versioned and must stay current
        [ -e "$dst" ] || [ -L "$dst" ] && rm -f "$dst"
        ln -s "$rel" "$dst"
        agent_log_success "Symlinked: $dst -> $rel"
    done

    # Remove deprecated start.md if it exists
    if [ -e "$dst_dir/start.md" ]; then
        rm -f "$dst_dir/start.md"
        agent_log_info "Removed: $dst_dir/start.md (deprecated, replaced by load.md)"
    fi
}

# Deploy rules (compact standards as Claude Code rules)
# Rules are path-scoped and auto-injected when editing matching files.
# They survive context compaction — unlike skills or /load content.
# Source: ai/standards/rules/*.md (generated by tools/compact-standards.py)
deploy_rules() {
    local rules_src="$AI_ROOT/standards/rules"
    local rules_dst="$PROJECT_ROOT/.claude/rules"

    if [ ! -d "$rules_src" ]; then
        agent_log_info "Skipped rules: $rules_src not found (run tools/compact-standards.py)"
        return 0
    fi

    if [ "$DRY_RUN" != "true" ]; then
        mkdir -p "$rules_dst"
    fi
    agent_log_info "Deploying rules (compact standards for context persistence)..."

    local count=0
    for src_file in "$rules_src"/*.md; do
        [ -f "$src_file" ] || continue
        local name
        name="$(basename "$src_file")"
        local dst_file="$rules_dst/$name"
        local rel
        rel="$(relative_path "$rules_dst" "$src_file")"

        if [ "$DRY_RUN" = "true" ]; then
            if [ ! -e "$dst_file" ] || [ "$FORCE" = "true" ]; then
                echo "Would symlink rule: $dst_file -> $rel"
            else
                echo "Would skip rule (exists): $dst_file"
            fi
            count=$((count + 1))
            continue
        fi

        if [ ! -e "$dst_file" ] || [ "$FORCE" = "true" ]; then
            [ -e "$dst_file" ] || [ -L "$dst_file" ] && rm -f "$dst_file"
            ln -s "$rel" "$dst_file"
            count=$((count + 1))
        fi
    done

    if [ "$DRY_RUN" != "true" ]; then
        agent_log_success "Deployed $count rule files to $rules_dst/"
    fi

    # Also deploy user standards if present
    local user_standards="${XDG_CONFIG_HOME:-$HOME/.config}/ai/USER-CODING-STANDARDS.md"
    if [ -f "$user_standards" ]; then
        local dst_file="$rules_dst/user-standards.md"
        local rel
        rel="$(relative_path "$rules_dst" "$user_standards")"
        if [ "$DRY_RUN" = "true" ]; then
            echo "Would symlink user standards: $dst_file -> $rel"
        elif [ ! -e "$dst_file" ] || [ "$FORCE" = "true" ]; then
            [ -e "$dst_file" ] || [ -L "$dst_file" ] && rm -f "$dst_file"
            ln -s "$rel" "$dst_file"
            agent_log_success "Deployed user standards: $user_standards"
        fi
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
            if [ "$VERBOSE" = "true" ]; then
                agent_log_info "Skill source not found: $src_file"
            fi
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
            if [ "$VERBOSE" = "true" ]; then
                agent_log_info "Created skill: $name/ with SKILL.md -> $rel_path"
            fi
        fi
    }

    agent_log_info "Deploying skills..."

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

    # C++
    if [ -f "$PROJECT_ROOT/CMakeLists.txt" ] || \
       find "$PROJECT_ROOT" -maxdepth 1 \( -name "*.cpp" -o -name "*.hpp" -o -name "*.cc" -o -name "*.h" \) -type f 2>/dev/null | grep -q .; then
        create_skill "cpp" "$standards_dir/languages/CPP.md"
        echo "  Detected: C++"
    fi

    # Bash (check for .sh files in root, excluding submodules)
    if find "$PROJECT_ROOT" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | grep -q .; then
        create_skill "bash" "$standards_dir/languages/BASH.md"
        echo "  Detected: Bash"
    fi

    # ClickHouse SQL
    if [ -f "$PROJECT_ROOT/clickhouse-server.xml" ] || \
       [ -f "$PROJECT_ROOT/clickhouse-client.xml" ] || \
       [ -f "$PROJECT_ROOT/config/clickhouse-server.xml" ] || \
       (find "$PROJECT_ROOT" -maxdepth 2 -name "*.sql" -type f -print0 2>/dev/null | \
        xargs -0 grep -l 'ENGINE.*MergeTree' 2>/dev/null | grep -q .); then
        create_skill "clickhouse-sql" "$standards_dir/languages/SQL-CLICKHOUSE.md"
        echo "  Detected: ClickHouse SQL"
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

    # PKI/TLS (detect certs dir, ssl configs, or TLS-related files)
    if [ -d "$PROJECT_ROOT/certs" ] || [ -d "$PROJECT_ROOT/ssl" ] || \
       [ -d "$PROJECT_ROOT/pki" ] || [ -d "$PROJECT_ROOT/tls" ] || \
       find "$PROJECT_ROOT" -maxdepth 2 \( -name "*.crt" -o -name "*.pem" -o -name "*.key" -o -name "ssl*.xml" -o -name "*-tls.yaml" \) -type f 2>/dev/null | grep -q .; then
        create_skill "pki" "$standards_dir/common/PKI.md"
        echo "  Detected: PKI/TLS"
    fi
}

# Install managed-settings.json to /etc/claude-code/ (requires sudo)
# This provides system-wide corporate defaults for Claude Code
install_managed_settings() {
    if [ "$NO_MANAGED" = "true" ]; then
        if [ "$VERBOSE" = "true" ]; then
            agent_log_info "Skipped: managed-settings.json (--no-managed)"
        fi
        return 0
    fi

    local src="$AI_ROOT/templates/claude-code/managed-settings.json"
    local dst_dir="/etc/claude-code"
    local dst="$dst_dir/managed-settings.json"

    if [ ! -f "$src" ]; then
        if [ "$VERBOSE" = "true" ]; then
            agent_log_info "Skipped: managed-settings.json template not found"
        fi
        return 0
    fi

    # Check if already installed and matches
    if [ -f "$dst" ]; then
        if cmp -s "$src" "$dst" 2>/dev/null; then
            agent_log_info "Managed settings already installed: $dst"
            return 0
        elif [ "$FORCE" != "true" ]; then
            agent_log_info "Skipped: $dst exists (use --force to update)"
            return 0
        fi
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo "Would install: $dst (requires sudo)"
        return 0
    fi

    # Check if we can use sudo
    if ! command -v sudo >/dev/null 2>&1; then
        agent_log_info "Skipped: managed-settings.json (sudo not available)"
        if [ "$VERBOSE" = "true" ]; then
            agent_log_info "  To install manually: sudo mkdir -p $dst_dir && sudo cp $src $dst"
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
        agent_log_success "Installed: $dst"
    else
        agent_log_warn "Failed to install managed-settings.json"
        agent_log_info "  To install manually: sudo mkdir -p $dst_dir && sudo cp $src $dst"
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
    echo "Claude Code Setup Summary"
    echo "================================"
    echo "AI Root: $AI_ROOT"
    echo "Project Root: $PROJECT_ROOT"

    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        echo "DRY RUN - No files were modified"
    else
        echo ""
        agent_log_success "Claude Code setup complete!"
        echo ""
        echo "Configuration (symlinked to ai/templates/claude-code/):"
        echo "  .claude/settings.json     -> settings.json"
        echo "  .claude/commands/load.md      -> commands/load.md"
        echo "  .claude/commands/save.md      -> commands/save.md"
        echo "  .claude/commands/review.md    -> commands/review.md"
        echo "  .claude/commands/simplify.md  -> commands/simplify.md"
        echo "  .claude/commands/standards.md -> commands/standards.md"
        echo "  .claude/rules/            -> rules/ (path-scoped, auto-inject on file read)"
        echo "  .claude/skills/           -> skills/ (full standards, on-demand for /review /simplify)"
        echo "  CLAUDE.md -> STATE.md"
        echo ""
        echo "Hooks (run from ai/hooks/ via settings.json):"
        echo "  SessionStart(startup) -> inject-standards.sh (auto-detect + inject)"
        echo "  SessionStart(compact) -> on-compact.sh (re-inject + git state)"
        echo ""
        echo "Next steps:"
        echo "  1. Open project in Claude Code — standards inject automatically"
        echo "  2. Run /load to load project state (TODO, STATE, git sync)"
        echo "  3. Rules also auto-inject when reading matching files (RAG)"
        echo "  4. Skills loaded on-demand for /review and /simplify"
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
  - Requires Claude Code CLI to be installed
  - Requires STATE.md (run attach.sh first)
  - Creates symlinks to templates (not copies)
  - Preserves ALL existing files by default (use --force to replace)
  - Creates CLAUDE.md -> STATE.md symlink
  - Deploys skills based on detected languages/infrastructure
  - Installs managed-settings.json to /etc/claude-code/ (requires sudo)
    Use --no-managed to skip this step

Examples:
  # Basic usage (setup in parent directory)
  ./agents/claude.sh

  # Preview changes without modifying files
  ./agents/claude.sh --dry-run

  # Force overwrite settings
  ./agents/claude.sh --force

  # Setup for custom project
  ./agents/claude.sh --path /path/to/project

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
                    agent_log_error "--path requires an argument"
                    exit "$EXIT_ERROR"
                fi
                PROJECT_ROOT="$2"
                shift 2
                ;;
            *)
                agent_log_error "Unknown option: $1"
                echo "Try '$0 --help' for more information"
                exit "$EXIT_ERROR"
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    # Check if project root exists
    if [ ! -d "$PROJECT_ROOT" ]; then
        agent_log_error "Project directory does not exist: $PROJECT_ROOT"
        exit "$EXIT_ERROR"
    fi

    # Check if project root is writable
    if [ ! -w "$PROJECT_ROOT" ]; then
        agent_log_error "Project directory is not writable: $PROJECT_ROOT"
        exit "$EXIT_ERROR"
    fi
}

# Main execution
main() {
    parse_args "$@"
    detect_paths
    check_agent_cli
    validate_environment
    check_prerequisites
    setup_claude_dir
    deploy_settings
    deploy_commands
    deploy_rules
    deploy_skills
    create_symlink
    install_managed_settings
    print_summary
}

# Run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
