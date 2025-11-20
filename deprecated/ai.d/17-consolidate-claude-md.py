#!/usr/bin/env python3
# HYPERCI_INLINE: true
"""
Consolidate CLAUDE.md into STATE.md and create symlink.

This script handles the migration from CLAUDE.md to STATE.md:
1. Merge STATE.md template (done by 15-merge-files.py)
2. If CLAUDE.md exists as a regular file (not symlink):
   - Merge CLAUDE.md content into STATE.md
   - Remove CLAUDE.md file
   - Create symlink: CLAUDE.md -> STATE.md

Actions:
- check: Verify if CLAUDE.md needs consolidation
- install: Consolidate CLAUDE.md into STATE.md and create symlink
- clean: Remove CLAUDE.md symlink (if exists)
"""

import os
import sys
from pathlib import Path

# Find ci_lib.py by walking up from script location
_current = Path(__file__).resolve()
for _ in range(10):
    _candidate = _current / "modules" / "common" / "ci_lib.py"
    if _candidate.exists():
        sys.path.insert(0, str(_current / "modules" / "common"))
        break
    _current = _current.parent
else:
    raise ImportError("Cannot find ci_lib.py - is this script in the correct location?")


def check() -> int:
    """Check if CLAUDE.md needs consolidation."""
    from ci_lib import get_ci_paths

    # Support test mode: use CWD if CI_TEST_MODE is set
    if os.getenv("CI_TEST_MODE"):
        project_root = Path.cwd()
    else:
        paths = get_ci_paths()
        project_root = paths["project_root"]

    claude_md = project_root / "CLAUDE.md"
    state_md = project_root / "STATE.md"

    # Check if CLAUDE.md exists
    if not claude_md.exists():
        print("[OK] No CLAUDE.md found (already consolidated or never existed)")
        return 0

    # Check if CLAUDE.md is already a symlink
    if claude_md.is_symlink():
        target = claude_md.resolve()
        if target == state_md.resolve():
            print("[OK] CLAUDE.md already symlinked to STATE.md")
            return 0
        else:
            print(f"[WARN] CLAUDE.md is a symlink but points to: {target}")
            return 0

    # CLAUDE.md exists as a regular file - needs consolidation
    print(
        "[INFO] CLAUDE.md exists as regular file - will be consolidated into STATE.md"
    )
    return 0


def install() -> int:
    """Consolidate CLAUDE.md into STATE.md and create symlink."""
    from ci_lib import get_ci_paths, merge_file

    # Support test mode: use CWD if CI_TEST_MODE is set
    if os.getenv("CI_TEST_MODE"):
        project_root = Path.cwd()
    else:
        paths = get_ci_paths()
        project_root = paths["project_root"]

    claude_md = project_root / "CLAUDE.md"
    state_md = project_root / "STATE.md"

    # Check if STATE.md exists
    if not state_md.exists():
        print("[ERROR] STATE.md not found - should be created by previous merge step")
        return 1

    # Check if CLAUDE.md exists
    if not claude_md.exists():
        # New project - create symlink immediately
        print("[INFO] No CLAUDE.md found - creating symlink to STATE.md")
        if not state_md.exists():
            print("[ERROR] STATE.md not found - should be created by merge system")
            return 1

        claude_md.symlink_to("STATE.md")
        print("[OK] Created CLAUDE.md → STATE.md symlink")
        return 0

    # Check if CLAUDE.md is already a symlink
    if claude_md.is_symlink():
        target = claude_md.resolve()
        if target == state_md.resolve():
            print("[OK] CLAUDE.md already symlinked to STATE.md")
            return 0
        else:
            print(f"[WARN] CLAUDE.md is a symlink to {target}, leaving as-is")
            return 0

    # CLAUDE.md exists as a regular file - consolidate it
    print("[INFO] Found CLAUDE.md as regular file - consolidating...")

    # Step 1: Merge CLAUDE.md content into STATE.md
    # The merge_file function will append CLAUDE.md content to STATE.md
    # with a marker to track where it came from
    marker = "HYPERCI_CLAUDE_MD: Merged from CLAUDE.md"
    changed, message = merge_file(
        source=claude_md,
        target=state_md,
        marker=marker,
        if_missing=False,  # Always merge, even if marker exists
    )

    if changed:
        print(f"[OK] Merged CLAUDE.md into STATE.md: {message}")
    else:
        print(f"[INFO] CLAUDE.md content already in STATE.md: {message}")

    # Step 2: Remove CLAUDE.md file
    try:
        claude_md.unlink()
        print("[OK] Removed CLAUDE.md file")
    except Exception as e:
        print(f"[ERROR] Failed to remove CLAUDE.md: {e}")
        return 1

    # Step 3: Create symlink: CLAUDE.md -> STATE.md
    try:
        # Create relative symlink (more portable)
        claude_md.symlink_to("STATE.md")
        print("[OK] Created symlink: CLAUDE.md -> STATE.md")
    except Exception as e:
        print(f"[ERROR] Failed to create symlink: {e}")
        return 1

    print("[OK] CLAUDE.md consolidation complete")
    return 0


def clean() -> int:
    """Remove CLAUDE.md symlink if it exists."""
    from ci_lib import get_ci_paths

    # Support test mode: use CWD if CI_TEST_MODE is set
    if os.getenv("CI_TEST_MODE"):
        project_root = Path.cwd()
    else:
        paths = get_ci_paths()
        project_root = paths["project_root"]

    claude_md = project_root / "CLAUDE.md"

    if not claude_md.exists():
        print("[INFO] CLAUDE.md does not exist")
        return 0

    if claude_md.is_symlink():
        try:
            claude_md.unlink()
            print("[OK] Removed CLAUDE.md symlink")
        except Exception as e:
            print(f"[ERROR] Failed to remove CLAUDE.md symlink: {e}")
            return 1
    else:
        print("[WARN] CLAUDE.md exists but is not a symlink - not removing")
        print("[WARN] Run consolidation (install) to migrate to STATE.md")

    return 0


def main() -> int:
    """Main entry point."""
    if len(sys.argv) < 2:
        print("[ERROR] Usage: 17-consolidate-claude-md.py [check|install|clean]")
        return 1

    action = sys.argv[1]

    if action == "check":
        return check()
    elif action == "install":
        return install()
    elif action == "clean":
        return clean()
    else:
        print(f"[ERROR] Unknown action: {action}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
