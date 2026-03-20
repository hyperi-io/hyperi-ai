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
# Context tier detection
# ---------------------------------------------------------------------------

# Tier determines which standards payload to inject:
#   "compact" — compact rules from standards/rules/ (~14-34K tokens, safe for 200K)
#   "full"    — full source from standards/{languages,common,infrastructure}/ (~100-220K, needs 1M)
#
# Detection priority:
#   1. HYPERI_CONTEXT_TIER env var (explicit override)
#   2. VS Code claudeCode.selectedModel setting (auto-detect [1m]/[2m] suffix)
#   3. Default: "compact" (safe for 200K — the common case)

_CONTEXT_TIER_CACHE: Optional[str] = None


def get_context_tier() -> str:
    """Detect the appropriate context tier for standards injection.

    Returns "compact" or "full".
    """
    global _CONTEXT_TIER_CACHE
    if _CONTEXT_TIER_CACHE is not None:
        return _CONTEXT_TIER_CACHE

    # 1. Explicit env var override
    tier = os.environ.get("HYPERI_CONTEXT_TIER", "").strip().lower()
    if tier in ("compact", "full"):
        _CONTEXT_TIER_CACHE = tier
        return tier

    # 2. Auto-detect from VS Code settings (claudeCode.selectedModel)
    tier = _detect_tier_from_vscode()
    if tier:
        _CONTEXT_TIER_CACHE = tier
        return tier

    # 3. Default to compact (safe for 200K)
    _CONTEXT_TIER_CACHE = "compact"
    return "compact"


def _detect_tier_from_vscode() -> Optional[str]:
    """Read claudeCode.selectedModel from VS Code user settings.

    Models with [Nm] suffix (e.g. opus[1m], sonnet[2m]) indicate extended
    context windows. Returns "full" if context >= 1M, else None.

    NOTE: This reads an undocumented VS Code extension setting. It may break
    if the Claude Code extension changes its config schema.
    """
    # Try standard VS Code settings paths
    candidates = []
    config_home = os.environ.get("XDG_CONFIG_HOME", "")
    if config_home:
        candidates.append(Path(config_home) / "Code" / "User" / "settings.json")
    candidates.extend(
        [
            Path.home() / ".config" / "Code" / "User" / "settings.json",
            Path.home() / ".config" / "Code - Insiders" / "User" / "settings.json",
            Path.home() / ".config" / "Codium" / "User" / "settings.json",
        ]
    )

    for settings_path in candidates:
        if not settings_path.is_file():
            continue
        try:
            with open(settings_path, encoding="utf-8") as f:
                # VS Code settings.json may have comments — strip them
                content = f.read()
                # Simple comment stripping (// line comments only)
                lines = []
                for line in content.splitlines():
                    stripped = line.lstrip()
                    if stripped.startswith("//"):
                        continue
                    lines.append(line)
                data = json.loads("\n".join(lines))

            model = data.get("claudeCode.selectedModel", "")
            if not model:
                continue

            # Parse context suffix: opus[1m], sonnet[2m], etc.
            m = re.search(r"\[(\d+)m\]", model)
            if m:
                context_millions = int(m.group(1))
                if context_millions >= 1:
                    return "full"

            # No suffix or < 1M — don't override default
            return None
        except (json.JSONDecodeError, KeyError, OSError):
            continue

    return None


# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------


def get_project_dir() -> Path:
    """Return the consumer project root from $CLAUDE_PROJECT_DIR or cwd."""
    return Path(os.environ.get("CLAUDE_PROJECT_DIR", ".")).resolve()


def get_ai_dir(project_dir: Path) -> Path:
    """Return the hyperi-ai/ submodule directory within the project.

    Handles two cases:
    - Consumer project: /projects/myapp/hyperi-ai/ (submodule)
    - Dogfooding: /projects/hyperi-ai/ (we ARE the repo)
    """
    submodule = project_dir / "hyperi-ai"
    if submodule.is_dir():
        return submodule
    # Dogfooding: check if project_dir itself IS hyperi-ai
    if (project_dir / "standards" / "rules").is_dir():
        return project_dir
    return submodule  # fallback (will fail gracefully downstream)


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
# Technology detection — frontmatter-driven
# ---------------------------------------------------------------------------
#
# Marker types (from detect_markers: in each rules/*.md file):
#   "file:<name>"       — exact file in project root
#   "dir:<name>"        — exact directory in project root
#   "glob:<pattern>"    — glob pattern in project root only
#   "deep_file:<name>"  — file anywhere up to 3 levels deep
#   "deep_glob:<pat>"   — glob pattern up to 3 levels deep


