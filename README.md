# HyperSec AI Code Assistant Standards

**Repository:** https://github.com/hypersec-io/ai
**Purpose:** Code standards, AI assistant guidance, and development templates
**License:** Apache-2.0

---

## Overview

This repository contains:
- **Code standards** - Language-agnostic and language-specific coding standards
- **AI assistant guidance** - Instructions for AI code completion tools (Claude Code, GitHub Copilot, etc.)
- **Development templates** - Claude Code configuration, slash commands, documentation templates

**This is a standards repository** - it contains no executable code, only documentation and configuration templates.

---

## Repository Structure

```
ai/
├── docs/
│   └── standards/
│       ├── STANDARDS.md           # Entry point with CAG/RAG loading strategy
│       ├── ai/                    # AI principles and token engineering
│       ├── code-assistant/        # AI-specific guidance (COMMON, PYTHON, HS-CI)
│       ├── common/                # Language-agnostic standards
│       └── python/                # Python-specific standards
└── templates/
    ├── claude-code/               # Claude Code integration
    │   ├── settings.json          # Permissions and configuration
    │   └── commands/              # Slash commands (/start, /save)
    ├── STATE.md                   # Project state template
    └── SETTINGS-PROFILES.md       # AI configuration profiles
```

---

## Usage

### For Projects

**Add as submodule:**
```bash
git submodule add https://github.com/hypersec-io/ai.git ai
git submodule update --init --recursive
```

**Reference in CI/bootstrap:**
- Copy templates from `ai/templates/` to project root
- Load standards from `ai/docs/standards/` in `/start` command
- Reference documentation in project STATE.md

### For AI Code Assistants

**Loading strategy (from STANDARDS.md):**

**If context window >= 500K tokens:**
- Load ALL standards using glob patterns
- Full CAG (Context-Aware Generation)

**If context window < 500K tokens:**
- Load Tier 1 (mandatory): code-assistant/, essential common files
- Load Tier 2 (on-demand): specific standards as needed
- CAG/RAG Hybrid approach

**See [docs/standards/STANDARDS.md](docs/standards/STANDARDS.md) for complete loading instructions.**

---

## Standards Included

### Code Standards
- **Language-agnostic:** SOLID, DRY, KISS, YAGNI, error handling, testing, security
- **Python:** PEP 8, type hints, testing, HS-CI integration
- **Git:** Conventional Commits, branching, PR standards

### AI Guidance
- **AI-GUIDELINES.md** - Quality warnings, best practices, platform-specific guides
- **COMMON.md** - Session management, CI infrastructure, commit messages
- **PYTHON.md** - Python virtual environments, testing, version sync
- **HS-CI.md** - CI-specific workflow (for CI development only)

### Design Principles
- SOLID principles with examples
- Error handling (security-first)
- No mocks policy
- Test-first development
- Containerization standards

---

## Integration with HS-CI

This repository is **separate from hs-ci** (CI/CD infrastructure).

**Separation:**
- `ai` - Standards, documentation, AI guidance (this repo)
- `ci` - Build/test/release automation, git hooks, CI scripts

**Projects typically use both:**
```
myproject/
├── ai/    (submodule → github.com/hypersec-io/ai)
├── ci/    (submodule → github.com/hypersec-io/ci)
```

---

## Claude Code Integration

**Templates provided:**
- `templates/claude-code/settings.json` - Permissions, model config
- `templates/claude-code/commands/start.md` - Session initialization
- `templates/claude-code/commands/save.md` - Progress checkpointing

**Setup:**
```bash
# Copy templates to project
cp -r ai/templates/claude-code/.claude/ .

# Templates reference ai/docs/standards/ for loading
```

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

## Versioning

**Semantic versioning:** MAJOR.MINOR.PATCH

- **MAJOR:** Breaking changes to standards structure or loading strategy
- **MINOR:** New standards added, non-breaking updates
- **PATCH:** Typo fixes, clarifications, examples

**Current version:** See [docs/standards/STANDARDS.md](docs/standards/STANDARDS.md)

---

## License

Apache License 2.0 - See [LICENSE](LICENSE)

**Copyright:** (c) 2025 HyperSec

---

## Links

- **Standards documentation:** [docs/standards/STANDARDS.md](docs/standards/STANDARDS.md)
- **HS-CI repository:** https://github.com/hypersec-io/ci
- **Issue tracker:** https://github.com/hypersec-io/ai/issues
