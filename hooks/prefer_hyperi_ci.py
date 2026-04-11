#!/usr/bin/env python3
# Project:   HyperI AI
# File:      hooks/prefer_hyperi_ci.py
# Purpose:   PreToolUse(Bash) hook — redirect native gh/git calls to hyperi-ci wrappers
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# Complements safety_guard.py. Where safety_guard blocks *dangerous* commands,
# this hook blocks *suboptimal* commands and tells Claude to use the hyperi-ci
# wrapper instead. Only active when hyperi-ci is on PATH — otherwise exits
# silently so hyperi-ai remains fully functional without hyperi-ci installed.
"""PreToolUse(Bash) hook — prefer hyperi-ci wrappers over native tools.

When `hyperi-ci` is installed and on PATH, intercepts bare `gh run`,
`gh workflow run`, `gh release`, and `git push` calls and tells Claude to
use the hyperi-ci wrapper instead. This gives the hyperi-ci CLI priority
in AI workflows without breaking native tool access for humans.

Graceful degradation:
  - If hyperi-ci is NOT on PATH, the hook exits silently (implicit allow).
  - If hyperi-ci IS on PATH but the command doesn't match a known pattern,
    the hook exits silently.
  - If the command sets HYPERCI_ALLOW_NATIVE=1 (inline env var), the hook
    exits silently. This is the escape hatch for legitimate native tool use
    (e.g. diagnosing a hyperi-ci bug, comparing behaviours).
  - Skip-list includes commands hyperi-ci itself wraps internally (so the
    hook does not re-trigger on its own work) and read-only gh queries that
    hyperi-ci has no wrapper for.

Contract:
  - Read JSON from stdin (Claude Code hook input).
  - On match: print JSON with permissionDecision="deny" and a redirect reason.
  - On no match: exit silently (implicit allow).

The intent is to steer LLM tool choice, not to prevent humans from ever
running native tools. Humans can always set HYPERCI_ALLOW_NATIVE=1 or
temporarily disable the hook.
"""

import re
import shutil
import sys
from pathlib import Path
from typing import List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))

import common  # noqa: E402


# ---------------------------------------------------------------------------
# Redirect rules: (regex, hyperi-ci equivalent, explanation)
# ---------------------------------------------------------------------------
#
# Regex matches the START of a command (after optional leading env vars).
# The redirect message tells Claude which hyperi-ci command to use instead.
#
# IMPORTANT: Order matters. More specific patterns must come before generic
# ones (e.g. `gh run watch` before `gh run`).

_REDIRECTS: List[Tuple[re.Pattern[str], str, str]] = [
    # --- git push -> hyperi-ci push ----------------------------------------
    (
        re.compile(r"^\s*git\s+push\b"),
        "hyperi-ci push",
        "Use `hyperi-ci push` instead of bare `git push`. It runs pre-push "
        "checks, handles the semantic-release rebase, and supports `--release` "
        "(auto-publish if CI passes) and `--no-ci` (skip CI on this push). "
        "See `hyperi-ci push --help`.",
    ),
    # --- gh run watch -> hyperi-ci watch -----------------------------------
    (
        re.compile(r"^\s*gh\s+run\s+watch\b"),
        "hyperi-ci watch",
        "Use `hyperi-ci watch` instead of `gh run watch`. It auto-detects the "
        "latest run on the current branch, shows per-job progress, and returns "
        "the correct exit code (0=success, 1=failed, 2=timeout).",
    ),
    # --- gh run view --log-failed -> hyperi-ci logs --failed ---------------
    (
        re.compile(r"^\s*gh\s+run\s+view\b.*(--log-failed|--log\b)"),
        "hyperi-ci logs --failed",
        "Use `hyperi-ci logs --failed` instead of `gh run view --log-failed`. "
        "It filters to failed steps only, supports `--job`, `--step`, `--grep`, "
        "and `--tail` filters, and auto-detects the latest run.",
    ),
    # --- gh run list -> hyperi-ci watch (auto-detects) ---------------------
    # Skip if --json or --jq is used — that's automation, not "find my run"
    (
        re.compile(r"^\s*gh\s+run\s+list\b(?!.*--json)(?!.*--jq)"),
        "hyperi-ci watch",
        "Use `hyperi-ci watch` (auto-detects latest run on current branch) "
        "instead of `gh run list` for finding your most recent CI run. "
        "If you need structured output, use `gh run list --json` explicitly.",
    ),
    # --- gh workflow run -> hyperi-ci trigger ------------------------------
    (
        re.compile(r"^\s*gh\s+workflow\s+run\b"),
        "hyperi-ci trigger",
        "Use `hyperi-ci trigger` instead of `gh workflow run`. It resolves the "
        "workflow from `.hyperi-ci.yaml`, handles branch defaults, and supports "
        "`--watch` to block until the run completes.",
    ),
    # --- gh release create / delete (publish flow) -------------------------
    # Read-only gh release view is intentionally NOT redirected — it's the
    # simplest way to inspect an existing GH Release and hyperi-ci has no
    # equivalent one-shot inspector.
    (
        re.compile(r"^\s*gh\s+release\s+(create|delete|upload)\b"),
        "hyperi-ci release",
        "Use `hyperi-ci release <tag>` instead of `gh release create/delete/"
        "upload`. It handles the full publish pipeline (build, GH Release, "
        "registries, R2). Use `hyperi-ci release --list` to see unpublished "
        "tags. If you are deleting a release to re-publish, run "
        "`gh release delete <tag>` explicitly with HYPERCI_ALLOW_NATIVE=1.",
    ),
]


