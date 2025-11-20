#!/usr/bin/env python3
"""
Shared CI/Bootstrap Utilities Library
======================================

This module provides common functions for all CI and bootstrap scripts.
Runs in unified .venv (project root) containing both runtime and CI tools.

Configuration Cascade (HyperSec Standard)
==========================================

ALL configuration follows this priority cascade (highest to lowest):

    1. CLI args/switches  # --host=X --port=Y (runtime, apps/CLIs only)
    2. ENV variables      # MYAPP_HOST=prod.example.com (session/deployment)
    3. .env file          # Local secrets (gitignored, never commit)
    4. settings.{env}.yaml # Environment-specific (settings.production.yaml)
    5. settings.yaml      # Project base config (version-controlled)
    6. defaults.yaml      # Safe fallback defaults (local dev)
    7. Hard-coded         # Last resort in code (default= parameter)

**Example - database.host config:**

    Priority    Source                          Value               Context
    --------    ------                          -----               -------
    1. CLI      --host prod.db.com              "prod.db.com"       (CLI override)
    2. ENV      MYAPP_DATABASE_HOST=test.db     "test.db"           (CI/staging)
    3. .env     MYAPP_DATABASE_HOST=local.db    "local.db"          (dev secrets)
    4. {env}    settings.production.yaml        "prod-rw.db.com"    (prod deploy)
    5. base     settings.yaml                   "postgres.local"    (team default)
    6. defaults defaults.yaml                   "localhost"         (safe fallback)
    7. code     default="localhost"             "localhost"         (hard-coded)

**HS-CI Adaptation:**

    HS-CI uses ci.yaml instead of settings.yaml:
    - ci.yaml (replaces settings.yaml - project CI config)
    - No environment-specific files yet (future: ci.production.yaml)
    - .env for secrets (JFrog credentials, tokens)
    - defaults.yaml for module defaults (common/, python/)

**File Naming:**

    settings.yaml        # DEFAULT for apps (most readable)
    config.yaml          # Alternative (more technical)
    ci.yaml              # HS-CI specific (namespace clarity)

**How to Use (Two Approaches):**

    # APPROACH 1: Use config object directly (recommended, cascade automatic)
    from ci_lib import get_ci_config

    config = get_ci_config()  # Cascade built-in via Dynaconf!

    # Access via attributes (Pythonic)
    mode = config.ai.merge_mode         # Auto-cascade: ENV > .env > ci.yaml > defaults
    enabled = config.nuitka.enabled     # Works for any config path

    # Or dict-style with fallback
    mode = config.get("ai.merge_mode", "skip")
    enabled = config.get("nuitka.enabled", False)

    # APPROACH 2: Use helper function (adds CLI arg support)
    from ci_lib import get_config_value

    # Simple usage (auto-generates env key)
    mode = get_config_value("ai.merge_mode", default="skip")

    # With CLI argument (for apps/CLIs)
    mode = get_config_value("ai.merge_mode", cli_value=args.mode, default="skip")

**Developer Choice:**
- Use config object for simplicity (90% of cases)
- Use get_config_value() when you need CLI arg support

**Configuration Files:**

    ci-local/ci.yaml          # Project-specific CI configuration
    ci/modules/*/defaults.yaml # Module defaults (common, python, etc.)
    .env                      # Local secrets (NEVER commit)

Basic Usage
===========

    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).parent.parent / "common"))
    from ci_lib import logger, get_ci_paths, get_configured_language, get_config_value

    # Get standard paths
    paths = get_ci_paths()
    PROJECT_ROOT = paths['project_root']
    CI_DIR = paths['ci_dir']

    # Get configuration with cascade
    merge_mode = get_config_value("ai.merge_mode", default="skip")
    enabled = get_config_value("nuitka.enabled", default=False)

Subprocess Usage Policy
=======================

This library uses subprocess for external tool invocations where appropriate.
We intentionally use subprocess rather than Python wrappers in these cases:

1. **git** - Standard CLI tool, available everywhere
   - Libraries like GitPython wrap subprocess internally anyway
   - Direct subprocess is more transparent and debuggable
   - Consolidated via helper: get_current_branch()

2. **Build tools** (python -m build, twine) - Use Python modules directly
   - These are true Python libraries, no subprocess needed
   - Already using: python -m build, python -m twine

3. **System commands** - Use subprocess when needed
   - Examples: bash scripts during bootstrap
   - Better than trying to reimplement shell logic in Python

Philosophy: Use native Python where it makes sense (build, twine, requests),
use subprocess for external tools that are standard parts of the environment (git).
"""
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

# External dependencies (available in .venv after bootstrap)
try:
    from dynaconf import Dynaconf

    DYNACONF_AVAILABLE = True
except ImportError:
    DYNACONF_AVAILABLE = False
    Dynaconf = None

try:
    from mergedeep import merge as mergedeep_merge

    MERGEDEEP_AVAILABLE = True
except ImportError:
    MERGEDEEP_AVAILABLE = False
    mergedeep_merge = None


# ============================================================================
# Standard src Script Setup (ALWAYS use this at the top of src scripts)
# ============================================================================
#
# STANDARD PATTERN for all src scripts (bootstrap/src/, run/src/, ai/src/):
#
#     #!/usr/bin/env python3
#     import sys
#     from pathlib import Path
#
#     # Find ci_lib.py by walking up from script location
#     _p = Path(__file__).resolve()
#     for _ in range(10):  # Max 10 levels up
#         if (_p / "modules" / "common" / "ci_lib.py").exists():
#             sys.path.insert(0, str(_p / "modules" / "common"))
#             break
#         _p = _p.parent
#     else:
#         raise ImportError("Cannot find ci_lib.py")
#
#     from ci_lib import get_project_root, get_ci_dir, get_ci_local_dir
#
#     PROJECT_ROOT = get_project_root()
#     CI_DIR = get_ci_dir()
#     CI_LOCAL_DIR = get_ci_local_dir()
#
# ============================================================================

try:
    from loguru import logger as _loguru_logger

    LOGURU_AVAILABLE = True
except ImportError:
    LOGURU_AVAILABLE = False
    _loguru_logger = None


# ============================================================================
# Path Utilities
# ============================================================================


def get_project_root() -> Path:
    """
    Get the project root directory.

    For files in ci/ submodule, returns the parent project root (not ci/).
    This handles git submodules correctly.

    Returns:
        Path to project root
    """
    # __file__ is in ci/modules/common/ci_lib.py
    # ci/ is a git submodule, so we need parent of ci/
    ci_dir = (
        Path(__file__).resolve().parent.parent.parent
    )  # ci/modules/common/ -> ci/modules/ -> ci/
    project_root = ci_dir.parent  # ci/ -> project root
    return project_root


def get_ci_paths() -> dict[str, Path]:
    """
    Get all standard CI paths in a single call.

    This is the ONE function that returns ALL paths used across CI scripts.
    Use this at the top of .d scripts to get all paths at once.

    Returns:
        Dictionary with keys:
        - 'project_root': Parent project path (e.g., /projects/hyperlib)
        - 'ci_dir': CI submodule path (e.g., /projects/hyperlib/ci) - READ-ONLY
        - 'ci_local_dir': CI-local writable path (e.g., /projects/hyperlib/ci-local)
        - 'tmp_dir': Temporary files path (e.g., /projects/hyperlib/.tmp) - gitignored
        - 'git_root': Git repository root (e.g., /projects/hyperlib)
        - 'ci_log_dir': CI logs path (e.g., /projects/hyperlib/ci-local/logs) - gitignored

    Example usage in .d scripts:
        paths = get_ci_paths()
        PROJECT_ROOT = paths['project_root']
        CI_DIR = paths['ci_dir']
        TMP_DIR = paths['tmp_dir']
        # etc.

    Or unpack all at once:
        paths = get_ci_paths()
        PROJECT_ROOT = paths['project_root']
        CI_DIR = paths['ci_dir']
        CI_LOCAL_DIR = paths['ci_local_dir']
        TMP_DIR = paths['tmp_dir']
        GIT_ROOT = paths['git_root']
        CI_LOG_DIR = paths['ci_log_dir']
    """
    project_root = get_project_root()

    return {
        "project_root": project_root,
        "ci_dir": project_root / "ci",
        "ci_local_dir": project_root / "ci-local",
        "tmp_dir": project_root / ".tmp",
        "git_root": project_root,  # Git root is same as project root
        "ci_log_dir": project_root / "ci-local" / "logs",
    }


# ============================================================================
# Command Execution
# ============================================================================


def run_command(
    cmd: list[str],
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    check: bool = True,
    capture_output: bool = False,
) -> subprocess.CompletedProcess:
    """
    Run a command with consistent error handling.

    Args:
        cmd: Command and arguments as list
        cwd: Working directory (defaults to project root)
        env: Environment variables (merged with os.environ)
        check: Raise exception on non-zero exit
        capture_output: Capture stdout/stderr

    Returns:
        CompletedProcess result
    """
    if cwd is None:
        cwd = get_project_root()

    if env:
        full_env = os.environ.copy()
        full_env.update(env)
    else:
        full_env = None

    return subprocess.run(
        cmd,
        cwd=cwd,
        env=full_env,
        check=check,
        capture_output=capture_output,
        text=bool(capture_output),
    )


# ============================================================================
# Logging Utilities (Loguru with RFC 3339 timestamps)
# ============================================================================

