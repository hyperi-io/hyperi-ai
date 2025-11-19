# Architecture - HyperSec AI Code Assistant Standards

**Technical design for installation and setup scripts**

---

## Overview

This document describes the technical architecture of the AI repository setup scripts. The design prioritises radical simplification while maintaining flexibility for three usage modes.

**Core Principle:** KISS (Keep It Simple, Stupid) - Scripts must be understandable by reading one file.

---

## Design Goals

### Primary Goals

1. **Radical simplification** - 95% reduction from legacy (25,000+ lines → <1,000 lines)
2. **Path-agnostic** - Works anywhere, not just `/ai`
3. **Cross-platform** - macOS (bash 3.2+), Ubuntu 22+, Fedora 42+
4. **Idempotent** - Safe to run multiple times
5. **Self-contained** - Each script < 200 lines

### Non-Goals

- **NOT** a CI/CD system (that's hs-ci)
- **NOT** Python-based (pure bash only)
- **NOT** complex templating (simple file copies)
- **NOT** project-specific (generic AI assistant support)

---

## Usage Modes

### Mode 1: Git Submodule (Production)

```bash
cd /my-project
git submodule add https://github.com/hypersec-io/ai.git ai
./ai/install.sh
./ai/claude-code.sh
```

**Detection:** `.git` is a file (points to parent's `.git/modules/ai`)

**Behaviour:**
- Standards already in `./ai/standards/` (read-only)
- Templates copied from `./ai/templates/`
- Creates `STATE.md`, `TODO.md` in project root
- Creates `.claude/` directory for Claude Code

### Mode 2: Git Clone (Development)

```bash
git clone https://github.com/hypersec-io/ai.git my-ai
cd /my-project
/path/to/my-ai/install.sh
/path/to/my-ai/claude-code.sh
```

**Detection:** `.git` is a directory (standalone repo)

**Behaviour:**
- Same as submodule mode
- Standards in `./ai/standards/` (if AI_ROOT symlinked)

### Mode 3: ZIP Download (Quick Start)

```bash
unzip ai-main.zip
cd /my-project
/path/to/ai-main/install.sh
/path/to/ai-main/claude-code.sh
```

**Detection:** No `.git` at all

**Behaviour:**
- Standards copied to project (since no git tracking)
- Templates deployed same as other modes

---

## Path Variables

### Auto-Detection

Scripts auto-detect their location and target:

```bash
# AI_ROOT - Where the ai repository lives
AI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PROJECT_ROOT - Where to install templates (default: parent of AI_ROOT)
PROJECT_ROOT="$(dirname "$AI_ROOT")"
```

### Override Capability

```bash
# User can override target directory
./install.sh --path /custom/project
./claude-code.sh --path /custom/project
```

### Environment Variables

```bash
# Optional environment overrides
export AI_ROOT=/path/to/ai
export PROJECT_ROOT=/path/to/project
./install.sh  # Uses env vars
```

---

## Script Architecture

### Script 1: install.sh

**Purpose:** Deploy STATE.md and TODO.md templates to project root

**Size Target:** < 150 lines

**Structure:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Path detection (20 lines)
detect_paths() {
    AI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$AI_ROOT")}"
}

# 2. Usage mode detection (15 lines)
detect_mode() {
    if [ -f "$AI_ROOT/.git" ]; then
        MODE="submodule"
    elif [ -d "$AI_ROOT/.git" ]; then
        MODE="clone"
    else
        MODE="standalone"
    fi
}

# 3. Template deployment (40 lines)
deploy_templates() {
    copy_if_missing "$AI_ROOT/templates/STATE.md" "$PROJECT_ROOT/STATE.md"
    copy_if_missing "$AI_ROOT/templates/TODO.md" "$PROJECT_ROOT/TODO.md"
}

# 4. Helper functions (30 lines)
copy_if_missing() {
    local src="$1"
    local dst="$2"
    if [ ! -f "$dst" ] || [ "$FORCE" = "true" ]; then
        cp "$src" "$dst"
        echo "Deployed: $dst"
    else
        echo "Skipped (exists): $dst"
    fi
}

# 5. Main execution (30 lines)
main() {
    parse_args "$@"
    detect_paths
    detect_mode
    deploy_templates
    print_summary
}

main "$@"
```

**Features:**
- `--help` - Usage information
- `--dry-run` - Show what would be done
- `--force` - Overwrite existing files
- `--path PATH` - Override target directory
- `--verbose` - Detailed output

### Script 2: claude-code.sh

**Purpose:** Setup Claude Code configuration and slash commands

**Size Target:** < 200 lines

**Structure:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Path detection (same as install.sh)

# 2. Prerequisites check (20 lines)
check_prerequisites() {
    if [ ! -f "$PROJECT_ROOT/STATE.md" ]; then
        echo "ERROR: STATE.md not found. Run install.sh first."
        exit 1
    fi
}

# 3. Claude directory setup (30 lines)
setup_claude_dir() {
    mkdir -p "$PROJECT_ROOT/.claude/commands"
    copy_settings
    copy_commands
}

# 4. Settings deployment (40 lines)
copy_settings() {
    local src="$AI_ROOT/templates/claude-code/settings.json"
    local dst="$PROJECT_ROOT/.claude/settings.json"

    if [ -f "$dst" ] && [ "$FORCE" != "true" ]; then
        echo "Settings exist, skipping (use --force to overwrite)"
    else
        cp "$src" "$dst"
    fi
}

# 5. Commands deployment (30 lines)
copy_commands() {
    # Always overwrite commands (they're versioned templates)
    cp "$AI_ROOT/templates/claude-code/commands/start.md" \
       "$PROJECT_ROOT/.claude/commands/"
    cp "$AI_ROOT/templates/claude-code/commands/save.md" \
       "$PROJECT_ROOT/.claude/commands/"
}

# 6. Symlink creation (30 lines)
create_symlink() {
    local target="$PROJECT_ROOT/CLAUDE.md"
    local source="STATE.md"

    if [ -L "$target" ]; then
        echo "CLAUDE.md symlink exists"
    else
        ln -s "$source" "$target"
        echo "Created: CLAUDE.md -> STATE.md"
    fi
}

# 7. Main execution
main() {
    parse_args "$@"
    detect_paths
    check_prerequisites
    setup_claude_dir
    create_symlink
    print_summary
}

main "$@"
```

**Features:**
- Same flags as install.sh
- Checks for STATE.md (requires install.sh first)
- Always overwrites slash commands (versioned)
- Preserves user settings by default

---

## File Operations

### Idempotence Strategy

**Key principle:** Safe to run multiple times

```bash
# Pattern 1: Skip if exists
if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
fi

# Pattern 2: Force flag
if [ ! -f "$dst" ] || [ "$FORCE" = "true" ]; then
    cp "$src" "$dst"
fi

# Pattern 3: Always overwrite (versioned files)
cp "$src" "$dst"  # Commands are always current
```

### Copy Operations

**Simple file copies only** (no templating):

```bash
# Good - simple copy
cp "$AI_ROOT/templates/STATE.md" "$PROJECT_ROOT/STATE.md"

# Bad - complex templating (avoid)
sed "s/{{PROJECT_NAME}}/$NAME/g" template.md > output.md
```

**Rationale:** Templates are generic enough to work as-is. Project-specific customisation happens after deployment.

---

## Error Handling

### Bash Safety

**All scripts use:**

```bash
#!/usr/bin/env bash
set -euo pipefail
# -e: Exit on error
# -u: Exit on undefined variable
# -o pipefail: Exit on pipe failure
```

### Error Messages

**Clear, actionable errors:**

```bash
# Good
echo "ERROR: STATE.md not found. Run install.sh first."
exit 1

# Bad
echo "Error"  # Not helpful
exit 1
```

### Exit Codes

```bash
0   # Success
1   # General error
2   # Missing dependency
64  # Usage error (--help)
```

---

## Bash 3.2 Compatibility

### macOS Default Shell

macOS ships with bash 3.2 (released 2006, never updated due to GPL3).

**Must avoid:**

```bash
# Bad - bash 4+ only
declare -A assoc_array  # Associative arrays
[[ $var =~ pattern ]]   # Regex matching
${var^^}                # Uppercase transformation
command &> file         # Combined redirect
```

**Safe patterns:**

```bash
# Good - bash 3.2 compatible
[ -f "$file" ]          # File test
$(command)              # Command substitution
${var#pattern}          # String manipulation
arr=(1 2 3)             # Indexed arrays
command > file 2>&1     # Redirect stderr to stdout
```

### Testing on macOS

**Verify bash version:**

```bash
bash --version
# GNU bash, version 3.2.57(1)-release (arm64-apple-darwin23)
```

---

## Directory Structure

### Repository Layout

```
$AI_ROOT/                    # Anywhere (path-agnostic)
├── install.sh               # Script 1: Deploy templates
├── claude-code.sh           # Script 2: Setup Claude Code
│
├── standards/               # AI guidance (main product)
│   ├── STANDARDS.md         # Entry point
│   ├── code-assistant/      # AI-specific
│   ├── common/              # Language-agnostic
│   └── python/              # Python-specific
│
├── templates/               # Deployment artifacts
│   ├── STATE.md             # Session state template
│   ├── TODO.md              # Task tracking template
│   └── claude-code/         # Claude Code templates
│       ├── settings.json
│       └── commands/
│           ├── start.md
│           └── save.md
│
└── docs/                    # Project documentation
    ├── SCOPE.md
    ├── ARCHITECTURE.md      # This file
    └── TESTING.md
```

### Deployed Layout

```
$PROJECT_ROOT/
├── ai/                      # This repository (submodule/symlink)
├── STATE.md                 # Deployed by install.sh
├── TODO.md                  # Deployed by install.sh
├── CLAUDE.md -> STATE.md    # Created by claude-code.sh
└── .claude/                 # Created by claude-code.sh
    ├── settings.json
    └── commands/
        ├── start.md
        └── save.md
```

---

## Testing Strategy

### Test Levels

1. **Unit tests** - Test individual functions (if extracted)
2. **Integration tests** - Test full script execution
3. **Cross-platform tests** - macOS, Ubuntu, Fedora

### Test Environment

```
.tmp/test-projects/          # Gitignored test area
├── test-submodule/          # Simulates submodule mode
├── test-clone/              # Simulates clone mode
└── test-standalone/         # Simulates standalone mode
```

### Test Cases

**install.sh:**
- [ ] Detects submodule mode correctly
- [ ] Detects clone mode correctly
- [ ] Detects standalone mode correctly
- [ ] Deploys STATE.md successfully
- [ ] Deploys TODO.md successfully
- [ ] Skips existing files (idempotent)
- [ ] Overwrites with --force
- [ ] Respects --path override
- [ ] --dry-run shows actions without executing
- [ ] Works on macOS (bash 3.2)
- [ ] Works on Ubuntu 22+
- [ ] Works on Fedora 42+

**claude-code.sh:**
- [ ] Checks for STATE.md (prerequisite)
- [ ] Creates .claude/ directory
- [ ] Deploys settings.json
- [ ] Deploys slash commands
- [ ] Creates CLAUDE.md symlink
- [ ] Idempotent (safe to re-run)
- [ ] Preserves existing settings by default
- [ ] Overwrites settings with --force
- [ ] Always updates commands (versioned)

**See [TESTING.md](TESTING.md) for detailed test plan.**

---

## Security Considerations

### Path Traversal

**Prevent malicious paths:**

```bash
# Validate paths don't escape project
realpath() {
    # Resolve path safely
    python3 -c "import os; print(os.path.realpath('$1'))"
}

# Check result is within expected directory
```

### File Permissions

**Respect umask:**

```bash
# Let umask control permissions (don't force 777)
cp file dest         # Inherits umask
mkdir -p .claude     # Inherits umask
```

**Exception:** Symlinks don't have permissions

### Input Validation

**Validate user inputs:**

```bash
# Check --path argument
if [ -n "$CUSTOM_PATH" ]; then
    if [ ! -d "$CUSTOM_PATH" ]; then
        echo "ERROR: Path does not exist: $CUSTOM_PATH"
        exit 1
    fi
fi
```

---

## Performance

### Script Execution Time

**Target:** < 1 second for all operations

**Actual (estimated):**
- install.sh: ~0.1s (2 file copies)
- claude-code.sh: ~0.2s (3 file copies + 1 symlink)

**Optimisation:** None needed - already fast enough

---

## Maintenance

### Adding New Templates

1. Add template file to `templates/`
2. Update relevant script to copy it
3. Document in README.md
4. Add test case
5. Update version in CHANGELOG.md

### Adding New Scripts

**Only if absolutely necessary** (YAGNI principle)

Current 2 scripts cover all core functionality:
- install.sh - Generic setup
- claude-code.sh - Claude Code specific

Future scripts (if needed):
- cursor.sh - Cursor IDE setup
- github-copilot.sh - GitHub Copilot setup

---

## Versioning

### Script Versions

Scripts don't have embedded versions (tracked by git tags).

### Template Versions

Templates include version markers:

```markdown
# STATE.md

**Last Updated:** 2025-01-20
**Template Version:** 1.0.0
```

---

## Documentation

### User Documentation

- [README.md](../README.md) - Quick start, usage modes
- [docs/SCOPE.md](SCOPE.md) - Project scope and goals

### Developer Documentation

- [docs/ARCHITECTURE.md](ARCHITECTURE.md) - This file
- [docs/TESTING.md](TESTING.md) - Testing strategy
- Script comments - Inline documentation

---

## Future Considerations

### Potential Enhancements

**Not in MVP:**
- Interactive setup wizard (ask for project name, etc.)
- Template validation (verify deployed files are correct)
- Update mechanism (check for newer templates)
- Migration tool (from legacy hs-ci/ai to new structure)

**Decision:** Ship MVP first, add features based on real user needs

---

## Comparison with Legacy

### Legacy (hs-ci/ai)

- **Size:** 25,000+ lines (ci_lib.py alone)
- **Language:** Python + bash wrapper
- **Dependencies:** dynaconf, pyyaml, virtualenv
- **Complexity:** High (multiple modules, config layers)
- **Install:** Complex bootstrap process

### New (this repo)

- **Size:** <1,000 lines (target: ~400)
- **Language:** Pure bash 3.2+
- **Dependencies:** None (bash + Unix tools)
- **Complexity:** Low (2 scripts, simple file copies)
- **Install:** Run one script

**95% reduction achieved through:**
- No Python (no virtualenv, no dependencies)
- No complex templating (simple file copies)
- No CI/CD (that's hs-ci's job)
- Focus on AI assistant support only

---

**Last Updated:** 2025-01-20
**Version:** 0.1.0
**Status:** Planning Complete
