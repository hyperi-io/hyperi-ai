#!/usr/bin/env python3
# Project:   HyperI AI
# File:      hooks/safety_guard.py
# Purpose:   PreToolUse(Bash) hook — block dangerous commands with corrective context
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# Complements settings.json permissions (which just block/ask) by giving Claude
# a corrective reason so it can self-correct instead of retrying blindly.
"""PreToolUse(Bash) hook.

Checks bash commands against a conservative set of dangerous patterns
(rm -rf /, force push to main, dd, mkfs, fork bomb, etc.).
If dangerous: outputs JSON with permissionDecision: deny and a helpful reason.
If safe: exits silently (implicit allow).
"""

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import common  # noqa: E402


def _current_branch() -> str:
    """Get the current git branch name, or empty string on error."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return ""


def main() -> None:
    hook_input = common.read_hook_input()

    # Extract command from Bash tool input
    tool_input = hook_input.get("tool_input", {})
    command = tool_input.get("command", "")
    if not command:
        return

    # Check against dangerous patterns
    result = common.check_command_safety(command)
    if result:
        _pattern, reason = result
        print(
            common.hook_response(
                "PreToolUse",
                permission_decision="deny",
                decision_reason=reason,
            )
        )
        return

    # Block git commit/push while on the release branch
    if re.search(r"git\s+(commit|push)\b", command):
        branch = _current_branch()
        if branch == "release":
            print(
                common.hook_response(
                    "PreToolUse",
                    permission_decision="deny",
                    decision_reason=(
                        "BLOCKED: You are on the release branch. Never commit or "
                        "push directly to release. Switch to main first: "
                        "'git checkout main'. All changes flow: main -> PR -> release."
                    ),
                )
            )


if __name__ == "__main__":
    main()
