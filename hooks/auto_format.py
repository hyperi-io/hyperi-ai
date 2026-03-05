#!/usr/bin/env python3
# Project:   HyperI AI
# File:      hooks/auto_format.py
# Purpose:   PostToolUse(Edit|Write|MultiEdit) hook — auto-format edited files
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# PostToolUse stdout is NOT injected into Claude's context (GitHub issue #18427).
# This hook is a side-effect only — it formats files after Claude edits them.
"""PostToolUse(Edit|Write|MultiEdit) hook.

Detects the file language from extension and runs the appropriate formatter
if it is installed (ruff, rustfmt, prettier, gofmt, shfmt, clang-format).
Always exits 0 — never blocks the workflow.
"""

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import common  # noqa: E402


def main() -> None:
    hook_input = common.read_hook_input()

    # Extract file path from tool input
    tool_input = hook_input.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    if not file_path:
        return

    # Get formatter command
    cmd = common.get_formatter(file_path)
    if not cmd:
        return

    # Run formatter (best-effort, never fail)
    try:
        subprocess.run(cmd, capture_output=True, timeout=30)
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass


if __name__ == "__main__":
    main()
