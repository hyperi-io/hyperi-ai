# Contributing to HyperI AI Standards

How to work with and contribute to this repository.

---

## Repository Overview

```text
hyperi-ai/
├── attach.sh            # Deploy STATE.md, TODO.md, agent configs
├── agents/              # Agent setup scripts (bash)
│   ├── common.sh        # Shared functions (CLI detection, logging)
│   ├── claude.sh        # Claude Code setup + version stamp
│   ├── codex.sh         # OpenAI Codex / GitHub Copilot setup
│   ├── cursor.sh        # Cursor IDE setup
│   └── gemini.sh        # Gemini Code setup
├── hooks/               # Claude Code hooks (Python 3 stdlib only)
│   ├── common.py        # Shared: tech detection, rule injection, safety, formatting
│   ├── inject_standards.py   # SessionStart(startup): date + standards + auto-update
│   ├── on_compact.py         # SessionStart(compact): re-inject after compaction
│   ├── auto_format.py        # PostToolUse: run formatter on edited files
│   ├── subagent_context.py   # SubagentStart: inject standards into subagents
│   ├── safety_guard.py       # PreToolUse(Bash): block dangerous commands
│   └── lint_check.py         # Stop: lint modified files, feed errors back
├── standards/           # Main product - coding standards
│   ├── STANDARDS.md             # Full reference
│   ├── QUICKSTART.md  # Router/index → standards/rules/
│   ├── rules/                  # Compact rules (<200 lines each, single source)
│   ├── common/                  # Language-agnostic standards
│   ├── languages/               # Python, Go, TypeScript, Rust, Bash, C++
│   └── infrastructure/          # Docker, K8s, Terraform, Ansible
├── templates/           # Deployment templates
│   ├── STATE.md, TODO.md        # Cross-assistant
│   └── claude-code/, copilot/, cursor/, gemini/
├── tools/               # Development tools
│   └── compact-standards.py    # Generate compact rules from full standards
├── tests/               # BATS test suite (86 tests)
└── docs/                # Project documentation
```

---

## Standards Architecture (CAG-Heavy)

Standards are primarily delivered via CAG (Context-Augmented Generation) at session
start, with redundant fallback layers:

1. **CAG (Primary):** All relevant standards — `UNIVERSAL.md`, detected tech rules,
   project context (STATE.md), skills, and commands — are pre-loaded into context at
   session start by `inject_cag_payload()` in `hooks/common.py`. Approximately 24K
   tokens (~2.4% of the 1M context window). Re-injected by `on_compact.py` after
   context compaction.
2. **RAG (Redundant fallback):** Path-scoped rule files (e.g. `python.md`) in
   `.claude/rules/` are still deployed and auto-injected by Claude Code when editing
   matching files. This provides a safety net if CAG injection is incomplete.
3. **Skills (On-Demand):** Full standards in `standards/languages/` and
   `standards/infrastructure/` loaded via `/review` or `/simplify`

Each agent's deploy script converts `standards/rules/*.md` into its platform's format:
- **Claude Code:** Symlinked to `.claude/rules/` (YAML `paths:` frontmatter preserved)
- **Cursor:** Converted to `.cursor/rules/*.mdc` (`category: Always|Auto Attached`)
- **Codex/Copilot:** Concatenated into `.github/copilot-instructions.md` at deploy time
- **Gemini:** Read via `/load` with detection table

---

## Development Workflow

### Setup

```bash
git clone https://github.com/hyperi-io/hyperi-ai.git
cd ai
```

### Making Changes

```bash
# 1. Make changes to standards/, templates/, or scripts

# 2. Test
bats tests/
shellcheck agents/*.sh attach*.sh

# 3. Commit (conventional commits)
git commit -m "fix: your change description"

# 4. Push — semantic-release handles versioning automatically
git push origin main
```

---

## Testing

### Run All Tests (86 tests)

```bash
bats tests/
```

### Run Specific Tests

```bash
bats tests/attach.bats           # attach.sh tests
bats tests/claude-code.bats      # Claude Code agent + hook wiring tests
bats tests/standards-rules.bats  # Standards injection + Python hook tests
bats tests/codex.bats            # Codex agent tests
bats tests/cursor.bats           # Cursor agent tests
bats tests/gemini.bats           # Gemini agent tests
```

