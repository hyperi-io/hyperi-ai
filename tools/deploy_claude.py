#!/usr/bin/env python3
"""Deploy Claude Code configuration for a project.

Handles: directory setup, settings/commands/rules/skills symlinks,
MCP config deployment, managed-settings installation, superpowers
plugin installation, version stamps, and summary output.

Called by agents/claude.sh (thin bash wrapper).
"""
# Project:   HyperI AI
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED

import argparse
import filecmp
import glob
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


# Exit codes (must match agents/common.sh)
EXIT_SUCCESS = 0
EXIT_ERROR = 1
EXIT_NOT_INSTALLED = 2

# ANSI colours (disabled if not a terminal)
if sys.stdout.isatty():
    _RED, _GREEN, _YELLOW, _BLUE, _NC = (
        "\033[0;31m", "\033[0;32m", "\033[0;33m", "\033[0;34m", "\033[0m",
    )
else:
    _RED = _GREEN = _YELLOW = _BLUE = _NC = ""


def log_info(msg: str) -> None:
    print(f"{_BLUE}[INFO]{_NC} {msg}")


def log_success(msg: str) -> None:
    print(f"{_GREEN}[OK]{_NC} {msg}")


def log_warn(msg: str) -> None:
    print(f"{_YELLOW}[WARN]{_NC} {msg}")


def log_error(msg: str) -> None:
    print(f"{_RED}[ERROR]{_NC} {msg}", file=sys.stderr)


# ── Path helpers ────────────────────────────────────────────────────


def relpath(from_dir: str, to_file: str) -> str:
    """Portable relative path calculation."""
    return os.path.relpath(to_file, from_dir)


def force_symlink(target: str, link: str) -> None:
    """Create symlink, removing existing file/link first."""
    p = Path(link)
    if p.exists() or p.is_symlink():
        p.unlink()
    os.symlink(target, link)


# ── Deploy functions ────────────────────────────────────────────────


def setup_claude_dir(project_root: str, dry_run: bool, verbose: bool) -> None:
    """Create .claude/ directory structure."""
    dirs = ["", "commands", "rules", "skills", "memory"]
    base = Path(project_root) / ".claude"
    for d in dirs:
        p = base / d if d else base
        if dry_run:
            print(f"Would create: {p}/")
        else:
            p.mkdir(parents=True, exist_ok=True)
            if verbose:
                log_info(f"Created: {p}/")


def deploy_settings(
    ai_root: str, project_root: str, *, dry_run: bool, force: bool, verbose: bool,
) -> None:
    """Deploy settings.json as symlink."""
    src = Path(ai_root) / "templates" / "claude-code" / "settings.json"
    dst = Path(project_root) / ".claude" / "settings.json"

    if not src.exists():
        log_error(f"Template not found: {src}")
        sys.exit(EXIT_ERROR)

    rel = relpath(str(dst.parent), str(src))

    if dry_run:
        if not dst.exists() or force:
            print(f"Would symlink: {dst} -> {rel}")
        else:
            print(f"Would skip (preserving existing): {dst}")
        return

    if not dst.exists() or force:
        force_symlink(rel, str(dst))
        log_success(f"Symlinked: {dst} -> {rel}")
    else:
        log_info(f"Skipped (preserving existing): {dst}")
        if verbose:
            log_info("  Use --force to overwrite with symlink")


