#!/usr/bin/env python3
# Project:   HyperI AI
# File:      hooks/lint_check.py
# Purpose:   Stop hook — lint modified files and feed errors back to Claude
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# EXPERIMENTAL: The Stop hook has known reliability issues (GitHub issue #24327).
# Claude may sometimes stop instead of acting on exit 2 feedback.
# The stop_hook_active guard prevents infinite loops.
"""Stop hook.

When Claude finishes responding, checks for lint errors in modified files.
If errors are found, exits with code 2 and sends errors to stderr,
which forces Claude to continue and fix the issues.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import common  # noqa: E402


def main() -> None:
    hook_input = common.read_hook_input()

    # CRITICAL: prevent infinite loop. If this is a re-check after Claude
    # already received feedback from a previous Stop hook, let it stop.
    if hook_input.get("stop_hook_active", False):
        return

    project_dir = common.get_project_dir()
    errors = common.lint_modified_files(project_dir)

    if errors:
        # Exit 2 = blocking error. stderr is fed back to Claude.
        error_text = "\n\n".join(errors)
        print(
            f"Lint errors found in modified files. Please fix before continuing:\n\n{error_text}",
            file=sys.stderr,
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
