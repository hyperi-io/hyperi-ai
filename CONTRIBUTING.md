# Contributing to HyperI AI Standards

How to work with and contribute to this repository.

---

## Repository Overview

```text
ai/
├── attach.sh            # Deploy STATE.md, TODO.md
├── agents/              # AI assistant setup scripts
│   ├── claude.sh        # Claude Code setup
│   ├── copilot.sh       # GitHub Copilot setup
│   ├── cursor.sh        # Cursor IDE setup
│   └── gemini.sh        # Gemini Code setup
├── standards/           # Main product - coding standards
│   ├── STANDARDS.md             # Full reference
│   ├── STANDARDS-QUICKSTART.md  # Core standards (always loaded)
│   ├── code-assistant/          # AI-specific guidance
│   ├── common/                  # Language-agnostic standards
│   ├── languages/               # Python, Go, TypeScript, Rust, Bash
│   └── infrastructure/          # Docker, K8s, Terraform, Ansible
├── templates/           # Deployment templates
│   ├── STATE.md, TODO.md        # Cross-assistant
│   └── claude-code/, copilot/, cursor/, gemini/
├── tests/               # BATS test suite
└── docs/                # Project documentation
```

---

## Development Workflow

### Setup

```bash
git clone https://github.com/hyperi-io/ai.git
cd ai
```

### Making Changes

```bash
# 1. Create branch
git checkout -b fix/no-ref/your-change

# 2. Make changes to standards/, templates/, or scripts

# 3. Test
bats tests/
./install.sh --dry-run
./claude-code.sh --dry-run

# 4. Commit (conventional commits)
git commit -m "fix: your change description"

# 5. Push and create PR
git push origin fix/no-ref/your-change
gh pr create
```

---

## Testing

### Run All Tests

```bash
bats tests/
```

### Run Specific Tests

```bash
bats tests/install.bats
bats tests/claude-code.bats
bats tests/copilot.bats
bats tests/cursor.bats
bats tests/gemini.bats
```

### Manual Testing

```bash
# Preview without changes
./install.sh --dry-run --verbose
./claude-code.sh --dry-run --verbose

# Test in temp directory
mkdir -p /tmp/test-project && cd /tmp/test-project
git init
/path/to/ai/install.sh --path .
/path/to/ai/claude-code.sh --path .
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
| `feat:` | MINOR (1.0.0 → 1.1.0) |
| `BREAKING CHANGE:` footer | MAJOR (1.0.0 → 2.0.0) |

**No release:**

`docs:`, `test:`, `chore:`, `ci:`, `refactor:`

### Commit Examples

```bash
git commit -m "fix: handle missing STATE.md gracefully"
git commit -m "feat: add support for cursor IDE"
git commit -m "docs: update standards loading section"
```

---

## Standards Development

### File Organisation

| Directory | Purpose |
|-----------|---------|
| `standards/STANDARDS-QUICKSTART.md` | Core standards, always loaded (~7.5K tokens) |
| `standards/code-assistant/` | AI-specific guidance |
| `standards/common/` | Language-agnostic standards |
| `standards/languages/` | Per-language: PYTHON.md, GOLANG.md, etc. |
| `standards/infrastructure/` | Per-tool: DOCKER.md, K8S.md, etc. |

### Token Budgets

| File Type | Maximum |
|-----------|---------|
| STANDARDS-QUICKSTART.md | 12K tokens |
| Language file (each) | 10K tokens |
| Infrastructure file (each) | 10K tokens |

### Adding New Standards

1. Create file in appropriate directory
2. Follow existing format
3. Update `STANDARDS-QUICKSTART.md` if it references new content
4. Update `/load` commands if auto-detection needed
5. Test token count: `wc -c FILE.md | awk '{print int($1/4)}'`

---

## Script Development

### Bash 3.2 Compatibility (macOS)

**Must avoid:**

```bash
declare -A map        # Associative arrays (bash 4+)
${var^^}              # Case modification (bash 4+)
command &> /dev/null  # Combined redirection (bash 4+)
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
3. Use helper-first function ordering
4. Keep under 300 lines
5. Make idempotent (safe to run repeatedly)
6. Run ShellCheck before committing

### Adding New Scripts

1. Copy structure from existing script (e.g., `claude-code.sh`)
2. Create templates in `templates/<assistant>/`
3. Add BATS tests in `tests/<assistant>.bats`
4. Update README.md
5. Commit with `feat:` type

---

## Template Development

### Cross-Assistant Templates

`templates/STATE.md` and `templates/TODO.md` are shared by all assistants.

Changes here affect all users - document clearly in commits.

### Assistant-Specific Templates

| Directory | Contents |
|-----------|----------|
| `templates/claude-code/` | settings.json, commands/load.md, commands/save.md |
| `templates/copilot/` | copilot-instructions.md |
| `templates/cursor/` | cli.json, rules/*.mdc |
| `templates/gemini/` | settings.json, commands/load.md, commands/save.md |

### Template Behaviour

| File Type | Default Behaviour |
|-----------|-------------------|
| Settings files | Preserve existing (skip if exists) |
| Commands/rules | Always overwrite (versioned) |
| Symlinks | Skip if exists |

---

## Release Process

Fully automated via semantic-release:

1. Push to main
2. Commits analysed for type
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
fix: handle edge case in install.sh
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
