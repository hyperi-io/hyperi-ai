# HyperSec AI Code Assistant Standards

Standards, templates, and setup scripts for AI-assisted development.

**License:** HyperSec EULA (proprietary)

---

## What This Is

A standards library that attaches to any project to provide:

- **Coding standards** - Language-agnostic + language-specific (Python, Go, TypeScript, Rust, Bash) + infrastructure (Docker, K8s, Terraform, Ansible)
- **Session state** - Cross-LLM session persistence (STATE.md, TODO.md)
- **AI assistant configs** - Setup scripts for Claude Code, GitHub Copilot, Cursor IDE, Gemini

**Design:**

- Pure bash 3.2+ (macOS, Linux, WSL)
- Zero dependencies beyond standard Unix tools
- Path-agnostic (works anywhere, any directory name)
- Idempotent (safe to run repeatedly)

---

## Quick Start

### 1. Attach to Your Project

```bash
# Option A: Git submodule (recommended - get updates)
git submodule add https://github.com/hypersec-io/ai.git ai
git config submodule.ai.update none  # Prevent accidental commits

# Option B: Clone (point-in-time copy)
git clone https://github.com/hypersec-io/ai.git ai && rm -rf ai/.git

# Option C: Download ZIP
curl -L https://github.com/hypersec-io/ai/archive/main.zip -o ai.zip
unzip ai.zip && mv ai-main ai
```

### 2. Deploy Session State Files

```bash
./ai/install.sh
# Creates: STATE.md, TODO.md in project root
```

### 3. Setup Your AI Assistant

```bash
./ai/claude-code.sh   # Claude Code (Anthropic)
./ai/copilot.sh       # GitHub Copilot / OpenAI Codex
./ai/cursor.sh        # Cursor IDE
./ai/gemini.sh        # Gemini Code (Google)
```

---

## What Gets Created

### By `install.sh` (all assistants)

| File | Purpose |
|------|---------|
| `STATE.md` | Project state, session history, context for AI |
| `TODO.md` | Task tracking, priorities |

### By assistant scripts

| Script | Creates |
|--------|---------|
| `claude-code.sh` | `.claude/settings.json`, `.claude/commands/`, `CLAUDE.md` → `STATE.md` |
| `copilot.sh` | `.github/copilot-instructions.md`, `COPILOT.md` → `STATE.md` |
| `cursor.sh` | `.cursor/cli.json`, `.cursor/rules/`, `CURSOR.md` → `STATE.md` |
| `gemini.sh` | `.gemini/settings.json`, `.gemini/commands/`, `GEMINI.md` → `STATE.md` |

---

## Repository Structure

```text
ai/                              # This repository ($AI_ROOT)
├── install.sh                   # Deploy STATE.md, TODO.md
├── claude-code.sh               # Claude Code setup
├── copilot.sh                   # GitHub Copilot setup
├── cursor.sh                    # Cursor IDE setup
├── gemini.sh                    # Gemini Code setup
│
├── standards/                   # Coding standards (main product)
│   ├── STANDARDS.md             # Full reference
│   ├── STANDARDS-QUICKSTART.md  # Core standards (~7.5K tokens)
│   ├── code-assistant/          # AI-specific guidance
│   ├── common/                  # Language-agnostic standards
│   ├── languages/               # Python, Go, TypeScript, Rust, Bash
│   └── infrastructure/          # Docker, K8s, Terraform, Ansible
│
├── templates/                   # Deployment templates
│   ├── STATE.md                 # Session state template
│   ├── TODO.md                  # Task tracking template
│   ├── claude-code/             # Claude Code configs
│   ├── copilot/                 # Copilot configs
│   ├── cursor/                  # Cursor configs
│   └── gemini/                  # Gemini configs
│
├── tests/                       # BATS test suite
└── docs/                        # Project documentation
```

---

## Standards Loading

AI assistants load standards based on project files detected:

**Always loaded:**

- `STANDARDS-QUICKSTART.md` (~7.5K tokens)

**Auto-detected by project files:**

| Project Files | Standards Loaded |
|---------------|------------------|
| `pyproject.toml`, `*.py` | `languages/PYTHON.md` |
| `go.mod` | `languages/GOLANG.md` |
| `package.json`, `tsconfig.json` | `languages/TYPESCRIPT.md` |
| `Cargo.toml` | `languages/RUST.md` |
| `*.sh` | `languages/BASH.md` |
| `Dockerfile` | `infrastructure/DOCKER.md` |
| `Chart.yaml` | `infrastructure/K8S.md` |
| `*.tf` | `infrastructure/TERRAFORM.md` |
| `ansible.cfg` | `infrastructure/ANSIBLE.md` |

**Token budget:** ~15-20K tokens typical session (vs ~50K+ if all loaded)

---

## Script Options

All scripts support:

```bash
--help      # Show usage
--dry-run   # Preview changes without modifying
--force     # Overwrite existing files
--path DIR  # Custom project root (default: parent directory)
--verbose   # Detailed output
```

---

## Claude Code Usage

After running `./ai/claude-code.sh`:

**`/load`** - Begin session

- Loads STATE.md, TODO.md
- Loads standards based on project type
- Checks git status

**`/save`** - Checkpoint progress

- Updates STATE.md with session progress
- Cleans TODO.md (removes completed)
- Fixes markdown linting

**Best practice:** Run `/save` every 30-40 exchanges or before breaks.

---

## Testing

```bash
# Run all tests
bats tests/

# Run specific test
bats tests/install.bats
bats tests/claude-code.bats
```

Tests cover all scripts across submodule, clone, and standalone modes.

---

## Testing Status

| Assistant | Automated Tests | Manual Testing |
|-----------|-----------------|----------------|
| Claude Code | ✅ | ✅ Verified in VS Code |
| GitHub Copilot | ✅ | ⚠️ Not manually verified |
| Cursor IDE | ✅ | ⚠️ Not manually verified |
| Gemini Code | ✅ | ⚠️ Not manually verified |

---

## Path Variables

Documentation uses these variables:

- `$AI_ROOT` - Where this repo is attached (e.g., `ai/`, `standards/`, `.ai/`)
- `$PROJECT_ROOT` - Parent project root (where STATE.md lives)

---

## License

HyperSec EULA (Proprietary) - See [LICENSE](LICENSE)

Copyright (c) 2025 HyperSec
