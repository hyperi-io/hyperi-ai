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
            rc = migrate_main()
            if rc == 0:
                print("**Submodule migrated: `ai/` → `hyperi-ai/`**")
                print("Run `git add .gitmodules hyperi-ai .claude && "
                      'git commit -m "chore: migrate ai submodule to hyperi-ai"` '
                      "to commit the rename.")
                print("")
            else:
                print("**WARNING: Submodule migration may be incomplete.**")
                print("See manual steps: `git submodule deinit -f ai && git rm -f ai "
                      "&& rm -rf .git/modules/ai && git submodule add "
                      "https://github.com/hyperi-io/hyperi-ai.git hyperi-ai`")
                print("")
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

    # Inject bash efficiency rules (always-on — prevents permission prompt stalls)
    print("")
    print("---")
    print("")
    print(common.bash_efficiency_rules())
    print("")

    # Survey available tools and report what CC can use
    available, missing_installable, missing_unknown = common.survey_tools()
    print("")
    print(common.format_tool_survey(available, missing_installable, missing_unknown))
    print("")


if __name__ == "__main__":
    main()
