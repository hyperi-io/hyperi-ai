# Project Scope - HyperSec AI Code Assistant Standards

## Purpose

This project provides **standards, documentation, and configuration templates** for AI code assistants. It's designed to "tack on" to existing projects and provide consistent AI assistant guidance across all HyperSec projects.

---

## Usage Modes

Projects can integrate this repository using **ONE OF** three methods:

### 1. Git Submodule (Recommended for continuous updates)
```bash
git submodule add https://github.com/hypersec-io/ai.git ai
git submodule update --init --recursive
```
**Use when:** You want the latest HyperSec-wide updates automatically.

### 2. Git Clone to Subdirectory (Point-in-time copy)
```bash
git clone https://github.com/hypersec-io/ai.git ai
cd ai && rm -rf .git
```
**Use when:** You want a stable point-in-time copy without tracking updates.

### 3. Download ZIP (Point-in-time copy)
```bash
curl -L https://github.com/hypersec-io/ai/archive/refs/heads/main.zip -o ai.zip
unzip ai.zip
mv ai-main ai
```
**Use when:** You want a standalone copy without git dependencies.

---

## Directory Structure

**Conceptual model:** This repository can be attached to any parent project at any path.

**Example attachment as `/ai` subdirectory (common but not required):**

```
parent-project/              # Your project
├── ai/                      # This repository (could be any name)
│   ├── install.sh           # Installation script (supports all 3 modes)
│   ├── claude-code.sh       # Claude Code setup (idempotent)
│   │
│   ├── standards/           # AI assistant standards and guidance
│   │   ├── STANDARDS.md     # Entry point with loading strategy
│   │   ├── ai/              # AI principles and token engineering
│   │   ├── code-assistant/  # AI-specific guidance
│   │   ├── common/          # Language-agnostic standards
│   │   └── python/          # Python-specific standards
│   │
│   ├── templates/           # AI assistant configuration templates
│   │   ├── STATE.md         # Cross-LLM session state (ALL assistants)
│   │   ├── TODO.md          # Cross-LLM task tracking (ALL assistants)
│   │   └── claude-code/     # Claude Code specific templates
│   │       ├── settings.json
│   │       └── commands/
│   │           ├── start.md
│   │           └── save.md
│   │
│   ├── docs/                # Project documentation
│   │   ├── SCOPE.md         # This file
│   │   ├── ARCHITECTURE.md  # Technical design (KISS focused)
│   │   └── TESTING.md       # Testing strategy
│   │
│   └── legacy/              # Legacy code (reference only, no Python used)
│
├── STATE.md                 # Created by install.sh (from templates/)
├── TODO.md                  # Created by install.sh (from templates/)
├── .claude/                 # Created by claude-code.sh
│   ├── settings.json
│   └── commands/
│       ├── start.md
│       └── save.md
└── CLAUDE.md -> STATE.md    # Symlink created by claude-code.sh
```

**Path references in this documentation:**
- `$AI_ROOT` = Where this repository is attached (e.g., `ai/`, `standards/`, `.ai/`)
- `$PROJECT_ROOT` = Parent project root (where STATE.md, TODO.md are deployed)
- Scripts auto-detect these paths, no hardcoded assumptions

---

## Core Concepts

### Cross-LLM Session State

**Two files shared across ALL AI assistants:**

1. **STATE.md** - Project state and session history
   - Architecture decisions
   - Current session progress
   - Recent work summary
   - Known issues/blockers

2. **TODO.md** - Task tracking
   - Active tasks
   - Pending work
   - Priorities

### AI Assistant Specific Configuration

Each AI assistant has a setup script (`<assistant>.sh`) that:
- Configures the assistant **idempotently** (safe to run multiple times)
- Links assistant-specific files to cross-LLM session state
- Deploys templates from `/templates/<assistant>/`

**Example:** Claude Code
- Runs: `./claude-code.sh`
- Creates: `.claude/` directory with settings
- Creates: `CLAUDE.md` → symlink → `STATE.md`
- Deploys: Templates from `templates/claude-code/`

