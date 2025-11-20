# Architecture

Technical design for the AI standards repository.

---

## Design Principles

1. **Radical simplification** - 95% reduction from deprecated code (25,000+ → <1,000 lines)
2. **Pure bash** - No Python, no dependencies (bash 3.2+ compatible)
3. **Path-agnostic** - Works anywhere, not just `/ai`
4. **Idempotent** - Safe to run multiple times
5. **Cross-platform** - macOS, Linux, WSL

---

## Components

### Scripts (2 files, ~500 lines)

**install.sh** - Deploy templates to project root
- Auto-detects usage mode (submodule/clone/standalone)
- Copies STATE.md and TODO.md templates
- Flags: --help, --dry-run, --force, --path, --verbose

**claude-code.sh** - Configure Claude Code
- Creates .claude/ directory and configuration
- Deploys settings.json and slash commands
- Creates CLAUDE.md → STATE.md symlink
- Optional: --1m flag enables 1M context window (modifies ~/.bashrc)
- Flags: --help, --dry-run, --force, --path, --verbose, --1m

### Standards (~18 files)

Comprehensive coding standards and AI guidance in `standards/` directory.

### Templates

Generic templates deployed by scripts in `templates/` directory.

### Tests (3 files, ~300 lines)

Bats test suite with 19 test cases in `tests/` directory.

---

## Deployment

Scripts deploy templates to project root:

```
project/
├── STATE.md                 # From templates/STATE.md
├── TODO.md                  # From templates/TODO.md
├── CLAUDE.md -> STATE.md    # Symlink created by claude-code.sh
└── .claude/                 # Created by claude-code.sh
    ├── settings.json
    └── commands/
        ├── start.md
        └── save.md
```

**Optionally to ~/.bashrc (if --1m flag used):**
```bash
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-4-5-20250929[1m]"
```

---

## CI/CD

### GitHub Actions

**test.yml** - Runs bats tests on every push/PR
**release.yml** - Auto-releases on push to main (semantic-release)

---

See [CONTRIBUTING.md](../CONTRIBUTING.md) for complete development workflow.
