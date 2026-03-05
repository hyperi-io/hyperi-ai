#!/usr/bin/env python3
# Project:   HyperI AI
# File:      hooks/common.py
# Purpose:   Shared utilities for Claude Code hooks (Python 3 stdlib only)
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
"""Shared utilities for Claude Code hooks.

All functions use Python 3 stdlib only — no pip dependencies.
This module is the single source of truth for:
- Technology detection (replaces duplication in inject-standards.sh and common.sh)
- Rule injection (UNIVERSAL + detected tech rules)
- Hook I/O (JSON stdin/stdout for structured hook responses)
- Auto-format (file extension → formatter mapping)
- Safety guard (dangerous command pattern detection)
- Auto-reattach (version-stamped submodule update detection)
- Auto-remediation (linter mapping for modified files)
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

def get_project_dir() -> Path:
    """Return the consumer project root from $CLAUDE_PROJECT_DIR or cwd."""
    return Path(os.environ.get("CLAUDE_PROJECT_DIR", ".")).resolve()


def get_ai_dir(project_dir: Path) -> Path:
    """Return the hyperi-ai/ submodule directory within the project."""
    return project_dir / "hyperi-ai"


def get_rules_dir(project_dir: Path) -> Path:
    """Return the standards/rules/ directory."""
    return get_ai_dir(project_dir) / "standards" / "rules"


# ---------------------------------------------------------------------------
# Hook I/O
# ---------------------------------------------------------------------------

def read_hook_input() -> Dict:
    """Read JSON from stdin (hook input). Returns empty dict on error/no input."""
    try:
        data = sys.stdin.read()
        if data.strip():
            return json.loads(data)
    except (json.JSONDecodeError, OSError):
        pass
    return {}


def hook_response(
    hook_event: str,
    *,
    permission_decision: Optional[str] = None,
    decision_reason: Optional[str] = None,
    additional_context: Optional[str] = None,
) -> str:
    """Build JSON response for hooks that need structured output.

    Used by PreToolUse (permission decisions) and SubagentStart (context injection).
    """
    specific: Dict = {"hookEventName": hook_event}
    if permission_decision is not None:
        specific["permissionDecision"] = permission_decision
    if decision_reason is not None:
        specific["permissionDecisionReason"] = decision_reason
    if additional_context is not None:
        specific["additionalContext"] = additional_context
    return json.dumps({"hookSpecificOutput": specific})


# ---------------------------------------------------------------------------
# Technology detection
# ---------------------------------------------------------------------------

# (tech_name, rule_filename, list_of_marker_checks)
# Marker check types:
#   ("file", "name")       — exact file in root
#   ("dir", "name")        — exact dir in root
#   ("glob", "pattern")    — glob in root only
#   ("deep_file", "name")  — file anywhere up to 3 levels deep
#   ("deep_glob", "pat")   — glob up to 3 levels deep
#
# "deep_" variants handle monorepos, workspaces, and nested project structures
# where marker files are not in the project root (e.g., Cargo.toml in a workspace
# member, pyproject.toml in src/backend/, Dockerfile in deploy/).
TECH_DETECTIONS: List[Tuple[str, str, List[Tuple[str, str]]]] = [
    ("python", "python.md", [
        ("file", "pyproject.toml"), ("file", "setup.py"),
        ("file", "requirements.txt"), ("file", "uv.lock"),
        ("deep_file", "pyproject.toml"), ("deep_file", "setup.py"),
    ]),
    ("bash", "bash.md", [
        ("glob", "*.sh"), ("glob", "*.bats"),
        ("deep_glob", "*.sh"),
    ]),
    ("typescript", "typescript.md", [
        ("file", "tsconfig.json"), ("file", "package.json"),
        ("deep_file", "tsconfig.json"), ("deep_file", "package.json"),
    ]),
    ("rust", "rust.md", [
        ("file", "Cargo.toml"),
        ("deep_file", "Cargo.toml"),
    ]),
    ("golang", "golang.md", [
        ("file", "go.mod"),
        ("deep_file", "go.mod"),
    ]),
    ("cpp", "cpp.md", [
        ("file", "CMakeLists.txt"),
        ("deep_file", "CMakeLists.txt"),
        ("deep_glob", "*.cpp"), ("deep_glob", "*.hpp"),
        ("deep_glob", "*.cc"), ("deep_glob", "*.h"),
    ]),
    ("docker", "docker.md", [
        ("file", "Dockerfile"), ("file", "docker-compose.yml"),
        ("file", "docker-compose.yaml"),
        ("deep_file", "Dockerfile"), ("deep_file", "docker-compose.yml"),
        ("deep_file", "docker-compose.yaml"),
    ]),
    ("ansible", "ansible.md", [
        ("file", "ansible.cfg"), ("glob", "playbook*.yml"),
        ("dir", "playbooks"),
        ("deep_file", "ansible.cfg"), ("deep_glob", "playbook*.yml"),
    ]),
    ("k8s", "k8s.md", [
        ("file", "Chart.yaml"), ("file", "values.yaml"),
        ("dir", "charts"),
        ("deep_file", "Chart.yaml"), ("deep_file", "values.yaml"),
    ]),
    ("terraform", "terraform.md", [
        ("glob", "*.tf"),
        ("deep_glob", "*.tf"),
    ]),
    ("clickhouse-sql", "clickhouse-sql.md", [
        ("glob", "*.sql"),
        ("deep_glob", "*.sql"),
    ]),
    ("pki", "pki.md", [
        ("dir", "certs"), ("dir", "ssl"), ("dir", "pki"),
    ]),
]

# Directories to skip during deep scans (performance + false positive avoidance)
_SKIP_DIRS = frozenset({
    ".git", ".hg", ".svn", "node_modules", "__pycache__", ".tox", ".venv",
    "venv", ".mypy_cache", "target", "dist", "build", ".next", ".nuxt",
    ".cache", ".eggs", "vendor", "third_party", "3rdparty",
})


def _any_marker_present(project_dir: Path, markers: List[Tuple[str, str]]) -> bool:
    for kind, pattern in markers:
        if kind == "file" and (project_dir / pattern).is_file():
            return True
        if kind == "dir" and (project_dir / pattern).is_dir():
            return True
        if kind == "glob" and any(project_dir.glob(pattern)):
            return True
        if kind == "deep_file":
            if _deep_file_exists(project_dir, pattern, max_depth=3):
                return True
        if kind == "deep_glob":
            if _deep_glob_exists(project_dir, pattern, max_depth=3):
                return True
    return False


def _deep_file_exists(root: Path, filename: str, max_depth: int) -> bool:
    """Check if a file exists anywhere up to max_depth levels deep."""
    return _walk_for_match(root, filename, is_glob=False, max_depth=max_depth)


def _deep_glob_exists(root: Path, pattern: str, max_depth: int) -> bool:
    """Check if any file matching glob pattern exists up to max_depth levels deep."""
    return _walk_for_match(root, pattern, is_glob=True, max_depth=max_depth)


def _walk_for_match(root: Path, pattern: str, is_glob: bool, max_depth: int) -> bool:
    """Walk directory tree looking for a file match, with depth limit and skip dirs."""
    if max_depth < 0:
        return False

    try:
        for entry in root.iterdir():
            if entry.is_file():
                if is_glob:
                    import fnmatch
                    if fnmatch.fnmatch(entry.name, pattern):
                        return True
                elif entry.name == pattern:
                    return True
            elif entry.is_dir() and entry.name not in _SKIP_DIRS and max_depth > 0:
                if _walk_for_match(entry, pattern, is_glob, max_depth - 1):
                    return True
    except (PermissionError, OSError):
        pass

    return False


def detect_technologies(project_dir: Path) -> List[Tuple[str, str]]:
    """Detect technologies present in project_dir.

    Returns list of (tech_name, rule_filename) tuples.
    """
    detected = []
    for tech_name, rule_file, markers in TECH_DETECTIONS:
        if _any_marker_present(project_dir, markers):
            detected.append((tech_name, rule_file))
    return detected


# ---------------------------------------------------------------------------
# Rule injection
# ---------------------------------------------------------------------------

def inject_rules(project_dir: Path) -> Tuple[str, List[str]]:
    """Read UNIVERSAL.md + detected tech rules.

    Returns (output_text, loaded_names) for SessionStart hooks that output
    plain text to stdout.
    """
    rules_dir = get_rules_dir(project_dir)
    if not rules_dir.is_dir():
        return (
            "WARNING: ai/standards/rules/ not found. "
            "The ai submodule may not be initialised.\n",
            [],
        )

    parts: List[str] = []
    loaded: List[str] = []

    # UNIVERSAL always
    universal = rules_dir / "UNIVERSAL.md"
    if universal.is_file():
        parts.append(universal.read_text())
        parts.append("")
        loaded.append("UNIVERSAL")

    # Detected technologies
    for tech_name, rule_file in detect_technologies(project_dir):
        rule_path = rules_dir / rule_file
        if rule_path.is_file():
            parts.append("---")
            parts.append("")
            parts.append(rule_path.read_text())
            parts.append("")
            loaded.append(tech_name)

    # Summary
    parts.append("---")
    parts.append("")
    parts.append(f"**HyperI AI standards loaded:** {', '.join(loaded)}")

    return ("\n".join(parts), loaded)


# ---------------------------------------------------------------------------
# Auto-format
# ---------------------------------------------------------------------------

# Extension → [command, args...] (file path appended by get_formatter)
_FORMATTER_MAP: Dict[str, List[str]] = {
    ".py": ["ruff", "format"],
    ".rs": ["rustfmt"],
    ".go": ["gofmt", "-w"],
    ".js": ["prettier", "--write"],
    ".jsx": ["prettier", "--write"],
    ".ts": ["prettier", "--write"],
    ".tsx": ["prettier", "--write"],
    ".json": ["prettier", "--write"],
    ".css": ["prettier", "--write"],
    ".html": ["prettier", "--write"],
    ".yaml": ["prettier", "--write"],
    ".yml": ["prettier", "--write"],
    ".sh": ["shfmt", "-w"],
    ".bash": ["shfmt", "-w"],
    ".c": ["clang-format", "-i"],
    ".cpp": ["clang-format", "-i"],
    ".cc": ["clang-format", "-i"],
    ".h": ["clang-format", "-i"],
    ".hpp": ["clang-format", "-i"],
}


def get_formatter(file_path: str) -> Optional[List[str]]:
    """Return [command, args..., file_path] if a formatter is available.

    Returns None if no formatter is known or the binary is not installed.
    """
    ext = Path(file_path).suffix.lower()
    cmd_args = _FORMATTER_MAP.get(ext)
    if not cmd_args:
        return None
    binary = cmd_args[0]
    if not shutil.which(binary):
        return None
    return cmd_args + [file_path]


# ---------------------------------------------------------------------------
# Auto-remediation (linting)
# ---------------------------------------------------------------------------

_LINTER_MAP: Dict[str, List[str]] = {
    ".py": ["ruff", "check", "--select", "E,W,F"],
    ".sh": ["shellcheck", "-f", "gcc"],
    ".bash": ["shellcheck", "-f", "gcc"],
    ".ts": ["npx", "eslint", "--quiet"],
    ".tsx": ["npx", "eslint", "--quiet"],
    ".js": ["npx", "eslint", "--quiet"],
    ".jsx": ["npx", "eslint", "--quiet"],
    ".go": ["go", "vet"],
}


def get_linter(file_path: str) -> Optional[List[str]]:
    """Return [command, args..., file_path] if a linter is available.

    Returns None if no linter is known or the binary is not installed.
    """
    ext = Path(file_path).suffix.lower()
    cmd_args = _LINTER_MAP.get(ext)
    if not cmd_args:
        return None
    binary = cmd_args[0]
    if not shutil.which(binary):
        return None
    return cmd_args + [file_path]


def lint_modified_files(project_dir: Path) -> List[str]:
    """Run linters on git-modified files. Returns list of error messages."""
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only"],
            capture_output=True, text=True, timeout=10,
            cwd=str(project_dir),
        )
        if result.returncode != 0:
            return []
        files = [f.strip() for f in result.stdout.strip().split("\n") if f.strip()]
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []

    errors: List[str] = []
    for f in files:
        full_path = str(project_dir / f)
        if not Path(full_path).is_file():
            continue
        cmd = get_linter(full_path)
        if not cmd:
            continue
        try:
            lint_result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=30,
                cwd=str(project_dir),
            )
            if lint_result.returncode != 0 and lint_result.stdout.strip():
                errors.append(f"## {f}\n{lint_result.stdout.strip()}")
            elif lint_result.returncode != 0 and lint_result.stderr.strip():
                errors.append(f"## {f}\n{lint_result.stderr.strip()}")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    return errors


# ---------------------------------------------------------------------------
# Safety guard
# ---------------------------------------------------------------------------

_DANGEROUS_PATTERNS: List[Tuple[str, str]] = [
    (r"rm\s+-rf\s+/\s*$", "BLOCKED: Refuses to remove filesystem root. Use a specific path or trash."),
    (r"rm\s+-rf\s+/\*", "BLOCKED: Refuses to remove all files under /. Use a specific path."),
    (r"rm\s+-rf\s+~\s*$", "BLOCKED: Refuses to remove home directory."),
    (r"rm\s+-rf\s+~/\*", "BLOCKED: Refuses to remove all files in home directory."),
    (r"git\s+push\s+.*--force\s+.*\b(main|master)\b", "BLOCKED: Force-pushing to main/master can destroy team history. Use --force-with-lease or push to a feature branch."),
    (r"dd\s+if=/dev/(zero|random)", "BLOCKED: Writing /dev/zero or /dev/random can destroy data. Verify the target device carefully."),
    (r"mkfs\.", "BLOCKED: Formatting a filesystem destroys all data on the device. Verify the target."),
    (r":\(\)\s*\{\s*:\|:\s*&\s*\}\s*;:", "BLOCKED: Fork bomb detected."),
    (r">\s*/dev/sd[a-z]", "BLOCKED: Writing directly to a block device can destroy the partition table."),
    (r"chmod\s+-R\s+777\s+/\s*$", "BLOCKED: Setting 777 permissions recursively on / is a severe security risk."),
]


def check_command_safety(command: str) -> Optional[Tuple[str, str]]:
    """Check a command against dangerous patterns.

    Returns (pattern, reason) if dangerous, None if safe.
    """
    for pattern, reason in _DANGEROUS_PATTERNS:
        if re.search(pattern, command):
            return (pattern, reason)
    return None


# ---------------------------------------------------------------------------
# Auto-reattach
# ---------------------------------------------------------------------------

def git_rev_parse(repo_dir: Path) -> Optional[str]:
    """Get HEAD commit hash. Returns None on error."""
    try:
        result = subprocess.run(
            ["git", "-C", str(repo_dir), "rev-parse", "HEAD"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return None


def git_diff_names(repo_dir: Path, old_rev: str, new_rev: str) -> List[str]:
    """Get list of changed file paths between two commits."""
    if not old_rev:
        return []
    try:
        result = subprocess.run(
            ["git", "-C", str(repo_dir), "diff", "--name-only", old_rev, new_rev],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            return [f.strip() for f in result.stdout.strip().split("\n") if f.strip()]
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return []


def auto_update_submodule(project_dir: Path, name: str = "hyperi-ai") -> bool:
    """Silently update a submodule if it's behind remote.

    Checks .gitmodules update mode — only updates if 'rebase' or unset (default).
    Skips if update = 'none' (pinned) or the submodule directory doesn't exist.

    Returns True if the submodule was updated, False otherwise.
    """
    sub_dir = project_dir / name
    if not (sub_dir / ".git").exists():
        return False  # not present or not a submodule/repo

    # Check update mode from .gitmodules
    gitmodules = project_dir / ".gitmodules"
    if gitmodules.is_file():
        try:
            result = subprocess.run(
                ["git", "config", "-f", str(gitmodules),
                 f"submodule.{name}.update"],
                capture_output=True, text=True, timeout=5,
                cwd=str(project_dir),
            )
            mode = result.stdout.strip()
            if mode == "none":
                return False  # pinned, skip
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Fetch + update silently
    try:
        subprocess.run(
            ["git", "submodule", "update", "--remote", name],
            capture_output=True, timeout=30,
            cwd=str(project_dir),
        )
        return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def auto_update_submodules(project_dir: Path) -> None:
    """Silently update hyperi-ai and ci submodules if present and not pinned."""
    auto_update_submodule(project_dir, "hyperi-ai")
    auto_update_submodule(project_dir, "ci")


def check_version_and_reattach(project_dir: Path) -> Optional[str]:
    """Detect hyperi-ai submodule changes and auto-remediate.

    Returns message describing what was done, or None if up-to-date.
    """
    ai_dir = get_ai_dir(project_dir)
    version_file = project_dir / ".claude" / ".ai-version"

    # Get current submodule HEAD
    current = git_rev_parse(ai_dir)
    if not current:
        return None  # can't determine version (not a git repo)

    deployed = ""
    if version_file.exists():
        try:
            deployed = version_file.read_text().strip()
        except OSError:
            pass

    if current == deployed:
        return None  # up-to-date

    # What changed between deployed and current?
    changed = git_diff_names(ai_dir, deployed, current)

    actions: List[str] = []
    needs_redeploy = False
    needs_restart_note = False

    for f in changed:
        if f.startswith("hooks/"):
            needs_restart_note = True
        if f.startswith("templates/claude-code/commands/"):
            needs_redeploy = True
        if f.startswith("standards/rules/"):
            needs_redeploy = True
        if f.startswith("agents/"):
            needs_redeploy = True
        if f.startswith("templates/claude-code/settings"):
            actions.append("Settings template updated (symlink auto-applied)")

    if needs_redeploy:
        claude_sh = ai_dir / "agents" / "claude.sh"
        if claude_sh.is_file():
            try:
                subprocess.run(
                    ["bash", str(claude_sh)],
                    capture_output=True, timeout=30,
                    cwd=str(project_dir),
                )
                actions.append("Re-deployed commands, rules, and skills via claude.sh")
            except (subprocess.TimeoutExpired, FileNotFoundError):
                actions.append("WARNING: Failed to run claude.sh for re-deployment")

    # Update version stamp
    try:
        version_file.parent.mkdir(parents=True, exist_ok=True)
        version_file.write_text(current + "\n")
    except OSError:
        pass

    if needs_restart_note:
        actions.append("Hooks changed — restart session after this one for full effect")

    if not actions:
        actions.append("AI submodule updated (no deployment changes needed)")

    return "**AI submodule auto-update:** " + "; ".join(actions)
