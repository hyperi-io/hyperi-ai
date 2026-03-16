#!/usr/bin/env python3
"""Merge MCP server configuration into a project's .mcp.json.

Usage: merge_mcp.py <source> <destination> [--force]

Merges mcpServers from <source> into <destination>.
- If <destination> doesn't exist, copies <source>.
- If <destination> exists, adds missing servers (preserves existing).
- With --force, overwrites existing servers with source values.

Exit codes:
  0 = success
  1 = error
"""
# Project:   HyperI AI
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED

import json
import sys


def main() -> int:
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <source> <destination> [--force]", file=sys.stderr)
        return 1

    src_path = sys.argv[1]
    dst_path = sys.argv[2]
    force = "--force" in sys.argv[3:]

    try:
        with open(src_path) as f:
            source = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Error reading source {src_path}: {e}", file=sys.stderr)
        return 1

    try:
        with open(dst_path) as f:
            existing = json.load(f)
    except FileNotFoundError:
        # No existing config -- write source directly
        with open(dst_path, "w") as f:
            json.dump(source, f, indent=2)
            f.write("\n")
        return 0
    except (OSError, json.JSONDecodeError) as e:
        print(f"Error reading destination {dst_path}: {e}", file=sys.stderr)
        return 1

    # Merge servers
    servers = existing.setdefault("mcpServers", {})
    for name, config in source.get("mcpServers", {}).items():
        if name not in servers or force:
            servers[name] = config

    with open(dst_path, "w") as f:
        json.dump(existing, f, indent=2)
        f.write("\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
