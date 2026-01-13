# HyperSec AI Code Assistant Standards

Standards, templates, and setup scripts for AI-assisted development.

**[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes

**License:** HyperSec EULA (proprietary)

---

## What This Is

A standards library that attaches to any project to provide:

- **Coding standards** - Language-agnostic + language-specific (Python, Go, TypeScript, Rust, Bash, C++) + infrastructure (Docker, K8s, Terraform, Ansible)
- **Session state** - Cross-LLM session persistence (STATE.md, TODO.md)
- **AI assistant configs** - Setup scripts for Claude Code, Cursor IDE, Gemini Code, OpenAI Codex

**Design:**

- Pure bash 3.2+ (macOS, Linux, WSL)
- Zero dependencies beyond standard Unix tools
- Path-agnostic (works anywhere, any directory name)
- Idempotent (safe to run repeatedly)
- Works standalone or alongside HyperSec CI (`ci/` submodule)

---

## Attach Options

```bash
./ai/attach.sh [OPTIONS]

OPTIONS:
  --agent NAME       Setup specific agent (claude, cursor, gemini, codex)
  --all-agents       Setup all installed agents
  --no-agent         Skip agent detection entirely

  --pin              Pin submodule version (disable auto-update)
  --force            Overwrite existing files
  --no-hooks         Skip git hook installation
  --dry-run          Preview changes without modifying
  --verbose          Detailed output

EXAMPLES:
  ./ai/attach.sh                    # Auto-detect and configure first found agent
  ./ai/attach.sh --agent claude     # Attach + Claude Code
  ./ai/attach.sh --all-agents       # Configure all installed agents
  ./ai/attach.sh --no-agent         # Attach without agent setup
  ./ai/attach.sh --force            # Overwrite existing files
```

**Agent auto-detection:** When no agent flag specified, attach.sh detects installed
CLIs in priority order: `claude` → `agent` (Cursor) → `gemini` → `codex`

**Deprecated flags:** `--claude`, `--cursor`, `--gemini` still work but show warnings.
Use `--agent NAME` instead.

---

## What Gets Created

### By `attach.sh`

| File | Purpose |
|------|---------|
| `STATE.md` | Project state, session history, context for AI |
| `TODO.md` | Task tracking, priorities |

### By agent scripts

| Script | CLI | Creates |
|--------|-----|---------|
| `agents/claude.sh` | `claude` | `.claude/settings.json`, `.claude/commands/`, `CLAUDE.md` → `STATE.md` |
| `agents/cursor.sh` | `agent` | `.cursor/cli.json`, `.cursor/rules/`, `CURSOR.md` → `STATE.md` |
| `agents/gemini.sh` | `gemini` | `.gemini/settings.json`, `.gemini/commands/`, `GEMINI.md` → `STATE.md` |
| `agents/codex.sh` | `codex` | `.github/copilot-instructions.md`, `.github/skills/`, `.vscode/settings.json`, `CODEX.md` → `STATE.md` |

---

## Repository Structure

```text
ai/                              # This repository ($AI_ROOT)
├── attach.sh                    # Attach AI to project (auto-detects agents)
│
├── agents/                      # Agent setup scripts
│   ├── common.sh               # Shared functions (CLI detection, logging)
│   ├── claude.sh               # Claude Code setup
│   ├── cursor.sh               # Cursor IDE setup
│   ├── gemini.sh               # Gemini Code setup
│   └── codex.sh                # OpenAI Codex / VS Code setup
│
├── standards/                   # Coding standards (main product)
│   ├── STANDARDS.md             # Full reference
│   ├── STANDARDS-QUICKSTART.md  # Core standards (~7.5K tokens)
│   ├── code-assistant/          # AI-specific guidance
│   ├── common/                  # Language-agnostic standards
│   ├── languages/               # Python, Go, TypeScript, Rust, Bash, C++
│   └── infrastructure/          # Docker, K8s, Terraform, Ansible
│
├── templates/                   # Deployment templates
│   ├── STATE.md                 # Session state template
│   ├── TODO.md                  # Task tracking template
│   ├── claude-code/             # Claude Code configs
│   ├── cursor/                  # Cursor configs
│   ├── gemini/                  # Gemini configs
│   ├── copilot/                 # Copilot/Codex configs
│   └── github/skills/           # VS Code Agent Skills templates
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
./ai/attach.sh --agent claude
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
| `CMakeLists.txt`, `*.cpp` | `languages/CPP.md` |
| `Dockerfile` | `infrastructure/DOCKER.md` |
| `Chart.yaml` | `infrastructure/K8S.md` |
| `*.tf` | `infrastructure/TERRAFORM.md` |
| `ansible.cfg` | `infrastructure/ANSIBLE.md` |
| `certs/`, `ssl/`, `pki/` | `common/PKI.md` |

**Token budget:** ~15-20K tokens typical session (vs ~50K+ if all loaded)

---

## VS Code 1.108+ Agent Skills

The `codex.sh` agent creates VS Code Agent Skills in `.github/skills/`:

```json
{
    "chat.useAgentSkills": true
}
```

Skills are YAML-frontmatter markdown files automatically loaded based on project context.

---

## Claude Code Usage

After running `./ai/attach.sh --agent claude`:

**`/load`** - Begin session

- Establishes current date (not training data date)
- Loads TODO.md (tasks), STATE.md (static context)
- Loads standards based on project type
- Syncs git and updates ai submodule

**`/save`** - Checkpoint progress

- Updates TODO.md with task progress
- Validates STATE.md has no forbidden content
- Checks git status

**Best practice:** Run `/save` every 30-40 exchanges or before breaks.

### Recommended VS Code Settings

Add to your VS Code `settings.json` for optimal Claude Code experience:

```json
{
  "claudeCode.initialPermissionMode": "acceptEdits"
}
```

| Setting | Value | Effect |
|---------|-------|--------|
| `initialPermissionMode` | `acceptEdits` | Auto-approve file edits (recommended) |
| | `default` | Prompt for each edit |
| | `plan` | Start in planning mode |
| | `bypassPermissions` | Skip all prompts (use with caution) |

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

## Path Variables

Documentation uses these variables:

- `$AI_ROOT` - Where this repo is attached (e.g., `ai/`, `standards/`, `.ai/`)
- `$PROJECT_ROOT` - Parent project root (where STATE.md lives)

---

## License

HyperSec EULA (Proprietary) - See [LICENSE](LICENSE)

Copyright (c) 2026 HyperSec