# Configure module-level logger with RFC 3339 timestamps (plain text for CI)
# Handle case where loguru is not yet installed (during bootstrap)
try:
    from loguru import logger as _loguru_logger

    # Remove default handler
    _loguru_logger.remove()

    # Get log level from config (default: INFO)
    log_level = os.getenv("CI_LOG_LEVEL", "INFO").upper()

    # Get project root for log directory (inline to avoid circular dependency)
    # Find ci-local directory (walk up from ci/ to find project root)
    _script_dir = Path(__file__).resolve().parent
    _ci_dir = _script_dir.parent.parent  # ci/modules/common -> ci
    _project_root = _ci_dir.parent
    _log_dir = _project_root / "ci-local" / "logs"
    _log_dir.mkdir(parents=True, exist_ok=True)

    # Log format (RFC 3339 timestamps, plain text for CI)
    _log_format = (
        "{time:YYYY-MM-DDTHH:mm:ss.SSSZZ} | "
        "{level: <8} | "
        "{name}:{function}:{line} - "
        "{message}"
    )

    # Add console handler
    _loguru_logger.add(
        sys.stderr,
        format=_log_format,
        colorize=False,
        level=log_level,
    )

    # Add file handler with rotation (like logrotate)
    # - Rotate at 10MB
    # - Keep 7 days of logs (7 files * 10MB = 70MB max)
    # - Compress old logs
    _loguru_logger.add(
        _log_dir / "ci.log",
        format=_log_format,
        colorize=False,
        level=log_level,
        rotation="10 MB",
        retention="7 days",
        compression="gz",
    )

    logger = _loguru_logger
except ImportError:
    # Loguru not installed yet (bootstrap phase)
    # Create a simple logger replacement with RFC3339 timestamps
    import datetime

    class SimpleLogger:
        """Simple logger for bootstrap phase (before loguru is installed)."""

        def __init__(self):
            self.log_level = os.getenv("CI_LOG_LEVEL", "INFO").upper()

        def _timestamp(self):
            """Generate RFC3339 timestamp."""
            now = datetime.datetime.now(datetime.timezone.utc)
            return now.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + now.strftime("%z")

        def info(self, msg, *args):
            formatted_msg = msg % args if args else msg
            print(f"{self._timestamp()} | INFO     | {formatted_msg}")

        def warning(self, msg, *args):
            formatted_msg = msg % args if args else msg
            print(f"{self._timestamp()} | WARNING  | {formatted_msg}", file=sys.stderr)

        def error(self, msg, *args):
            formatted_msg = msg % args if args else msg
            print(f"{self._timestamp()} | ERROR    | {formatted_msg}", file=sys.stderr)

        def debug(self, msg, *args):
            if self.log_level == "DEBUG":
                formatted_msg = msg % args if args else msg
                print(f"{self._timestamp()} | DEBUG    | {formatted_msg}", file=sys.stderr)

    logger = SimpleLogger()


# ============================================================================
# Git Utilities (via subprocess - git is standard tool)
# ============================================================================
# NOTE: We use subprocess for git operations rather than GitPython because:
# - git is a standard tool available everywhere
# - GitPython wraps subprocess internally anyway
# - Direct subprocess is more transparent and debuggable
# - Fewer dependencies, simpler CI environment
# ============================================================================


def get_current_branch() -> str:
    """
    Get current git branch name.

    Returns:
        Branch name (e.g., 'main')

    Raises:
        subprocess.CalledProcessError: If git command fails
    """
    result = run_command(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True,
        check=True,
    )
    return result.stdout.strip()


def get_configured_language() -> str | None:
    """
    Get configured project language from ci-local/ci.yaml.

    Reads project.language or project.languages from ci.yaml configuration.

    Returns:
        Language name (e.g., 'python', 'rust') or None if not configured

    Examples:
        >>> lang = get_configured_language()
        >>> if lang == 'python':
        >>>     print("Python project")
    """
    paths = get_ci_paths()
    ci_yaml = paths["ci_local_dir"] / "ci.yaml"

    if not ci_yaml.exists():
        return None

    try:
        import yaml

        with open(ci_yaml) as f:
            config = yaml.safe_load(f) or {}

        project = config.get("project", {})

        # Check for single language (project.language)
        if "language" in project:
            return project["language"]

        # Check for multiple languages (project.languages) - return first
        if "languages" in project:
            languages = project["languages"]
            if isinstance(languages, list) and languages:
                return languages[0]
            elif isinstance(languages, str):
                return languages

        return None
    except Exception:
        return None


def get_available_language_modules() -> list[str]:
    """
    Discover available language modules in ci/modules/.

    Scans ci/modules/ directory for language modules (excluding 'common').
    A valid language module contains at least one .d directory.

    Returns:
        List of available language module names (e.g., ['python', 'rust', 'node'])

    Examples:
        >>> langs = get_available_language_modules()
        >>> print(f"Available: {', '.join(langs)}")
        Available: python, rust, node
    """
    paths = get_ci_paths()
    modules_dir = paths["ci_dir"] / "modules"

    if not modules_dir.exists():
        return []

    available = []
    for module_dir in sorted(modules_dir.iterdir()):
        # Skip 'common' (not a language module)
        if module_dir.name == "common":
            continue

        # Valid language module must have at least one .d directory
        if module_dir.is_dir():
            has_dotd = any(
                (module_dir / d).exists() for d in ["bootstrap.d", "run.d", "ai.d"]
            )
            if has_dotd:
                available.append(module_dir.name)

    return available


def validate_language_module(language: str) -> tuple[bool, str]:
    """
    Validate that a language module exists and is properly structured.

    Args:
        language: Language name to validate (e.g., 'python', 'rust')

    Returns:
        Tuple of (is_valid: bool, message: str)

    Examples:
        >>> valid, msg = validate_language_module('python')
        >>> if not valid:
        >>>     print(f"Invalid: {msg}")
    """
    if language == "core":
        return (True, "Using 'core' (common-only, no language module)")

    paths = get_ci_paths()
    module_dir = paths["ci_dir"] / "modules" / language

    if not module_dir.exists():
        available = get_available_language_modules()
        return (
            False,
            f"Language module '{language}' not found. Available: {', '.join(available)}",
        )

    if not module_dir.is_dir():
        return (False, f"'{language}' exists but is not a directory")

    # Check for at least one .d directory
    dotd_dirs = ["bootstrap.d", "run.d", "ai.d"]
    has_dotd = any((module_dir / d).exists() for d in dotd_dirs)

    if not has_dotd:
        return (
            False,
            f"Language module '{language}' missing .d directories ({', '.join(dotd_dirs)})",
        )

    return (True, f"Language module '{language}' is valid")


# ============================================================================
# Version Management
# ============================================================================

# ============================================================================
# System Dependency Hints
# ============================================================================


def print_system_dependency_hint(
    package_name: str, command_name: str | None = None
) -> None:
    """
    Print platform-specific installation hints for missing system dependencies.

    This is the standard way to notify users about missing system dependencies
    across all bootstrap scripts. Bootstrap should NEVER auto-install system
    packages - only provide clear guidance.

    Args:
        package_name: Human-readable name of the package (e.g., "C compiler", "Node.js")
        command_name: Optional command to check (e.g., "gcc", "node")

    Example:
        if not shutil.which("gcc"):
            print_system_dependency_hint("C compiler (gcc)", "gcc")
    """
    import platform

    system = platform.system()
    logger.error(f"System dependency not found: {package_name}")

    if command_name:
        logger.error(f"  Missing command: {command_name}")

    logger.error("")
    logger.error("Installation instructions:")

    if system == "Linux":
        try:
            with open("/etc/os-release") as f:
                os_release = f.read().lower()

            if "fedora" in os_release or "rhel" in os_release or "centos" in os_release:
                logger.error("  Fedora/RHEL: sudo dnf install <package>")
                if (
                    package_name.lower() == "c compiler"
                    or "gcc" in package_name.lower()
                ):
                    logger.error(
                        "  Example: sudo dnf install gcc gcc-c++ python3-devel"
                    )
            elif "debian" in os_release or "ubuntu" in os_release:
                logger.error("  Debian/Ubuntu: sudo apt-get install <package>")
                if (
                    package_name.lower() == "c compiler"
                    or "gcc" in package_name.lower()
                ):
                    logger.error(
                        "  Example: sudo apt-get install build-essential python3-dev"
                    )
            else:
                logger.error("  Use your distribution's package manager")
        except Exception:
            logger.error("  Use your distribution's package manager (dnf, apt, etc.)")

    elif system == "Darwin":
        logger.error("  macOS: Use Homebrew or system installers")
        if (
            package_name.lower() == "c compiler"
            or "gcc" in package_name.lower()
            or "clang" in package_name.lower()
        ):
            logger.error("  Example: xcode-select --install")
        else:
            logger.error("  Example: brew install <package>")

    elif system == "Windows":
        logger.error("  Windows: Use system installers or package managers")
        if package_name.lower() == "c compiler":
            logger.error("  Example: Visual Studio Build Tools or MinGW")
    else:
        logger.error(f"  Platform: {system} (consult platform documentation)")

    logger.error("")


# ============================================================================
# Module Initialization
# ============================================================================


# ============================================================================
# CI Configuration Management (Dynaconf)
# ============================================================================
# Migrated from ci_config.py for consolidation


# Lazy initialization of settings
_ci_settings = None


# Convenience accessors for common CI settings
def build_type() -> str:
    """Get build type: 'nuitka' if CI_NUITKA=1, else 'package' (default)."""
    # Check CI_NUITKA first (modern boolean flag)
    if os.environ.get("CI_NUITKA") == "1":
        return "nuitka"

    # Fallback to config value
    value = get_config_value("build.type", "CI_BUILD_TYPE", None)
    if value:
        return value

    # Legacy: Check old BUILD_PROFILE for backward compatibility
    legacy_value = os.environ.get("BUILD_PROFILE")
    if legacy_value:
        return legacy_value

    return "package"


def coverage_source() -> str:
    """Get CI_COVERAGE_SOURCE (default: empty)."""
    return get_config_value("coverage.source", "CI_COVERAGE_SOURCE", "")


def nuitka_protection() -> str:
    """Get NUITKA_PROTECTION level (default: recommended)."""
    return get_config_value("nuitka.protection", "NUITKA_PROTECTION", "recommended")


