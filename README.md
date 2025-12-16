# HyperSec AI Code Assistant Standards

Standards, templates, and setup scripts for AI-assisted development.

**License:** HyperSec EULA (proprietary)

---

## TL;DR - Just Run This

**AI + CI (recommended):**

```bash
git submodule add https://github.com/hypersec-io/ci.git ci && ./ci/attach.sh --python-package
git submodule add https://github.com/hypersec-io/ai.git ai && ./ai/attach.sh --claude
```

**AI only:**

```bash
git submodule add https://github.com/hypersec-io/ai.git ai && ./ai/attach.sh --claude
```

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
- Works standalone or alongside HyperSec CI (`ci/` submodule)

---

## Quick Start

### Full HyperSec Setup (Recommended)

Two commands to set up both CI and AI:

```bash
# Add CI submodule and configure workflows
git submodule add https://github.com/hypersec-io/ci.git ci && ./ci/attach.sh --python-package

# Add AI submodule and configure Claude Code
git submodule add https://github.com/hypersec-io/ai.git ai && ./ai/attach.sh --claude
```

**For greenfield projects** (no git repo yet), use `hypersec-attach.sh` after adding the CI submodule:

```bash
git submodule add https://github.com/hypersec-io/ci.git ci
./ci/hypersec-attach.sh --python-package
```

This additionally handles git init and GitHub repository creation prompts.

### AI Only Setup

```bash
git submodule add https://github.com/hypersec-io/ai.git ai && ./ai/attach.sh --claude
```

#### Alternative: Clone (point-in-time copy)

```bash
git clone https://github.com/hypersec-io/ai.git ai && rm -rf ai/.git
```

#### Alternative: Download ZIP

```bash
curl -L https://github.com/hypersec-io/ai/archive/main.zip -o ai.zip
unzip ai.zip && mv ai-main ai
```

### Setup Your AI Assistant (if not done via --flag)

```bash
./ai/claude.sh    # Claude Code (Anthropic)
./ai/copilot.sh   # GitHub Copilot
./ai/cursor.sh    # Cursor IDE
./ai/gemini.sh    # Gemini Code (Google)
```

---

## Attach Options

```bash
./ai/attach.sh [OPTIONS]

OPTIONS:
  --claude         Attach + configure Claude Code
  --copilot        Attach + configure GitHub Copilot
  --cursor         Attach + configure Cursor IDE
  --gemini         Attach + configure Gemini Code

  --pin            Pin submodule version (disable auto-update)
  --force          Overwrite existing files
  --no-hooks       Skip git hook installation
  --dry-run        Preview changes without modifying
  --verbose        Detailed output

EXAMPLES:
  ./ai/attach.sh                    # Basic attach
  ./ai/attach.sh --claude           # Attach + Claude Code
  ./ai/attach.sh --claude --pin     # Attach + Claude, pinned version
  ./ai/attach.sh --force            # Overwrite existing files
```

---

## What Gets Created

### By `attach.sh`

| File | Purpose |
|------|---------|
| `STATE.md` | Project state, session history, context for AI |
| `TODO.md` | Task tracking, priorities |
| `.git/hooks/*` | Git hooks (branch validation, submodule auto-update) |

### By assistant scripts

| Script | Creates |
|--------|---------|
| `claude.sh` | `.claude/settings.json`, `.claude/commands/`, `CLAUDE.md` → `STATE.md` |
| `copilot.sh` | `.github/copilot-instructions.md`, `COPILOT.md` → `STATE.md` |
| `cursor.sh` | `.cursor/cli.json`, `.cursor/rules/`, `CURSOR.md` → `STATE.md` |
| `gemini.sh` | `.gemini/settings.json`, `.gemini/commands/`, `GEMINI.md` → `STATE.md` |

---

## Repository Structure

```text
ai/                              # This repository ($AI_ROOT)
├── attach.sh                    # Attach AI to project
├── claude.sh                    # Claude Code setup
├── copilot.sh                   # GitHub Copilot setup
├── cursor.sh                    # Cursor IDE setup
├── gemini.sh                    # Gemini Code setup
│
├── hooks/                       # Git hooks
│   ├── pre-commit               # Branch name validation
│   ├── commit-msg               # AI attribution removal
│   └── post-checkout            # Submodule auto-update
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

## Using with HyperSec CI

The `ai/` and `ci/` submodules are designed to work together seamlessly:

```bash
# Attach both submodules
git submodule add https://github.com/hypersec-io/ci.git ci
git submodule add https://github.com/hypersec-io/ai.git ai

# Run either attach script - both configure both submodules
./ci/attach.sh --python-package
./ai/attach.sh --claude
```

**When both are present:**

- **CI hooks take precedence** - CI's hooks are more comprehensive (Python validation, CI change detection)
- **Both submodules are auto-configured** - Running either `attach.sh` configures both `ai` and `ci` submodules
- **Same submodule settings** - Both use `update=rebase` in `.gitmodules` (propagates to clones)
- **Same push protection** - Both block pushes via `post-checkout` hook

**Order doesn't matter** - Attach in any order; the scripts detect and cooperate.

---

## Submodule Configuration

### Default (auto-update)

Submodules auto-update from upstream when you run `git submodule update`:

```bash
git submodule update --remote ai
```

Settings stored in `.gitmodules` (propagates to all clones):

- `update = rebase` - Apply upstream changes
- `fetchRecurseSubmodules = true` - Include in clone

### Pinned mode (--pin)

Disable auto-update for fixed versions:

```bash
./ai/attach.sh --pin
```

Update to specific version manually:
```bash
git -C ai fetch
git -C ai checkout v1.0.0
git add ai
git commit -m "chore: pin ai to v1.0.0"
```

### Switch between modes

```bash
# Enable auto-update (default)
git config -f .gitmodules submodule.ai.update rebase

# Disable auto-update (pinned)
git config -f .gitmodules submodule.ai.update none
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

## Claude Code Usage

After running `./ai/claude.sh`:

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
bats tests/attach.bats
bats tests/claude.bats
```

Tests cover all scripts across submodule, clone, and standalone modes.

---

## Path Variables

Documentation uses these variables:

- `$AI_ROOT` - Where this repo is attached (e.g., `ai/`, `standards/`, `.ai/`)
- `$PROJECT_ROOT` - Parent project root (where STATE.md lives)

---

## License

HyperSec EULA (Proprietary) - See [LICENSE](LICENSE)

Copyright (c) 2025 HyperSec
