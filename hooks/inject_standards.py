#!/usr/bin/env python3
# Project:   HyperI AI
# File:      hooks/inject_standards.py
# Purpose:   SessionStart(startup) hook — inject coding standards + auto-reattach
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# Stdout is injected into Claude's context at session start.
"""SessionStart(startup) hook.

Detects project technologies, injects matching coding standards into Claude's
context, and auto-reattaches if the ai submodule has been updated since last deploy.
"""

import sys
from datetime import date
from pathlib import Path

# Allow import from same directory
sys.path.insert(0, str(Path(__file__).resolve().parent))

import common  # noqa: E402


def main() -> None:
    project_dir = common.get_project_dir()

    # Migrate ai/ → hyperi-ai/ if old name detected
    old_ai = project_dir / "ai"
    new_ai = project_dir / "hyperi-ai"
    if old_ai.exists() and not new_ai.exists():
        try:
            from migrate_submodule_name import main as migrate_main
            migrate_main()
        except Exception as exc:
            print(f"[migrate] auto-migration failed: {exc}", file=sys.stderr)

    # Auto-update: silently pull latest hyperi-ai submodule if behind remote
    common.auto_update_submodules(project_dir)

    # Auto-reattach: detect submodule updates and re-deploy if needed
    reattach_msg = common.check_version_and_reattach(project_dir)

    # Inject current date — models often hallucinate dates from training data
    today = date.today()
    print(f"**Current date: {today.strftime('%Y-%m-%d %A')}**")
    print(f"Your training data may show an older date — IGNORE IT. Today is {today.isoformat()}.")
    print(f"Use this date for ALL date-dependent decisions (web searches, version lookups, etc.).")
    print("")

    # Inject standards
    text, loaded = common.inject_rules(project_dir)
    print(text)

    # Report reattach if it happened
    if reattach_msg:
        print("")
        print(reattach_msg)


if __name__ == "__main__":
    main()