# GitHub Actions detection
# JFrog credentials (keep ARTIFACTORY_* naming)
def artifactory_username() -> str:
    """Get ARTIFACTORY_USERNAME from environment."""
    return os.environ.get("ARTIFACTORY_USERNAME", "")


def artifactory_password() -> str:
    """Get ARTIFACTORY_PASSWORD from environment."""
    return os.environ.get("ARTIFACTORY_PASSWORD", "")


def artifactory_pypi_host() -> str:
    """Get ARTIFACTORY_PYPI_HOST or construct from ci.yaml."""
    # Allow ENV override
    env_override = os.environ.get("ARTIFACTORY_PYPI_HOST")
    if env_override:
        return env_override

    # Build from ci.yaml configuration
    jfrog_host = get_config_value("repository.jfrog.host", default="hypersec.jfrog.io")
    pypi_repo = get_config_value("repository.jfrog.pypi_repo", default="hypersec-pypi-local")

    return f"https://{jfrog_host}/artifactory/api/pypi/{pypi_repo}"


def artifactory_storage_api_url() -> str:
    """Get JFrog storage API base URL from ci.yaml."""
    jfrog_host = get_config_value("repository.jfrog.host", default="hypersec.jfrog.io")
    pypi_repo = get_config_value("repository.jfrog.pypi_repo", default="hypersec-pypi-local")

    return f"https://{jfrog_host}/artifactory/api/storage/{pypi_repo}"


def artifactory_ui_url() -> str:
    """Get JFrog UI URL from ci.yaml."""
    jfrog_host = get_config_value("repository.jfrog.host", default="hypersec.jfrog.io")
    pypi_repo = get_config_value("repository.jfrog.pypi_repo", default="hypersec-pypi-local")

    return f"https://{jfrog_host}/ui/repos/tree/General/{pypi_repo}"


def jfrog_api_timeout() -> int:
    """Get JFrog API timeout from ci.yaml."""
    return get_config_value("repository.jfrog.api_timeout", default=30)


def github_repo_full() -> str:
    """Get full GitHub repository name (org/repo)."""
    return f"{github_org()}/{github_repo()}"


def github_actions_url() -> str:
    """Get GitHub Actions URL."""
    return f"https://github.com/{github_repo_full()}/actions"


def package_name() -> str:
    """Get package name from pyproject.toml."""
    # Read from pyproject.toml [project.name] (most reliable)
    pyproject_path = get_ci_paths()["project_root"] / "pyproject.toml"
    if pyproject_path.exists():
        try:
            import tomllib
            with open(pyproject_path, "rb") as f:
                data = tomllib.load(f)
            pkg_name = data.get("project", {}).get("name")
            if pkg_name:
                return pkg_name
        except Exception:
            pass

    # Fallback to config (legacy)
    return get_config_value("package.name", default=None)


def verify_timeout() -> int:
    """Get publish verification timeout from ci.yaml."""
    return get_config_value("publish.verify_timeout", default=600)


def verify_enabled() -> bool:
    """Check if publish verification is enabled."""
    return get_ci_bool("verify_publish", False) or get_ci_bool(
        "publish.verify_enabled", False
    )


# ============================================================================
# Configuration Cascade (Copied AS-IS from hyperlib/config.py)
# ============================================================================
# NOTE: This code is copied from hyperlib to avoid circular dependency.
# Uses dynaconf (available in .venv).


def get_ci_config() -> Any:
    """
    Get CI configuration with automatic cascade built-in.

    **The cascade is automatic** - developers don't need to implement it!
    Just get the config object and access values:

        config = get_ci_config()
        mode = config.ai.merge_mode         # Cascade automatic!
        enabled = config.nuitka.enabled     # ENV > .env > ci.yaml > defaults

    **Full Cascade (Dynaconf handles this automatically):**

        1. ENV variables    → CI_AI_MERGE_MODE=skip
        2. .env file        → CI_AI_MERGE_MODE=force
        3. ci.yaml          → ai.merge_mode: merge
        4. python/defaults  → ai.merge_mode: no-overwrite (language-specific)
        5. common/defaults  → ai.merge_mode: skip (universal)
        6. Code fallback    → config.get("ai.merge_mode", "default_value")

    **Zero Configuration Required:**
    - No manual ENV checks
    - No file loading logic
    - No cascade implementation
    - Just: config.get(path) or config.path.to.value

    Returns:
        Dynaconf settings object with cascade built-in (or empty dict if unavailable)

    Example:
        config = get_ci_config()
        host = config.database.host  # Automatic cascade: ENV > .env > files > defaults
    """
    if not DYNACONF_AVAILABLE:
        # Fallback to simple dict if dynaconf not available
        return {}

    project_root = get_project_root()
    ci_dir = project_root / "ci"

    # Build settings files list (REVERSE order - dynaconf loads first = lowest priority)
    # Dynaconf merges in order, so first file has lowest priority
    settings_files = []

    # Layer 5: Common defaults (lowest file priority, universal)
    common_defaults = ci_dir / "modules" / "common" / "defaults.yaml"
    if common_defaults.exists():
        settings_files.append(str(common_defaults))

    # Layer 4b: Language defaults (higher than common, language-specific)
    # Load defaults for configured language
    try:
        language = get_configured_language()
        if language != "core":  # core means common-only, no language module
            language_defaults = ci_dir / "modules" / language / "defaults.yaml"
            if language_defaults.exists():
                settings_files.append(str(language_defaults))
    except Exception:
        # Language not configured yet, skip language defaults
        pass

    # Layer 4a: Project ci.yaml (highest file priority, project-specific)
    # Located in ci-local/ (not project root) to separate config from code
    ci_yaml = project_root / "ci-local" / "ci.yaml"
    if ci_yaml.exists():
        settings_files.append(str(ci_yaml))

    # Initialize Dynaconf with multi-layer defaults
    # Pattern adapted from hyperlib/config.py for HS-CI's multi-defaults approach
    config = Dynaconf(
        envvar_prefix="CI",  # Layer 2: ENV variables (CI_*)
        settings_files=settings_files,  # Layer 4-5: yaml cascade
        load_dotenv=True,  # Layer 3: .env file
        environments=False,  # Single config (no dev/prod envs)
        merge_enabled=True,  # Enable @merge directive for list concatenation
        # Full cascade: CLI (set by master) > ENV > .env > ci.yaml > python/defaults > common/defaults
    )

    return config


def get_config_value(
    config_path: str, env_key: str = None, default: Any = None, cli_value: Any = None
) -> Any:
    """
    Get configuration value using HyperSec 7-layer cascade.

    **Configuration Cascade (Highest to Lowest Priority):**

        1. CLI args/switches  → cli_value parameter (apps/CLIs only)
        2. ENV variables      → CI_* prefix (e.g., CI_AI_MERGE_MODE)
        3. .env file          → Project secrets (gitignored)
        4. settings.{env}.yaml → Environment-specific (future: ci.production.yaml)
        5. settings.yaml      → Project base (HS-CI uses ci.yaml)
        6. defaults.yaml      → Module defaults (common/, python/)
        7. Hard-coded         → default parameter (code fallback)

    **Typical Usage Patterns:**

        # Pattern 1: Simple config read (most common)
        mode = get_config_value("ai.merge_mode", default="skip")
        # Auto-generates env key: CI_AI_MERGE_MODE
        # Cascade: ENV > .env > ci.yaml > "skip"

        # Pattern 2: With CLI argument (for apps/CLIs)
        mode = get_config_value("ai.merge_mode", cli_value=args.mode, default="skip")
        # Cascade: args.mode > CI_AI_MERGE_MODE > .env > ci.yaml > "skip"

        # Pattern 3: Custom env key (rare)
        mode = get_config_value("ai.merge_mode", env_key="CUSTOM_MODE", default="skip")
        # Cascade: CLI > CUSTOM_MODE > .env > ci.yaml > "skip"

        # Pattern 4: No env override (config-file only)
        package = get_config_value("ai.mcp.servers.memory.package",
                                   env_key=None, default="mcp-knowledge-graph")
        # Cascade: ci.yaml > defaults.yaml > "mcp-knowledge-graph"

    **Config Path Examples:**

        "ai.merge_mode"           → CI_AI_MERGE_MODE (auto-generated)
        "nuitka.enabled"          → CI_NUITKA_ENABLED
        "tests.min_coverage"      → CI_TESTS_MIN_COVERAGE
        "ci.version"              → CI_CI_VERSION

    **Where to Use:**

        ✓ Bootstrap scripts (setup, install actions)
        ✓ Runtime scripts (build, test, publish)
        ✓ Git hooks (commit validation)
        ✓ AI tools (configuration loading)
        ✗ Don't use for secrets (use ENV or .env directly)

    Args:
        config_path: Dot-notation path in ci.yaml (e.g., "ai.merge_mode")
                    Auto-generates CI_* env key from this path
        env_key: ENV variable name override
                 - None: Skip ENV check (config-file only)
                 - String: Use custom env key
                 - Omit: Auto-generate from config_path
        default: Default fallback value (lowest priority)
                 Used when no other source provides a value
        cli_value: CLI argument value (highest priority)
                  Only use for apps/CLIs with argparse

    Returns:
        Configuration value from highest priority source
        Type depends on config (str, bool, int, list, dict)

    **Implementation Note:**
    Uses Dynaconf for config file cascade (ENV > .env > yaml layers).
    Falls back to ENV-only if Dynaconf unavailable (bootstrap edge case).
    """
    # Layer 1: CLI argument (highest priority)
    # CLI flags are only available in app/CLI contexts
    # For libraries/packages, this is always None
    if cli_value is not None:
        return cli_value

    # Auto-generate ENV key from config_path if not explicitly provided
    # Example: "ai.merge_mode" → "CI_AI_MERGE_MODE"
    # Set to None to skip ENV check (config-file only)
    if env_key is None and config_path:
        env_key = "CI_" + config_path.replace(".", "_").upper()

    # Layers 2-5: ENV → .env → ci.yaml → defaults.yaml
    # Dynaconf handles the file cascade automatically
    if DYNACONF_AVAILABLE:
        config = get_ci_config()  # Loads all config files with cascade
        value = config.get(config_path, default)  # Get value with fallback
        return value
    else:
        # Bootstrap edge case: Dynaconf not yet installed
        # Fallback to ENV-only check (limited cascade)
        if env_key:
            return os.getenv(env_key, default)
        return default