# ---------------------------------------------------------------------------
# Skip patterns: commands that must NOT trigger a redirect
# ---------------------------------------------------------------------------
#
# These run WITHIN hyperi-ci itself (or in hyperi-ci's internals) and must
# pass through untouched to avoid infinite recursion or breaking internal
# workflows.

_SKIP_PATTERNS: List[re.Pattern[str]] = [
    # Explicit escape hatch — any command prefixed with HYPERCI_ALLOW_NATIVE=1
    re.compile(r"\bHYPERCI_ALLOW_NATIVE\s*=\s*1\b"),
    # hyperi-ci sets HYPERCI_PUSH=1 before calling git push internally
    re.compile(r"\bHYPERCI_PUSH\s*=\s*1\b"),
    # The hyperi-ci CLI itself — don't redirect when already using the wrapper
    re.compile(r"^\s*hyperi-ci\b"),
    # uvx invocations of hyperi-ci
    re.compile(r"^\s*uvx\s+.*\bhyperi-ci\b"),
    # Git read-only queries — no hyperi-ci wrapper and not worth blocking
    re.compile(
        r"^\s*git\s+(status|log|show|diff|blame|branch|tag|remote|ls-files|rev-parse|describe|config|fetch|pull|stash|add|commit|checkout|switch|merge|rebase|reflog|cherry-pick|rm)\b"
    ),
    # gh read-only queries that have no hyperi-ci wrapper
    re.compile(
        r"^\s*gh\s+(auth|api|repo|pr|issue|browse|codespace|search|label|ruleset|variable|cache|attestation|extension|alias|gist|secret|ssh-key|gpg-key|org|project|status)\b"
    ),
    # gh release view is read-only and has no hyperi-ci equivalent
    re.compile(r"^\s*gh\s+release\s+(view|list|download)\b"),
]


def _hyperi_ci_available() -> bool:
    """Check if hyperi-ci CLI is on PATH.

    Returns True if the hyperi-ci binary (or uvx wrapper) is callable.
    If False, the hook exits silently — hyperi-ai works standalone.
    """
    return shutil.which("hyperi-ci") is not None


def _should_skip(command: str) -> bool:
    """Return True if the command matches any skip pattern."""
    for pattern in _SKIP_PATTERNS:
        if pattern.search(command):
            return True
    return False


def _find_redirect(command: str) -> Optional[Tuple[str, str]]:
    """Return (replacement, reason) if the command matches a redirect rule."""
    for pattern, replacement, reason in _REDIRECTS:
        if pattern.search(command):
            return (replacement, reason)
    return None


def _build_deny_message(replacement: str, reason: str) -> str:
    """Build the full deny message shown to Claude."""
    return (
        f"REDIRECT: Use `{replacement}` instead.\n\n"
        f"{reason}\n\n"
        f"If you genuinely need the native tool (e.g. to diagnose a "
        f"hyperi-ci issue or compare behaviour), prefix the command with "
        f"`HYPERCI_ALLOW_NATIVE=1 ...` to bypass this hook."
    )


def main() -> None:
    hook_input = common.read_hook_input()

    tool_input = hook_input.get("tool_input", {})
    command = tool_input.get("command", "")
    if not command:
        return

    # Graceful degradation: if hyperi-ci isn't installed, never interfere.
    if not _hyperi_ci_available():
        return

    # Skip-list check first — avoid infinite recursion on hyperi-ci's own calls.
    if _should_skip(command):
        return

    # Try to match a redirect rule.
    match = _find_redirect(command)
    if match is None:
        return

    replacement, reason = match
    message = _build_deny_message(replacement, reason)

    print(
        common.hook_response(
            "PreToolUse",
            permission_decision="deny",
            decision_reason=message,
        )
    )


if __name__ == "__main__":
    main()