def _parse_rules_frontmatter(rules_path: Path) -> dict:
    """Parse YAML-ish frontmatter from a rules/*.md file (stdlib only)."""
    text = rules_path.read_text(encoding="utf-8", errors="replace")
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    fm = text[3:end]

    result: dict = {}
    current_key: Optional[str] = None
    current_list: Optional[List] = None

    for line in fm.splitlines():
        list_m = re.match(r"^  - (.+)$", line)
        kv_m = re.match(r"^(\w[\w_-]*):\s*(.*)$", line)
        if list_m and current_key and current_list is not None:
            current_list.append(list_m.group(1).strip().strip('"').strip("'"))
        elif kv_m:
            key, val = kv_m.group(1), kv_m.group(2).strip().strip('"').strip("'")
            if val == "":
                current_key = key
                current_list = []
                result[key] = current_list
            else:
                result[key] = val
                current_key = None
                current_list = None

    result.setdefault("detect_markers", [])
    return result


def _load_tech_detections(
    rules_dir: Path,
) -> List[Tuple[str, str, List[Tuple[str, str]]]]:
    """Build tech detections dynamically from detect_markers in rules files.

    Returns list of (tech_name, rule_filename, markers) — same structure as
    the old hardcoded TECH_DETECTIONS. Skips UNIVERSAL.md.
    """
    detections: List[Tuple[str, str, List[Tuple[str, str]]]] = []
    for rules_path in sorted(rules_dir.glob("*.md")):
        if rules_path.name == "UNIVERSAL.md":
            continue
        meta = _parse_rules_frontmatter(rules_path)
        raw_markers: List[str] = meta.get("detect_markers", [])
        if not raw_markers:
            continue
        markers: List[Tuple[str, str]] = []
        for m in raw_markers:
            if ":" in m:
                kind, value = m.split(":", 1)
                markers.append((kind.strip(), value.strip()))
        if markers:
            detections.append((rules_path.stem, rules_path.name, markers))
    return detections


# Directories to skip during deep scans (performance + false positive avoidance)
_SKIP_DIRS = frozenset(
    {
        ".git",
        ".hg",
        ".svn",
        "node_modules",
        "__pycache__",
        ".tox",
        ".venv",
        "venv",
        ".mypy_cache",
        "target",
        "dist",
        "build",
        ".next",
        ".nuxt",
        ".cache",
        ".eggs",
        "vendor",
        "third_party",
        "3rdparty",
    }
)


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
    rules_dir = get_rules_dir(project_dir)
    if not rules_dir.is_dir():
        return []
    detected = []
    for tech_name, rule_file, markers in _load_tech_detections(rules_dir):
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
            "NOTE: hyperi-ai/standards/rules/ not found — "
            "coding standards not loaded. "
            "If you have access, run: git submodule update --init hyperi-ai\n",
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

    # User personal overrides (highest priority — loaded last so they win)
    user_standards = Path(
        os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"),
        "hyperi-ai",
        "USER-CODING-STANDARDS.md",
    )
    if user_standards.is_file():
        parts.append("---")
        parts.append("")
        parts.append("# User Coding Standards (OVERRIDE — these take priority)")
        parts.append("")
        parts.append(user_standards.read_text(encoding="utf-8"))
        parts.append("")
        loaded.append("USER")

    # Summary
    parts.append("---")
    parts.append("")
    parts.append(f"**HyperI AI standards loaded:** {', '.join(loaded)}")

    return ("\n".join(parts), loaded)


def _resolve_full_source(rule_path: Path, standards_dir: Path) -> Optional[Path]:
    """Resolve a compact rule to its full source standard via the source: frontmatter.

    Returns the full source Path if it exists, None otherwise.
    """
    meta = _parse_rules_frontmatter(rule_path)
    source = meta.get("source", "")
    if not source:
        return None
    full_path = standards_dir / source
    if full_path.is_file():
        return full_path
    return None


