#!/usr/bin/env python3
# HYPERCI_INLINE: true
"""
Universal AI file merge script - reads merge config from defaults.yaml.

Merges AI assistant files defined in ai.merges configuration using the master
merge_file() function which auto-detects file types and delegates to
specialized merge functions.

Actions:
- check: Verify target files exist
- setup: Merge files from templates
- clean: Remove AI assistant files (if force mode)
"""

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
    """Check if AI merge targets exist."""
    # Import ci_lib functions (dynaconf always available via wrapper)
    from ci_lib import get_ci_config, get_ci_paths, logger

    paths = get_ci_paths()
    config = get_ci_config()

    # Get merge list from config (use dot notation for Dynaconf merge support)
    merges = config.get("ai.merges", [])

    if not merges:
        logger.warning("No AI files configured for merging")
        logger.info("This may indicate:")
        logger.info(
            "  1. ci-local/ci.yaml has 'ai:' section without 'dynaconf_merge: true'"
        )
        logger.info("  2. Old ci/ submodule version (update with: cd ci && git pull)")
        logger.info("  3. Missing ai.merges in ci/modules/common/defaults.yaml")
        return 0

    missing = []
    for merge_spec in merges:
        # Skip conditional merges in check (they're resolved at setup time)
        if merge_spec.get("conditional"):
            continue

        target = Path(merge_spec["target"])
        if not target.is_absolute():
            target = paths["project_root"] / target

        if not target.exists():
            missing.append(str(target.relative_to(paths["project_root"])))

    if missing:
        logger.info(f"{len(missing)} AI file(s) will be created on setup:")
        for f in missing:
            logger.info(f"  - {f}")
    else:
        logger.info("All AI merge target(s) exist")

    return 0


def setup() -> int:
    """Merge AI files according to configuration."""
    # Import ci_lib functions (dynaconf always available via wrapper)
    from ci_lib import get_ci_config, get_ci_paths, logger, merge_file

    paths = get_ci_paths()
    config = get_ci_config()
    ci_dir = paths["ci_dir"]
    project_root = paths["project_root"]

    # Get merge list from config (use dot notation for Dynaconf merge support)
    merges = config.get("ai.merges", [])

    if not merges:
        logger.warning("No AI files configured for merging")
        logger.info("This may indicate:")
        logger.info(
            "  1. ci-local/ci.yaml has 'ai:' section without 'dynaconf_merge: true'"
        )
        logger.info("  2. Old ci/ submodule version (update with: cd ci && git pull)")
        logger.info("  3. Missing ai.merges in ci/modules/common/defaults.yaml")
        return 0

    logger.info(f"Merging {len(merges)} AI file(s) from templates...")

    merged_count = 0
    skipped_count = 0
    failed = []

    for merge_spec in merges:
        source_path = merge_spec["source"]
        target_path = merge_spec["target"]
        marker = merge_spec.get("marker")
        if_missing = merge_spec.get("if_missing", False)
        copy_overwrite = merge_spec.get("copy_overwrite", False)
        conditional = merge_spec.get("conditional")

        # Resolve source path (relative to ci_dir)
        source = ci_dir / source_path

        # Resolve target path (relative to project_root)
        target = Path(target_path)
        if not target.is_absolute():
            target = project_root / target

        # Check if source exists
        if not source.exists():
            # Don't fail on conditional sources (they may not exist for all tiers)
            if conditional:
                logger.info(f"Skipping conditional source: {source_path}")
                skipped_count += 1
                continue
            else:
                logger.warning(f"Source not found: {source_path}")
                failed.append(target_path)
                continue

        # Merge using master merge function (auto-detects file type)
        changed, message = merge_file(
            source,
            target,
            marker=marker,
            if_missing=if_missing,
            copy_overwrite=copy_overwrite,
        )

        if changed:
            logger.info(message)
            merged_count += 1
        else:
            if if_missing and target.exists():
                skipped_count += 1
            else:
                # Only log if there's a message (avoid empty INFO lines)
                if message:
                    logger.info(message)
                else:
                    # DEBUG: Log when message is empty to help diagnose issues
                    logger.debug(
                        f"Merge returned changed=False with empty message for {target_path}"
                    )

    # Summary
    logger.info(
        f"Merged {merged_count} file(s), skipped {skipped_count}, failed {len(failed)}"
    )

    if failed:
        logger.error(f"Failed to merge: {', '.join(failed)}")
        return 1

    return 0


def clean() -> int:
    """Remove AI assistant files."""
    from ci_lib import logger

    logger.info("Clean not implemented (use force mode to remove AI files)")
    return 0


def main() -> int:
    """Main entry point."""
    from ci_lib import logger

    if len(sys.argv) < 2:
        logger.error("Usage: 15-merge-files.py [check|install|clean]")
        return 1

    action = sys.argv[1]

    if action == "check":
        return check()
    elif action == "install":
        return setup()
    elif action == "clean":
        return clean()
    else:
        logger.error(f"Unknown action: {action}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