# ============================================================================
# Logging (Copied AS-IS patterns from hyperlib/logger.py)
# ============================================================================
# NOTE: Patterns copied from hyperlib to avoid circular dependency.
# Uses loguru (available in .venv).

# ============================================================================
# JSON and Markdown Merge Utilities
# ============================================================================


def deep_merge_json(base: dict, override: dict) -> dict:
    """
    Deep merge two JSON dictionaries (override wins on conflicts).

    Used by AI settings merge (20-merge-settings.py) and other config merges.

    Merge rules:
    - Nested dicts are merged recursively
    - Lists are replaced (not merged)
    - Primitives from override replace base

    Args:
        base: Base dictionary (lower priority)
        override: Override dictionary (higher priority)

    Returns:
        Merged dictionary (does not modify inputs)

    Example:
        base = {"a": 1, "b": {"c": 2}}
        override = {"b": {"d": 3}, "e": 4}
        result = deep_merge_json(base, override)
        # {"a": 1, "b": {"c": 2, "d": 3}, "e": 4}
    """
    if MERGEDEEP_AVAILABLE:
        # Use standard mergedeep library (battle-tested)
        import copy

        result = copy.deepcopy(base)
        mergedeep_merge(result, override)
        return result
    else:
        # Fallback to custom implementation (for early bootstrap)
        import copy

        result = copy.deepcopy(base)

        for key, value in override.items():
            if (
                key in result
                and isinstance(result[key], dict)
                and isinstance(value, dict)
            ):
                # Recursive merge for nested dicts
                result[key] = deep_merge_json(result[key], value)
            else:
                # Replace for everything else (lists, primitives, new keys)
                result[key] = copy.deepcopy(value)

        return result


def deep_merge_no_overwrite(base: dict, template: dict) -> dict:
    """
    Deep merge template into base WITHOUT overwriting existing values.

    Used for pyproject.toml merging where project-specific values should be preserved.

    Merge rules:
    - Nested dicts are merged recursively
    - Lists from template are APPENDED to base lists (unique items only)
    - Primitives from template are ADDED only if key doesn't exist in base
    - Existing primitive values in base are NEVER replaced

    Args:
        base: Base dictionary (existing project config - takes priority)
        template: Template dictionary (CI defaults - only fills gaps)

    Returns:
        Merged dictionary (does not modify inputs)

    Example:
        base = {"a": 1, "b": {"c": 2}, "d": ["existing"]}
        template = {"a": 999, "b": {"c": 999, "e": 3}, "d": ["new", "existing"], "f": 4}
        result = deep_merge_no_overwrite(base, template)
        # {"a": 1, "b": {"c": 2, "e": 3}, "d": ["existing", "new"], "f": 4}
        # Note: a and b.c kept their base values; d got "new" appended; b.e and f were added
    """
    import copy

    result = copy.deepcopy(base)

    for key, value in template.items():
        if key not in result:
            # Key doesn't exist in base - add from template
            result[key] = copy.deepcopy(value)
        elif isinstance(result[key], dict) and isinstance(value, dict):
            # Both are dicts - recursive merge (still no-overwrite)
            result[key] = deep_merge_no_overwrite(result[key], value)
        elif isinstance(result[key], list) and isinstance(value, list):
            # Both are lists - append unique items from template
            for item in value:
                if item not in result[key]:
                    result[key].append(item)
        # else: key exists in base with non-dict/non-list value - keep base value (no overwrite)

    return result


def append_markdown_file(
    target_file: Path, source_file: Path, source_label: str
) -> tuple[bool, str]:
    """
    Append markdown file content with duplicate detection (IDEMPOTENT).

    Used by AI STATE.md append (30-append-state.py) and standards copy.

    If target exists:
    - Checks for marker to prevent duplicate appends
    - Appends source content with separator and marker

    If target doesn't exist:
    - Creates target with source content

    Args:
        target_file: Target markdown file path
        source_file: Source markdown file path
        source_label: Label for marker (e.g., "ci/common/ai/STATE.md")

    Returns:
        (was_modified, log_message) tuple

    Example:
        was_modified, msg = append_markdown_file(
            Path("STATE.md"),
            Path("ci/common/ai/STATE.md"),
            "ci/common/ai/STATE.md"
        )
        if was_modified:
            print(msg)  # "STATE.md (appended) ← ci/common/ai/STATE.md"
    """
    if not source_file.exists():
        return (False, "")

    # Create marker for idempotent append
    marker = f"<!-- HYPERCI_STATE_MD: {source_label} -->"

    if target_file.exists():
        # File exists - check if already appended
        target_content = target_file.read_text()

        # Idempotent check (prevents duplicates)
        if marker in target_content:
            return (False, "")

        # Append with marker
        source_content = source_file.read_text()
        separator = "\n\n---\n\n"
        appended_content = f"{separator}{marker}\n{source_content}"

        with open(target_file, "a") as f:
            f.write(appended_content)

        return (True, f"{target_file.name} (appended) ← {source_label}")
    else:
        # File doesn't exist - create with marker
        target_file.parent.mkdir(parents=True, exist_ok=True)
        source_content = source_file.read_text()

        with open(target_file, "w") as f:
            f.write(f"{marker}\n{source_content}")

        return (True, f"{target_file.name} (created) ← {source_label}")


def merge_gitignore_file(
    target_file: Path, source_file: Path, source_label: str
) -> tuple[bool, str]:
    """
    Merge .gitignore file with duplicate detection (IDEMPOTENT).

    Merges gitignore patterns from source into target, avoiding duplicates.
    Preserves comments and blank lines. Adds section marker for source tracking.

    Args:
        target_file: Target .gitignore file path
        source_file: Source .gitignore file path
        source_label: Label for marker (e.g., "ci/common")

    Returns:
        (was_modified, log_message) tuple

    Example:
        was_modified, msg = merge_gitignore_file(
            Path(".gitignore"),
            Path("ci/common/.gitignore"),
            "ci/common"
        )
    """
    if not source_file.exists():
        return (False, "")

    # Read source patterns
    source_lines = source_file.read_text().splitlines()

    # Create section markers
    start_marker = f"# === {source_label} gitignore patterns ==="
    end_marker = f"# === End {source_label} ==="

    if target_file.exists():
        target_content = target_file.read_text()

        # Check if already merged (idempotent)
        if start_marker in target_content:
            return (False, "")

        # Get existing patterns (for deduplication)
        existing_patterns = set()
        for line in target_content.splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                existing_patterns.add(line)

        # Filter source patterns to only new ones
        new_patterns = []
        for line in source_lines:
            stripped = line.strip()
            # Keep comments and blank lines as-is
            if not stripped or stripped.startswith("#"):
                new_patterns.append(line)
            # Only add pattern if not already present
            elif stripped not in existing_patterns:
                new_patterns.append(line)
                existing_patterns.add(stripped)

        # Only append if there are new patterns (beyond comments)
        has_new_patterns = any(
            line.strip() and not line.strip().startswith("#") for line in new_patterns
        )

        if has_new_patterns or source_lines:  # Include if has comments too
            with open(target_file, "a") as f:
                f.write("\n\n")
                f.write(start_marker + "\n")
                f.write("\n".join(new_patterns))
                f.write("\n" + end_marker + "\n")

            return (True, f".gitignore (merged) ← {source_label}")
        else:
            return (False, "")
    else:
        # Create new file with marker
        target_file.parent.mkdir(parents=True, exist_ok=True)
        with open(target_file, "w") as f:
            f.write(start_marker + "\n")
            f.write("\n".join(source_lines))
            f.write("\n" + end_marker + "\n")

        return (True, f".gitignore (created) ← {source_label}")


def merge_gitattributes_file(
    target_file: Path, source_file: Path, source_label: str
) -> tuple[bool, str]:
    """
    Merge .gitattributes file with duplicate detection (IDEMPOTENT).

    Merges gitattributes patterns from source into target, avoiding duplicates.
    Preserves comments and blank lines. Adds section marker for source tracking.

    Args:
        target_file: Target .gitattributes file path
        source_file: Source .gitattributes file path
        source_label: Label for marker (e.g., "ci/common")

    Returns:
        (was_modified, log_message) tuple

    Example:
        was_modified, msg = merge_gitattributes_file(
            Path(".gitattributes"),
            Path("ci/common/.gitattributes"),
            "ci/common"
        )
    """
    if not source_file.exists():
        return (False, "")

    # Read source patterns
    source_lines = source_file.read_text().splitlines()

    # Create section markers
    start_marker = f"# === {source_label} gitattributes patterns ==="
    end_marker = f"# === End {source_label} ==="

    if target_file.exists():
        target_content = target_file.read_text()

        # Check if already merged (idempotent)
        if start_marker in target_content:
            return (False, "")

        # Get existing patterns (for deduplication by path pattern)
        existing_patterns = {}
        for line in target_content.splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                # Parse pattern (first token is the path pattern)
                parts = line.split()
                if parts:
                    existing_patterns[parts[0]] = line

        # Filter source patterns to only new ones
        new_patterns = []
        for line in source_lines:
            stripped = line.strip()
            # Keep comments and blank lines as-is
            if not stripped or stripped.startswith("#"):
                new_patterns.append(line)
            else:
                # Check if this path pattern already exists
                parts = stripped.split()
                if parts and parts[0] not in existing_patterns:
                    new_patterns.append(line)
                    existing_patterns[parts[0]] = line

        # Only append if there are new patterns
        has_new_patterns = any(
            line.strip() and not line.strip().startswith("#") for line in new_patterns
        )

        if has_new_patterns or source_lines:
            with open(target_file, "a") as f:
                f.write("\n\n")
                f.write(start_marker + "\n")
                f.write("\n".join(new_patterns))
                f.write("\n" + end_marker + "\n")

            return (True, f".gitattributes (merged) ← {source_label}")
        else:
            return (False, "")
    else:
        # Create new file with marker
        target_file.parent.mkdir(parents=True, exist_ok=True)
        with open(target_file, "w") as f:
            f.write(start_marker + "\n")
            f.write("\n".join(source_lines))
            f.write("\n" + end_marker + "\n")

        return (True, f".gitattributes (created) ← {source_label}")