### Manual Testing

```bash
# Preview without changes
./attach.sh --dry-run --verbose

# Test in temp directory
TMP_DIR=$(mktemp -d)
git init "$TMP_DIR"
./attach.sh --path "$TMP_DIR" --no-agent
./agents/claude.sh --path "$TMP_DIR" --dry-run
rm -rf "$TMP_DIR"
```

### ShellCheck

```bash
shellcheck agents/*.sh attach*.sh
```

---

## Git Conventions

### Branch Naming

Format: `<type>/<issue-ref>/<description>`

```bash
fix/no-ref/missing-template
feat/AI-123/add-cursor-support
docs/no-ref/update-readme
```

### Commit Types

**Trigger releases:**

| Type | Bump |
|------|------|
| `fix:` | PATCH (1.0.0 → 1.0.1) |
| `refactor:` | PATCH (1.0.0 → 1.0.1) |
| `feat:` | MINOR (1.0.0 → 1.1.0) |
| `BREAKING CHANGE:` footer or `!` suffix | MAJOR (1.0.0 → 2.0.0) |

**No release:**

`docs:`, `test:`, `chore:`, `ci:`

### Commit Examples

```bash
git commit -m "fix: handle missing STATE.md gracefully"
git commit -m "feat: add support for new AI assistant"
git commit -m "docs: update standards loading section"
git commit -m "refactor!: restructure standards delivery" -m "BREAKING CHANGE: consumers must re-run attach.sh"
```

---

## Standards Development

### File Organisation

| Directory | Purpose |
|-----------|---------|
| `standards/rules/UNIVERSAL.md` | Cross-cutting rules, always loaded (~137 lines) |
| `standards/rules/<topic>.md` | Compact path-scoped rules (<200 lines each) |
| `standards/universal/` | Language-agnostic standards |
| `standards/languages/` | Per-language: PYTHON.md, GOLANG.md, etc. |
| `standards/infrastructure/` | Per-tool: DOCKER.md, K8S.md, etc. |

### Token Budgets

| File Type | Maximum |
|-----------|---------|
| Compact rule (each) | 200 lines max |
| Language file (each) | 10K tokens |
| Infrastructure file (each) | 10K tokens |

### Adding New Standards

1. Create full standard in appropriate `standards/languages/` or `standards/infrastructure/` directory
2. Run `tools/compact-standards.py` to generate compact rule in `standards/rules/`
3. Add detection entry to `hooks/common.py` `TECH_DETECTIONS` table
4. Add skill deployment to `agents/claude.sh` `deploy_skills()`
5. The compact rule is automatically picked up by all agent deploy scripts

---

## Script Development

### Bash 3.2 Compatibility (macOS)

**Must avoid:**

```bash
declare -A map        # Associative arrays (bash 4+)
${var^^}              # Case modification (bash 4+)
command &> /dev/null  # Combined redirect (bash 4+)
mapfile -t arr        # mapfile (bash 4+)
```

**Safe to use:**

```bash
$(command)            # Command substitution
${var:-default}       # Default values
indexed_array=()      # Indexed arrays
[ ] and [[ ]]         # Test operators
```

### Script Guidelines

1. Start with `#!/usr/bin/env bash` and `set -euo pipefail`
2. Support `--help`, `--dry-run`, `--force`, `--path`, `--verbose`
3. Use helper-first function ordering with `main()` at bottom
4. Make idempotent (safe to run repeatedly)
5. Run `shellcheck` before committing; run `macbash` if installed

### set -e Safety

Capture non-zero exit codes without triggering errexit:

```bash
local exit_code=0
some_command || exit_code=$?
# use $exit_code instead of checking $?
```

---

## Hook Development (Python 3)

All Claude Code hooks live in `hooks/` and use Python 3 stdlib only (no pip).

### Architecture

- **`hooks/common.py`** — shared module, single source of truth for:
  - Technology detection (`TECH_DETECTIONS` table + `detect_technologies()`)
  - Rule injection (`inject_rules()`)
  - Hook I/O (`read_hook_input()`, `hook_response()`)
  - Formatter/linter mapping (`get_formatter()`, `get_linter()`)
  - Safety patterns (`check_command_safety()`)
  - Auto-reattach (`check_version_and_reattach()`)
  - Submodule auto-update (`auto_update_submodules()`)

