#!/usr/bin/env python3
# HYPERCI_INLINE: true
"""
Merge Claude Code environment variables into ~/.bashrc idempotently.

Moves ENV settings from settings.local.json to .bashrc to work around
Claude Code settings.local.json ENV processing bugs.

Actions:
- check: Verify .bashrc is writable
- install: Merge Claude Code ENV vars into ~/.bashrc
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
    """Check if .bashrc is writable."""
    from ci_lib import logger

    bashrc = Path.home() / ".bashrc"

    if not bashrc.exists():
        logger.warning("~/.bashrc does not exist (will be created)")
        return 0

    if not bashrc.is_file():
        logger.error("~/.bashrc exists but is not a file")
        return 1

    if not bashrc.stat().st_mode & 0o200:
        logger.error("~/.bashrc is not writable")
        return 1

    logger.info("~/.bashrc is writable")
    return 0


def install() -> int:
    """Merge Claude Code ENV vars into ~/.bashrc."""
    from ci_lib import logger, merge_bash_env

    bashrc = Path.home() / ".bashrc"

    # Claude Code ENV vars (moved from settings.local.json due to ENV processing bugs)
    env_vars = {
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-5-20250929[1m]",
        "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "12288",
        "USE_BUILTIN_RIPGREP": "1",
        "CLAUDE_CODE_ENABLE_PARALLEL_TOOLS": "1",
        "CLAUDE_CODE_MAX_PARALLEL_TOOLS": "3",
    }

    # Merge into .bashrc
    changed, message = merge_bash_env(bashrc, env_vars, marker="HYPERCI_CLAUDE_CODE")

    if changed:
        logger.info(message)
        logger.info("Run 'source ~/.bashrc' or restart terminal to apply changes")
    else:
        logger.info(message)

    return 0


def main() -> int:
    """Main entry point."""
    from ci_lib import logger

    if len(sys.argv) < 2:
        logger.error("Usage: 20-bashrc-env.py [check|install]")
        return 1

    action = sys.argv[1]

    if action == "check":
        return check()
    elif action == "install":
        return install()
    else:
        logger.error(f"Unknown action: {action}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