---

## Installation Script (`install.sh`)

### Requirements

Must work in **all 3 usage modes:**
1. Git submodule (`.git/` exists, is a file pointing to parent repo)
2. Git clone without .git (`.git/` removed)
3. ZIP download (no `.git/` directory)

### Functionality

```bash
./install.sh [--path /path/to/project]

# Detects usage mode automatically
# Deploys to /ai path of target project
# Idempotent (safe to run multiple times)
```

**Actions:**
1. Detect usage mode (submodule, clone, or standalone)
2. Copy/link standards to target project's `ai/` directory
3. Deploy cross-LLM templates (STATE.md, TODO.md)
4. Display next steps for AI assistant setup

**Does NOT:**
- Configure specific AI assistants (use `<assistant>.sh` for that)
- Modify target project's files (except creating `ai/` directory)

---

## AI Assistant Setup Scripts

### Pattern: `<assistant>.sh`

Each AI assistant has a dedicated setup script:

```bash
./claude-code.sh [--path /path/to/project]
./github-copilot.sh [--path /path/to/project]  # Future
./cursor.sh [--path /path/to/project]          # Future
```

### Requirements

- **Idempotent**: Safe to run multiple times
- **Standalone**: Works without assuming git clone
- **Cross-mode**: Works for all 3 usage modes
- **Template-based**: Uses files from `/templates/<assistant>/`

### Claude Code Example

```bash
# Run setup
./claude-code.sh

# What it does:
# 1. Creates .claude/ directory
# 2. Deploys settings.json (from templates/claude-code/)
# 3. Deploys slash commands (start.md, save.md)
# 4. Creates CLAUDE.md → STATE.md symlink
# 5. Verifies configuration
```

---

## Testing Strategy

### Test Project Location

```
/projects/ai-test/
```

**Setup:**
```bash
mkdir -p /projects/ai-test
cd /projects/ai-test
git init
```

### Test Scenarios

1. **Test installation in all 3 modes**
   - Submodule mode
   - Clone mode
   - ZIP download mode

2. **Test idempotence**
   - Run install.sh twice, verify no errors
   - Run claude-code.sh twice, verify no duplicates

3. **Test cross-LLM session state**
   - Verify STATE.md and TODO.md created
   - Verify CLAUDE.md symlink works
   - Verify templates deployed correctly

4. **Test standalone mode**
   - Remove all git files
   - Run install.sh
   - Verify it works without git dependencies

---

## Design Principles

### 1. Radical Simplification (Primary Goal) - KISS Principle

**Apply KISS (Keep It Simple, Stupid) ruthlessly, especially for initial builds.**

**Legacy hs-ci/ai was way over-engineered. We're fixing that.**

**Significantly reduce complexity compared to legacy hs-ci approach:**

**Legacy hs-ci/ai problems:**
- ❌ 25,000+ line `ci_lib.py` library
- ❌ Complex 7-layer configuration cascade
- ❌ Modular `.d` pattern requiring orchestration
- ❌ Tight coupling to hs-ci infrastructure
- ❌ Dynaconf dependency for simple file operations
- ❌ Marker-based merge system with conditional logic
- ❌ Python virtual environment bootstrapping
- ❌ Multiple scripts coordinating via shared state

**New simplified approach:**
- ✅ Simple bash scripts (< 200 lines each)
- ✅ No Python dependencies (pure bash + standard Unix tools)
- ✅ No configuration cascade (just copy templates)
- ✅ No complex merging (symlinks + simple file copies)
- ✅ No dependency on hs-ci or any CI system
- ✅ Standalone scripts that work in isolation
- ✅ Each script is self-contained and readable
- ✅ **Understandable by reading one file**

**Complexity reduction targets:**
- Legacy: ~30 files, 25,000+ lines, Python ecosystem required
- New: ~3-5 files, <1,000 lines total, bash + Unix tools only
- **Goal: 95%+ reduction in code complexity**

