<!--
  Project:      HyperI AI
  File:         QUICKSTART.md
  Purpose:      5-minute guide to adding HyperI AI to your project
  Language:     Markdown

  License:      Proprietary
  Copyright:    (c) 2026 HYPERI PTY LIMITED
-->

# HyperI AI Quickstart

Get AI-assisted development running in under 5 minutes.

> **Note:** The `hyperi-ai/` submodule provides standards and configuration - not code
> to import. Your project never imports or links to it. Humans and AI assistants
> read the standards; your code ignores this directory.

## TL;DR

```bash
# Add submodule then attach (run commands separately — do not chain with &&)
git submodule add https://github.com/hyperi-io/hyperi-ai.git hyperi-ai
./hyperi-ai/attach.sh --agent claude
```

## Step 1: Add AI Submodule

```bash
git submodule add https://github.com/hyperi-io/hyperi-ai.git hyperi-ai
./hyperi-ai/attach.sh --agent claude
```

**Assistant options:** `--agent claude`, `--agent codex`, `--agent cursor`, `--agent gemini`

**Greenfield projects** (no git repo yet):

```bash
git init
git branch -m main
git submodule add https://github.com/hyperi-io/hyperi-ai.git hyperi-ai
./hyperi-ai/attach.sh --agent claude
```

## Step 2: Start Using

**Claude Code:**

```bash
/load    # Begin session (loads standards, state, syncs submodule)
/save    # Checkpoint progress
```

Standards are auto-injected as you edit files — no manual loading needed.
Editing `*.py` → python rules inject. Editing `*.sh` → bash rules inject.

**Other assistants:** Configs auto-created, just start coding.

## What Gets Created

| File | Purpose |
|------|---------|
| `STATE.md` | Project state and context for AI |
| `TODO.md` | Task tracking |
| `.claude/` | Claude Code configuration (if `--agent claude`) |
| `.claude/rules/` | Compact path-scoped standards (auto-inject by file type) |
| `.claude/skills/` | Full standards for `/review` and `/simplify` |
| `.claude/memory/` | Project-specific persistent memory |

## Auto-Update (Default)

**The `hyperi-ai/` submodule auto-updates from upstream on every Claude Code
session start.** No manual commands needed — the `SessionStart` hook
handles it silently, including re-deploying changed commands, rules, and skills.

To force an immediate update outside of Claude Code:

```bash
git submodule update --remote hyperi-ai
./hyperi-ai/attach.sh --agent claude
```

## Pinning (Disable Auto-Update)

To lock a submodule to a specific version:

```bash
# Pin via .gitmodules (auto-update hook will skip pinned submodules)
git config -f .gitmodules submodule.hyperi-ai.update none
git add .gitmodules
git commit -m "chore: pin ai submodule"
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

These override all project and team standards. Keep it short — only
preferences that matter to you personally across every project.

## Style
- <your style preferences here>

## Patterns
- <your preferred patterns here>

## Communication
- <how you want the AI to communicate>
EOF
```

This file is injected **last** at session start — your preferences win over everything
else. It applies to every project that uses hyperi-ai, so keep it personal and concise.

Respects `XDG_CONFIG_HOME` if set (defaults to `~/.config`).

## More Information

- [README.md](README.md) - Full documentation
- [standards/STANDARDS.md](standards/STANDARDS.md) - Coding standards reference
