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
    print("""
---

## Context Recovery (Post-Compaction)

Context was compacted. Coding standards have been re-injected below.
**Run `/load` to restore full project state** (STATE.md, TODO.md, git sync).

---
""")

    today = date.today()
    print(f"**Current date: {today.strftime('%Y-%m-%d %A')}** (use this, not training data)")
    print("")

    project_dir = common.get_project_dir()
    text, loaded = common.inject_rules(project_dir)
    print(text)

    # Re-inject bash efficiency rules (always-on — critical post-compact)
    print("")
    print("---")
    print("")
    print(common.bash_efficiency_rules())
    print("")

    # Re-survey available tools
    available, missing = common.survey_tools()
    print("")
    print(common.format_tool_survey(available, missing))
    print("")

    print("")
    print("**Run `/load` now** to restore full project context (STATE.md, TODO.md, submodule updates).")


if __name__ == "__main__":
    main()