def patch_self_deploy_hooks(
    project_root: str, *, dry_run: bool, verbose: bool,
) -> None:
    """Patch settings.json hook paths for self-deploy mode.

    In consumer projects, hooks live at $CLAUDE_PROJECT_DIR/hyperi-ai/hooks/.
    In self-deploy (the project IS hyperi-ai), they live at $CLAUDE_PROJECT_DIR/hooks/.
    This replaces the symlink with a patched copy.
    """
    settings_path = Path(project_root) / ".claude" / "settings.json"
    if not settings_path.exists():
        return

    if dry_run:
        print("Would patch settings.json hook paths for self-deploy")
        return

    # Resolve symlink to read the template content
    real_path = settings_path.resolve()
    with open(real_path) as f:
        content = f.read()

    patched = content.replace(
        '$CLAUDE_PROJECT_DIR/hyperi-ai/hooks/',
        '$CLAUDE_PROJECT_DIR/hooks/',
    )

    if patched == content:
        if verbose:
            log_info("Hook paths already correct for self-deploy")
        return

    # Replace symlink with patched file
    settings_path.unlink()
    with open(settings_path, "w") as f:
        f.write(patched)
    log_success("Patched settings.json hook paths for self-deploy")


def deploy_commands(
    ai_root: str, project_root: str, *, dry_run: bool, verbose: bool,
) -> None:
    """Deploy slash commands as symlinks (always re-deployed)."""
    src_dir = Path(ai_root) / "commands"
    # Backwards compat fallback
    if not src_dir.is_dir():
        src_dir = Path(ai_root) / "templates" / "claude-code" / "commands"
    if not src_dir.is_dir():
        log_error(f"Commands directory not found: {Path(ai_root) / 'commands'}")
        sys.exit(EXIT_ERROR)

    dst_dir = Path(project_root) / ".claude" / "commands"
    commands = ["load", "save", "review", "simplify", "standards", "setup-claude", "doco"]

    if dry_run:
        for cmd in commands:
            print(f"Would symlink: {dst_dir / f'{cmd}.md'} -> .../{cmd}.md")
        start = dst_dir / "start.md"
        if start.exists():
            print(f"Would remove: {start} (deprecated)")
        return

    for cmd in commands:
        src = src_dir / f"{cmd}.md"
        dst = dst_dir / f"{cmd}.md"
        rel = relpath(str(dst_dir), str(src))

        # Auto-remediation: remove stale symlinks to old templates/ path
        if dst.is_symlink():
            target = os.readlink(str(dst))
            if "templates/claude-code/commands" in target:
                dst.unlink()
                if verbose:
                    log_info(f"Cleaned stale symlink: {dst}")

        force_symlink(rel, str(dst))
        log_success(f"Symlinked: {dst} -> {rel}")

    # Remove deprecated start.md
    start = dst_dir / "start.md"
    if start.exists():
        start.unlink()
        log_info("Removed: start.md (deprecated, replaced by load.md)")


def deploy_rules(
    ai_root: str, project_root: str, *, dry_run: bool, force: bool, verbose: bool,
) -> None:
    """Deploy rules as symlinks."""
    rules_src = Path(ai_root) / "standards" / "rules"
    rules_dst = Path(project_root) / ".claude" / "rules"

    if not rules_src.is_dir():
        log_info(f"Skipped rules: {rules_src} not found")
        return

    if not dry_run:
        rules_dst.mkdir(parents=True, exist_ok=True)
    log_info("Deploying rules (compact standards for context persistence)...")

    count = 0
    for src_file in sorted(rules_src.glob("*.md")):
        dst_file = rules_dst / src_file.name
        rel = relpath(str(rules_dst), str(src_file))

        if dry_run:
            if not dst_file.exists() or force:
                print(f"Would symlink rule: {dst_file} -> {rel}")
            else:
                print(f"Would skip rule (exists): {dst_file}")
            count += 1
            continue

        if not dst_file.exists() or force:
            force_symlink(rel, str(dst_file))
            count += 1

    if not dry_run:
        log_success(f"Deployed {count} rule files to {rules_dst}/")

    # Clean up migrated methodology rules
    migrated = ["debugging", "verification", "testing", "parallel-agents", "documentation"]
    for name in migrated:
        old = rules_dst / f"{name}.md"
        if old.exists() or old.is_symlink():
            if dry_run:
                print(f"Would remove migrated rule: {old} (now a skill)")
            else:
                old.unlink()
                if verbose:
                    log_info(f"Cleaned migrated rule: {old}")

    # User standards
    xdg = os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
    user_std = Path(xdg) / "hyperi-ai" / "USER-CODING-STANDARDS.md"
    if user_std.is_file():
        dst_file = rules_dst / "user-standards.md"
        rel = relpath(str(rules_dst), str(user_std))
        if dry_run:
            print(f"Would symlink user standards: {dst_file} -> {rel}")
        elif not dst_file.exists() or force:
            force_symlink(rel, str(dst_file))
            log_success(f"Deployed user standards: {user_std}")


