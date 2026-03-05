#!/usr/bin/env python3
# Project:   HyperI AI
# File:      hooks/subagent_context.py
# Purpose:   SubagentStart hook — inject coding standards into subagent context
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# Subagents get a fresh context and do NOT inherit SessionStart-injected standards.
# This hook injects them via additionalContext in the JSON response.
"""SubagentStart hook.

When Claude spawns a subagent (Explore, Plan, or custom), this hook injects
the same coding standards that SessionStart loaded into the parent agent.
Without this, all code written by subagents would ignore project standards.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import common  # noqa: E402


def main() -> None:
    # Read hook input (contains agent_type, agent_id)
    common.read_hook_input()

    project_dir = common.get_project_dir()
    text, loaded = common.inject_rules(project_dir)

    if loaded:
        print(common.hook_response(
            "SubagentStart",
            additional_context=text,
        ))


if __name__ == "__main__":
    main()
