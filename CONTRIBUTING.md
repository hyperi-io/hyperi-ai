# Contributing to HyperSec AI Standards

This document describes how to work with and contribute to this repository.

---

## Project Overview

**Purpose:** Standards and templates for developers and AI code assistants

**Repository:** https://github.com/hypersec-io/ai (private)

**Key components:**
- `standards/` - Coding standards, AI guidance, best practices
- `templates/` - STATE.md, TODO.md, assistant-specific configurations
- `install.sh` - Deploy cross-assistant templates (STATE.md, TODO.md)
- `claude-code.sh` - Configure Claude Code specifically
- `cursor.sh`, `copilot.sh` - (Future) Other assistant setup scripts

---

## Development Workflow

### Initial Setup

After cloning the repository, install git hooks:

```bash
# Install hooks for branch name validation and AI attribution removal
ln -sf ../../hooks/commit-msg .git/hooks/commit-msg
ln -sf ../../hooks/pre-commit .git/hooks/pre-commit
```

These hooks will:
- Validate branch names match HyperSec standards
- Remove AI attribution from commit messages automatically


### Repository Structure

```
ai/
├── install.sh           # Template deployment script
├── claude-code.sh       # Claude Code setup script
├── standards/           # Main product - coding standards
├── templates/           # Deployment templates
├── tests/              # Bats test suite
├── docs/               # Project documentation
└── deprecated/         # Reference only (old hs-ci/ai code)
```

### Making Changes

**For HyperSec internal developers:**

```bash
# 1. Clone repository
git clone https://github.com/hypersec-io/ai.git
cd ai

# 2. Create feature branch (format: type/issue-ref/description)
git checkout -b fix/no-ref/your-change

# 3. Make changes
# Edit standards/, templates/, or scripts

# 4. Test your changes
./install.sh --help
./claude-code.sh --help
# Manual testing in /projects/ai-test/

# 5. Commit with conventional commits
git add .
git commit -m "fix: your change description"

# 6. Push and create PR
git push origin fix/no-ref/your-change
gh pr create --title "fix: your change" --body "Description"

# 7. After approval and merge, semantic-release auto-publishes
```

**For external contributors (if repository becomes public):**

```bash
# 1. Fork repository on GitHub
# 2. Clone your fork
git clone https://github.com/YOUR-USERNAME/ai.git
cd ai

# 3. Create feature branch (format: type/issue-ref/description)
git checkout -b fix/no-ref/your-change

# 4. Make changes and test
# 5. Commit and push to your fork
git push origin fix/no-ref/your-change

# 6. Create PR to hypersec-io/ai
gh pr create --repo hypersec-io/ai
```

---

## Testing

### Manual Testing

**Quick smoke test:**

```bash
# Test scripts work
./install.sh --help
./claude-code.sh --help
./install.sh --dry-run
./claude-code.sh --dry-run

# Test in pilot project
cd /projects/ai-test/pilot-test
./ai/install.sh
./ai/claude-code.sh
```

### Automated Testing

**Bats test suite (requires bats installation):**

```bash
# Install bats
brew install bats-core  # macOS
sudo apt install bats   # Ubuntu
sudo dnf install bats   # Fedora

# Run all tests
cd /projects/ai
bats tests/

# Run specific test file
bats tests/install.bats
bats tests/claude-code.bats
```

**Test coverage:**
- 11 tests for install.sh
- 8 tests for claude-code.sh
- Tests all three usage modes (submodule, clone, standalone)
- Tests idempotence, force mode, dry-run, custom paths

---

## Git Workflow

### Branch Naming

All branches must follow HyperSec standards:

**Format:** `<type>/<issue-ref>/<short-description>`

**Examples:**
```bash
fix/no-ref/missing-template      # No issue ticket
feat/AI-123/add-cursor-support   # With issue ticket
docs/no-ref/update-readme        # Documentation change
```

**Issue reference:**
- Use actual ticket ID if exists (e.g., `AI-123`)
- Use `no-ref` if no ticket

See [standards/common/GIT-WORKFLOW.md](standards/common/GIT-WORKFLOW.md) for complete branching standards.

### Conventional Commits

All commits must follow conventional commit format:

```
<type>: <description>

[optional body]

[optional footer]
```

### Commit Types

**Types that trigger releases:**
- `feat:` - New feature (minor bump: 1.0.0 → 1.1.0)
- `fix:` - Bug fix (patch bump: 1.0.0 → 1.0.1)
- `perf:` - Performance improvement (patch bump)
- `sec:` - Security fix (patch bump)
- `hotfix:` - Critical fix (patch bump)

**Types that don't trigger releases:**
- `docs:` - Documentation only
- `test:` - Tests only
- `chore:` - Maintenance, dependencies
- `ci:` - CI/CD changes
- `refactor:` - Code restructure (no functional change)

**Breaking changes:**
- Add `BREAKING CHANGE:` footer to trigger major bump (1.0.0 → 2.0.0)

### Examples

```bash
# Good commits
git commit -m "feat: add support for cursor IDE"
git commit -m "fix: handle missing template gracefully"
git commit -m "docs: update installation instructions"

# Breaking change
git commit -m "feat: change template structure

BREAKING CHANGE: Templates now use different directory layout.
Requires re-running install.sh in existing projects."
```