def uv_install(
    venv: Path,
    target_dir: Path,
    lockfile: Path | None = None,
    pyproject: Path | None = None,
    quiet: bool = False,
    editable: bool = False,
    frozen: bool = True,
) -> bool:
    """
    General-purpose uv installation function.

    Supports two modes:
    1. Locked install (from uv.lock): Uses `uv sync --frozen`
    2. Unlocked install (from pyproject.toml): Uses `uv pip install -e`

    Args:
        venv: Virtual environment directory (e.g., .venv)
        target_dir: Directory containing pyproject.toml/uv.lock
        lockfile: Path to uv.lock (optional, auto-detected from target_dir)
        pyproject: Path to pyproject.toml (optional, auto-detected from target_dir)
        quiet: Suppress output (default: False)
        editable: Install in editable mode (default: False, only for unlocked)
        frozen: Use --frozen flag for locked installs (default: True)

    Returns:
        True if successful, False if failed

    Example:
        from ci_lib import uv_install, get_ci_paths

        paths = get_ci_paths()
        venv = paths['project_root'] / '.venv'
        project_root = paths['project_root']

        # Install from lockfile (preferred)
        success = uv_install(
            venv=venv,
            target_dir=project_root,
            lockfile=project_root / 'uv.lock',
            quiet=True
        )

        # Fallback to unlocked install
        if not success:
            uv_install(
                venv=venv,
                target_dir=project_root,
                pyproject=project_root / 'pyproject.toml',
                editable=True
            )
    """
    import os
    import subprocess

    # Auto-detect lockfile and pyproject if not provided
    if lockfile is None:
        lockfile = target_dir / "uv.lock"
    if pyproject is None:
        pyproject = target_dir / "pyproject.toml"

    ci_python = venv / "bin" / "python"

    # Use system uv (not .venv/bin/uv) - uv manages venvs, shouldn't be inside them
    # Verify uv is available
    try:
        subprocess.run(["uv", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("[ERR] uv not found in PATH", file=sys.stderr)
        print(
            "[ERR] Install: curl -LsSf https://astral.sh/uv/install.sh | sh",
            file=sys.stderr,
        )
        return False

    # Try locked install first (if lockfile exists)
    if lockfile.exists() and pyproject.exists():
        print(f"[INFO] Installing from {lockfile.name} (locked versions)...")
        try:
            cmd = ["uv", "sync"]
            if frozen:
                cmd.append("--frozen")

            kwargs = {
                "cwd": target_dir,
                "env": {**os.environ, "VIRTUAL_ENV": str(venv)},
            }
            if quiet:
                kwargs["stdout"] = subprocess.DEVNULL
                kwargs["stderr"] = subprocess.DEVNULL

            subprocess.check_call(cmd, **kwargs)
            print(f"[OK] Installed from {lockfile.name} (reproducible)")
            return True
        except subprocess.CalledProcessError as e:
            print(
                f"[WARN] Failed to install from {lockfile.name}: {e}", file=sys.stderr
            )
            print(f"[INFO] Falling back to {pyproject.name} (unlocked)...")
            # Fall through to unlocked install

    # Unlocked install (from pyproject.toml)
    if pyproject.exists():
        print(f"[INFO] Installing from {pyproject.name} (version ranges)...")
        try:
            cmd = [
                "uv",
                "pip",
                "install",
                "--python",
                str(ci_python),
            ]
            if editable:
                cmd.extend(["-e", str(target_dir)])
            else:
                cmd.append(str(target_dir))

            kwargs = {"cwd": target_dir}
            if quiet:
                kwargs["stdout"] = subprocess.DEVNULL
                kwargs["stderr"] = subprocess.DEVNULL

            subprocess.check_call(cmd, **kwargs)
            print(f"[OK] Installed from {pyproject.name}")
            if lockfile.parent.exists():
                print(
                    f"[INFO] For reproducibility, run: cd {target_dir.name} && uv lock"
                )
            return True
        except subprocess.CalledProcessError as e:
            print(
                f"[WARN] Failed to install from {pyproject.name}: {e}", file=sys.stderr
            )
            print("[INFO] Continuing anyway (tools may already be installed)")
            return False

    print(
        f"[WARN] No lockfile or pyproject.toml found in {target_dir}", file=sys.stderr
    )
    return False


def run_uv(
    args: list[str], cwd: Path = None, check: bool = True, capture_output: bool = False
) -> subprocess.CompletedProcess:
    """
    Run uv command (system uv, not .venv/bin/uv).

    uv should be installed system-wide:
        curl -LsSf https://astral.sh/uv/install.sh | sh

    Args:
        args: uv command arguments (e.g., ["sync", "--all-extras"])
        cwd: Working directory (default: current directory)
        check: Raise exception on non-zero exit (default: True)
        capture_output: Capture stdout/stderr (default: False)

    Returns:
        CompletedProcess result

    Example:
        # Sync dependencies
        run_uv(["sync", "--all-extras"], cwd=project_root)

        # Install package
        run_uv(
            ["pip", "install", "-e", ".", "--index-strategy", "unsafe-best-match"],
            cwd=project_root,
        )

        # Check version
        result = run_uv(["--version"], capture_output=True, check=False)
    """
    import subprocess

    cmd = ["uv"] + args

    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            check=check,
            capture_output=capture_output,
            text=bool(capture_output),
        )
        return result
    except FileNotFoundError:
        print("[ERR] uv not found in PATH", file=sys.stderr)
        print(
            "[ERR] Install: curl -LsSf https://astral.sh/uv/install.sh | sh",
            file=sys.stderr,
        )
        if check:
            raise
        return subprocess.CompletedProcess(args=cmd, returncode=1, stdout="", stderr="")


def install_project_editable(
    project_root: Path, ci_venv: Path, quiet: bool = True
) -> bool:
    """
    Install project in editable mode into .venv.

    This allows CI tools (like pytest in .venv) to import and test project code.

    Args:
        project_root: Project root directory (contains pyproject.toml)
        ci_venv: CI venv directory (.venv)
        quiet: Suppress output (default: True)

    Returns:
        True if successful, False if failed

    Example:
        from ci_lib import install_project_editable, get_ci_paths

        paths = get_ci_paths()
        success = install_project_editable(
            paths['project_root'],
            paths['project_root'] / '.venv'
        )
    """
    project_pyproject = project_root / "pyproject.toml"
    if not project_pyproject.exists():
        return False

    ci_python = ci_venv / "bin" / "python"

    # Use system uv (not .venv/bin/uv)
    try:
        subprocess.run(["uv", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("[ERR] uv not found in PATH", file=sys.stderr)
        return False

    print("[INFO] Installing project in editable mode into .venv...")
    try:
        cmd = [
            "uv",
            "pip",
            "install",
            "--python",
            str(ci_python),
            "-e",
            str(project_root),
        ]

        kwargs = {"cwd": project_root}
        if quiet:
            kwargs["stdout"] = subprocess.DEVNULL
            kwargs["stderr"] = subprocess.DEVNULL

        subprocess.check_call(cmd, **kwargs)
        print("[OK] Project installed in editable mode in .venv")
        return True
    except subprocess.CalledProcessError as e:
        print(
            f"[WARN] Failed to install project in editable mode: {e}", file=sys.stderr
        )
        print("[INFO] Tests may fail if they need to import project code")
        return False


def merge_file(
    source: Path,
    target: Path,
    marker: str | None = None,
    if_missing: bool = False,
    copy_overwrite: bool = False,
) -> tuple[bool, str]:
    """
    Universal file merge function - auto-detects type from extension.

    Auto-detects merge strategy based on file extension:
    - .json, .jsonc → deep merge JSON
    - .toml → deep merge TOML (Python 3.12+)
    - .md, .markdown → append with markers
    - .gitignore → merge gitignore patterns
    - .gitattributes → merge with markers
    - .yaml, .yml → deep merge YAML
    - .conf, .cfg, .ini, .env.sample → merge lines
    - Other → simple copy

    Args:
        source: Source file path
        target: Target file path
        marker: Optional marker for idempotent merges (auto-generated if None)
        if_missing: Only merge if target doesn't exist (default: False)
        copy_overwrite: Force simple copy (ignore file type, overwrite target) (default: False)

    Returns:
        Tuple of (changed: bool, message: str)

    Examples:
        >>> merge_file(Path('ci/.gitignore'), Path('.gitignore'))
        (True, "Merged .gitignore")

        >>> merge_file(Path('ci/settings.json'), Path('.claude/settings.json'))
        (True, "Deep merged settings.json")

        >>> merge_file(Path('ci/TODO.md'), Path('TODO.md'), if_missing=True)
        (False, "TODO.md already exists")
    """
    import json
    import shutil

    # Check if target exists and if_missing is True
    if if_missing and target.exists():
        return (False, f"{target.name} already exists")

    # Check if source exists
    if not source.exists():
        return (False, f"Source not found: {source}")

    # Force copy-overwrite mode (ignore file type detection)
    if copy_overwrite:
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            return (True, f"Copied {target.name} (overwrite)")
        except Exception as e:
            return (False, f"Failed to copy: {e}")

    # Auto-generate marker if not provided
    if marker is None:
        marker = str(source)

    # Detect file type from extension
    ext = source.suffix.lower()

    # JSON files - deep merge
    if ext in [".json", ".jsonc"]:
        try:
            # Read source
            with open(source) as f:
                source_data = json.load(f)

            # Read target (if exists)
            if target.exists():
                with open(target) as f:
                    target_data = json.load(f)
            else:
                target_data = {}

            # Determine merge mode: no-overwrite (default) or overwrite (via ENV/CLI)
            # ENV: CI_MERGE_MODE=overwrite forces overwrite behavior
            # Default: no-overwrite (preserves existing project values)
            merge_mode = get_config_value("merge.mode", "CI_MERGE_MODE", "no-overwrite")

            # Deep merge with appropriate strategy
            if merge_mode == "overwrite":
                # Template values override existing values
                merged = deep_merge_json(target_data, source_data)
            else:
                # Default: no-overwrite - existing values preserved
                merged = deep_merge_no_overwrite(target_data, source_data)

            # Write back
            target.parent.mkdir(parents=True, exist_ok=True)
            with open(target, "w") as f:
                json.dump(merged, f, indent=2)
                f.write("\n")

            mode_msg = (
                "merged (overwrite)"
                if merge_mode == "overwrite"
                else "merged (no-overwrite)"
            )
            return (True, f"Deep {mode_msg} {target.name}")
        except Exception as e:
            return (False, f"Failed to merge JSON: {e}")

    # TOML files - deep merge (Python 3.12+)
    elif ext == ".toml":
        try:
            import tomllib  # Python 3.12+ built-in

            # Read source (binary mode for tomllib)
            with open(source, "rb") as f:
                source_data = tomllib.load(f)

            # Read target (if exists)
            if target.exists():
                with open(target, "rb") as f:
                    target_data = tomllib.load(f)
            else:
                target_data = {}

            # Determine merge mode: no-overwrite (default) or overwrite (via ENV/CLI)
            # ENV: CI_MERGE_MODE=overwrite forces overwrite behavior
            # Default: no-overwrite (preserves existing project values)
            merge_mode = get_config_value("merge.mode", "CI_MERGE_MODE", "no-overwrite")

            # Deep merge with appropriate strategy
            if merge_mode == "overwrite":
                # Template values override existing values
                merged = deep_merge_json(target_data, source_data)
            else:
                # Default: no-overwrite - existing values preserved
                merged = deep_merge_no_overwrite(target_data, source_data)

            # Write back (requires tomli_w for writing TOML)
            try:
                import tomli_w
            except ImportError:
                # FAIL LOUDLY - don't silently copy without merging!
                return (
                    False,
                    "TOML merge requires tomli_w package (pip install tomli-w)",
                )

            target.parent.mkdir(parents=True, exist_ok=True)
            with open(target, "wb") as f:
                tomli_w.dump(merged, f)

            mode_msg = (
                "merged (overwrite)"
                if merge_mode == "overwrite"
                else "merged (no-overwrite)"
            )
            return (True, f"Deep {mode_msg} {target.name}")

        except Exception as e:
            return (False, f"Failed to merge TOML: {e}")

    # Markdown files - append with markers
    elif ext in [".md", ".markdown"]:
        return append_markdown_file(target, source, marker)

    # Gitignore files - merge patterns
    elif source.name == "gitignore" or source.name == ".gitignore":
        # Use marker as source_label for tracking
        source_label = marker or str(source.relative_to(source.parent.parent))
        return merge_gitignore_file(target, source, source_label)

    # Gitattributes files - merge with markers
    elif source.name == "gitattributes" or source.name == ".gitattributes":
        source_label = marker or str(source.relative_to(source.parent.parent))
        return merge_gitattributes_file(target, source, source_label)

    # YAML files - deep merge OR simple copy for GitHub Actions workflows
    elif ext in [".yaml", ".yml"]:
        # GitHub Actions workflows should be copied, not merged
        # (PyYAML corrupts 'on:' keyword → 'true:')
        if ".github/workflows" in str(target):
            try:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
                return (True, f"Copied {target.name}")
            except Exception as e:
                return (False, f"Failed to copy workflow: {e}")

        # Other YAML files: deep merge
        try:
            import yaml

            # Read source
            with open(source) as f:
                source_data = yaml.safe_load(f) or {}

            # Read target (if exists)
            if target.exists():
                with open(target) as f:
                    target_data = yaml.safe_load(f) or {}
            else:
                target_data = {}

            # Deep merge
            merged = deep_merge_json(target_data, source_data)

            # Write back
            target.parent.mkdir(parents=True, exist_ok=True)
            with open(target, "w") as f:
                yaml.dump(merged, f, default_flow_style=False, sort_keys=False)

            return (True, f"Deep merged {target.name}")
        except Exception as e:
            return (False, f"Failed to merge YAML: {e}")

    # Config/env files - merge lines
    elif ext in [".conf", ".cfg", ".ini"] or source.name.endswith(".env.sample"):
        # Use merge_lines_file if it exists, otherwise simple append
        try:
            # Read source lines
            source_lines = source.read_text().splitlines()

            if target.exists():
                # Merge: add lines that don't exist yet
                existing_lines = set(target.read_text().splitlines())
                new_lines = [
                    line
                    for line in source_lines
                    if line not in existing_lines and line.strip()
                ]

                if new_lines:
                    with open(target, "a") as f:
                        f.write("\n")
                        f.write("\n".join(new_lines))
                        f.write("\n")
                    return (
                        True,
                        f"Merged {len(new_lines)} new lines into {target.name}",
                    )
                else:
                    return (False, f"{target.name} already up-to-date")
            else:
                # Create new from source
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("\n".join(source_lines) + "\n")
                return (True, f"Created {target.name} from template")
        except Exception as e:
            return (False, f"Failed to merge config: {e}")

    # Default - simple copy
    else:
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            return (True, f"Copied {target.name}")
        except Exception as e:
            return (False, f"Failed to copy: {e}")


def merge_env(json_file: Path, env_vars: dict[str, str]) -> bool:
    """
    Merge environment variables into a JSON file's "env" section.

    Reads JSON file, adds/updates keys in the "env" object, writes back.
    Creates "env" object if it doesn't exist.

    Args:
        json_file: Path to JSON file (e.g., .claude/settings.json)
        env_vars: Dictionary of environment variables to inject

    Returns:
        True if successful, False otherwise

    Example:
        merge_env(Path(".claude/settings.json"), {
            "CLAUDE_CODE_CONTEXT_WINDOW_TOKENS": "950000"
        })
    """
    try:
        import json

        # Read existing JSON
        if json_file.exists():
            with open(json_file) as f:
                data = json.load(f)
        else:
            data = {}

        # Ensure "env" section exists
        if "env" not in data:
            data["env"] = {}

        # Merge environment variables
        for key, value in env_vars.items():
            data["env"][key] = value

        # Write back with formatting
        with open(json_file, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")

        return True
    except Exception as e:
        logger.error(f"Failed to merge env vars into {json_file}: {e}")
        return False


def merge_bash_env(
    bash_file: Path, env_vars: dict[str, str], marker: str = "HYPERCI_ENV"
) -> tuple[bool, str]:
    """
    Merge environment variables into any bash file idempotently.

    Adds or updates export statements in a marked section.
    Multiple runs don't duplicate exports (idempotent).

    Args:
        bash_file: Path to bash file (e.g., ~/.bashrc, ~/.bash_profile, /etc/profile.d/app.sh)
        env_vars: Dictionary of environment variables to export
        marker: Section marker for idempotent updates

    Returns:
        Tuple of (changed: bool, message: str)

    Example:
        merge_bash_env(Path.home() / ".bashrc", {
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-5-20250929[1m]",
            "CLAUDE_CODE_CONTEXT_WINDOW_TOKENS": "950000"
        })
    """
    try:
        # Read existing file
        if bash_file.exists():
            with open(bash_file) as f:
                lines = f.readlines()
        else:
            lines = []

        # Find existing marker section
        start_marker = f"# BEGIN {marker}\n"
        end_marker = f"# END {marker}\n"

        start_idx = None
        end_idx = None

        for i, line in enumerate(lines):
            if line == start_marker:
                start_idx = i
            elif line == end_marker and start_idx is not None:
                end_idx = i
                break

        # Build new export section
        export_lines = [start_marker]
        for key, value in sorted(env_vars.items()):
            export_lines.append(f'export {key}="{value}"\n')
        export_lines.append(end_marker)

        # Check if content changed
        if start_idx is not None and end_idx is not None:
            # Replace existing section
            existing_section = lines[start_idx : end_idx + 1]
            if existing_section == export_lines:
                return (False, f"No changes to {bash_file.name}")

            # Replace section
            new_lines = lines[:start_idx] + export_lines + lines[end_idx + 1 :]
            changed = True
        else:
            # Add new section at end
            if lines and not lines[-1].endswith("\n"):
                lines.append("\n")
            if lines:
                lines.append("\n")
            new_lines = lines + export_lines
            changed = True

        # Write back
        with open(bash_file, "w") as f:
            f.writelines(new_lines)

        return (changed, f"Updated {bash_file.name} with {len(env_vars)} ENV var(s)")

    except Exception as e:
        logger.error(f"Failed to merge bash file: {e}")
        return (False, f"Failed: {e}")


def is_inline_module(script_path: Path) -> bool:
    """
    Check if a .d script should be run inline (imported) or as subprocess.

    Scripts with '# HYPERCI_INLINE: true' in first 5 lines run inline.
    Others run as subprocess for backward compatibility.

    Args:
        script_path: Path to Python script

    Returns:
        True if should run inline, False if subprocess
    """
    try:
        with open(script_path) as f:
            for _ in range(5):
                line = f.readline()
                if not line:
                    break
                if "# HYPERCI_INLINE: true" in line or "# HYPERCI_INLINE:true" in line:
                    return True
        return False
    except Exception:
        return False


def run_dotd_scripts(
    dotd_dirs: list[Path], action: str, **context
) -> dict[str, tuple[bool, str]]:
    """
    Run all .d scripts from multiple directories in merged numeric order.

    Merges scripts from ci/modules/common/*.d/, ci/modules/{lang}/*.d/,
    and ci-local/*.d/, executing them in numeric order (10-, 20-, etc.).

    Scripts with 'HYPERCI_INLINE: true' marker run in-process (shared context).
    Others run as subprocess (backward compatibility).

    Args:
        dotd_dirs: List of .d directories to search (in priority order)
        action: Action to execute ('check', 'install', 'setup', etc.)
        **context: Shared context injected into inline modules:
            - paths: Dict of CI paths
            - config: CI configuration
            - Path, subprocess, sys, os: Common imports
            - All ci_lib functions

    Returns:
        Dict mapping script name to (success, message) tuple

    Example:
        from ci_lib import run_dotd_scripts, get_ci_paths, get_ci_config
        import sys, os, subprocess
        from pathlib import Path

        paths = get_ci_paths()
        context = {
            'paths': paths,
            'config': get_ci_config(),
            'Path': Path,
            'subprocess': subprocess,
            'sys': sys,
            'os': os,
        }

        results = run_dotd_scripts(
            [
                paths['ci_dir'] / 'modules/common/bootstrap.d',
                paths['ci_dir'] / 'modules/python/bootstrap.d',
                paths['ci_local_dir'] / 'bootstrap.d',
            ],
            'install',
            **context
        )
    """
    import importlib.util

    # Collect all scripts from all directories
    all_scripts = {}
    for dotd_dir in dotd_dirs:
        if not dotd_dir.exists():
            continue

        for script in dotd_dir.glob("*.py"):
            if script.name.startswith("_"):
                continue
            # Later directories override earlier ones (same numeric prefix)
            all_scripts[script.name] = script

    # Sort by numeric prefix (10-, 20-, etc.)
    sorted_scripts = sorted(all_scripts.items(), key=lambda x: x[0])

    results = {}
    for script_name, script_path in sorted_scripts:
        try:
            if is_inline_module(script_path):
                # INLINE: Import and execute in-process
                spec = importlib.util.spec_from_file_location(
                    script_path.stem, script_path
                )
                if not spec or not spec.loader:
                    results[script_name] = (False, "Failed to load module spec")
                    continue

                module = importlib.util.module_from_spec(spec)

                # Inject context into module namespace
                module.__dict__.update(context)

                # Set sys.argv for scripts that read from it
                import sys as _sys

                original_argv = _sys.argv.copy()
                _sys.argv = [str(script_path), action]
                module.__dict__["sys"] = _sys  # Inject modified sys

                try:
                    # Execute module
                    spec.loader.exec_module(module)

                    # Look for action function (check, install, etc.)
                    if hasattr(module, action):
                        result = getattr(module, action)()
                        # Normalize result format
                        if isinstance(result, tuple):
                            results[script_name] = result
                        elif isinstance(result, bool):
                            results[script_name] = (
                                result,
                                "OK" if result else "Failed",
                            )
                        else:
                            results[script_name] = (
                                True,
                                str(result) if result else "OK",
                            )
                    elif hasattr(module, "main"):
                        result = module.main()  # Don't pass action, it's in sys.argv
                        if isinstance(result, tuple):
                            results[script_name] = result
                        elif isinstance(result, int):
                            results[script_name] = (
                                result == 0,
                                "OK" if result == 0 else f"Exit code {result}",
                            )
                        else:
                            results[script_name] = (
                                True,
                                str(result) if result else "OK",
                            )
                    else:
                        results[script_name] = (
                            False,
                            f"No {action}() or main() function found",
                        )
                finally:
                    # Restore original sys.argv
                    _sys.argv = original_argv

            else:
                # SUBPROCESS: Run as external process (backward compatibility)
                result = subprocess.run(
                    [sys.executable, str(script_path), action],
                    capture_output=True,
                    text=True,
                    check=False,
                )

                if result.returncode == 0:
                    results[script_name] = (True, result.stdout.strip() or "OK")
                else:
                    results[script_name] = (
                        False,
                        result.stderr.strip() or f"Exit code {result.returncode}",
                    )

        except Exception as e:
            results[script_name] = (False, f"Exception: {e}")

    return results


# ============================================================================
# Commit Tag Validation (for GIT-WORKFLOW.md standard)
# ============================================================================


def get_commit_tags() -> dict[str, list[str]]:
    """
    Get all valid commit tags from configuration.

    Returns dict with keys:
        - semantic_versioning: Tags that trigger version bumps (feat, fix, perf)
        - optional_semantic: Tags configurable for version bumps (refactor, hotfix)
        - non_versioning: Tags that don't trigger bumps (docs, chore, etc.)
        - all: Combined list of all valid tags

    Tags are loaded from commit.tags in defaults.yaml (or ci.yaml override).
    """
    config = get_ci_config()

    # Get tag categories from config (use dot notation for Dynaconf)
    semantic = config.get("commit.tags.semantic_versioning", [])
    optional = config.get("commit.tags.optional_semantic", [])
    non_versioning = config.get("commit.tags.non_versioning", [])

    # Combine all tags
    all_tags = semantic + optional + non_versioning

    return {
        "semantic_versioning": semantic,
        "optional_semantic": optional,
        "non_versioning": non_versioning,
        "all": all_tags,
    }


def is_valid_commit_tag(message: str) -> tuple[bool, str | None]:
    """
    Check if commit message has a valid tag from GIT-WORKFLOW.md standard.

    Valid format: <tag>: <description> OR <tag>(<scope>): <description>

    Args:
        message: Commit message (first line or full message)

    Returns:
        (is_valid, tag) - tag is None if no valid tag found

    Example:
        >>> is_valid_commit_tag("feat: add authentication")
        (True, "feat")

        >>> is_valid_commit_tag("feat(api): add OAuth")
        (True, "feat")

        >>> is_valid_commit_tag("invalid: no such tag")
        (False, None)
    """
    if not message or ":" not in message:
        return False, None

    # Get first line only (for multiline messages)
    first_line = message.split("\n")[0].strip()

    # Extract tag (everything before first colon)
    tag = first_line.split(":", 1)[0].strip()

    # Handle scoped tags like "feat(scope):" -> "feat"
    if "(" in tag:
        tag = tag.split("(")[0].strip()

    # Check against all valid tags from config
    tags = get_commit_tags()
    if tag in tags["all"]:
        return True, tag

    return False, None


def get_tag_category(tag: str) -> str | None:
    """
    Get the category of a commit tag.

    Args:
        tag: Tag name (e.g., "feat", "fix", "docs")

    Returns:
        Category name or None if tag not found:
        - "semantic_versioning"
        - "optional_semantic"
        - "non_versioning"

    Example:
        >>> get_tag_category("feat")
        "semantic_versioning"

        >>> get_tag_category("docs")
        "non_versioning"
    """
    tags = get_commit_tags()

    if tag in tags["semantic_versioning"]:
        return "semantic_versioning"
    elif tag in tags["optional_semantic"]:
        return "optional_semantic"
    elif tag in tags["non_versioning"]:
        return "non_versioning"

    return None


# ============================================================================
# CI Submodule Mode Detection
# ============================================================================


def is_ci_submodule() -> bool:
    """
    Check if ci/ directory is a git submodule.

    Returns:
        True if ci/ is a git submodule, False otherwise
    """
    try:
        project_root = get_project_root()
        gitmodules = project_root / ".gitmodules"

        if not gitmodules.exists():
            return False

        content = gitmodules.read_text()
        return "path = ci" in content or '[submodule "ci"]' in content
    except Exception:
        return False


def is_ci_readonly() -> bool:
    """
    Detect if ci/ is a read-only submodule.

    Since hs-ci uses its own GitHub Actions for development (not self-hosting),
    ALL projects treat ci/ as read-only when it's a submodule.

    Returns:
        True if ci/ is a submodule (read-only), False if standalone

    Example:
        >>> if is_ci_readonly():
        ...     print("Don't modify ci/ - it's a read-only submodule")
    """
    try:
        # ci/ is a submodule → read-only (all projects, including hs-ci)
        return is_ci_submodule()

    except Exception:
        # On error, assume read-only for safety
        return True


def enforce_pypi_policy() -> None:
    """
    Enforce PyPI usage policy: private JFrog if available, public if not.

    Tests JFrog connectivity and sets environment variables to enforce:
    - JFrog working → FORCE private PyPI ONLY (no public fallback)
    - JFrog not working → Use public PyPI
    - WARNS when switching between private and public

    Call this at the start of bootstrap.py and run.py.
    """
    import urllib.request
    import urllib.error

    # Check if JFrog credentials exist
    username = os.environ.get("ARTIFACTORY_USERNAME")
    password = os.environ.get("ARTIFACTORY_PASSWORD")
    token = os.environ.get("ARTIFACTORY_TOKEN")
    has_credentials = bool((username and password) or token)

    # Track previous state to detect switches
    previous_mode = os.environ.get("_PYPI_MODE")

    if has_credentials:
        # Test JFrog connectivity
        jf_host = "hypersec.jfrog.io/artifactory/api/pypi/hypersec-pypi-local/simple"
        test_url = f"https://{jf_host}"

        try:
            if token:
                token_user = os.environ.get("ARTIFACTORY_TOKEN_USER", "artifactory@hypersec.io")
                auth_handler = urllib.request.HTTPBasicAuthHandler()
                auth_handler.add_password(None, test_url, token_user, token)
                opener = urllib.request.build_opener(auth_handler)
                urllib.request.install_opener(opener)
            else:
                auth_handler = urllib.request.HTTPBasicAuthHandler()
                auth_handler.add_password(None, test_url, username, password)
                opener = urllib.request.build_opener(auth_handler)
                urllib.request.install_opener(opener)

            response = urllib.request.urlopen(test_url, timeout=10)
            if response.status == 200:
                # JFrog works → FORCE private PyPI ONLY
                os.environ["PIP_NO_INDEX"] = "false"  # Not fully isolated (still use --index-url)
                os.environ["_PYPI_MODE"] = "private"
                if previous_mode == "public":
                    logger.warning("⚠️  Switched from PUBLIC PyPI to PRIVATE JFrog")
                    logger.warning("   All installs will use JFrog private PyPI only")
                return
        except Exception:
            pass

    # JFrog not available → use public PyPI
    os.environ["_PYPI_MODE"] = "public"
    if previous_mode == "private":
        logger.warning("⚠️  Switched from PRIVATE JFrog to PUBLIC PyPI")
        logger.warning("   JFrog credentials not working or not configured")


def get_ci_mode() -> str:
    """
    Get CI operation mode for current project.

    Returns:
        "readonly" - ci/ is read-only submodule (normal projects)
        "development" - ci/ is editable (hyperlib development)
        "standalone" - ci/ is not a submodule (direct install)

    Example:
        >>> mode = get_ci_mode()
        >>> if mode == "development":
        ...     print("You can commit to ci/ submodule")
    """
    if not is_ci_submodule():
        return "standalone"

    if is_ci_readonly():
        return "readonly"

    return "development"


def get_submodule_status() -> dict[str, Any]:
    """
    Get status of ci/ git submodule (development mode only).

    Returns dict with:
        - has_changes: bool - True if ci/ has uncommitted changes
        - has_staged: bool - True if ci/ has staged changes
        - has_commits: bool - True if ci/ has unpushed commits
        - current_hash: str - Current commit hash
        - branch: str - Current branch name
        - is_detached: bool - True if in detached HEAD state

    Raises:
        RuntimeError: If not in development mode or ci/ is not a submodule

    Example:
        >>> if get_ci_mode() == "development":
        ...     status = get_submodule_status()
        ...     if status['has_changes']:
        ...         print("CI submodule has uncommitted changes")
    """
    import subprocess

    if get_ci_mode() != "development":
        raise RuntimeError("Submodule status only available in development mode")

    ci_dir = get_ci_dir()
    status = {}

    try:
        # Check for uncommitted changes
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=ci_dir,
            capture_output=True,
            text=True,
            check=True,
        )
        status["has_changes"] = bool(result.stdout.strip())

        # Check for staged changes
        result = subprocess.run(
            ["git", "diff", "--cached", "--quiet"],
            cwd=ci_dir,
            capture_output=True,
            check=False,
        )
        status["has_staged"] = result.returncode != 0

        # Get current commit hash
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ci_dir,
            capture_output=True,
            text=True,
            check=True,
        )
        status["current_hash"] = result.stdout.strip()[:8]  # Short hash

        # Get current branch
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=ci_dir,
            capture_output=True,
            text=True,
            check=True,
        )
        branch = result.stdout.strip()
        status["branch"] = branch
        status["is_detached"] = branch == "HEAD"

        # Check for unpushed commits
        if not status["is_detached"]:
            result = subprocess.run(
                ["git", "rev-list", f"origin/{branch}..HEAD", "--count"],
                cwd=ci_dir,
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode == 0:
                count = int(result.stdout.strip())
                status["has_commits"] = count > 0
            else:
                status["has_commits"] = False
        else:
            status["has_commits"] = False

    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Failed to get submodule status: {e}")

    return status


def detect_change_locations() -> dict[str, bool]:
    """
    Detect where uncommitted changes are located.

    Returns dict with:
        - ci: bool - True if changes in ci/ directory
        - root: bool - True if changes outside ci/ directory

    This helps determine which repository needs commits.

    Example:
        >>> changes = detect_change_locations()
        >>> if changes['ci'] and changes['root']:
        ...     print("Changes span both repositories - need 2 commits")
    """
    import subprocess

    project_root = get_project_root()

    try:
        # Get all modified files (staged and unstaged)
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=project_root,
            capture_output=True,
            text=True,
            check=True,
        )

        files = result.stdout.strip().split("\n") if result.stdout.strip() else []

        ci_changes = any(f[3:].startswith("ci/") for f in files if len(f) > 3)
        root_changes = any(not f[3:].startswith("ci/") for f in files if len(f) > 3)

        return {"ci": ci_changes, "root": root_changes}

    except subprocess.CalledProcessError:
        return {"ci": False, "root": False}


def update_ci_local_config(key: str, value: any) -> None:
    """
    Update configuration value in ci-local/ci.yaml.

    This function updates values in ci-local/ci.yaml (project-specific overrides).
    Supports nested keys using dot notation (e.g., "python.source_root").

    Args:
        key: Configuration key (supports dot notation for nested keys)
        value: Value to set

    Example:
        update_ci_local_config('python.source_root', 'src/mypackage')
        update_ci_local_config('nuitka.enabled', True)
    """
    from pathlib import Path

    import yaml

    paths = get_ci_paths()
    ci_local_yaml = paths["ci_local_dir"] / "ci.yaml"

    # Load existing config (or start with empty dict)
    if ci_local_yaml.exists():
        with open(ci_local_yaml) as f:
            config = yaml.safe_load(f) or {}
    else:
        config = {}

    # Set value using dot notation (e.g., "python.source_root")
    keys = key.split(".")
    current = config
    for k in keys[:-1]:
        if k not in current:
            current[k] = {}
        current = current[k]

    current[keys[-1]] = value

    # Write back
    ci_local_yaml.parent.mkdir(parents=True, exist_ok=True)
    with open(ci_local_yaml, "w") as f:
        yaml.safe_dump(config, f, default_flow_style=False, sort_keys=False)


def get_source_root(language: str = None) -> str:
    """
    Get source code root directory from configuration.

    This function retrieves the source root from ci.yaml (auto-detected during
    bootstrap or manually configured). All CI tools should use this instead of
    hardcoding paths or detecting at runtime.

    Configuration cascade:
    1. ENV: CI_<LANGUAGE>_SOURCE_ROOT (e.g., CI_PYTHON_SOURCE_ROOT)
    2. ci-local/ci.yaml: <language>.source_root (e.g., python.source_root)
    3. ci/ci.yaml: <language>.source_root
    4. Fallback: "." (current directory)

    Args:
        language: Language-specific root (e.g., 'python', 'rust', 'go')
                 If None, returns common project.source_root

    Returns:
        Source root path (relative to project root)

    Examples:
        >>> get_source_root('python')
        'src/mypackage'

        >>> get_source_root('python')
        'PyPDFForm'  # Flat layout

        >>> get_source_root()
        '.'  # Fallback
    """
    import os

    config = get_ci_config()

    if language:
        # Check environment variable first
        env_key = f"CI_{language.upper()}_SOURCE_ROOT"
        env_value = os.getenv(env_key)
        if env_value:
            return env_value

        # Try language-specific config
        root = config.get(f"{language}.source_root")
        if root:
            return root

    # Fallback to common project.source_root
    root = config.get("project.source_root")
    if root:
        return root

    # Final fallback
    return "."


def detect_project_name(language: str = None) -> str:
    """
    Detect project name from multiple sources with intelligent fallbacks.

    Detection priority (first found wins):
    1. Language-specific config file (pyproject.toml, Cargo.toml, package.json, go.mod)
    2. git remote URL (extract repo name)
    3. Parent directory name (last resort)

    Args:
        language: Optional language hint ('python', 'rust', 'javascript', 'go')
                 If None, tries generic detection

    Returns:
        Project name (sanitized for use as package name)

    Examples:
        >>> detect_project_name('python')
        'my-awesome-project'  # from pyproject.toml [project] name

        >>> detect_project_name()
        'my-project'  # from git remote URL or directory name
    """
    import subprocess
    from pathlib import Path

    project_root = get_project_root()

    # 1. Try language-specific config file
    if language == "python":
        pyproject = project_root / "pyproject.toml"
        if pyproject.exists():
            try:
                import tomllib

                with open(pyproject, "rb") as f:
                    data = tomllib.load(f)
                    name = data.get("project", {}).get("name")
                    if name:
                        return name
            except Exception:
                pass

    elif language == "rust":
        cargo = project_root / "Cargo.toml"
        if cargo.exists():
            try:
                import tomllib

                with open(cargo, "rb") as f:
                    data = tomllib.load(f)
                    name = data.get("package", {}).get("name")
                    if name:
                        return name
            except Exception:
                pass

    elif language in ["javascript", "typescript", "node"]:
        package_json = project_root / "package.json"
        if package_json.exists():
            try:
                import json

                with open(package_json) as f:
                    data = json.load(f)
                    name = data.get("name")
                    if name:
                        return name
            except Exception:
                pass

    elif language == "go":
        go_mod = project_root / "go.mod"
        if go_mod.exists():
            try:
                with open(go_mod) as f:
                    for line in f:
                        if line.strip().startswith("module "):
                            # Extract last component of module path
                            module = line.strip().split()[1]
                            name = module.split("/")[-1]
                            if name:
                                return name
            except Exception:
                pass

    # 2. Try git remote URL
    try:
        result = subprocess.run(
            ["git", "config", "--get", "remote.origin.url"],
            capture_output=True,
            text=True,
            timeout=2,
            cwd=project_root,
        )
        if result.returncode == 0:
            url = result.stdout.strip()
            # Extract repo name from URL
            # https://github.com/user/repo.git -> repo
            # git@github.com:user/repo.git -> repo
            name = url.rstrip("/").split("/")[-1]
            name = name.removesuffix(".git")
            if name and name != "origin":
                return name
    except (
        subprocess.TimeoutExpired,
        subprocess.CalledProcessError,
        FileNotFoundError,
    ):
        pass

    # 3. Final fallback: parent directory name
    return project_root.name
