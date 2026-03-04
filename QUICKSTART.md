<!--
  Project:      HyperI AI
  File:         QUICKSTART.md
  Purpose:      5-minute guide to adding HyperI AI to your project
  Language:     Markdown

  License:      FSL-1.1-ALv2
  Copyright:    (c) 2026 HYPERI PTY LIMITED
-->

# HyperI AI Quickstart

Get AI-assisted development running in under 5 minutes.

> **Note:** The `ai/` submodule provides standards and configuration - not code
> to import. Your project never imports or links to it. Humans and AI assistants
> read the standards; your code ignores this directory.

## TL;DR

```bash
# Add submodule then attach (run commands separately — do not chain with &&)
git submodule add https://github.com/hyperi-io/ai.git ai
./ai/attach.sh --agent claude
```

## Step 1: Add AI Submodule

**AI + CI (recommended):**

```bash
git submodule add https://github.com/hyperi-io/ci.git ci
./ci/attach.sh --python-package
git submodule add https://github.com/hyperi-io/ai.git ai
./ai/attach.sh --agent claude
```

**AI only:**

```bash
git submodule add https://github.com/hyperi-io/ai.git ai
./ai/attach.sh --agent claude
```

**Assistant options:** `--agent claude`, `--agent codex`, `--agent cursor`, `--agent gemini`

**Greenfield projects** (no git repo yet):

```bash
git init
git branch -m main
git submodule add https://github.com/hyperi-io/ai.git ai
./ai/attach.sh --agent claude
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

## Updating AI

```bash
git submodule update --remote ai
./ai/attach.sh --agent claude
```

## Upgrading Existing Projects

If your project has outdated AI config:

```bash
git submodule update --remote ai
./ai/attach.sh --agent claude --force
```

## More Information

- [README.md](README.md) - Full documentation
- [standards/STANDARDS.md](standards/STANDARDS.md) - Coding standards reference