def _load_standards_compact(
    rules_dir: Path, project_dir: Path
) -> Tuple[List[str], List[str]]:
    """Load standards as compact rules (for 200K context windows).

    Returns (text_parts, loaded_names).
    """
    parts: List[str] = []
    loaded: List[str] = []

    # UNIVERSAL always first
    universal = rules_dir / "UNIVERSAL.md"
    if universal.is_file():
        parts.append(universal.read_text(encoding="utf-8"))
        parts.append("")
        loaded.append("UNIVERSAL")

    # Detected technology rules (compact)
    for tech_name, rule_file in detect_technologies(project_dir):
        rule_path = rules_dir / rule_file
        if rule_path.is_file():
            parts.append("---")
            parts.append("")
            parts.append(rule_path.read_text(encoding="utf-8"))
            parts.append("")
            loaded.append(tech_name)

    # Common rules — everything not UNIVERSAL and not a tech-detection rule
    tech_files: set[str] = set()
    for _name, _fname, _markers in _load_tech_detections(rules_dir):
        tech_files.add(_fname)

    for rule_path in sorted(rules_dir.glob("*.md")):
        if rule_path.name == "UNIVERSAL.md":
            continue
        if rule_path.name in tech_files:
            continue
        parts.append("---")
        parts.append("")
        parts.append(rule_path.read_text(encoding="utf-8"))
        parts.append("")
        loaded.append(rule_path.stem)

    return parts, loaded


def _load_standards_full(
    rules_dir: Path, project_dir: Path
) -> Tuple[List[str], List[str]]:
    """Load standards as full source documents (for 1M+ context windows).

    Uses the source: frontmatter in each compact rule to find the full source
    file in standards/{languages,common,infrastructure}/. Falls back to compact
    if no source mapping exists.

    Returns (text_parts, loaded_names).
    """
    standards_dir = rules_dir.parent  # standards/rules/ -> standards/
    parts: List[str] = []
    loaded: List[str] = []

    # UNIVERSAL always first (same in both tiers — it IS the source)
    universal = rules_dir / "UNIVERSAL.md"
    if universal.is_file():
        parts.append(universal.read_text(encoding="utf-8"))
        parts.append("")
        loaded.append("UNIVERSAL")

    # Detected technology rules — load full source where available
    for tech_name, rule_file in detect_technologies(project_dir):
        rule_path = rules_dir / rule_file
        if not rule_path.is_file():
            continue
        full_path = _resolve_full_source(rule_path, standards_dir)
        if full_path:
            parts.append("---")
            parts.append("")
            parts.append(full_path.read_text(encoding="utf-8"))
            parts.append("")
            loaded.append(f"{tech_name}[full]")
        else:
            parts.append("---")
            parts.append("")
            parts.append(rule_path.read_text(encoding="utf-8"))
            parts.append("")
            loaded.append(tech_name)

    # Common rules — load full source where available
    tech_files: set[str] = set()
    for _name, _fname, _markers in _load_tech_detections(rules_dir):
        tech_files.add(_fname)

    for rule_path in sorted(rules_dir.glob("*.md")):
        if rule_path.name == "UNIVERSAL.md":
            continue
        if rule_path.name in tech_files:
            continue
        full_path = _resolve_full_source(rule_path, standards_dir)
        if full_path:
            parts.append("---")
            parts.append("")
            parts.append(full_path.read_text(encoding="utf-8"))
            parts.append("")
            loaded.append(f"{rule_path.stem}[full]")
        else:
            parts.append("---")
            parts.append("")
            parts.append(rule_path.read_text(encoding="utf-8"))
            parts.append("")
            loaded.append(rule_path.stem)

    return parts, loaded


