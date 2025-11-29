# HyperSec AI Code Assistant Standards

**Repository:** <<https://github.com/hypersec-io/ai>>

**Purpose:** Standards, guidance, and templates that "tack on" to any project

**License:** HyperSec EULA (proprietary)

---

## What's Included

**Standards** - Coding standards, AI guidance, best practices (in `standards/`)

**Templates** - STATE.md, TODO.md, AI assistant configurations (in `templates/`)

**Setup scripts** - Pure bash, assistant-specific setup


**Key features:**

- Works as git submodule, clone, or ZIP download
- Pure bash 3.2+ (macOS, Linux, WSL compatible)
- Zero dependencies beyond standard Unix tools
- Path-agnostic (works anywhere)
- Cross-LLM session state

---

## Quick Start

**Attach to your project (choose ONE method):**

```bash
# Method 1: Git submodule (recommended - get updates automatically)
git submodule add https://github.com/hypersec-io/ai.git ai
git submodule update --init --recursive

# IMPORTANT: Enforce read-only to prevent accidental commits
git config submodule.ai.update none
git -C ai config core.fileMode false
git -C ai config advice.detachedHead false

# Method 2: Git clone (point-in-time copy)
git clone https://github.com/hypersec-io/ai.git ai
cd ai && rm -rf .git

# Method 3: Download ZIP (standalone)
curl -L https://github.com/hypersec-io/ai/archive/refs/heads/main.zip -o ai.zip
unzip ai.zip && mv ai-main ai
```

**Run installation:**

```bash
# From inside the attached directory (e.g., ai/)
./install.sh

# This creates in your project root:
# - STATE.md (session state)
# - TODO.md (task tracking)
```

**Setup your AI assistant (optional):**

```bash
# Claude Code (Anthropic)
./claude-code.sh

# GitHub Copilot/Codex (OpenAI)
./copilot.sh

# Cursor IDE
./cursor.sh

# Gemini Code (Google)
./gemini.sh
```

---

## AI Assistant Setup

### Claude Code (Anthropic)

**Setup:**

```bash
./claude-code.sh
```

**What it creates:**

- `.claude/settings.json` - Permissions, model configuration, context settings
- `.claude/commands/start.md` - Session initialization slash command
- `.claude/commands/save.md` - Progress checkpoint slash command
- `CLAUDE.md` → `STATE.md` symlink

**Slash commands:**

**`/start`** - Initialize your session

- Reads STATE.md (project state and history)
- Reads TODO.md (current tasks)
- Loads standards based on context window
- Checks git status and recent commits
- Verifies environment setup

**`/save`** - Checkpoint your progress

- Updates STATE.md with current session progress
- Rationalizes STATE.md (removes stale info)
- Updates TODO.md (marks completed, adds new tasks)
- Fixes markdown linting errors
- Creates clean checkpoint for next session

**Best practices:**

- Run `/start` at the beginning of every session
- Run `/save` after major milestones or every 30-40 exchanges
- Run `/save` before breaks to preserve context
- STATE.md and TODO.md persist across sessions

---

### GitHub Copilot/Codex (OpenAI)

**Setup:**

```bash
./copilot.sh
```

**What it creates:**

- `.github/copilot-instructions.md` - Custom instructions for Copilot/Codex
- `COPILOT.md` → `STATE.md` symlink

**How it works:**

- Copilot reads `.github/copilot-instructions.md` automatically
- Instructions reference `$AI_ROOT/standards/` for coding standards
- STATE.md provides project context
- TODO.md guides task prioritization

**Best practices:**

- Keep STATE.md and TODO.md updated manually (no slash commands)
- Copilot uses these files for better code suggestions
- Works with both GitHub Copilot and OpenAI Codex

---

### Cursor IDE

**Setup:**

```bash
./cursor.sh
```

**What it creates:**

- `.cursor/cli.json` - Cursor permissions and settings
- `.cursor/rules/` - AI instruction rules (.mdc files)
- `CURSOR.md` → `STATE.md` symlink

