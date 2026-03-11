#!/usr/bin/env python3
# Project:   HyperI AI
# File:      hooks/survey_tools_cli.py
# Purpose:   CLI wrapper for tool survey — used by /setup-claude command
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
"""CLI tool survey — prints installed/missing/available tools for /setup-claude."""

import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import common  # noqa: E402


def main() -> None:
    available, missing_installable, missing_unknown = common.survey_tools()

    desc_map = {name: desc for name, _, desc in common._TOOL_SURVEY}

    print("## Tool Survey Results")
    print()

    # Installed
    print("### Installed")
    if available:
        for name in available:
            alias = common._resolve_tool_binary(name)
            binary_path = shutil.which(alias) if alias else None
            desc = desc_map.get(name, "")
            path_info = f" ({binary_path})" if binary_path else ""
            if alias and alias != name:
                print(f"  {name} ({alias}){path_info}: {desc}")
            else:
                print(f"  {name}{path_info}: {desc}")
    else:
        print("  (none)")

    # Missing but installable
    print()
    print("### Not Installed (available in package repos)")
    if missing_installable:
        for entry in missing_installable:
            print(f"  {entry}")
    else:
        print("  (none — all tools installed)")

    # Missing and unknown
    if missing_unknown:
        print()
        print("### Not Available in Repos")
        for name in missing_unknown:
            desc = desc_map.get(name, "")
            print(f"  {name}: {desc} (manual install needed)")

    # Summary
    print()
    total = len(available) + len(missing_installable) + len(missing_unknown)
    print(f"Total: {len(available)}/{total} installed", end="")
    if missing_installable:
        print(f", {len(missing_installable)} installable from repos", end="")
    print()


if __name__ == "__main__":
    main()