def inject_cag_payload(project_dir: Path) -> Tuple[str, List[str]]:
    """Unified CAG injection — loads standards, skills, and context.

    Context tier selection:
      - "compact": compact rules from standards/rules/ (~14-34K tokens, for 200K)
      - "full": full source from standards/{languages,common,infrastructure}/ (for 1M+)

    Tier is auto-detected from VS Code model selection or HYPERI_CONTEXT_TIER env var.
    Set HYPERI_CAG_LEAN=1 to fall back to the minimal inject_rules() path.

    Returns (output_text, loaded_names).
    """
    if os.environ.get("HYPERI_CAG_LEAN") == "1":
        return inject_rules(project_dir)

    rules_dir = get_rules_dir(project_dir)
    if not rules_dir.is_dir():
        return (
            "NOTE: hyperi-ai/standards/rules/ not found — "
            "coding standards not loaded. "
            "If you have access, run: git submodule update --init hyperi-ai\n",
            [],
        )

    # Select tier and load standards accordingly
    tier = get_context_tier()
    if tier == "full":
        parts, loaded = _load_standards_full(rules_dir, project_dir)
    else:
        parts, loaded = _load_standards_compact(rules_dir, project_dir)

    # 4. Skills — load each skills/*/SKILL.md, strip YAML frontmatter
    ai_dir = get_ai_dir(project_dir)
    skills_dir = ai_dir / "skills"
    if skills_dir.is_dir():
        for skill_dir in sorted(skills_dir.iterdir()):
            skill_file = skill_dir / "SKILL.md"
            if not skill_file.is_file():
                continue
            skill_text = skill_file.read_text(encoding="utf-8", errors="replace")
            # Strip YAML frontmatter (between --- delimiters)
            if skill_text.startswith("---"):
                end = skill_text.find("\n---", 3)
                if end != -1:
                    # Skip past the closing --- and any immediate newline
                    body_start = end + 4
                    if body_start < len(skill_text) and skill_text[body_start] == "\n":
                        body_start += 1
                    skill_text = skill_text[body_start:]
            skill_name = skill_dir.name
            parts.append("---")
            parts.append("")
            parts.append(f"# Skill: {skill_name}")
            parts.append("")
            parts.append(skill_text.strip())
            parts.append("")
            loaded.append(f"skill:{skill_name}")

    # 5. STATE.md from consumer project root (not the hyperi-ai submodule)
    state_file = project_dir / "STATE.md"
    if state_file.is_file():
        parts.append("---")
        parts.append("")
        parts.append("# Project State")
        parts.append("")
        parts.append(state_file.read_text(encoding="utf-8", errors="replace"))
        parts.append("")
        loaded.append("STATE")

    # 6. User standards override (highest priority — loaded last)
    user_standards = Path(
        os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"),
        "hyperi-ai",
        "USER-CODING-STANDARDS.md",
    )
    if user_standards.is_file():
        parts.append("---")
        parts.append("")
        parts.append("# User Coding Standards (OVERRIDE — these take priority)")
        parts.append("")
        parts.append(user_standards.read_text(encoding="utf-8"))
        parts.append("")
        loaded.append("USER")

    # 7. Bash efficiency rules
    parts.append("---")
    parts.append("")
    parts.append(bash_efficiency_rules())
    parts.append("")

    # 8. Tool survey
    available, missing_installable, missing_unknown = survey_tools()
    parts.append("")
    parts.append(format_tool_survey(available, missing_installable, missing_unknown))
    parts.append("")

    # Summary
    parts.append("---")
    parts.append("")
    parts.append(f"[CAG payload ({tier}): {', '.join(loaded)}]")

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
            capture_output=True,
            text=True,
            timeout=10,
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
                cmd,
                capture_output=True,
                text=True,
                timeout=30,
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
# Test integrity check
# ---------------------------------------------------------------------------

# Patterns that indicate an assertion was present (one per line)
_ASSERT_PATTERNS = re.compile(
    r"(?:assert\b|self\.assert|expect\(|\.should|\.to_eq|\.to_be|"
    r"\.to_equal|\.to_have|\.toEqual|\.toBe|\.toHave|EXPECT_|ASSERT_)",
    re.IGNORECASE,
)

# Patterns that indicate a test was skipped/disabled
_SKIP_PATTERNS = re.compile(
    r"(?:@pytest\.mark\.skip|@pytest\.mark\.xfail|\.skip\(|"
    r"@unittest\.skip|@ignore|@disabled|pending\(|xit\(|xdescribe\(|"
    r"#\s*NOQA|#\s*pragma:\s*no\s*cover)",
    re.IGNORECASE,
)

# File patterns that look like test files
_TEST_FILE_PATTERNS = re.compile(
    r"(?:^test_|_test\.py$|\.test\.[jt]sx?$|\.spec\.[jt]sx?$|"
    r"_test\.go$|_test\.rs$|\.bats$)",
)