def _detect_tech(project_root: str) -> list[tuple[str, str, str]]:
    """Detect project technologies. Returns [(name, skill_name, source_path)]."""
    p = Path(project_root)
    found: list[tuple[str, str, str]] = []

    # Languages
    if any((p / f).exists() for f in ("pyproject.toml", "setup.py", "requirements.txt", "uv.lock")):
        found.append(("Python", "python", "languages/PYTHON.md"))
    if (p / "go.mod").exists():
        found.append(("Go", "golang", "languages/GOLANG.md"))
    if any((p / f).exists() for f in ("tsconfig.json", "package.json")):
        found.append(("TypeScript", "typescript", "languages/TYPESCRIPT.md"))
    if (p / "Cargo.toml").exists():
        found.append(("Rust", "rust", "languages/RUST.md"))
    if (p / "CMakeLists.txt").exists() or any(p.glob("*.cpp")) or any(p.glob("*.hpp")):
        found.append(("C++", "cpp", "languages/CPP.md"))
    if any(p.glob("*.sh")):
        found.append(("Bash", "bash", "languages/BASH.md"))
    # ClickHouse
    ch_markers = ["clickhouse-server.xml", "clickhouse-client.xml", "config/clickhouse-server.xml"]
    if any((p / m).exists() for m in ch_markers):
        found.append(("ClickHouse SQL", "clickhouse-sql", "languages/SQL-CLICKHOUSE.md"))

    # Infrastructure
    if any((p / f).exists() for f in ("Dockerfile", "docker-compose.yaml", "docker-compose.yml")):
        found.append(("Docker", "docker", "infrastructure/DOCKER.md"))
    if any((p / f).exists() for f in ("Chart.yaml", "values.yaml")) or (p / "charts").is_dir():
        found.append(("Kubernetes", "k8s", "infrastructure/K8S.md"))
    if any(p.glob("*.tf")):
        found.append(("Terraform", "terraform", "infrastructure/TERRAFORM.md"))
    if any((p / f).exists() for f in ("ansible.cfg", "playbook.yml")) or (p / "playbooks").is_dir():
        found.append(("Ansible", "ansible", "infrastructure/ANSIBLE.md"))
    # PKI
    pki_dirs = ["certs", "ssl", "pki", "tls"]
    if any((p / d).is_dir() for d in pki_dirs):
        found.append(("PKI/TLS", "pki", "common/PKI.md"))

    return found


def _create_skill(
    name: str, src_file: str, skills_dir: str,
    *, dry_run: bool, force: bool, verbose: bool,
) -> bool:
    """Create a skill directory with SKILL.md symlinked to source. Returns True if created."""
    if not Path(src_file).is_file():
        if verbose:
            log_info(f"Skill source not found: {src_file}")
        return False

    skill_dir = Path(skills_dir) / name
    skill_md = skill_dir / "SKILL.md"
    rel = relpath(str(skill_dir), src_file)

    if dry_run:
        if not skill_dir.exists() or force:
            print(f"Would create skill: {name}/ with SKILL.md -> {rel}")
        else:
            print(f"Would skip skill (exists): {name}/")
        return True

    if not skill_dir.exists() or force:
        if skill_dir.exists():
            shutil.rmtree(str(skill_dir))
        skill_dir.mkdir(parents=True)
        os.symlink(rel, str(skill_md))
        if verbose:
            log_info(f"Created skill: {name}/ with SKILL.md -> {rel}")
    return True


