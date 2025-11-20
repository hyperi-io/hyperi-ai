# HyperSec AI Code Assistant Standards

**Repository:** https://github.com/hypersec-io/ai
**Purpose:** Standards, guidance, and templates that "tack on" to any project
**License:** HyperSec EULA (proprietary)

---

## Overview

This repository provides **standards and templates for developers and AI code assistants** that can be attached to any project.

**What's included:**
- **Standards** - AI assistant guidance, coding standards, best practices
- **Templates** - STATE.md, TODO.md, Claude Code configuration
- **Setup scripts** - Simple bash scripts for installation (NO Python required)

**Design principle:** Radical simplification - 95% reduction in complexity vs legacy hs-ci/ai

**Key features:**
- Works as git submodule, clone, or ZIP download
- Pure bash scripts (bash 3.2+ compatible - works on macOS, Linux, WSL)
- No dependencies beyond standard Unix tools
- Path-agnostic (can be attached anywhere, not just `/ai`)
- Cross-LLM session state (STATE.md, TODO.md work for all AI assistants)

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

**Setup Claude Code (optional):**

```bash
./claude-code.sh

# This creates:
# - .claude/ directory with settings
# - CLAUDE.md -> STATE.md symlink
```

---

## Repository Structure

**Path variables used in documentation:**
- `$AI_ROOT` = Where this repo is attached (e.g., `ai/`, `standards/`, `.ai/`)
- `$PROJECT_ROOT` = Parent project root (where STATE.md, TODO.md are deployed)

```text
parent-project/              # Your project ($PROJECT_ROOT)
├── ai/                      # This repository ($AI_ROOT - can be any name)
│   ├── install.sh           # Installation script
│   ├── claude-code.sh       # Claude Code setup
│   │
│   ├── standards/           # AI assistant guidance (main product)
│   │   ├── STANDARDS.md     # Entry point with loading strategy
│   │   ├── code-assistant/  # AI-specific guidance
│   │   ├── common/          # Language-agnostic standards
│   │   └── python/          # Python-specific standards
│   │
│   └── templates/           # Configuration templates
│       ├── STATE.md         # Cross-LLM session state template
│       ├── TODO.md          # Cross-LLM task tracking template
│       └── claude-code/     # Claude Code specific
│
├── STATE.md                 # Created by install.sh
├── TODO.md                  # Created by install.sh
├── .claude/                 # Created by claude-code.sh
└── CLAUDE.md -> STATE.md    # Symlink created by claude-code.sh
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

**Cross-LLM (all AI assistants):**
- `STATE.md` - Project state and session history
- `TODO.md` - Task tracking with time estimates

**Claude Code specific:**
- `settings.json` - Permissions, model config
- `commands/start.md` - Session initialization
- `commands/save.md` - Progress checkpointing

### Setup Scripts (root)

- `install.sh` - Deploy templates to project root
- `claude-code.sh` - Configure Claude Code (creates .claude/ and symlinks)

**All scripts:**
- Pure bash (bash 3.2+ compatible)
- Self-contained (< 200 lines each)
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

**Migration note:** Legacy hs-ci/ai code has been split out and radically simplified.

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