def check_test_integrity(project_dir: Path) -> List[str]:
    """Check git-modified test files for removed assertions or added skips.

    Returns list of warning messages (empty if all clean).
    """
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only"],
            capture_output=True,
            text=True,
            timeout=10,
            cwd=str(project_dir),
        )
        if result.returncode != 0:
            return []
        files = [f.strip() for f in result.stdout.strip().split("\n") if f.strip()]
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []

    # Filter to test files only
    test_files = [f for f in files if _TEST_FILE_PATTERNS.search(Path(f).name)]
    if not test_files:
        return []

    warnings: List[str] = []
    for f in test_files:
        try:
            diff_result = subprocess.run(
                ["git", "diff", "-U0", "--", f],
                capture_output=True,
                text=True,
                timeout=10,
                cwd=str(project_dir),
            )
            if diff_result.returncode != 0:
                continue
        except (subprocess.TimeoutExpired, FileNotFoundError):
            continue

        removed_asserts = 0
        added_asserts = 0
        added_skips = 0

        for line in diff_result.stdout.split("\n"):
            if line.startswith("-") and not line.startswith("---"):
                if _ASSERT_PATTERNS.search(line):
                    removed_asserts += 1
            elif line.startswith("+") and not line.startswith("+++"):
                if _ASSERT_PATTERNS.search(line):
                    added_asserts += 1
                if _SKIP_PATTERNS.search(line):
                    added_skips += 1

        issues = []
        net_removed = removed_asserts - added_asserts
        if net_removed > 0:
            issues.append(f"{net_removed} assertion(s) removed")
        if added_skips > 0:
            issues.append(f"{added_skips} skip/xfail marker(s) added")

        if issues:
            warnings.append(
                f"## {f}\n"
                f"TEST INTEGRITY WARNING: {', '.join(issues)}.\n"
                f"If you weakened tests to make them pass, STOP — "
                f"fix the implementation instead."
            )

    return warnings


# ---------------------------------------------------------------------------
# Safety guard
# ---------------------------------------------------------------------------

_DANGEROUS_PATTERNS: List[Tuple[str, str]] = [
    (
        r"rm\s+-rf\s+/\s*$",
        "BLOCKED: Refuses to remove filesystem root. Use a specific path or trash.",
    ),
    (
        r"rm\s+-rf\s+/\*",
        "BLOCKED: Refuses to remove all files under /. Use a specific path.",
    ),
    (r"rm\s+-rf\s+~\s*$", "BLOCKED: Refuses to remove home directory."),
    (r"rm\s+-rf\s+~/\*", "BLOCKED: Refuses to remove all files in home directory."),
    (
        r"git\s+push\s+.*--force\s+.*\b(main|master)\b",
        "BLOCKED: Force-pushing to main/master can destroy team history. Use --force-with-lease or push to a feature branch.",
    ),
    (
        r"git\s+reset\s+--hard",
        "BLOCKED: git reset --hard destroys uncommitted work. Use git stash or commit first.",
    ),
    (
        r"git\s+checkout\s+--\s",
        "BLOCKED: git checkout -- discards uncommitted changes to files. Commit or stash first.",
    ),
    (
        r"git\s+restore\s+(?!--staged)(?!-S)\S",
        "BLOCKED: git restore discards uncommitted changes. Use git restore --staged to unstage, or commit/stash first.",
    ),
    (
        r"--no-verify",
        "BLOCKED: --no-verify bypasses pre-commit hooks. Fix the hook issue instead of skipping it.",
    ),
    (
        r"dd\s+if=/dev/(zero|random)",
        "BLOCKED: Writing /dev/zero or /dev/random can destroy data. Verify the target device carefully.",
    ),
    (
        r"mkfs\.",
        "BLOCKED: Formatting a filesystem destroys all data on the device. Verify the target.",
    ),
    (r":\(\)\s*\{\s*:\|:\s*&\s*\}\s*;:", "BLOCKED: Fork bomb detected."),
    (
        r">\s*/dev/sd[a-z]",
        "BLOCKED: Writing directly to a block device can destroy the partition table.",
    ),
    (
        r"chmod\s+-R\s+777\s+/\s*$",
        "BLOCKED: Setting 777 permissions recursively on / is a severe security risk.",
    ),
    (
        r"git\s+push\s+\S+\s+release\b",
        "BLOCKED: Never push directly to release. All changes flow: main -> PR -> release. Push to main and create a PR instead.",
    ),
    (
        r"git\s+push\s+.*--force.*\brelease\b",
        "BLOCKED: Never force-push to release. Release is protected — use PRs from main.",
    ),
    (
        r"git\s+(checkout|switch)\s+release(?![-/\w])",
        "BLOCKED: Never switch to the release branch. All changes go to main first, then PR to release. Stay on main or a feature branch.",
    ),
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
            capture_output=True,
            text=True,
            timeout=10,
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
            capture_output=True,
            text=True,
            timeout=10,
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
                ["git", "config", "-f", str(gitmodules), f"submodule.{name}.update"],
                capture_output=True,
                text=True,
                timeout=5,
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
            capture_output=True,
            timeout=30,
            cwd=str(project_dir),
        )
        return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def auto_update_submodules(project_dir: Path) -> None:
    """Silently update hyperi-ai submodule if present and not pinned."""
    auto_update_submodule(project_dir, "hyperi-ai")


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
                    capture_output=True,
                    timeout=30,
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