def deploy_skills(
    ai_root: str, project_root: str, *, dry_run: bool, force: bool, verbose: bool,
) -> None:
    """Deploy skills (standards + detected tech + methodology)."""
    skills_dir = str(Path(project_root) / ".claude" / "skills")
    standards_dir = Path(ai_root) / "standards"

    log_info("Deploying skills...")

    # Core skills
    _create_skill("standards", str(standards_dir / "STANDARDS.md"), skills_dir,
                   dry_run=dry_run, force=force, verbose=verbose)
    _create_skill("ai-guidelines", str(standards_dir / "code-assistant" / "AI-GUIDELINES.md"),
                   skills_dir, dry_run=dry_run, force=force, verbose=verbose)
    _create_skill("ai-common", str(standards_dir / "code-assistant" / "COMMON.md"),
                   skills_dir, dry_run=dry_run, force=force, verbose=verbose)
    print("  Core: standards, ai-guidelines, ai-common")

    # Detected tech skills
    for display, skill_name, std_path in _detect_tech(project_root):
        src = str(standards_dir / std_path)
        if _create_skill(skill_name, src, skills_dir, dry_run=dry_run, force=force, verbose=verbose):
            print(f"  Detected: {display}")

    # Methodology skills (from skills/ directory)
    methodology_dir = Path(ai_root) / "skills"
    if methodology_dir.is_dir():
        names = []
        for skill_src_dir in sorted(methodology_dir.iterdir()):
            if not skill_src_dir.is_dir():
                continue
            src_file = skill_src_dir / "SKILL.md"
            if not src_file.is_file():
                continue
            _create_skill(skill_src_dir.name, str(src_file), skills_dir,
                          dry_run=dry_run, force=force, verbose=verbose)
            names.append(skill_src_dir.name)
        if names:
            print(f"  Methodology: {' '.join(names)}")


def deploy_mcp(
    ai_root: str, project_root: str, *, dry_run: bool, force: bool, verbose: bool,
) -> None:
    """Deploy MCP server configuration."""
    src = Path(ai_root) / ".mcp.json"
    dst = Path(project_root) / ".mcp.json"

    if not src.exists():
        if verbose:
            log_info(f"Skipped MCP: {src} not found")
        return

    # Self-deploy: src == dst
    if src.resolve() == dst.resolve():
        if verbose:
            log_info("Skipped MCP: already at project root (self-deploy)")
        return

    if dry_run:
        if not dst.exists():
            print(f"Would copy MCP config: {dst}")
        elif dst.is_symlink():
            print(f"Would replace MCP symlink with merged config: {dst}")
        else:
            print(f"Would merge MCP servers into existing: {dst}")
        return

    if not dst.exists():
        shutil.copy2(str(src), str(dst))
        log_success(f"Deployed MCP config: {dst}")
    elif dst.is_symlink():
        dst.unlink()
        shutil.copy2(str(src), str(dst))
        log_success(f"Replaced MCP symlink with config: {dst}")
    else:
        merge_script = Path(ai_root) / "tools" / "merge_mcp.py"
        cmd = [sys.executable, str(merge_script), str(src), str(dst)]
        if force:
            cmd.append("--force")
        if subprocess.run(cmd, capture_output=True).returncode == 0:
            log_success(f"Merged MCP servers into: {dst}")
        else:
            log_warn(f"Failed to merge MCP config — copy manually from {src}")