---

## Release Process

### Automated Releases

Releases are fully automated via semantic-release:

1. **Push to main** - Commits are analyzed
2. **Version determined** - Based on commit types
3. **VERSION file updated** - e.g., `1.2.3`
4. **CHANGELOG.md updated** - Auto-generated from commits
5. **Git tag created** - e.g., `1.2.3` (no v prefix)
6. **GitHub release created** - With release notes

**No manual intervention needed!**

### Version Sources

Version information exists in **exactly 4 places:**
1. `VERSION` file - Single source of truth (managed by semantic-release)
2. `CHANGELOG.md` - Release history (managed by semantic-release)
3. Git tags - e.g., `1.2.3` (created by semantic-release)
4. GitHub releases - https://github.com/hypersec-io/ai/releases

**Do NOT add version info to:**
- Scripts (install.sh, claude-code.sh)
- Documentation files (README.md, docs/*.md)
- Standards files (standards/*.md)
- Template files

---

## Standards Updates

### Updating Standards Files

Standards files are in `standards/` directory:

```
standards/
├── STANDARDS.md         # Entry point
├── code-assistant/      # AI-specific guidance
├── common/              # Language-agnostic standards
└── python/              # Python-specific standards
```

**Process:**

1. Make changes to standards files
2. Test that standards load correctly
3. Commit with appropriate type:
   - `feat:` if adding new standards (minor bump)
   - `fix:` if clarifying existing standards (patch bump)
   - `docs:` if only formatting/typos (no bump)

### Template Updates

Templates are in `templates/` directory:

```
templates/
├── STATE.md             # Project state template
├── TODO.md              # Task tracking template
└── claude-code/         # Claude Code templates
    ├── settings.json
    └── commands/
        ├── start.md
        └── save.md
```

**Important:** Template changes may affect existing users. Document changes clearly in commit messages.

---

## Script Development

### Bash Compatibility

**All scripts must work with bash 3.2+ (macOS default):**

**Avoid:**
- Associative arrays (bash 4+)
- `&>` redirection (use `2>&1`)
- `${var^^}` transformations (bash 4+)

**Use:**
- `[ ]` test operators
- `$(command)` substitution
- Indexed arrays
- POSIX-compatible patterns

### Script Guidelines

1. **Keep scripts simple** - Target < 200 lines per script
2. **Make idempotent** - Safe to run multiple times
3. **Add help text** - Always support --help
4. **Support dry-run** - Show actions without executing
5. **Validate inputs** - Check paths, arguments
6. **Clear error messages** - Actionable error text

### Adding New Scripts

**Only add scripts when necessary** (YAGNI principle).

Current scripts cover core use cases:
- `install.sh` - Generic template deployment
- `claude-code.sh` - Claude Code specific setup

If adding new scripts (e.g., `cursor.sh`, `copilot.sh`):
1. Follow same structure as existing scripts
2. Add bats tests
3. Update README.md
4. Commit with `feat:` type

---

## Documentation

### Required Documentation

- `README.md` - Quick start, installation, overview
- `CONTRIBUTING.md` - This file
- `ARCHITECTURE.md` - Technical design (in docs/)
- `CHANGELOG.md` - Auto-generated, don't edit manually

### Documentation Standards

**Keep documentation:**
- Concise and scannable
- Up-to-date with code
- Free of version numbers (use VERSION file instead)
- Australian English spelling

**Don't include:**
- Hardcoded versions (use VERSION file)
- Dates in filenames
- Marketing language
- AI attribution

---

## Pull Request Guidelines

### PR Title

Use conventional commit format:

```
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

### Review Process

**Internal (HyperSec):**
1. Create PR
2. Automated checks run (GitHub Actions)
3. Request review from team lead
4. Address feedback
5. Merge to main (squash or merge commit)
6. Semantic-release auto-publishes

**External (if public):**
1. Fork and create PR
2. Maintainer review required
3. May request changes
4. Merge after approval

---

## Maintenance

### Regular Tasks

**Monthly:**
- Review standards for accuracy
- Check for outdated information
- Update dependencies in workflows
- Test with latest Claude Code version

**As needed:**
- Respond to issues
- Review PRs
- Update templates based on feedback
- Add support for new AI assistants

### Deprecation Policy

If deprecating features:
1. Add deprecation notice in relevant files
2. Keep deprecated feature for one major version
3. Document migration path
4. Use `BREAKING CHANGE:` footer when removing

---

## Getting Help

**For HyperSec developers:**
- Slack: #standards channel
- GitHub Issues: https://github.com/hypersec-io/ai/issues
- Email: dev@hypersec.io

**For external users (if repository becomes public):**
- GitHub Issues only
- No direct support guaranteed

---

## License

This repository is proprietary (HyperSec EULA).

**Internal use:** Freely use in all HyperSec projects
**External use:** Not permitted without license agreement

See [LICENSE](LICENSE) for details.

---

**Questions?** Create a GitHub issue or ask in #standards Slack channel.