**Cursor AI Rules:**

- Rules files (`.mdc`) loaded automatically by Cursor
- Reference `$AI_ROOT/standards/` for coding standards
- STATE.md provides project context
- TODO.md guides current tasks

**Best practices:**

- Update STATE.md and TODO.md as you work
- Cursor automatically applies rules from `.cursor/rules/`
- Use Cursor's built-in chat to reference STATE.md context

---

### Gemini Code (Google)

**Setup:**

```bash
./gemini.sh
```

**What it creates:**

- `.gemini/settings.json` - Gemini configuration
- `.gemini/commands/` - Custom commands (if supported)
- `GEMINI.md` → `STATE.md` symlink

**How it works:**

- Gemini reads configuration from `.gemini/`
- References `$AI_ROOT/standards/` for coding standards
- STATE.md provides project context
- TODO.md guides task prioritization

**Best practices:**

- Keep STATE.md and TODO.md current
- Gemini has large context window (1M+ tokens) - can load full standards
- Reference GEMINI.md in chat for project context

---

## Overview

This repository provides **coding standards and project templates** for three user types:

### 1. Human Developers (Using Standards Directly)

Reference comprehensive coding standards without AI assistance:
- Language-agnostic standards (SOLID, DRY, KISS, YAGNI)
- Python-specific standards (PEP 8, type hints, testing)
- Git workflow and commit conventions
- Error handling and security best practices
- Design principles and containerisation

**Use case:** Code reviews, architecture decisions, onboarding

### 2. Developers with AI Code Assistants

Standards optimised for AI-assisted development:
- AI-specific guidance (quality warnings, best practices)
- Session management (STATE.md, TODO.md for context)
- Commit message guidelines for AI tools
- Multi-platform support (Claude Code, GitHub Copilot/Codex, Cursor IDE, Gemini Code)
- Token optimisation and context management

**Use case:** Daily development with any AI code assistant

### 3. AI Code Assistants (Reading for Context)

Context-adaptive loading strategy for AI models:
- Full CAG loading for 500K+ token windows
- Tiered CAG/RAG hybrid for smaller contexts
- Standards organised for efficient token usage
- Project state tracking across sessions
- Cross-assistant compatibility (assistant-agnostic design)

**Use case:** Any AI assistant loading standards (Claude, Copilot/Codex, Cursor, Gemini, etc.)

---

## Repository Structure

**Path variables used in documentation:**
- `$AI_ROOT` = Where this repo is attached (e.g., `ai/`, `standards/`, `.ai/`)
- `$PROJECT_ROOT` = Parent project root (where STATE.md, TODO.md are deployed)

```text
parent-project/              # Your project ($PROJECT_ROOT)
├── ai/                      # This repository ($AI_ROOT - can be any name)
│   ├── install.sh           # Deploy cross-assistant templates
│   ├── claude-code.sh       # Claude Code (Anthropic) setup
│   ├── copilot.sh           # GitHub Copilot/Codex (OpenAI) setup
│   ├── cursor.sh            # Cursor IDE setup
│   ├── gemini.sh            # Gemini Code (Google) setup
│   │
│   ├── standards/           # Coding standards (assistant-agnostic)
│   │   ├── STANDARDS.md     # Entry point with loading strategy
│   │   ├── code-assistant/  # AI-specific guidance (all assistants)
│   │   ├── common/          # Language-agnostic standards
│   │   └── python/          # Python-specific standards
│   │
│   └── templates/           # Templates for all AI assistants
│       ├── STATE.md         # Cross-assistant session state
│       ├── TODO.md          # Cross-assistant task tracking
│       ├── claude-code/     # Claude Code specific
│       ├── copilot/         # GitHub Copilot specific
│       ├── cursor/          # Cursor IDE specific
│       └── gemini/          # Gemini Code specific
│
├── STATE.md                 # Created by install.sh (all assistants use this)
├── TODO.md                  # Created by install.sh (all assistants use this)
│
├── .claude/                 # Created by claude-code.sh
├── CLAUDE.md -> STATE.md    # Symlink for Claude Code
│
├── .github/copilot-instructions.md  # Created by copilot.sh
├── COPILOT.md -> STATE.md   # Symlink for GitHub Copilot/Codex
│
├── .cursor/                 # Created by cursor.sh
│   ├── cli.json             # Cursor permissions & settings
│   └── rules/               # Cursor AI instruction rules (.mdc)
├── CURSOR.md -> STATE.md    # Symlink for Cursor IDE
│
├── .gemini/                 # Created by gemini.sh
└── GEMINI.md -> STATE.md    # Symlink for Gemini Code
```

