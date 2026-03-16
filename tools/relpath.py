#!/usr/bin/env python3
"""Calculate relative path from one directory to a file.

Usage: relpath.py <from_dir> <to_file>

Prints the relative path from <from_dir> to <to_file>.
Portable replacement for realpath --relative-to (not available on macOS).

Exit codes:
  0 = success
  1 = error
"""
# Project:   HyperI AI
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED

import os.path
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <from_dir> <to_file>", file=sys.stderr)
        return 1

    print(os.path.relpath(sys.argv[2], sys.argv[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
