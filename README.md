# HyperI AI Code Assistant Standards

Standards, templates, and setup scripts for AI-assisted development.

**[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes

**License:** Proprietary — HYPERI PTY LIMITED internal use only

---

## Important: This Is Not a Code Dependency

**The `ai/` submodule provides standards and configuration - not code to import.**
Your project should never import, require, or link to anything in this directory.

- ✅ Humans and AI assistants read standards from `ai/standards/`
- ✅ Setup scripts create config files (`.claude/`, `STATE.md`, etc.)
- ❌ No `import ai`, `require('ai')`, or build dependencies
- ❌ No runtime code paths into `ai/`

If you find yourself writing code that references `ai/`, stop - that's not how
this works. The `ai/` directory provides coding standards for humans and AI
assistants to follow, plus configuration for AI tools. It's not a library.

---

## What This Is

A standards library that attaches to any project to provide:

- **Coding standards** - Language-agnostic + language-specific (Python, Go, TypeScript, Rust, Bash, C++) + infrastructure (Docker, K8s, Terraform, Ansible)
- **Session state** - Cross-LLM session persistence (STATE.md, TODO.md)
- **AI assistant configs** - Setup scripts for Claude Code, Cursor IDE, Gemini Code, OpenAI Codex

**Design:**

- **Hooks:** Python 3 stdlib (no pip dependencies) — technology detection, standards injection, safety, formatting, linting
- **Scripts:** Bash 3.2+ (macOS, Linux, WSL) — attach.sh, agent deployment
- Path-agnostic (works anywhere, any directory name)
- Idempotent (safe to run repeatedly)
- Works standalone or alongside HyperI CI (`ci/` submodule)

---

## Attach Options

There are **two attach modes** depending on whether your repository is internal or public:

| Repository Type | Script | Approach |
|-----------------|--------|----------|
| Internal/private | `attach.sh` | Git submodule (versioned, auto-updates) |
| Public/open-source | `attach-public.sh` | Gitignored directory (local only, never committed) |

### Internal Repos (attach.sh)

Use for internal/private repositories where `ai/` can be a visible submodule:

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

### Public Repos (attach-public.sh)

Use for public/open-source repositories where you don't want internal tooling exposed:

```bash
./ai/attach-public.sh [OPTIONS]

OPTIONS:
  --agent NAME       Setup specific agent (claude, cursor, gemini, codex)
  --all-agents       Setup all installed agents
  --no-agent         Skip agent detection entirely

  --path PATH        Specify project root (default: current directory)
  --force            Overwrite existing files
  --dry-run          Preview changes without modifying
  --verbose          Detailed output

EXAMPLES:
  # First time - run from ai/ repo or with --path
  /projects/ai/attach-public.sh --path /path/to/public-repo

  # Or clone ai/ manually, then run
  git clone --depth 1 https://github.com/hyperi-io/ai.git ai
  ./ai/attach-public.sh
```

**What's different:**

| Aspect | attach.sh (internal) | attach-public.sh (public) |
|--------|---------------------|---------------------------|
| `ai/` visibility | Git submodule (committed) | Gitignored (local only) |
| Updates | `git submodule update --remote` | `git -C ai pull` or `/load` auto-syncs |
| Cloning | Automatic via submodule | Manual clone or via `/load` |
| `.gitmodules` | Updated | Not touched |

**How it works:**

1. Clones `ai/` locally (keeps `.git/` for manual updates via `git -C ai pull`)
2. Adds `ai/` to `.gitignore` (never committed to public repo)
3. Creates `.claude/commands/load.md` that auto-updates `ai/` on each `/load`
4. Deploys the same templates as `attach.sh`

**For public repo contributors:** Run `attach-public.sh` once, or just use `/load`
which will clone `ai/` automatically if missing. To manually update: `git -C ai pull`

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
| `agents/claude.sh` | `claude` | `.claude/settings.json`, `.claude/commands/` (symlinks), `.claude/rules/` (symlinks), `.claude/skills/`, `.claude/memory/`, `CLAUDE.md` → `STATE.md` |
| `agents/cursor.sh` | `agent` | `.cursor/cli.json`, `.cursor/rules/*.mdc` (converted from `standards/rules/`), `CURSOR.md` → `STATE.md` |
| `agents/gemini.sh` | `gemini` | `.gemini/settings.json`, `.gemini/commands/`, `GEMINI.md` → `STATE.md` |
| `agents/codex.sh` | `codex` | `.github/copilot-instructions.md` (generated), `.github/skills/`, `.vscode/settings.json`, `CODEX.md` → `STATE.md` |

---

## Repository Structure

```text
ai/                              # This repository ($AI_ROOT)
├── attach.sh                    # Attach AI to project (submodule mode)
├── attach-public.sh             # Attach AI to public repo (gitignored mode)
│
├── agents/                      # Agent setup scripts (bash)
│   ├── common.sh               # Shared functions (CLI detection, logging)
│   ├── claude.sh               # Claude Code setup + version stamp
│   ├── cursor.sh               # Cursor IDE setup
│   ├── gemini.sh               # Gemini Code setup
│   └── codex.sh                # OpenAI Codex / GitHub Copilot setup
│
├── hooks/                       # Claude Code hooks (Python 3 stdlib)
│   ├── common.py               # Shared: tech detection, rule injection, safety, formatting
│   ├── inject_standards.py     # SessionStart(startup): date + standards + auto-update
│   ├── on_compact.py           # SessionStart(compact): re-inject after compaction
│   ├── auto_format.py          # PostToolUse(Edit|Write): run formatter on edited files
│   ├── subagent_context.py     # SubagentStart: inject standards into subagents
│   ├── safety_guard.py         # PreToolUse(Bash): block dangerous commands
│   └── lint_check.py           # Stop: lint modified files, feed errors back
│
├── standards/                   # Coding standards (main product)
│   ├── STANDARDS.md             # Full reference
│   ├── STANDARDS-QUICKSTART.md  # Router → standards/rules/ (compact single source)
│   ├── rules/                  # Compact rules (<200 lines) — single source for all agents
│   │   ├── UNIVERSAL.md        # Cross-cutting rules (always loaded)
│   │   └── <topic>.md          # Path-scoped rules (auto-injected by file type)
│   ├── code-assistant/          # AI-specific guidance
│   ├── common/                  # Language-agnostic standards
│   ├── languages/               # Python, Go, TypeScript, Rust, Bash, C++
│   └── infrastructure/          # Docker, K8s, Terraform, Ansible
│
├── templates/                   # Deployment templates
│   ├── STATE.md                 # Session state template
│   ├── TODO.md                  # Task tracking template
│   ├── claude-code/             # Claude Code configs (commands, settings, hook wiring)
│   ├── cursor/                  # Cursor configs (cli.json, session rules)
│   ├── gemini/                  # Gemini configs
│   ├── copilot/                 # Copilot/Codex header template
│   └── github/skills/           # VS Code Agent Skills templates
│
├── tools/                       # Development tools
│   └── compact-standards.py    # Generate compact rules from full standards (API script)
│
├── tests/                       # BATS test suite (86 tests)
└── docs/                        # Project documentation
```

---

## Using with HyperI CI

The `ai/` and `ci/` submodules are designed to work together seamlessly:

```bash
# Attach both submodules
git submodule add https://github.com/hyperi-io/ci.git ci
git submodule add https://github.com/hyperi-io/ai.git ai

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

## Submodule Auto-Update

### Default behaviour (auto-update on every session)

**Both `ai/` and `ci/` submodules are automatically updated from upstream
every time a Claude Code session starts.** This happens silently via the
`SessionStart` hook — no manual `git submodule update` needed.

The hook also auto-reattaches: if updated files include commands, rules, or
agent config, it re-runs `claude.sh` to re-deploy them.

Settings stored in `.gitmodules` (propagates to all clones):

- `update = rebase` — apply upstream changes (default)
- `fetchRecurseSubmodules = true` — include in clone

### Pinning a submodule (disable auto-update)

If you need a fixed version (e.g., for reproducible builds or auditing),
pin the submodule. The auto-update hook respects this and will skip it.

```bash
# Pin via attach
./ai/attach.sh --pin

# Or set directly in .gitmodules
git config -f .gitmodules submodule.ai.update none
git config -f .gitmodules submodule.ci.update none   # pin ci too
git add .gitmodules
git commit -m "chore: pin ai and ci submodules"
```

Update a pinned submodule to a specific version manually:

```bash
git -C ai fetch
git -C ai checkout v2.0.0
git add ai
git commit -m "chore: pin ai to v2.0.0"
```

### Unpinning (re-enable auto-update)

```bash
git config -f .gitmodules submodule.ai.update rebase
git config -f .gitmodules submodule.ci.update rebase
git add .gitmodules
git commit -m "chore: unpin ai and ci submodules"
```

### How auto-update works

On every Claude Code session start, the `inject_standards.py` hook:

1. Checks `.gitmodules` for each submodule (`ai`, `ci`)
2. If `update = none` → skip (pinned)
3. If `update = rebase` or unset → run `git submodule update --remote <name>`
4. After updating `ai/`, checks if deployment files changed and re-deploys
5. Writes a version stamp to `.claude/.ai-version` for change tracking

This is fully silent — no output unless something actually changed.

---

## Standards Loading (Three-Layer Architecture)

Standards are delivered in three layers, each with different persistence:

### Layer 1 — CAG: Auto-injected at session start

`standards/rules/UNIVERSAL.md` plus all detected technology rules are automatically
injected into Claude's context by the `SessionStart` hook (`inject_standards.py`).
This also injects the current date and web-search-before-code mandate.

Technology detection scans up to 3 levels deep (handles monorepos and workspaces):

| Marker Files Detected | Rule Auto-Injected |
|----------------------|-------------------|
| `pyproject.toml`, `setup.py`, `requirements.txt` | `python.md` |
| `go.mod` | `golang.md` |
| `package.json`, `tsconfig.json` | `typescript.md` |
| `Cargo.toml` | `rust.md` |
| `*.sh`, `*.bats` | `bash.md` |
| `CMakeLists.txt`, `*.cpp`, `*.cc` | `cpp.md` |
| `Dockerfile`, `docker-compose.yml` | `docker.md` |
| `Chart.yaml`, `values.yaml` | `k8s.md` |
| `*.tf` | `terraform.md` |
| `ansible.cfg`, `playbook*.yml` | `ansible.md` |
| `*.sql` | `clickhouse-sql.md` |
| `certs/`, `ssl/`, `pki/` | `pki.md` |

### Layer 2 — RAG: Auto-injected by file type (survives context compaction)

Compact path-scoped rules in `.claude/rules/` are injected automatically by Claude Code
when you edit matching files. They survive context compaction — unlike session-loaded content.

### Layer 3 — Skills: Full standards on demand

Full standards in `.claude/skills/` are loaded explicitly via `/review` or `/simplify`
when you need deep reference. Not loaded at session start — preserves context budget.

**Token budget:** ~15-20K tokens typical session (vs ~50K+ if all loaded upfront)

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

## Claude Code Integration

After running `./ai/attach.sh --agent claude`, Claude Code gets a full hook
chain that runs automatically — no manual setup per session.

### What happens automatically (no user action needed)

| When | Hook | What It Does |
|------|------|-------------|
| Session start | `inject_standards.py` | Auto-updates ai/ci submodules, injects current date, detects project technologies, injects UNIVERSAL + matching rules, auto-reattaches if submodule changed |
| Context compacted | `on_compact.py` | Re-injects date and standards (lost during compaction) |
| File edited/written | `auto_format.py` | Runs formatter (ruff, rustfmt, gofmt, prettier, shfmt, clang-format) |
| Subagent spawned | `subagent_context.py` | Injects standards into subagent context (they miss SessionStart) |
| Bash command run | `safety_guard.py` | Blocks dangerous commands (rm -rf /, force push main, dd, mkfs, fork bombs) |
| Task completed | `lint_check.py` | Lints modified files, feeds errors back to Claude to fix |

### Session lifecycle (normal flow)

```text
┌─────────────────────────────────────────────────────────────────┐
│ 1. USER OPENS PROJECT IN CLAUDE CODE                            │
│                                                                 │
│    SessionStart(startup) fires automatically:                   │
│    ├── Auto-update ai/ and ci/ submodules (if not pinned)       │
│    ├── Auto-reattach (re-deploy if submodule files changed)     │
│    ├── Inject current date (overrides stale training data)      │
│    ├── Detect project technologies (scans 3 levels deep)        │
│    └── Inject UNIVERSAL.md + all matching tech rules            │
│                                                                 │
│    Standards are now in context. No /load needed for standards.  │
├─────────────────────────────────────────────────────────────────┤
│ 2. USER RUNS /load (optional but recommended)                   │
│                                                                 │
│    ├── Reads TODO.md (task tracking)                            │
│    ├── Reads STATE.md (project architecture, decisions)         │
│    ├── Syncs git (pull --rebase, status, recent commits)        │
│    └── Verifies standards are loaded                            │
├─────────────────────────────────────────────────────────────────┤
│ 3. USER WORKS — hooks fire automatically                        │
│                                                                 │
│    Edit/Write file → auto_format.py runs formatter              │
│    Bash command    → safety_guard.py blocks dangerous commands   │
│    Spawn subagent  → subagent_context.py injects standards      │
│    Task completes  → lint_check.py checks modified files        │
├─────────────────────────────────────────────────────────────────┤
│ 4. CONTEXT COMPACTS (automatic, when context window fills)      │
│                                                                 │
│    SessionStart(compact) fires:                                 │
│    ├── Re-injects current date                                  │
│    ├── Re-injects all standards (lost during compaction)        │
│    └── Prompts user to run /load for full project state         │
├─────────────────────────────────────────────────────────────────┤
│ 5. USER RUNS /save (periodically, every 30-40 exchanges)       │
│                                                                 │
│    ├── Updates TODO.md with progress                            │
│    ├── Validates STATE.md                                       │
│    └── Checks git status                                        │
└─────────────────────────────────────────────────────────────────┘
```

### Slash commands

**`/load`** — Restore full session context (TODO.md, STATE.md, git sync).
Standards are already loaded by the SessionStart hook — `/load` verifies and
supplements with project state.

**`/save`** — Checkpoint progress (TODO.md, STATE.md validation, git status)

**`/review`** — Code review against full standards (loads skills on demand)

**`/simplify`** — Review for reuse, quality, and efficiency

**`/standards <topic>`** — Force-load a specific rule file (e.g., `/standards rust`)

**Best practice:** Run `/save` every 30-40 exchanges or before breaks.

### Recommended VS Code Settings

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

Proprietary — HYPERI PTY LIMITED internal use only. See [LICENSE](LICENSE).

Copyright (c) 2025-2026 HYPERI PTY LIMITED (ABN 31 622 581 748)
