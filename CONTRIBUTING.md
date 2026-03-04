# Contributing to HyperI AI Standards

How to work with and contribute to this repository.

---

## Repository Overview

```text
ai/
├── attach.sh            # Deploy STATE.md, TODO.md (internal repos)
├── attach-public.sh     # Deploy for public repos (gitignored mode)
├── agents/              # AI assistant setup scripts
│   ├── common.sh        # Shared functions (CLI detection, logging, detection)
│   ├── claude.sh        # Claude Code setup
│   ├── codex.sh         # OpenAI Codex / GitHub Copilot setup
│   ├── cursor.sh        # Cursor IDE setup
│   └── gemini.sh        # Gemini Code setup
├── standards/           # Main product - coding standards
│   ├── STANDARDS.md             # Full reference
│   ├── STANDARDS-QUICKSTART.md  # Router/index → standards/rules/
│   ├── rules/                  # Compact rules (<200 lines each, single source)
│   ├── code-assistant/          # AI-specific guidance
│   ├── common/                  # Language-agnostic standards
│   ├── languages/               # Python, Go, TypeScript, Rust, Bash, C++
│   └── infrastructure/          # Docker, K8s, Terraform, Ansible
├── templates/           # Deployment templates
│   ├── STATE.md, TODO.md        # Cross-assistant
│   └── claude-code/, copilot/, cursor/, gemini/
├── tools/               # Development tools
│   └── compact-standards.py    # Generate compact rules from full standards
├── tests/               # BATS test suite
└── docs/                # Project documentation
```

---

## Standards Architecture (v2)

Standards are delivered in three layers, all sourced from `standards/rules/`:

1. **CAG (Context-Augmented Generation):** `UNIVERSAL.md` loaded explicitly via `/load`
2. **RAG (Retrieval-Augmented Generation):** Path-scoped rule files (e.g. `python.md`) auto-injected by Claude Code when editing matching files — survives context compaction
3. **Skills (On-Demand):** Full standards in `standards/languages/` and `standards/infrastructure/` loaded via `/review` or `/simplify`

Each agent's deploy script converts `standards/rules/*.md` into its platform's format:
- **Claude Code:** Symlinked to `.claude/rules/` (YAML `paths:` frontmatter preserved)
- **Cursor:** Converted to `.cursor/rules/*.mdc` (`category: Always|Auto Attached`)
- **Codex/Copilot:** Concatenated into `.github/copilot-instructions.md` at deploy time
- **Gemini:** Read via `/load` with detection table

---

## Development Workflow

### Setup

```bash
git clone https://github.com/hyperi-io/ai.git
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

### Run All Tests

```bash
bats tests/
```

### Run Specific Tests

```bash
bats tests/attach.bats
bats tests/claude-code.bats
bats tests/codex.bats
bats tests/cursor.bats
bats tests/gemini.bats
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
| `standards/code-assistant/` | AI-specific guidance |
| `standards/common/` | Language-agnostic standards |
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
3. Add detection markers to `agents/common.sh` `detect_project_technologies()`
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

### Adding New Agent Scripts

1. Copy structure from an existing agent script (e.g., `agents/claude.sh`)
2. Create templates in `templates/<assistant>/`
3. Add BATS tests in `tests/<assistant>.bats`
4. Update `attach.sh` and `attach-public.sh` `run_agent_detection()`
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

- GitHub Issues: <https://github.com/hyperi-io/ai/issues>
- Slack: #standards (HyperI internal)

---

## License

This project is licensed under the Functional Source License, Version 1.1,
ALv2 Future License (FSL-1.1-ALv2). See [LICENSE](LICENSE).

All contributions are licensed under the same terms. Each version automatically
becomes available under Apache License, Version 2.0 on the second anniversary
of its release.

Copyright (c) 2025-2026 HYPERI PTY LIMITED (ABN 31 622 581 748)