**KISS principles for initial implementation:**
- ✅ Do the simplest thing that works first
- ✅ Hardcode reasonable defaults (don't over-configure)
- ✅ Copy files directly (no fancy templating systems)
- ✅ Use basic if/else logic (no abstract frameworks)
- ✅ Single-purpose functions (no multi-level abstractions)
- ✅ Clear error messages (no complex error handling hierarchies)
- ✅ **If it takes more than 50 lines, it's probably over-engineered**

### 2. Standards are the Main Product

The `/standards/` directory contains the primary deliverable:
- AI assistant guidance
- Coding standards
- Best practices
- Loading strategies (CAG/RAG)

### 3. Templates are Deployment Artifacts

The `/templates/` directory contains configuration templates:
- Deployed to target projects via simple copy operations
- Customizable per project (no complex merging)
- Version-controlled separately from standards

### 4. Installation is Flexible

Support multiple integration modes:
- Submodule for continuous updates
- Clone for point-in-time stability
- ZIP for maximum portability

### 5. AI Assistant Agnostic Core

- STATE.md and TODO.md work for ALL assistants
- Assistant-specific configuration is isolated
- Easy to add new assistants (just add `<assistant>.sh`)

### 6. No Dependencies Beyond Unix Basics

**Required tools (present on all Unix systems):**
- bash
- cp, ln, mkdir
- test, [ ]
- echo, printf

**NO requirements for:**
- Python (no .venv needed)
- pip, uv, virtualenv
- dynaconf, pyyaml
- Complex libraries or frameworks

### 7. Cross-Platform Compatibility

**Target systems (primary):**
- **macOS** - bash 3.2 (default system bash)
- **Ubuntu 22.04+** - bash 5.1+
- **Fedora 42+** - bash 5.2+

**Compatibility requirements:**
- Scripts must work with bash 3.2 (macOS limitation)
- Use POSIX-compatible features where possible
- Avoid bash 4+ features (associative arrays, etc.)
- Test on all three platforms before release

**Also expected to work on:**
- Debian, RHEL, CentOS, Rocky Linux, AlmaLinux
- Any Unix-like system with bash 3.2+
- WSL (Windows Subsystem for Linux)

**Not required to support:**
- Windows native (use WSL instead)
- Shell variants (zsh, fish, ksh) - bash only

---

## Migration from Legacy

The legacy `/legacy/` code implemented a monolithic `ci/ai` tool in Python that:
- Merged files based on complex configuration
- Handled CLAUDE.md consolidation
- Managed .bashrc environment variables
- Required Python, dynaconf, pyyaml, virtualenv

**IMPORTANT: Legacy code is REFERENCE ONLY**
- ⚠️ **NO Python code will be used in this project**
- ⚠️ **Legacy code shows WHAT operations to perform, not HOW**
- ⚠️ All new implementation will be pure bash scripts
- ⚠️ Legacy directory exists only to understand requirements

**New approach (100% bash):**
- Simple standalone bash scripts
- No Python, no dependencies, no virtual environments
- No dependency on hs-ci infrastructure
- Works independently of CI/CD system
- Focus on standards delivery, not complex merging
- Direct file operations (cp, ln) instead of Python libraries

---

## Success Criteria

1. ✅ Can attach to any project using 3 different methods
2. ✅ Standards are usable by AI assistants immediately
3. ✅ Install script works without git (standalone mode)
4. ✅ AI assistant setup is idempotent
5. ✅ Cross-LLM session state (STATE.md, TODO.md) works
6. ✅ Testing validates all modes against /projects/ai-test

---

## Future Enhancements

- Add GitHub Copilot support (`github-copilot.sh`)
- Add Cursor support (`cursor.sh`)
- Add Gemini support (`gemini.sh`)
- Template validation tool
- Standards version management
- Auto-update mechanism for submodule mode

---


**License:** HyperSec EULA (proprietary)
