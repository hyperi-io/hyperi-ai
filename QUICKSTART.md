<!--
  Project:      HyperI AI
  File:         QUICKSTART.md
  Purpose:      Single guide to attaching HyperI AI to any project
  Language:     Markdown

  License:      Proprietary
  Copyright:    (c) 2026 HYPERI PTY LIMITED
-->

# HyperI AI Quickstart

Get AI-assisted development running in under 5 minutes.

> **What is this?** The `hyperi-ai/` submodule (or stealth clone) provides
> standards and configuration -- not code to import. Your project never imports
> or links to it. Humans and AI assistants read the standards; your code ignores
> this directory.

---

## Pick Your Mode

Two modes depending on whether you control the project.

| Signal | Mode | Why |
|---|---|---|
| Remote URL has `hyperi-io/` or `hypersec-io/` | **Submodule** | Our project, committed artifacts are fine |
| `.hyperi-ci.yaml` exists | **Submodule** | Uses our CI -- definitely ours |
| `LICENSE` mentions "HYPERI PTY LIMITED" | **Submodule** | Our IP |
| `.gitmodules` already has `hyperi-ai` | **Submodule** | Already attached |
| None of the above | **Stealth** | External -- zero committed footprint |

---

## Submodule Mode (Our Projects)

For any project under `hyperi-io/` or `hypersec-io/`.

```bash
git submodule add https://github.com/hyperi-io/hyperi-ai.git hyperi-ai
./hyperi-ai/attach.sh --agent claude
git add .gitmodules hyperi-ai .claude STATE.md TODO.md
git commit -m "chore: attach hyperi-ai standards"
```

Skip `submodule add` if `.gitmodules` already has `hyperi-ai`.

**Assistant options:** `--agent claude`, `--agent codex`, `--agent cursor`, `--agent gemini`

**Greenfield projects** (no git repo yet):

```bash
git init
git branch -m main
git submodule add https://github.com/hyperi-io/hyperi-ai.git hyperi-ai
./hyperi-ai/attach.sh --agent claude
```

## Stealth Mode (External Projects)

For projects we don't own -- open-source repos, third-party code, anything
where hyperi-ai artifacts must never appear in the commit history.

```bash
# One-time: clone hyperi-ai to a shared location
git clone https://github.com/hyperi-io/hyperi-ai.git ~/.local/share/hyperi-ai

# From the project root
~/.local/share/hyperi-ai/attach.sh --stealth --path .
```

Nothing gets committed. `.git/info/exclude` hides everything locally.
Run `git status` to confirm -- no hyperi-ai-related changes should appear.

Do NOT stage or commit anything in a stealth project. If hyperi-ai files
show in `git status`, check `.git/info/exclude`.

---

## Verify

After either mode:

```bash
ls .claude/rules/         # Standards
ls .claude/skills/        # Methodology skills
ls .claude/settings.json  # Hook configuration
```

All three must exist. If not, re-run `attach.sh` with `--force`.

## Start Using

**Claude Code:**

```bash
/load    # Begin session (loads standards, state, syncs)
/save    # Checkpoint progress
```

Standards are auto-injected as you edit files -- no manual loading needed.
Editing `*.py` -> python rules inject. Editing `*.sh` -> bash rules inject.

**Other assistants:** Configs auto-created, just start coding.

## What Gets Created

| File | Purpose |
|------|---------|
| `STATE.md` | Project architecture and context for AI |
| `TODO.md` | Task tracking |
| `.claude/` | Claude Code configuration (if `--agent claude`) |
| `.claude/rules/` | Compact path-scoped standards (auto-inject by file type) |
| `.claude/skills/` | Methodology skills (verification, docs-audit, release, deps, etc.) |
| `.claude/memory/` | Project-specific persistent memory |

---

## Updating

**Automatic:** Both modes auto-update on every Claude Code session start. The
session-start hook pulls the latest hyperi-ai (submodule or stealth clone) and
re-deploys if anything changed. No manual steps needed.

**Manual** (if you need to force an update):

```bash
# Submodule projects
git submodule update --remote hyperi-ai
./hyperi-ai/attach.sh --force

# Stealth projects
git -C ~/.local/share/hyperi-ai pull
~/.local/share/hyperi-ai/attach.sh --stealth --force --path .
```

## Pinning (Disable Auto-Update)

To lock the submodule to a specific version:

```bash
git config -f .gitmodules submodule.hyperi-ai.update none
git add .gitmodules
git commit -m "chore: pin hyperi-ai submodule"
```

To unpin: `git config -f .gitmodules submodule.hyperi-ai.update rebase`

## Upgrading Existing Projects

If your project has outdated AI config:

```bash
git submodule update --remote hyperi-ai
./hyperi-ai/attach.sh --agent claude --force
```

## Personal Overrides (Optional)

Add a personal standards file that overrides all project rules across every repo:

```bash
mkdir -p ~/.config/hyperi-ai
cat > ~/.config/hyperi-ai/USER-CODING-STANDARDS.md << 'EOF'
# Personal Coding Standards

These override all project and team standards. Keep it short -- only
preferences that matter to you personally across every project.

## Style
- <your style preferences here>

## Communication
- <how you want the AI to communicate>
EOF
```

This file is injected **last** at session start -- your preferences win over
everything else. Respects `XDG_CONFIG_HOME` if set (defaults to `~/.config`).

## Notes

- Stealth symlinks are absolute (`~/.local/share/hyperi-ai/...`). If they
  break, re-run the stealth attach.
- Submodule symlinks are relative (`../../hyperi-ai/...`). These survive
  clones and moves.
- `git clean -fdx` nukes stealth `.claude/` -- re-run `attach.sh --stealth`
  to restore (the system-wide clone is untouched).

---

## More Information

- [README.md](README.md) -- Full documentation
- [standards/STANDARDS.md](standards/STANDARDS.md) -- Standards index and reference

---

## AI Agent Instructions

If you are an AI coding assistant asked to "attach hyperi-ai", follow these
steps exactly. Do not skip detection.

### 1. Detect project type

Run each check in the target project:

```bash
git remote -v 2>/dev/null | head -1
ls .hyperi-ci.yaml 2>/dev/null
grep -l "HYPERI PTY LIMITED" LICENSE 2>/dev/null
grep -l "hyperi-ai" .gitmodules 2>/dev/null
```

If ANY check matches, this is a **HyperI-controlled project** -- use submodule
mode. If NONE match, this is **external** -- use stealth mode.

### 2. Submodule mode (HyperI-controlled)

```bash
# Skip if .gitmodules already has hyperi-ai
git submodule add https://github.com/hyperi-io/hyperi-ai.git hyperi-ai
./hyperi-ai/attach.sh --agent claude
git add .gitmodules hyperi-ai .claude STATE.md TODO.md
git commit -m "chore: attach hyperi-ai standards"
```

### 3. Stealth mode (external)

```bash
if [ ! -d ~/.local/share/hyperi-ai ]; then
    git clone https://github.com/hyperi-io/hyperi-ai.git ~/.local/share/hyperi-ai
fi
~/.local/share/hyperi-ai/attach.sh --stealth --path "$(pwd)"
```

Do NOT stage or commit anything. Verify with `git status` -- no
hyperi-ai-related files should appear.

### 4. Verify

```bash
ls .claude/rules/
ls .claude/skills/
ls .claude/settings.json
```

All three must exist. If not, re-run `attach.sh` with `--force`.