def create_symlink(
    project_root: str, *, dry_run: bool, self_mode: bool, verbose: bool,
) -> None:
    """Create CLAUDE.md -> STATE.md symlink."""
    if self_mode:
        if verbose:
            log_info("Skipped: CLAUDE.md symlink (self-deploy)")
        return

    link = Path(project_root) / "CLAUDE.md"

    if dry_run:
        if link.is_symlink():
            print(f"Would skip (exists): {link} -> {os.readlink(str(link))}")
        else:
            print(f"Would create: {link} -> STATE.md")
        return

    if link.is_symlink():
        log_info(f"Skipped (exists): {link} -> {os.readlink(str(link))}")
    elif link.is_file():
        log_warn(f"{link} exists as a regular file")
        log_info("  Delete it manually to create symlink, or use --force")
    else:
        os.symlink("STATE.md", str(link))
        log_success(f"Created: {link} -> STATE.md")


def install_managed_settings(
    ai_root: str, *, dry_run: bool, force: bool, no_managed: bool, verbose: bool,
) -> None:
    """Install managed-settings.json to /etc/claude-code/ (requires sudo)."""
    if no_managed:
        if verbose:
            log_info("Skipped: managed-settings.json (--no-managed)")
        return

    src = Path(ai_root) / "templates" / "claude-code" / "managed-settings.json"
    dst = Path("/etc/claude-code/managed-settings.json")

    if not src.exists():
        if verbose:
            log_info("Skipped: managed-settings.json template not found")
        return

    if dst.exists():
        if filecmp.cmp(str(src), str(dst), shallow=False):
            log_info(f"Managed settings already installed: {dst}")
            return
        if not force:
            log_info(f"Skipped: {dst} exists (use --force to update)")
            return

    if dry_run:
        print(f"Would install: {dst} (requires sudo)")
        return

    if not shutil.which("sudo"):
        log_info("Skipped: managed-settings.json (sudo not available)")
        if verbose:
            log_info(f"  To install manually: sudo mkdir -p {dst.parent} && sudo cp {src} {dst}")
        return

    print()
    print("Installing organisation-wide Claude Code settings...")
    print(f"  Source: {src}")
    print(f"  Destination: {dst}")
    print()
    print("This configures Claude Code defaults for all projects on this machine:")
    print("  - Disables telemetry and error reporting")
    print("  - Removes co-authored-by attribution from commits")
    print("  - Requires confirmation for reading sensitive files")
    print()
    print("You may be prompted for your password (sudo required).")
    print()

    try:
        subprocess.run(["sudo", "mkdir", "-p", str(dst.parent)], check=True)
        subprocess.run(["sudo", "cp", str(src), str(dst)], check=True)
        subprocess.run(["sudo", "chmod", "644", str(dst)], check=True)
        log_success(f"Installed: {dst}")
    except subprocess.CalledProcessError:
        log_warn("Failed to install managed-settings.json")
        log_info(f"  To install manually: sudo mkdir -p {dst.parent} && sudo cp {src} {dst}")


def install_superpowers(
    agent_cli: str, *, dry_run: bool, no_superpowers: bool, verbose: bool,
) -> None:
    """Install superpowers plugin for methodology skills."""
    if no_superpowers:
        if verbose:
            log_info("Skipped: superpowers plugin (--no-superpowers)")
        return

    # Check if CLI supports plugins
    try:
        subprocess.run([agent_cli, "plugin", "list"], capture_output=True, timeout=10)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        if verbose:
            log_info("Skipped: superpowers (plugin support not available)")
        return

    # Check if already installed
    result = subprocess.run([agent_cli, "plugin", "list"], capture_output=True, text=True, timeout=10)
    if "superpowers" in (result.stdout + result.stderr):
        if verbose:
            log_info("Superpowers plugin already installed")
        return

    if dry_run:
        print("Would install: superpowers plugin (methodology skills)")
        print("  marketplace: obra/superpowers-marketplace")
        print("  scope: user")
        return

    log_info("Installing superpowers plugin (methodology: debugging, TDD, planning)...")

    # Add marketplace
    mp_result = subprocess.run(
        [agent_cli, "plugin", "marketplace", "list"], capture_output=True, text=True, timeout=10,
    )
    if "superpowers-marketplace" not in (mp_result.stdout + mp_result.stderr):
        r = subprocess.run(
            [agent_cli, "plugin", "marketplace", "add", "obra/superpowers-marketplace"],
            capture_output=True, timeout=30,
        )
        if r.returncode == 0:
            log_success("Added marketplace: superpowers-marketplace")
        else:
            log_warn("Failed to add superpowers marketplace")
            log_info("  Manual install: claude plugin marketplace add obra/superpowers-marketplace")
            return

    # Install plugin
    r = subprocess.run(
        [agent_cli, "plugin", "install", "superpowers@superpowers-marketplace", "--scope", "user"],
        capture_output=True, timeout=60,
    )
    if r.returncode == 0:
        log_success("Installed: superpowers plugin (restart Claude Code to activate)")
    else:
        log_warn("Failed to install superpowers plugin")
        log_info("  Manual install: claude plugin install superpowers@superpowers-marketplace")


