# HyperSec AI Code Assistant Standards

**Repository:** https://github.com/hypersec-io/ai
**Purpose:** Standards, guidance, and templates that "tack on" to any project
**License:** HyperSec EULA (proprietary)

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
- Platform-specific guides (Claude Code, GitHub Copilot)
- Token optimisation and context management

**Use case:** Daily development with Claude Code, Copilot, Cursor

### 3. AI Code Assistants (Reading for Context)

Context-adaptive loading strategy for AI models:
- Full CAG loading for 500K+ token windows
- Tiered CAG/RAG hybrid for smaller contexts
- Standards organised for efficient token usage
- Project state tracking across sessions
- Cross-LLM compatibility

**Use case:** Claude Code, GitHub Copilot, Cursor, Gemini loading standards

---

## What's Included

**Standards** - Coding standards, AI guidance, best practices (in `standards/`)
**Templates** - STATE.md, TODO.md, AI assistant configurations (in `templates/`)
**Setup scripts** - Pure bash, assistant-specific setup

**Design principle:** Radical simplification - 95% reduction vs deprecated hs-ci/ai code

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
# Claude Code
./claude-code.sh

# (Future) Cursor
# ./cursor.sh

# (Future) GitHub Copilot
# ./copilot.sh
```

---

## Repository Structure

**Path variables used in documentation:**
- `$AI_ROOT` = Where this repo is attached (e.g., `ai/`, `standards/`, `.ai/`)
- `$PROJECT_ROOT` = Parent project root (where STATE.md, TODO.md are deployed)

```text
parent-project/              # Your project ($PROJECT_ROOT)
├── ai/                      # This repository ($AI_ROOT - can be any name)
│   ├── install.sh           # Deploy cross-assistant templates
│   ├── claude-code.sh       # Claude Code specific setup
│   ├── cursor.sh            # (Future) Cursor specific setup
│   ├── copilot.sh           # (Future) GitHub Copilot setup
│   │
│   ├── standards/           # Coding standards (main product)
│   │   ├── STANDARDS.md     # Entry point with loading strategy
│   │   ├── code-assistant/  # AI-specific guidance (all assistants)
│   │   ├── common/          # Language-agnostic standards
│   │   └── python/          # Python-specific standards
│   │
│   └── templates/           # Templates for all AI assistants
│       ├── STATE.md         # Cross-assistant session state
│       ├── TODO.md          # Cross-assistant task tracking
│       ├── claude-code/     # Claude Code specific
│       ├── cursor/          # (Future) Cursor specific
│       └── copilot/         # (Future) Copilot specific
│
├── STATE.md                 # Created by install.sh (all assistants use this)
├── TODO.md                  # Created by install.sh (all assistants use this)
├── .claude/                 # Created by claude-code.sh (Claude Code only)
└── CLAUDE.md -> STATE.md    # Symlink (Claude Code only)
```

---

## For AI Code Assistants

**Standards are path-agnostic - reference using `$AI_ROOT` variable.**

**Loading strategy:**

- **Context window >= 500K tokens:** Load ALL standards (full CAG)
- **Context window < 500K tokens:** Load Tier 1 mandatory, Tier 2 on-demand (CAG/RAG hybrid)

**See [standards/STANDARDS.md](standards/STANDARDS.md) for complete loading instructions.**

---

## What's Included

### Standards Documentation (`standards/`)

**AI-specific guidance:**
- Session management, commit messages, CI workflows
- Platform-specific guides (Claude Code, GitHub Copilot)
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
- `claude-code/` - Claude Code configuration and slash commands
- `cursor/` - (Future) Cursor configuration
- `copilot/` - (Future) GitHub Copilot configuration

### Setup Scripts (root)

**Cross-assistant:**
- `install.sh` - Deploy STATE.md and TODO.md (all assistants use these)

**Assistant-specific:**
- `claude-code.sh` - Configure Claude Code (creates .claude/ directory)
- `cursor.sh` - (Future) Configure Cursor
- `copilot.sh` - (Future) Configure GitHub Copilot

**All scripts:**
- Pure bash (bash 3.2+ compatible)
- Self-contained (< 300 lines each)
- Idempotent (safe to run multiple times)
- No dependencies beyond Unix basics

---

## Relationship with HS-CI

This repository is **independent** of hs-ci (CI/CD infrastructure).

**Separation of concerns:**
- `ai` - Standards, documentation, AI guidance (this repo)
- `ci` - Build/test/release automation, git hooks

**Can be used:**
- Together with hs-ci (common for HyperSec projects)
- Standalone (no hs-ci dependency required)
- With any other CI/CD system

**Migration note:** Deprecated hs-ci/ai code (in `deprecated/`) has been split out and radically simplified.

---

## Contributing

**This repository is read-only for most projects.**

To propose standards changes:
1. Create GitHub issue with proposal
2. Submit PR with changes to `docs/standards/`
3. Get approval from 2+ team leads
4. Update version in STANDARDS.md

**Version history tracked in STANDARDS.md**

---

## Release Process

Releases are fully automated via semantic-release on push to `main`:

- VERSION file contains current version (e.g., `1.2.3`)
- CHANGELOG.md contains release history
- Git tags track versions (e.g., `1.2.3` without `v` prefix)
- GitHub releases created automatically

**Commit types that trigger releases:**

- `feat:` - Minor version bump (1.0.0 → 1.1.0)
- `fix:`, `perf:`, `refactor:`, `sec:`, `hotfix:` - Patch version bump (1.0.0 → 1.0.1)
- `BREAKING CHANGE:` footer - Major version bump (1.0.0 → 2.0.0)
- Other types (`docs:`, `test:`, `chore:`, etc.) - No version bump

---

## License

HyperSec EULA (Proprietary) - See [LICENSE](LICENSE)

**Copyright:** (c) 2025 HyperSec Pty Ltd

---

## Links

- **Standards documentation:** [standards/STANDARDS.md](standards/STANDARDS.md)
- **HS-CI repository:** https://github.com/hypersec-io/ci
- **Issue tracker:** https://github.com/hypersec-io/ai/issues
