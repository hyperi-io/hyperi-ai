# HyperI AI Code Assistant Standards

Standards, templates, and setup scripts for AI-assisted development.

**[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes

**License:** Proprietary -- HYPERI PTY LIMITED internal use only

---

## Important: This Is Not a Code Dependency

**The `hyperi-ai/` submodule provides standards and configuration - not code to import.**
Your project should never import, require, or link to anything in this directory.

- Humans and AI assistants read standards from `hyperi-ai/standards/`
- Setup scripts create config files (`.claude/`, `.mcp.json`, `STATE.md`, etc.)
- No `import hyperi_ai`, `require('hyperi-ai')`, or build dependencies
- No runtime code paths into `hyperi-ai/`

If you find yourself writing code that references `hyperi-ai/`, stop -- that's not how
this works. The `hyperi-ai/` directory provides coding standards for humans and AI
assistants to follow, plus configuration for AI tools. It's not a library.

---

## What This Is

A standards library that attaches to any project as a git submodule to provide
coding standards, AI assistant configuration, and engineering discipline rules
for Claude Code, Cursor IDE, Gemini Code, and OpenAI Codex.

**Design:** Python 3 stdlib hooks (no pip dependencies), Bash 3.2+ scripts
(macOS, Linux, WSL), path-agnostic, idempotent, works standalone or alongside
HyperI CI.

**Methodology:** We use [superpowers](https://github.com/obra/superpowers) for
general development methodology (debugging, TDD, brainstorming, worktrees, planning,
code review). hyperi-ai carries only what's unique to us: corporate coding standards,
verification, documentation, and bleeding-edge dependency protection.

---

## Architecture

The submodule has seven distinct layers:

| Layer | Location | Format | Purpose | Survives Compaction |
|---|---|---|---|---|
| **Rules** | `standards/rules/` | Markdown + YAML frontmatter | Path-scoped coding standards, auto-injected on file read | Yes (CC rules) |
| **Skills** | `skills/` | Agent Skills `SKILL.md` | Unique methodology: verification, documentation, bleeding-edge | Yes (descriptions) |
| **Commands** | `commands/` | Markdown prompt files | User-invocable: `/review`, `/load`, `/save`, `/setup-claude`, etc. | N/A (user-triggered) |
| **Hooks** | `hooks/` | Python scripts | Automatic event handlers (format, lint, safety, inject) | Yes (hook config) |
| **Settings** | `templates/claude-code/settings.json` | JSON | Permission patterns, hook wiring | Yes (file-based) |
| **MCP** | `.mcp.json` | JSON | MCP server config (Context7 for live library docs) | Yes (MCP config) |
| **Agents** | `agents/` | Shell scripts | Setup/deploy scripts per AI tool | N/A (one-time deploy) |

### What each layer does

| Layer | Source | Delivered As | What It Covers |
|---|---|---|---|
| **Corporate code standards** | `standards/rules/UNIVERSAL.md` | CC rule (always-on) | Australian English, file headers, no emojis, git conventions, licensing, security |
| **Language rules** | `standards/rules/<lang>.md` | CC rule (path-scoped) | Python/uv/ruff, Rust, Go, TypeScript, Bash, C++, ClickHouse SQL |
| **Infrastructure rules** | `standards/rules/<infra>.md` | CC rule (path-scoped) | Docker, K8s, Terraform, Ansible, PKI |
| **Cross-cutting rules** | `standards/rules/*.md` | CC rule (path-scoped) | Git, security, CI, error handling, design principles, code style, config, mocks |
| **Verification** | `skills/verification/` | CC skill | Verify before claiming completion -- requires fresh command output as evidence |
| **Documentation** | `skills/documentation/` | CC skill | Docs must match code reality -- verify before writing |
| **Bleeding-edge** | `skills/bleeding-edge/` | CC skill | Stale training data protection -- web search first, Context7 MCP for live docs |
| **Live library docs** | `.mcp.json` (Context7) | MCP server | Fetch current documentation for any library via `resolve-library-id` + `query-docs` |
| **Debugging** | superpowers plugin | CC skill | Systematic debugging methodology |
| **TDD** | superpowers plugin | CC skill | Test-driven development enforcement |
| **Brainstorming** | superpowers plugin | CC skill | Design and brainstorming workflow |

### How the layers interact

```text
attach.sh
  |-- agents/claude.sh (or cursor.sh, gemini.sh, codex.sh)
        |-- Deploy settings.json --> hooks/ (automatic event handlers)
        |-- Symlink commands/    --> /review, /save, /load, /setup-claude
        |-- Symlink rules/       --> .claude/rules/ (file-type scoped)
        |-- Symlink skills/      --> .claude/skills/ (verification, documentation, bleeding-edge)
        +-- Deploy .mcp.json     --> Context7 MCP for live library documentation

Session starts:
  inject_standards.py --> Reads standards/rules/*.md frontmatter
                          --> Detects project tech (Cargo.toml -> rust.md)
                          --> Injects matching rules into AI context
                          --> Survives context compaction via on_compact.py

  Skills loaded on demand:
    "verify before claiming done" --> loads verification skill
    "add httpx dependency"        --> loads bleeding-edge skill
    "update README.md"            --> loads documentation skill
```

### Skills vs Rules

- **Rules** (`standards/rules/`) -- compact, path-scoped, auto-injected when editing
  matching files. Survive context compaction. These carry corporate coding standards.

- **Skills** (`skills/`) -- methodology protocols with descriptions that survive
  compaction. CC loads the full skill content when the description matches what
  the developer is doing. These carry verification, documentation, and bleeding-edge
  protection.

- **Commands** (`commands/`) -- prompt-based playbooks the user invokes explicitly
  via `/command`. These tell the AI what to analyse and produce.

---

## Attach

```bash
./hyperi-ai/attach.sh [OPTIONS]

OPTIONS:
  --agent NAME       Setup specific agent (claude, cursor, gemini, codex)
  --all-agents       Setup all installed agents
  --no-agent         Skip agent detection entirely

  --pin              Pin submodule version (disable auto-update)
  --force            Overwrite existing files
  --dry-run          Preview changes without modifying
  --verbose          Detailed output

EXAMPLES:
  ./hyperi-ai/attach.sh                    # Auto-detect and configure first found agent
  ./hyperi-ai/attach.sh --agent claude     # Attach + Claude Code
  ./hyperi-ai/attach.sh --all-agents       # Configure all installed agents
  ./hyperi-ai/attach.sh --no-agent         # Attach without agent setup
  ./hyperi-ai/attach.sh --force            # Overwrite existing files
```

**Agent auto-detection:** When no agent flag specified, attach.sh detects installed
CLIs in priority order: `claude` -> `agent` (Cursor) -> `gemini` -> `codex`

### Open-Source Repos

For public/open-source repositories, use the same `attach.sh` with the submodule.
The `hyperi-ai/` submodule references a private repository -- this is intentional:

- **Internal developers** have access and get auto-updating standards
- **External contributors** clone normally (`git clone` without `--recursive`) and get
  all committed config files (STATE.md, TODO.md, .claude/, etc.) without the submodule
- **Hooks degrade gracefully** -- if `hyperi-ai/` is missing, standards injection is
  skipped with a note; formatting, linting, and safety hooks work independently
- **No crashes** -- the submodule is a dev tool, not a runtime dependency

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
| `agents/claude.sh` | `claude` | `.claude/settings.json`, `.claude/commands/` (symlinks), `.claude/rules/` (symlinks), `.claude/skills/` (symlinks), `.claude/memory/`, `.mcp.json` (Context7), `CLAUDE.md` -> `STATE.md` |
| `agents/cursor.sh` | `agent` | `.cursor/cli.json`, `.cursor/rules/*.mdc` (converted), `CURSOR.md` -> `STATE.md` |
| `agents/gemini.sh` | `gemini` | `.gemini/settings.json`, `.gemini/commands/`, `GEMINI.md` -> `STATE.md` |
| `agents/codex.sh` | `codex` | `.github/copilot-instructions.md` (generated), `.github/skills/`, `.vscode/settings.json`, `CODEX.md` -> `STATE.md` |

---

## Repository Structure

```text
hyperi-ai/                       # This repository ($AI_ROOT)
|-- attach.sh                    # Attach AI to project (submodule mode)
|
|-- .claude-plugin/              # CC plugin manifest (plugin mode)
|   +-- plugin.json              # Name, version, description
|
|-- skills/                      # Our unique methodology skills (Agent Skills standard)
|   |-- verification/SKILL.md   # Verify before claiming completion
|   |-- documentation/SKILL.md  # Docs must match code reality
|   +-- bleeding-edge/SKILL.md  # Stale training data protection + Context7
|
|-- commands/                    # Slash commands (user-invocable)
|   |-- load.md                 # /load -- restore session context
|   |-- save.md                 # /save -- checkpoint progress
|   |-- review.md               # /review -- code review against standards
|   |-- simplify.md             # /simplify -- review for reuse + efficiency
|   |-- standards.md            # /standards <topic> -- force-load a rule
|   |-- setup-claude.md         # /setup-claude -- environment setup
|   +-- doco.md                 # /doco -- documentation audit
|
|-- hooks/                       # Claude Code hooks (Python 3 stdlib)
|   |-- hooks.json              # Hook config for plugin mode
|   |-- common.py               # Shared: tech detection, rule injection, safety, formatting
|   |-- inject_standards.py     # SessionStart(startup): date + standards + auto-update
|   |-- on_compact.py           # SessionStart(compact): re-inject after compaction
|   |-- auto_format.py          # PostToolUse(Edit|Write): run formatter on edited files
|   |-- subagent_context.py     # SubagentStart: inject standards into subagents
|   |-- safety_guard.py         # PreToolUse(Bash): block dangerous commands
|   +-- lint_check.py           # Stop: lint modified files, feed errors back
|
|-- agents/                      # Agent setup scripts (bash)
|   |-- common.sh               # Shared functions (CLI detection, logging)
|   |-- claude.sh               # Claude Code setup + version stamp
|   |-- cursor.sh               # Cursor IDE setup
|   |-- gemini.sh               # Gemini Code setup
|   +-- codex.sh                # OpenAI Codex / GitHub Copilot setup
|
|-- standards/                   # Coding standards (main product)
|   |-- STANDARDS.md             # Full reference
|   |-- STANDARDS-QUICKSTART.md  # Router to rules/ (compact single source)
|   |-- rules/                  # Compact rules (<200 lines) -- single source for all agents
|   |   |-- UNIVERSAL.md        # Cross-cutting rules (always loaded)
|   |   +-- <topic>.md          # Path-scoped rules (auto-injected by file type)
|   |-- code-assistant/          # AI-specific guidance
|   |-- common/                  # Language-agnostic standards
|   |-- languages/               # Python, Go, TypeScript, Rust, Bash, C++
|   +-- infrastructure/          # Docker, K8s, Terraform, Ansible
|
|-- templates/                   # Deployment templates
|   |-- STATE.md                 # Session state template
|   |-- TODO.md                  # Task tracking template
|   +-- claude-code/             # Claude Code configs (settings, hook wiring)
|
|-- .mcp.json                    # MCP server config (Context7 -- deployed to consumer projects)
|-- tools/                       # Development tools
|   +-- compact-standards.py    # Generate compact rules from full standards (API script)
|
|-- tests/                       # BATS test suite (86 tests)
+-- docs/                        # Project documentation
```

---

## Context7 MCP (Live Library Documentation)

The `bleeding-edge` skill works with [Context7 MCP](https://github.com/upstash/context7)
to fetch current documentation for any library, preventing stale training data mistakes.

`claude.sh` deploys `.mcp.json` to the consumer project root, providing Context7 MCP tools:

- **`resolve-library-id`** -- find the Context7 identifier for a library
- **`query-docs`** -- fetch current documentation for a specific API

### Rate limits and API key

Context7 works without an API key (free tier: 1,000 requests/month, 60/hour).
For higher limits, set `CONTEXT7_API_KEY` in your environment:

```bash
# In your shell profile (~/.bashrc, ~/.zshrc)
export CONTEXT7_API_KEY="ctx7sk-..."

# Or in the project .env file (gitignored)
echo 'CONTEXT7_API_KEY=ctx7sk-...' >> .env
```

The bleeding-edge skill handles rate limits gracefully: if Context7 returns 429,
it logs a single warning and falls back to web search for the rest of the session.

### Fallback chain

```
Context7 MCP -> Web Search -> Explicitly state uncertainty
```

---

## Superpowers Integration

We use [superpowers](https://github.com/obra/superpowers) for general development
methodology. hyperi-ai handles corporate standards; superpowers handles how to work.

| What | Source | Why |
|---|---|---|
| Debugging methodology | superpowers | Systematic debugging, not ours to maintain |
| TDD enforcement | superpowers | Test-driven development workflow |
| Brainstorming/design | superpowers | Design thinking workflow |
| Git worktrees | superpowers | Parallel development workflow |
| Plan writing | superpowers | Structured planning |
| Code review methodology | superpowers | Review workflow (our `/review` adds corporate standards) |
| Corporate coding standards | hyperi-ai | 21 rules -- language, infra, cross-cutting |
| Verification before completion | hyperi-ai | Unique -- superpowers has no equivalent |
| Documentation/code-reality audit | hyperi-ai | Unique -- superpowers has no equivalent |
| Bleeding-edge protection | hyperi-ai | Unique -- superpowers has no equivalent |

Install superpowers: `claude plugin install superpowers@superpowers-marketplace`

See [docs/SUPERPOWERS.md](docs/SUPERPOWERS.md) for integration details.

---

## Submodule Auto-Update

### Default behaviour (auto-update on every session)

**The `hyperi-ai/` submodule is automatically updated from upstream every time
a Claude Code session starts.** This happens silently via the `SessionStart`
hook -- no manual `git submodule update` needed.

The hook also auto-reattaches: if updated files include commands, rules, or
agent config, it re-runs `claude.sh` to re-deploy them.

Settings stored in `.gitmodules` (propagates to all clones):

- `update = rebase` -- apply upstream changes (default)
- `fetchRecurseSubmodules = true` -- include in clone

### Pinning (disable auto-update)

If you need a fixed version (e.g., for reproducible builds or auditing),
pin the submodule. The auto-update hook respects this and will skip it.

```bash
# Pin via attach
./hyperi-ai/attach.sh --pin

# Or set directly in .gitmodules
git config -f .gitmodules submodule.hyperi-ai.update none
git add .gitmodules
git commit -m "chore: pin ai submodule"
```

Update a pinned submodule to a specific version manually:

```bash
git -C hyperi-ai fetch
git -C hyperi-ai checkout v2.0.0
git add hyperi-ai
git commit -m "chore: pin ai to v2.0.0"
```

### Unpinning (re-enable auto-update)

```bash
git config -f .gitmodules submodule.hyperi-ai.update rebase
git add .gitmodules
git commit -m "chore: unpin ai submodule"
```

### How auto-update works

On every Claude Code session start, the `inject_standards.py` hook:

1. Checks `.gitmodules` for `hyperi-ai` submodule
2. If `update = none` -> skip (pinned)
3. If `update = rebase` or unset -> run `git submodule update --remote hyperi-ai`
4. Checks if deployment files changed and re-deploys
5. Writes a version stamp to `.claude/.ai-version` for change tracking

This is fully silent -- no output unless something actually changed.

---

## Standards Loading

Standards are delivered in three layers, each with different persistence:

### Layer 0 -- User overrides (highest priority)

If `~/.config/hyperi-ai/USER-CODING-STANDARDS.md` exists, it is injected **last** at
session start -- after all other standards. Rules in this file override everything else.

Use this for personal coding preferences that apply across all projects (naming
conventions, comment style, preferred patterns, etc.). The file is never committed
to any project -- it lives in your home directory.

```bash
# Create your personal overrides
mkdir -p ~/.config/hyperi-ai
cat > ~/.config/hyperi-ai/USER-CODING-STANDARDS.md << 'EOF'
# My Coding Preferences
- Always use snake_case for variables
- Prefer early returns over nested conditionals
EOF
```

Respects `XDG_CONFIG_HOME` if set (defaults to `~/.config`).

### Layer 1 -- Rules: Path-scoped, auto-injected (survives compaction)

Compact path-scoped rules in `.claude/rules/` are injected automatically by Claude Code
when you edit matching files. They survive context compaction.

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
| `.releaserc`, `release.config.*`, `.github/`, `VERSION` | `ci.md` |

### Layer 2 -- Skills: Methodology on demand (descriptions survive compaction)

Skills in `.claude/skills/` have descriptions that persist across compaction.
CC loads the full skill content when the description matches the current task:

| Skill | Triggers When |
|---|---|
| `verification` | Claiming completion, committing, creating PRs |
| `documentation` | Writing or updating docs, README, STATE.md |
| `bleeding-edge` | Adding dependencies, using library APIs, Docker images |

### Layer 3 -- CAG: Injected at session start

`standards/rules/UNIVERSAL.md` plus all detected technology rules are automatically
injected into Claude's context by the `SessionStart` hook (`inject_standards.py`).

---

## Claude Code Integration

After running `./hyperi-ai/attach.sh --agent claude`, Claude Code gets a full hook
chain that runs automatically -- no manual setup per session.

### What happens automatically (no user action needed)

| When | Hook | What It Does |
|------|------|-------------|
| Session start | `inject_standards.py` | Auto-updates submodule, injects date + UNIVERSAL + tech rules + user overrides, auto-reattaches if changed |
| Context compacted | `on_compact.py` | Re-injects date and standards (lost during compaction) |
| File edited/written | `auto_format.py` | Runs formatter (ruff, rustfmt, gofmt, prettier, shfmt, clang-format) |
| Subagent spawned | `subagent_context.py` | Injects standards into subagent context |
| Bash command run | `safety_guard.py` | Blocks dangerous commands (rm -rf /, force push main, dd, mkfs, fork bombs) |
| Task completed | `lint_check.py` | Lints modified files, feeds errors back to Claude to fix |

### Slash commands

**`/load`** -- Restore full session context (TODO.md, STATE.md, git sync).
Standards are already loaded by the SessionStart hook -- `/load` supplements
with project state.

**`/save`** -- Checkpoint progress (TODO.md, STATE.md validation, git status)

**`/review`** -- Code review against full standards (loads skills on demand)

**`/simplify`** -- Review for reuse, quality, and efficiency

**`/standards <topic>`** -- Force-load a specific rule file (e.g., `/standards rust`)

**`/setup-claude`** -- Configure environment, install superpowers, survey tools

**`/doco`** -- Documentation audit against code reality

**Best practice:** Run `/save` every 30-40 exchanges or before breaks.

---

## Dual Mode: Submodule + Plugin

hyperi-ai works in two modes from the same repository:

### Submodule mode (primary)

```bash
git submodule add https://github.com/hyperi-io/hyperi-ai.git hyperi-ai
./hyperi-ai/attach.sh --agent claude
```

`claude.sh` deploys rules, skills, commands, settings, and MCP config as symlinks
from the submodule into the consumer project's `.claude/` directory.

### Plugin mode

The repository also includes a CC plugin manifest (`.claude-plugin/plugin.json`)
and hook config (`hooks/hooks.json`). This enables direct plugin installation
for environments where git submodules aren't practical.

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

- `$AI_ROOT` - Where this repo is attached (e.g., `hyperi-ai/`, `standards/`, `.ai/`)
- `$PROJECT_ROOT` - Parent project root (where STATE.md lives)

---

## License

Proprietary -- HYPERI PTY LIMITED internal use only. See [LICENSE](LICENSE).

Copyright (c) 2025-2026 HYPERI PTY LIMITED (ABN 31 622 581 748)