# ---------------------------------------------------------------------------
# Tool survey — discover available single-line-friendly CLI tools
# ---------------------------------------------------------------------------

# (binary_name, aliases_to_check, description_of_what_it_replaces)
_TOOL_SURVEY: List[Tuple[str, List[str], str]] = [
    # Text processing — replace pipe chains
    ("sd", ["sd"], "sed alternative (simpler regex syntax, single command)"),
    (
        "awk",
        ["awk", "gawk"],
        "text processing (field extraction, transforms — replaces cut|sort|uniq chains)",
    ),
    (
        "miller",
        ["mlr", "miller"],
        "CSV/JSON/tabular processor (replaces awk|sort|uniq|cut chains)",
    ),
    ("jq", ["jq"], "JSON processor (replaces grep|sed on JSON data)"),
    ("yq", ["yq"], "YAML/XML processor (like jq but for YAML)"),
    ("gron", ["gron"], "flatten JSON for grep (replaces jq|grep chains)"),
    # File finding — replace find|grep chains
    (
        "fd",
        ["fdfind", "fd"],
        "fast find replacement (single command, regex, respects .gitignore)",
    ),
    (
        "ripgrep",
        ["rg", "ripgrep"],
        "fast recursive grep (single command, respects .gitignore)",
    ),
    # File operations — replace pipe-to-file patterns
    ("sponge", ["sponge"], "in-place filter (replaces cmd > tmp && mv tmp file)"),
    ("ifne", ["ifne"], "run command only if stdin non-empty (from moreutils)"),
    ("pee", ["pee"], "pipe to multiple commands (from moreutils)"),
    ("ts", ["ts"], "timestamp lines (from moreutils)"),
    ("chronic", ["chronic"], "run command silently unless it fails (from moreutils)"),
    ("parallel", ["parallel"], "GNU parallel (replaces for loops over files)"),
    # Display
    ("bat", ["batcat", "bat"], "syntax-highlighted cat"),
    # Shell scripting
    (
        "macbash",
        ["macbash"],
        "check bash scripts for macOS/BSD compat issues and convert multi-line to single-line",
    ),
    # CI/CD — only relevant when .hyperi-ci.yaml is present
    (
        "hyperi-ci",
        ["hyperi-ci"],
        "polyglot CI/CD CLI (quality, test, build, publish — same locally and in CI)",
    ),
]


# Tools that are only relevant when certain project files exist
_CONDITIONAL_TOOLS: Dict[str, str] = {
    "hyperi-ci": ".hyperi-ci.yaml",  # only needed for hyperi-ci projects
}