---

## For AI Code Assistants

**Standards are path-agnostic - reference using `$AI_ROOT` variable.**

**Loading strategy:**

- **Context window >= 500K tokens:** Load ALL standards (full CAG)
- **Context window < 500K tokens:** Load Tier 1 mandatory, Tier 2 on-demand (CAG/RAG hybrid)

**See [standards/STANDARDS.md](standards/STANDARDS.md) for complete loading instructions.**

---

## Standards and Templates Details

### Standards Documentation (`standards/`)

**AI-specific guidance:**

- Session management, commit messages, CI workflows
- Assistant-agnostic design (works with any AI code assistant)
- Quality warnings (4x higher defect rates in AI code)
- Token optimization and context management

**Coding standards:**

- Language-agnostic (SOLID, DRY, KISS, YAGNI)
- Python (PEP 8, type hints, testing)
- Error handling (security-first)
- Git workflow (Conventional Commits)

**Design principles:**

- No mocks policy
- Test-first development
- Containerization (Docker, Kubernetes)
- Cross-platform compatibility

### Templates (`templates/`)

**Cross-assistant (all AI tools use these):**

- `STATE.md` - Project state and session history
- `TODO.md` - Task tracking with time estimates

**Assistant-specific (in subdirectories):**

- `claude-code/` - Claude Code (Anthropic) - settings.json, slash commands
- `copilot/` - GitHub Copilot/Codex (OpenAI) - copilot-instructions.md
- `cursor/` - Cursor IDE - cli.json, rules (.mdc files)
- `gemini/` - Gemini Code (Google) - settings.json, commands

### Setup Scripts (root)

**Cross-assistant:**

- `install.sh` - Deploy STATE.md and TODO.md (all assistants use these)

**Assistant-specific:**

- `claude-code.sh` - Configure Claude Code (creates .claude/ directory + CLAUDE.md symlink)
- `copilot.sh` - Configure GitHub Copilot/Codex (creates .github/copilot-instructions.md + COPILOT.md symlink)
- `cursor.sh` - Configure Cursor IDE (creates .cursor/ directory + CURSOR.md symlink)
- `gemini.sh` - Configure Gemini Code (creates .gemini/ directory + GEMINI.md symlink)

**All scripts:**

- Pure bash (bash 3.2+ compatible)
- Self-contained (< 300 lines each)
- Idempotent (safe to run multiple times)
- No dependencies beyond Unix basics

---

## Testing Status

**Note:** Only Claude Code has been tested end-to-end with a human in the middle using VS Code and the official Claude Code extension. All other assistants (Copilot/Codex, Cursor, Gemini) have comprehensive automated test coverage but have not been manually verified in their respective IDEs.

**GitHub Copilot/Codex:** The `copilot.sh` script configures both GitHub Copilot and OpenAI Codex using the standard `.github/copilot-instructions.md` file format supported by both tools.

---

## Contributing

**This repository is read-only for most projects.**

To propose standards changes:
1. Create GitHub issue with proposal
2. Submit PR with changes to `standards/`
3. Get approval from 2+ team leads
4. Update version in STANDARDS.md

---
## License

HyperSec EULA (Proprietary) - See [LICENSE](LICENSE)

**Copyright:** (c) 2025 HyperSec Pty Ltd

---

## Links

- **Standards documentation:** [standards/STANDARDS.md](standards/STANDARDS.md)
