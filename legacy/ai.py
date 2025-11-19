#!/usr/bin/env python3
"""
AI Assistant Setup Tool - Master Script

This tool manages AI assistant configuration for HS-CI projects.
Follows standardized .d module pattern (same as bootstrap and run).

Usage:
    ci/ai install --mode merge   # Install AI configuration
    ci/ai check                  # Check requirements
    ci/ai clean                  # Remove AI configuration

Environment Variables:
    CI_AI_MERGE_MODE=<mode>      # Merge mode: merge, no-overwrite, force, skip
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# Find ci_lib.py by walking up from script location
_p = Path(__file__).resolve()
for _ in range(10):  # Max 10 levels up
    if (_p / "modules" / "common" / "ci_lib.py").exists():
        sys.path.insert(0, str(_p / "modules" / "common"))
        break
    _p = _p.parent
else:
    raise ImportError("Cannot find ci_lib.py")

from ci_lib import get_ci_paths

paths = get_ci_paths()
PROJECT_ROOT = paths["project_root"]
CI_DIR = paths["ci_dir"]
CI_LOCAL_DIR = paths["ci_local_dir"]


def parse_args():
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="AI Assistant Setup Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  ci/ai install --mode merge     # Full install (merge settings)
  ci/ai install --mode force     # Force overwrite everything
  ci/ai check                    # Check Node.js/npx requirements
  ci/ai clean                    # Remove .claude/ and docs/standards/

Environment Variables:
  CI_AI_MERGE_MODE=merge         # Same as --mode merge
        """,
    )

    parser.add_argument(
        "action", choices=["install", "check", "clean"], help="Action to perform"
    )

    parser.add_argument(
        "--mode",
        choices=["merge", "no-overwrite", "force", "skip"],
        default=None,
        help="Merge mode for setup (default: from ENV or ci.yaml)",
    )

    parser.add_argument(
        "--claude-pro",
        action="store_true",
        help="Use Claude Pro tier settings (4K tokens, sonnet only)",
    )

    parser.add_argument(
        "--claude-pro-max",
        action="store_true",
        help="Use Claude Pro Max tier settings (16K tokens, opus+sonnet) - default",
    )

    # Parse args with strict validation (reject unknown args)
    args, unknown = parser.parse_known_args()

    if unknown:
        print(f"\n[ERROR] Unknown/invalid arguments: {' '.join(unknown)}")
        print("\nValid arguments:")
        parser.print_help()
        sys.exit(1)

    return args


def discover_ai_scripts():
    """
    Discover AI scripts from:
    1. ci/modules/common/ai.d/ (universal scripts, priority 0)
    2. ci/modules/<language>/ai.d/ (language-specific scripts, priority 0)
    3. ci-local/ai.d/ (project-specific scripts, priority 1 - run AFTER ci/)

    Note: Only loads common + THE CONFIGURED LANGUAGE (not all language modules)

    Returns:
        List of (script_path, label, priority) tuples, sorted by priority then filename
    """
    scripts = []

    # 1. Discover from ci/modules/*/ai.d/ (priority 0)
    # Load ONLY: common + configured language (not all language modules!)
    from ci_lib import get_configured_language

    configured_language = get_configured_language()

    # Always load common
    modules_to_load = ["common"]

    # Add configured language (if not 'core')
    if configured_language and configured_language != "core":
        modules_to_load.append(configured_language)

    modules_dir = CI_DIR / "modules"
    if modules_dir.exists():
        for module_name in modules_to_load:
            module_dir = modules_dir / module_name
            if module_dir.is_dir():
                ai_d_dir = module_dir / "ai.d"
                if ai_d_dir.exists():
                    layer_scripts = sorted(
                        [
                            p
                            for p in ai_d_dir.iterdir()
                            if p.is_file()
                            and p.suffix == ".py"
                            and not p.name.endswith(".disabled")
                        ]
                    )
                    for script in layer_scripts:
                        scripts.append((script, module_name, 0))

    # 2. Discover from ci-local/ai.d/ (priority 1 - run AFTER ci/ scripts)
    ai_d_dir = PROJECT_ROOT / "ci-local" / "ai.d"
    if ai_d_dir.exists():
        layer_scripts = sorted(
            [
                p
                for p in ai_d_dir.iterdir()
                if p.is_file()
                and (p.suffix in [".py", ".sh"])
                and not p.name.endswith(".disabled")
            ]
        )
        for script in layer_scripts:
            scripts.append((script, "local", 1))

    # Sort: priority 0 (ci/) runs before priority 1 (ci-local/)
    # Within same priority, sort by filename
    scripts.sort(key=lambda x: (x[2], x[0].name, x[1]))

    return scripts


def run_ai_script(script_path: Path, action: str, label: str) -> int:
    """
    Run a single ai/.d script with the given action.

    Args:
        script_path: Path to .d script
        action: Action to perform (install, check, clean)
        label: Label for logging (common, python)

    Returns:
        Exit code from script
    """
    script_name = script_path.name
    print(f"[INFO] AI {action} [{label}]: {script_name}")

    try:
        result = subprocess.run(
            [sys.executable, str(script_path), action], cwd=PROJECT_ROOT
        )
        return result.returncode
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Script {script_name} failed with code {e.returncode}")
        return e.returncode
    except Exception as e:
        print(f"[ERROR] Failed to run {script_name}: {e}")
        return 1


def main() -> int:
    """Main entrypoint."""
    args = parse_args()

    # Determine merge mode from: CLI arg > ENV > defaults.yaml
    merge_mode = args.mode
    if merge_mode is None:
        # Check ENV variable
        merge_mode = os.getenv("CI_AI_MERGE_MODE")
        if merge_mode is None:
            # Use config cascade (from defaults.yaml)
            # TODO: Use get_config_value() when integrated
            # For now, default to 'merge' (matches defaults.yaml)
            merge_mode = "merge"

    # Set ENV for .d scripts to use
    os.environ["CI_AI_MERGE_MODE"] = merge_mode

    # Determine Claude tier (Pro or Pro Max)
    if args.claude_pro:
        os.environ["CI_AI_CLAUDE_TIER"] = "pro"
    elif args.claude_pro_max:
        os.environ["CI_AI_CLAUDE_TIER"] = "pro-max"
    else:
        # Default to Pro Max if not specified
        os.environ.setdefault("CI_AI_CLAUDE_TIER", "pro-max")

    print(f"[INFO] AI tool: action={args.action}, mode={merge_mode}")

    # Discover and run ai/src scripts
    scripts = discover_ai_scripts()

    if not scripts:
        print("[WARN] No ai/src scripts found")
        return 0

    # Run each script with the action
    for script_path, label, priority in scripts:
        exit_code = run_ai_script(script_path, args.action, label)
        if exit_code != 0:
            print(f"[ERROR] AI {args.action} failed in {script_path.name}")
            return exit_code

    print(f"[INFO] AI {args.action} completed successfully")
    return 0


if __name__ == "__main__":
    sys.exit(main())
