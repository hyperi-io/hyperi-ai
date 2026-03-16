#!/usr/bin/env python3
# Project:   HyperI AI
# File:      hooks/on_compact.py
# Purpose:   SessionStart(compact) hook — re-inject standards after context compaction
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# Stdout is injected into Claude's context after compaction.
"""SessionStart(compact) hook.

Re-injects coding standards after Claude Code compacts the context window.
Standards and project state are lost during compaction; this hook restores them.
"""

import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import common  # noqa: E402


def main() -> None:
    today = date.today()
    print(
        f"**Current date: {today.strftime('%Y-%m-%d %A')}** (use this, not training data)"
    )
    print("")

    project_dir = common.get_project_dir()
    text, _loaded = common.inject_cag_payload(project_dir)
    print(text)
    print("")

    print("Context compacted. Full standards re-injected.")


if __name__ == "__main__":
    main()
