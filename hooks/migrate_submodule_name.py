#!/usr/bin/env python3
"""Migrate ai/ submodule to hyperi-ai/.

Handles the full git submodule rename:
  1. Update .gitmodules (submodule name + path)
  2. Update .git/config (submodule section)
  3. Move .git/modules/ai → .git/modules/hyperi-ai
  4. Rename ai/ → hyperi-ai/
  5. Update gitdir pointer inside submodule .git file
  6. Update deployed config files (settings.json, commands)

Each step is idempotent — safe to re-run after partial failure.
No pip dependencies — Python 3 stdlib only.
"""

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

OLD_NAME = "ai"
NEW_NAME = "hyperi-ai"


def get_project_dir() -> Path:
    """Determine project root from CLAUDE_PROJECT_DIR or cwd."""
    env = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if env:
        return Path(env)
    return Path.cwd()


def log(msg: str) -> None:
    print(f"[migrate] {msg}", file=sys.stderr)


def already_migrated(project_dir: Path) -> bool:
    """Check if migration is fully complete."""
    new_dir = project_dir / NEW_NAME
    old_dir = project_dir / OLD_NAME
    if not new_dir.exists():
        return False
    if old_dir.exists():
        return False  # partial state — needs cleanup
    # Verify gitdir pointer is correct
    git_file = new_dir / ".git"
    if git_file.is_file():
        text = git_file.read_text()
        if f"modules/{OLD_NAME}" in text:
            return False  # gitdir still points to old name
    return True


def needs_migration(project_dir: Path) -> bool:
    """Check if migration is needed (old name exists or partial state)."""
    old_dir = project_dir / OLD_NAME
    new_dir = project_dir / NEW_NAME
    # Old directory exists
    if old_dir.exists() and (old_dir / ".git").exists():
        return True
    # Partial state: new dir exists but gitdir pointer is wrong
    if new_dir.exists():
        git_file = new_dir / ".git"
        if git_file.is_file() and f"modules/{OLD_NAME}" in git_file.read_text():
            return True
    return False


def update_gitmodules(project_dir: Path) -> bool:
    """Rename submodule entry in .gitmodules."""
    gitmodules = project_dir / ".gitmodules"
    if not gitmodules.is_file():
        return False

    text = gitmodules.read_text()
    original = text

    # Rename [submodule "ai"] → [submodule "hyperi-ai"]
    text = text.replace(f'[submodule "{OLD_NAME}"]', f'[submodule "{NEW_NAME}"]')
    # Update path = ai → path = hyperi-ai
    text = re.sub(
        rf"(\s+path\s*=\s*){OLD_NAME}\s*$",
        rf"\g<1>{NEW_NAME}",
        text,
        flags=re.MULTILINE,
    )
    # Update URL if it references the old repo name
    text = text.replace(f"/{OLD_NAME}.git", f"/{NEW_NAME}.git")

    if text != original:
        gitmodules.write_text(text)
        try:
            subprocess.run(
                ["git", "add", ".gitmodules"],
                cwd=str(project_dir),
                capture_output=True,
                timeout=10,
            )
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
        return True
    return False


def update_git_config(project_dir: Path) -> None:
    """Rename submodule section in .git/config."""
    git_dir = project_dir / ".git"
    if not git_dir.is_dir():
        return

    config = git_dir / "config"
    if not config.is_file():
        return

    text = config.read_text()
    original = text

    text = text.replace(f'[submodule "{OLD_NAME}"]', f'[submodule "{NEW_NAME}"]')
    text = text.replace(f"/{OLD_NAME}.git", f"/{NEW_NAME}.git")

    if text != original:
        config.write_text(text)


def move_git_modules(project_dir: Path) -> None:
    """Move .git/modules/ai → .git/modules/hyperi-ai."""
    git_dir = project_dir / ".git"
    if not git_dir.is_dir():
        return

    old_modules = git_dir / "modules" / OLD_NAME
    new_modules = git_dir / "modules" / NEW_NAME

    if old_modules.is_dir() and not new_modules.exists():
        # Update worktree path inside the module's config before moving
        module_config = old_modules / "config"
        if module_config.is_file():
            text = module_config.read_text()
            text = text.replace(
                f"worktree = ../../../{OLD_NAME}",
                f"worktree = ../../../{NEW_NAME}",
            )
            module_config.write_text(text)

        shutil.move(str(old_modules), str(new_modules))
    elif old_modules.is_dir() and new_modules.is_dir():
        # Both exist — partial state, remove old if new looks valid
        if (new_modules / "HEAD").exists():
            shutil.rmtree(str(old_modules))