def survey_tools() -> Tuple[List[str], List[str], List[str]]:
    """Survey host for available single-line-friendly tools.

    Returns (available, missing_installable, missing_unknown) where:
    - available: tools found on PATH
    - missing_installable: not installed but available in apt/dnf repos
    - missing_unknown: not installed and not found in repos (may need manual install)

    Tools listed in _CONDITIONAL_TOOLS are skipped unless their marker
    file exists in the project root.
    """
    project_root = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    available: List[str] = []
    missing: List[str] = []
    for name, aliases, _desc in _TOOL_SURVEY:
        # Skip conditional tools if their marker file is absent
        marker = _CONDITIONAL_TOOLS.get(name)
        if marker and not os.path.exists(os.path.join(project_root, marker)):
            continue
        found = any(shutil.which(a) for a in aliases)
        if found:
            available.append(name)
        else:
            missing.append(name)

    if not missing:
        return available, [], []

    # Check which missing tools are available in package repos
    missing_installable: List[str] = []
    missing_unknown: List[str] = []
    for name in missing:
        pkg = _check_package_available(name)
        if pkg:
            missing_installable.append(f"{name} ({pkg})")
        else:
            missing_unknown.append(name)

    return available, missing_installable, missing_unknown


# Map tool names to likely package names for apt/dnf lookup
# apt/dnf package names
_APT_PACKAGE_NAMES: Dict[str, List[str]] = {
    "sd": ["sd"],
    "awk": ["gawk", "mawk"],
    "miller": ["miller"],
    "jq": ["jq"],
    "yq": ["yq"],
    "gron": ["gron"],
    "fd": ["fd-find"],
    "ripgrep": ["ripgrep"],
    "sponge": ["moreutils"],
    "ifne": ["moreutils"],
    "pee": ["moreutils"],
    "ts": ["moreutils"],
    "chronic": ["moreutils"],
    "parallel": ["parallel"],
    "bat": ["bat"],
    "entr": ["entr"],
    # macbash is not in standard repos — installed from GitHub releases
    # https://github.com/hyperi-io/macbash/releases
    # hyperi-ci is a Python tool — installed via uv/pip, not OS packages
}

# Homebrew formula names (where different from apt)
_BREW_PACKAGE_NAMES: Dict[str, List[str]] = {
    "sd": ["sd"],
    "awk": ["gawk"],
    "miller": ["miller"],
    "jq": ["jq"],
    "yq": ["yq"],
    "gron": ["gron"],
    "fd": ["fd"],
    "ripgrep": ["ripgrep"],
    "sponge": ["moreutils"],
    "ifne": ["moreutils"],
    "pee": ["moreutils"],
    "ts": ["moreutils"],
    "chronic": ["moreutils"],
    "parallel": ["parallel"],
    "bat": ["bat"],
    "entr": ["entr"],
    # macbash: install from https://github.com/hyperi-io/macbash/releases
}


