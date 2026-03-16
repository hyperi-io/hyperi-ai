#!/usr/bin/env python3
"""Discover a GitHub Personal Access Token from common locations.

Checks (in order):
  1. $GITHUB_TOKEN environment variable
  2. $GH_TOKEN environment variable
  3. Project-level .env file ($CLAUDE_PROJECT_DIR/.env)
  4. Home directory .env file (~/.env)
  5. `gh auth token` command (gh CLI keyring)
  6. ~/.config/gh/hosts.yml (gh CLI config file)
  7. ~/.netrc (machine github.com)

Usage:
  discover_github_pat.py              # prints token or exits 1
  discover_github_pat.py --source     # prints "source: <location>" to stderr

Prints the token to stdout if found, exits 1 if not found.
Never prints diagnostics to stdout -- only the token or nothing.
"""
# Project:   HyperI AI
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED

import os
import subprocess
import sys
from pathlib import Path


def from_env() -> str | None:
    """Check GITHUB_TOKEN and GH_TOKEN env vars."""
    return os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN") or None


def from_dotenv_project() -> str | None:
    """Check project-level .env file for GITHUB_TOKEN or GH_TOKEN."""
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project_dir:
        return None
    return _read_dotenv(Path(project_dir) / ".env")


def from_dotenv_home() -> str | None:
    """Check ~/.env for GITHUB_TOKEN or GH_TOKEN."""
    return _read_dotenv(Path.home() / ".env")


def _read_dotenv(dotenv_path: Path) -> str | None:
    """Read GITHUB_TOKEN or GH_TOKEN from a .env file."""
    if not dotenv_path.exists():
        return None
    try:
        for line in dotenv_path.read_text().splitlines():
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip("'\"")
            if key in ("GITHUB_TOKEN", "GH_TOKEN", "GITHUB_PERSONAL_ACCESS_TOKEN") and value:
                return value
    except OSError:
        pass
    return None


def from_gh_cli() -> str | None:
    """Run `gh auth token` to get token from gh CLI keyring."""
    try:
        result = subprocess.run(
            ["gh", "auth", "token"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None


def from_gh_config() -> str | None:
    """Read token from ~/.config/gh/hosts.yml."""
    config_dir = os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
    hosts_file = Path(config_dir) / "gh" / "hosts.yml"
    if not hosts_file.exists():
        return None
    try:
        content = hosts_file.read_text()
        for line in content.splitlines():
            stripped = line.strip()
            if stripped.startswith("oauth_token:"):
                token = stripped.split(":", 1)[1].strip()
                if token:
                    return token
    except OSError:
        pass
    return None


def from_netrc() -> str | None:
    """Read token from ~/.netrc (machine github.com)."""
    netrc_file = Path.home() / ".netrc"
    if not netrc_file.exists():
        return None
    try:
        content = netrc_file.read_text()
        lines = content.split()
        for i, word in enumerate(lines):
            if word == "machine" and i + 1 < len(lines) and lines[i + 1] == "github.com":
                # Look for password field
                for j in range(i + 2, min(i + 8, len(lines))):
                    if lines[j] == "password" and j + 1 < len(lines):
                        return lines[j + 1]
    except OSError:
        pass
    return None


def main() -> int:
    show_source = "--source" in sys.argv

    sources = [
        ("env ($GITHUB_TOKEN or $GH_TOKEN)", from_env),
        ("project .env", from_dotenv_project),
        ("~/.env", from_dotenv_home),
        ("gh auth token (CLI keyring)", from_gh_cli),
        ("~/.config/gh/hosts.yml", from_gh_config),
        ("~/.netrc", from_netrc),
    ]

    for name, finder in sources:
        token = finder()
        if token:
            print(token)
            if show_source:
                print(f"source: {name}", file=sys.stderr)
            return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