def rename_directory(project_dir: Path) -> None:
    """Rename ai/ → hyperi-ai/."""
    old_dir = project_dir / OLD_NAME
    new_dir = project_dir / NEW_NAME

    if old_dir.exists() and not new_dir.exists():
        old_dir.rename(new_dir)
    elif old_dir.exists() and new_dir.exists():
        # Both exist — partial state. Keep new, remove old if it's empty or stale.
        old_contents = list(old_dir.iterdir())
        if not old_contents or (len(old_contents) == 1 and old_contents[0].name == ".git"):
            shutil.rmtree(str(old_dir))


def fix_gitdir_pointer(project_dir: Path) -> None:
    """Update the .git file inside the submodule to point to new modules path."""
    git_file = project_dir / NEW_NAME / ".git"
    if not git_file.is_file():
        return

    text = git_file.read_text().strip()
    if f"modules/{OLD_NAME}" in text:
        text = text.replace(f"modules/{OLD_NAME}", f"modules/{NEW_NAME}")
        git_file.write_text(text + "\n")


def update_settings_json(project_dir: Path) -> None:
    """Update hook paths in .claude/settings.json."""
    settings = project_dir / ".claude" / "settings.json"
    if not settings.is_file():
        return

    text = settings.read_text()
    updated = text.replace(f"/{OLD_NAME}/hooks/", f"/{NEW_NAME}/hooks/")
    if updated != text:
        settings.write_text(updated)


def update_command_templates(project_dir: Path) -> None:
    """Update path references in deployed command files."""
    commands_dir = project_dir / ".claude" / "commands"
    if not commands_dir.is_dir():
        return

    for md_file in commands_dir.glob("*.md"):
        if md_file.is_symlink():
            continue  # skip symlinks — they point into the submodule already
        text = md_file.read_text()
        updated = text.replace(f"/{OLD_NAME}/", f"/{NEW_NAME}/")
        updated = updated.replace(f"../../{OLD_NAME}/", f"../../{NEW_NAME}/")
        if updated != text:
            md_file.write_text(updated)


def stage_rename(project_dir: Path) -> None:
    """Stage the submodule rename in git index."""
    try:
        # Remove old submodule from index (--cached keeps worktree, -f for submodules)
        subprocess.run(
            ["git", "rm", "--cached", "-f", OLD_NAME],
            cwd=str(project_dir),
            capture_output=True,
            timeout=10,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    try:
        # Stage new submodule path
        subprocess.run(
            ["git", "add", NEW_NAME],
            cwd=str(project_dir),
            capture_output=True,
            timeout=10,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass


def main() -> int:
    project_dir = get_project_dir()

    if already_migrated(project_dir):
        return 0

    if not needs_migration(project_dir):
        return 0

    log(f"Migrating submodule: {OLD_NAME}/ → {NEW_NAME}/")

    # Each step is idempotent — safe to re-run after partial failure

    # 1. Update .gitmodules
    if update_gitmodules(project_dir):
        log("Updated .gitmodules")

    # 2. Update .git/config
    update_git_config(project_dir)

    # 3. Move .git/modules/ai → .git/modules/hyperi-ai
    move_git_modules(project_dir)
    log("Moved git modules directory")

    # 4. Rename the directory
    rename_directory(project_dir)
    log(f"Renamed {OLD_NAME}/ → {NEW_NAME}/")

    # 5. Fix gitdir pointer inside submodule
    fix_gitdir_pointer(project_dir)

    # 6. Stage the rename
    stage_rename(project_dir)

    # 7. Update deployed config files
    update_settings_json(project_dir)
    log("Updated .claude/settings.json hook paths")

    update_command_templates(project_dir)
    log("Updated .claude/commands/ paths")

    # Verify migration completed
    if already_migrated(project_dir):
        log("Migration complete.")
    else:
        log("WARNING: Migration may be incomplete — run attach.sh to verify.")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