def _check_package_available(tool_name: str) -> Optional[str]:
    """Check if a tool's package is available in system repos.

    Supports apt (Debian/Ubuntu), dnf (Fedora/RHEL), and brew (macOS).
    Returns the package name if found, None otherwise.
    """
    # Try apt-cache (Debian/Ubuntu)
    if shutil.which("apt-cache"):
        for pkg in _APT_PACKAGE_NAMES.get(tool_name, [tool_name]):
            try:
                result = subprocess.run(
                    ["apt-cache", "show", pkg],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if result.returncode == 0:
                    return f"apt: {pkg}"
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

    # Try dnf (Fedora/RHEL)
    if shutil.which("dnf"):
        for pkg in _APT_PACKAGE_NAMES.get(tool_name, [tool_name]):
            try:
                result = subprocess.run(
                    ["dnf", "info", pkg],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if result.returncode == 0:
                    return f"dnf: {pkg}"
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

    # Try brew (macOS / Linuxbrew)
    if shutil.which("brew"):
        for pkg in _BREW_PACKAGE_NAMES.get(tool_name, [tool_name]):
            try:
                result = subprocess.run(
                    ["brew", "info", "--json=v2", pkg],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                if result.returncode == 0:
                    return f"brew: {pkg}"
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

    return None


def format_tool_survey(
    available: List[str],
    missing_installable: List[str],
    missing_unknown: List[str],
) -> str:
    """Format tool survey results as compact text for injection."""
    lines: List[str] = []
    lines.append("## Available CLI Tools")
    lines.append("")

    if available:
        # Build a lookup for descriptions
        desc_map = {name: desc for name, _, desc in _TOOL_SURVEY}
        for name in available:
            alias = _resolve_tool_binary(name)
            desc = desc_map.get(name, "")
            if alias and alias != name:
                lines.append(f"- **{name}** (`{alias}`): {desc}")
            else:
                lines.append(f"- **{name}**: {desc}")

    if missing_installable:
        lines.append("")
        lines.append(
            f"*Not installed (available in repos):* {', '.join(missing_installable)}"
        )
        lines.append("*Run `/setup-claude` to install missing tools.*")

    if missing_unknown:
        lines.append("")
        lines.append(f"*Not installed (not in repos):* {', '.join(missing_unknown)}")
        if "macbash" in missing_unknown:
            lines.append(
                "*Install macbash from https://github.com/hyperi-io/macbash/releases*"
            )
        if "hyperi-ci" in missing_unknown:
            lines.append("*Install hyperi-ci: `uv tool install hyperi-ci`*")

    return "\n".join(lines)


def _resolve_tool_binary(name: str) -> Optional[str]:
    """Find the actual binary name for a tool."""
    for tool_name, aliases, _ in _TOOL_SURVEY:
        if tool_name == name:
            for a in aliases:
                if shutil.which(a):
                    return a
    return None


# ---------------------------------------------------------------------------
# Bash efficiency rules — always injected at startup and post-compact
# ---------------------------------------------------------------------------

_BASH_EFFICIENCY_RULES = """
## Bash Efficiency Rules

These rules are MANDATORY for all Bash tool use. They prevent permission prompt
stalls and ensure commands complete without user intervention.

### 1. NEVER Use Compound Commands

**BANNED:** `&&`, `||`, `;` between commands, `|` pipes, inline `for`/`while`/`if`

**Instead:** Use separate Bash tool calls for each command. Claude Code runs
independent calls in parallel automatically — this is faster than `&&` chaining.

### 2. Use `.tmp/` for Intermediates

The project has a gitignored `.tmp/` directory. Use it for ALL temporary files:

- Write command output: `grep -r "pattern" src/ > .tmp/results.txt`
- Read in next call: `sort .tmp/results.txt`
- NEVER use `/tmp` — it is outside the project and may not be in the permitted path

### 3. Write Scripts for Multi-Step Logic

For anything requiring pipes, loops, or conditionals:

1. Use the **Write** tool to create `.tmp/task.sh` (or `.py`)
2. Run it: `bash .tmp/task.sh`

This is a SINGLE command matching the allow list.

### 4. Prefer Efficient Single-Command Tools

Use tools that do in one command what would otherwise need pipes:

| Instead of...                    | Use...                                    |
|----------------------------------|-------------------------------------------|
| `find . -name X \\| grep Y`      | `fd X` or `fdfind X`                      |
| `grep -r X \\| sort \\| uniq -c`  | `rg -c X` (ripgrep with count)            |
| `cat f \\| jq . \\| grep X`       | `jq 'select(.key == "X")' f`             |
| `cmd > tmp && mv tmp file`       | `cmd \\| sponge file` or Write tool        |
| `for f in *.py; do cmd; done`    | `fd -e py -x cmd` or `parallel cmd ::: *.py` |
| `sed -i 's/old/new/g' file`      | `sd 'old' 'new' file`                    |
| `cut -d, -f2 \\| sort \\| uniq`   | `mlr --csv cut -f col then sort-by col`   |

### 5. Prefer Claude Code Native Tools Over Bash

| Task                    | Use this                | NOT this              |
|-------------------------|-------------------------|-----------------------|
| Read file contents      | `Read` tool             | `cat`, `head`, `tail` |
| Edit file               | `Edit` tool             | `sed`, `awk`          |
| Create file             | `Write` tool            | `echo >`, `cat <<`    |
| Search file contents    | `Grep` tool             | `grep`, `rg`          |
| Find files by name      | `Glob` tool             | `find`, `fd`, `ls`    |

Only use Bash when a dedicated tool genuinely cannot do the job (e.g. running
builds, tests, git operations, package managers).

### 6. Clean `.tmp/` Between Tasks

After completing a major task: `rm -f .tmp/*.txt .tmp/*.sh .tmp/*.py .tmp/*.json`
""".strip()


def bash_efficiency_rules() -> str:
    """Return the always-on bash efficiency rules text."""
    return _BASH_EFFICIENCY_RULES
