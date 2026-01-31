<!--
  Project:      HyperSec AI
  File:         QUICKSTART.md
  Purpose:      5-minute guide to adding HyperSec AI to your project
  Language:     Markdown

  License:      LicenseRef-HyperSec-EULA
  Copyright:    (c) 2025 HyperSec Pty Ltd
-->

# HyperSec AI Quickstart

Get AI-assisted development running in under 5 minutes.

> **Note:** The `ai/` submodule provides standards and configuration - not code
> to import. Your project never imports or links to it. Humans and AI assistants
> read the standards; your code ignores this directory.

## TL;DR

```bash
# AI + CI (recommended)
git submodule add https://github.com/hypersec-io/ci.git ci && ./ci/attach.sh --python-package
git submodule add https://github.com/hypersec-io/ai.git ai && ./ai/attach.sh --claude

# AI only
git submodule add https://github.com/hypersec-io/ai.git ai && ./ai/attach.sh --claude
```

## Step 1: Add AI Submodule

**AI + CI (recommended):**

```bash
git submodule add https://github.com/hypersec-io/ci.git ci && ./ci/attach.sh --python-package
git submodule add https://github.com/hypersec-io/ai.git ai && ./ai/attach.sh --claude
```

**AI only:**

```bash
git submodule add https://github.com/hypersec-io/ai.git ai && ./ai/attach.sh --claude
```

**Assistant options:** `--claude`, `--copilot`, `--cursor`, `--gemini`

**Greenfield projects** (no git repo yet):

```bash
git init && git branch -m main
git submodule add https://github.com/hypersec-io/ai.git ai
./ai/attach.sh --claude
```

## Step 2: Start Using

**Claude Code:**

```bash
/load    # Begin session (loads standards, state)
/save    # Checkpoint progress
```

**Other assistants:** Configs auto-created, just start coding.

## What Gets Created

| File | Purpose |
|------|---------|
| `STATE.md` | Project state and context for AI |
| `TODO.md` | Task tracking |
| `.claude/` | Claude Code configuration (if `--claude`) |

## Updating AI

```bash
git submodule update --remote ai
```

## Upgrading Existing Projects

If your project has outdated AI config:

```bash
git submodule update --remote ai
./ai/attach.sh --claude         # Auto-fixes configuration
```

## More Information

- [README.md](README.md) - Full documentation
- [standards/STANDARDS.md](standards/STANDARDS.md) - Coding standards reference