def write_version_stamp(ai_root: str, project_root: str, *, dry_run: bool, verbose: bool) -> None:
    """Write version stamp for auto-reattach detection."""
    if dry_run:
        print(f"Would write: {project_root}/.claude/.ai-version")
        return

    ai_git = Path(ai_root) / ".git"
    if not (ai_git.is_dir() or ai_git.is_file()):
        return
    if not shutil.which("git"):
        return

    try:
        result = subprocess.run(
            ["git", "-C", ai_root, "rev-parse", "HEAD"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            version = result.stdout.strip()
            Path(project_root, ".claude", ".ai-version").write_text(version)
            if verbose:
                log_info(f"Version stamp: {version}")
    except (subprocess.TimeoutExpired, OSError):
        pass


def print_summary(
    ai_root: str, project_root: str, agent_cli: str,
    *, dry_run: bool,
) -> None:
    """Print setup summary."""
    print()
    print("================================")
    print("Claude Code Setup Summary")
    print("================================")
    print(f"AI Root: {ai_root}")
    print(f"Project Root: {project_root}")

    if dry_run:
        print()
        print("DRY RUN - No files were modified")
    else:
        print()
        log_success("Claude Code setup complete!")
        print()
        print("Configuration (symlinked to ai/templates/claude-code/):")
        print("  .claude/settings.json     -> settings.json")
        for cmd in ("load", "save", "review", "simplify", "standards", "setup-claude"):
            print(f"  .claude/commands/{cmd}.md")
        print("  .claude/rules/            -> rules/ (path-scoped, auto-inject on file read)")
        print("  .claude/skills/           -> skills/ (full standards, on-demand for /review /simplify)")
        print("  CLAUDE.md -> STATE.md")
        print("  .mcp.json                 -> MCP servers (Context7 live docs)")
        print()
        print("Plugins:")
        try:
            r = subprocess.run(
                [agent_cli, "plugin", "list"], capture_output=True, text=True, timeout=10,
            )
            if "superpowers" in (r.stdout + r.stderr):
                print("  superpowers               -> methodology (debugging, TDD, planning, worktrees)")
            else:
                print("  superpowers               -> NOT INSTALLED (run: claude plugin install superpowers@superpowers-marketplace)")
        except (FileNotFoundError, subprocess.TimeoutExpired):
            print("  superpowers               -> UNKNOWN (CLI unavailable)")
        print()
        print("Hooks (run from ai/hooks/ via settings.json):")
        print("  SessionStart(startup) -> inject_standards.py (auto-detect + inject + reattach)")
        print("  SessionStart(compact) -> on_compact.py (re-inject standards)")
        print("  PostToolUse(Edit|Write) -> auto_format.py (run formatter on edited files)")
        print("  SubagentStart          -> subagent_context.py (inject standards into subagents)")
        print("  PreToolUse(Bash)       -> safety_guard.py (block dangerous commands)")
        print("  Stop                   -> lint_check.py (lint modified files, feed errors back)")
        print()
        print("Next steps:")
        print("  1. Open project in Claude Code — standards + efficiency rules inject automatically")
        print("  2. Run /setup-claude to configure .tmp/ workspace, survey tools, update permissions")
        print("  3. Run /load to load project state (TODO, STATE, git sync)")
        print("  4. Rules auto-inject on file read (RAG) and survive compacts")
    print("================================")


# ── Main ────────────────────────────────────────────────────────────


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="agents/claude.sh",
        description="Deploy Claude Code configuration",
    )
    p.add_argument("--ai-root", required=True, help=argparse.SUPPRESS)
    p.add_argument("--project-root", "--path", default="",
                    help="Path to consumer project (default: parent of ai/)")
    p.add_argument("--agent-cli", default="claude", help=argparse.SUPPRESS)
    p.add_argument("--dry-run", action="store_true",
                    help="Show what would be done without making changes")
    p.add_argument("--force", action="store_true",
                    help="Remove existing files and replace with symlinks")
    p.add_argument("--verbose", action="store_true", help="Enable verbose output")
    p.add_argument("--self", dest="self_mode", action="store_true",
                    help="Self-deploy: dogfood hyperi-ai onto itself")
    p.add_argument("--no-managed", action="store_true",
                    help="Skip system-wide managed-settings.json installation")
    p.add_argument("--no-superpowers", action="store_true",
                    help="Skip superpowers plugin installation")
    return p.parse_args()


def main() -> int:
    args = parse_args()

    ai_root = os.path.abspath(args.ai_root)
    if args.self_mode:
        project_root = ai_root
    elif args.project_root:
        project_root = os.path.abspath(args.project_root)
    else:
        project_root = os.path.dirname(ai_root)

    if args.verbose:
        log_info(f"AI_ROOT: {ai_root}")
        log_info(f"PROJECT_ROOT: {project_root}")
        if args.self_mode:
            log_info("Mode: self-deploy (dogfooding)")

    # Validate
    if not os.path.isdir(project_root):
        log_error(f"Project directory does not exist: {project_root}")
        return EXIT_ERROR
    if not os.access(project_root, os.W_OK):
        log_error(f"Project directory is not writable: {project_root}")
        return EXIT_ERROR

    # Prerequisites
    if not args.self_mode:
        state = Path(project_root) / "STATE.md"
        if not state.exists():
            log_error("STATE.md not found in project root")
            log_info("Run attach.sh first: ./hyperi-ai/attach.sh")
            return EXIT_ERROR
    elif args.verbose:
        log_info("Prerequisites: self-deploy mode (STATE.md not required)")

    # Deploy
    setup_claude_dir(project_root, args.dry_run, args.verbose)
    deploy_settings(ai_root, project_root, dry_run=args.dry_run, force=args.force, verbose=args.verbose)
    if args.self_mode:
        patch_self_deploy_hooks(project_root, dry_run=args.dry_run, verbose=args.verbose)
    deploy_commands(ai_root, project_root, dry_run=args.dry_run, verbose=args.verbose)
    deploy_rules(ai_root, project_root, dry_run=args.dry_run, force=args.force, verbose=args.verbose)
    deploy_skills(ai_root, project_root, dry_run=args.dry_run, force=args.force, verbose=args.verbose)
    deploy_mcp(ai_root, project_root, dry_run=args.dry_run, force=args.force, verbose=args.verbose)
    create_symlink(project_root, dry_run=args.dry_run, self_mode=args.self_mode, verbose=args.verbose)
    install_managed_settings(ai_root, dry_run=args.dry_run, force=args.force,
                              no_managed=args.no_managed, verbose=args.verbose)
    install_superpowers(args.agent_cli, dry_run=args.dry_run,
                         no_superpowers=args.no_superpowers, verbose=args.verbose)
    write_version_stamp(ai_root, project_root, dry_run=args.dry_run, verbose=args.verbose)
    print_summary(ai_root, project_root, args.agent_cli, dry_run=args.dry_run)

    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