- **Individual hooks** — thin wrappers that call common.py functions

### Hook Events and I/O

| Hook Event | stdin | stdout | Notes |
|------------|-------|--------|-------|
| `SessionStart` | — | Injected into Claude's context | Only hook whose stdout Claude sees |
| `PostToolUse` | JSON (tool_input) | NOT injected (side-effect only) | GitHub issue #18427 |
| `SubagentStart` | JSON (agent_type) | JSON with `additionalContext` | Injects into subagent |
| `PreToolUse` | JSON (tool_input) | JSON with `permissionDecision` | Can deny commands |
| `Stop` | JSON (stop_hook_active) | — (uses exit code 2 + stderr) | Known reliability issue #24327 |

### Adding a New Hook

1. Create `hooks/<name>.py` with shebang `#!/usr/bin/env python3`
2. Import common.py: `sys.path.insert(0, str(Path(__file__).resolve().parent))`
3. Add hook wiring to `templates/claude-code/settings.json`
4. Add BATS tests in `tests/standards-rules.bats`
5. Make executable: `chmod +x hooks/<name>.py`
6. Add to `agents/claude.sh` `print_summary()` hook display

### Guidelines

- **Python 3 stdlib only** — no pip, no external dependencies
- **Always exit 0** unless deliberately blocking (PreToolUse deny, Stop exit 2)
- **Graceful degradation** — if a tool isn't installed, skip silently
- **No side effects on error** — catch exceptions, don't crash the session

---

### Adding New Agent Scripts

1. Copy structure from an existing agent script (e.g., `agents/claude.sh`)
2. Create templates in `templates/<assistant>/`
3. Add BATS tests in `tests/<assistant>.bats`
4. Update `attach.sh` `run_agent_detection()`
5. Update README.md
6. Commit with `feat:` type

---

## Template Development

### Cross-Assistant Templates

`templates/STATE.md` and `templates/TODO.md` are shared by all assistants.

Changes here affect all users — document clearly in commits.

### Assistant-Specific Templates

| Directory | Contents |
|-----------|----------|
| `templates/claude-code/` | settings.json, commands/load.md, save.md, review.md, simplify.md |
| `templates/copilot/` | header.md (combined into copilot-instructions.md at deploy time) |
| `templates/cursor/` | cli.json, rules/session-start.mdc, session-save.mdc |
| `templates/gemini/` | settings.json, commands/load.md, save.md |

### Template Behaviour

| File Type | Default Behaviour |
|-----------|-------------------|
| Settings files | Preserve existing (skip if exists); `--force` to overwrite |
| Commands | Always re-deployed as symlinks (versioned, always current) |
| Rules | Symlinked on first deploy; `--force` to re-link |
| Skills | Created on first deploy; `--force` to recreate |

---

## Release Process

Fully automated via semantic-release:

1. Push to main
2. Commits analysed for type (breaking change → major, feat → minor, fix/refactor → patch)
3. VERSION file updated
4. CHANGELOG.md generated
5. Git tag created
6. GitHub release published

**No manual intervention needed.**

---

## Pull Request Guidelines

### PR Title

Use conventional commit format:

```text
fix: handle edge case in attach.sh
feat: add support for new AI assistant
docs: update installation guide
```

### PR Description

Include:

- Summary of changes
- Why the change is needed
- Testing performed
- Breaking changes (if any)

---

## Documentation Standards

**Do:**

- Keep concise and scannable
- Use tables for structured data
- Australian English in prose
- American English in code examples

**Don't:**

- Add version numbers (use VERSION file)
- Add dates in filenames
- Use marketing language
- Add AI attribution

---

## Getting Help

- GitHub Issues: <https://github.com/hyperi-io/hyperi-ai/issues>
- Slack: #standards (HyperI internal)

---

## License

This project is proprietary software owned by HYPERI PTY LIMITED. See [LICENSE](LICENSE).

All contributions become the property of HYPERI PTY LIMITED under the same terms.

Copyright (c) 2025-2026 HYPERI PTY LIMITED (ABN 31 622 581 748)
