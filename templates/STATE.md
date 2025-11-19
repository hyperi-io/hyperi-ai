# HyperCI - Common CI/CD Documentation

**Auto-appended to project STATE.md during AI setup**

## Critical Policies for AI Assistants

**ALWAYS READ ON SESSION START:**
1. This STATE.md file (you're reading it now)
2. `TODO.md` (current tasks and priorities)
3. **Use `/start` command** - Automatically loads all mandatory files below

**Mandatory files loaded by `/start`:**
- `ci/docs/standards/STANDARDS.md` - Entry point with LLM RAG strategy
- `ci/docs/standards/code-assistant/COMMON.md` - Session mgmt, bash, commits (ALWAYS)
- `ci/docs/standards/code-assistant/HYPERCI.md` - CI infrastructure guidance (IF working on CI)
- `ci/docs/standards/code-assistant/PYTHON.md` - Python guidance (IF Python project)
- `ci/docs/standards/common/CHARS-POLICY.md` - Character restrictions (ALWAYS)
- `ci/docs/standards/common/CODE-HEADER.md` - File headers (ALWAYS)
- `ci/docs/standards/common/GIT-WORKFLOW.md` - Git conventions (ALWAYS)
- `ci/docs/standards/common/QUICK-REFERENCE.md` - Cheat sheet (ALWAYS)
- `ci-local/ai/*.md` - Project/developer overrides (if any exist)

**Context-specific files (loaded by `/start` based on project type):**
- Python: `ci/docs/standards/python/CODING.md`
- Containerization: `ci/docs/standards/common/CONTAINERIZATION.md`

**Do not skip the `/start` command. It ensures consistent CAG (Code Assistant Guidance) loading.**

### 1. Commit Message Type Selection (UNDERSTATE, NOT OVERSTATE)

**AI assistants frequently overstate importance. Always err on understatement.**

**Default to `fix:` when uncertain:**
- ✅ `fix:` is almost always correct for bug fixes, improvements, refactors
- ❌ Don't use `feat:` unless it's truly a **NEW VERY SIGNIFICANT and BROAD** feature
- ❌ Don't use `BREAKING CHANGE:` unless it breaks backward compatibility

**Valid commit types:**
- `feat:` - **NEW VERY SIGNIFICANT and BROAD user-facing feature** (minor version bump) - RARELY USE
- `fix:` - **Bug fix, improvement, refactor, cleanup** (patch bump) - DEFAULT CHOICE
- `perf:` - Performance optimization only (patch bump)
- `chore:` - Maintenance, deps, config (no bump)
- `docs:` - Documentation only (no bump)
- `test:` - Tests only (no bump)
- `ci:` - CI configuration (no bump)

**Format:** `<type>: <description>` or `<type>(<scope>): <description>`

**Examples of correct usage:**
```
fix: update CI structure documentation          # NOT feat: (just docs)
fix: add commit message validation              # NOT feat: (internal tool)
fix: improve test coverage                      # NOT feat: (tests)
chore: update ci submodule                      # NOT feat: or fix:
feat: add OAuth authentication for users        # OK - NEW user feature
```

**Why this matters:**
- Semantic versioning depends on correct types
- Over-using `feat:` causes unnecessary minor version bumps
- Projects accumulate false "features" in changelogs
- `fix:` is safer and more accurate for most changes

**Validation:** commit-msg hook enforces format (auto-installed by bootstrap)

### 2. Directory Structure

**Read-only ci/ (git submodule):**
- `ci/` - HyperCI scripts (NEVER modify directly)
- `ci/modules/` - Modular CI scripts organized by language
- `ci/docs/` - Documentation

**Writable ci-local/ (project-specific):**
- `.env` - Credentials (gitignored)
- `ci-local/ci.yaml` - Project CI configuration

**Project workspace:**
- `.venv/` - Unified venv for project + CI tools (uv-managed)
- `pyproject.toml` - Project metadata + CI tool configs
- `.tmp/` - Temporary files (ALWAYS use this, not /tmp)

### 3. AI Guidance Architecture (Merge Only When Must)

**CRITICAL PRINCIPLE: Read directly from source, merge ONLY when we MUST.**

**File locations:**
- **Core guidance (read-only):** `ci/docs/standards/ai/*.md`
  - CODE-ASSISTANT-COMMON.md - Universal guidance for all projects
  - CODE-ASSISTANT-HYPERCI.md - CI infrastructure work only
  - CODE-ASSISTANT-PYTHON.md - Python-specific guidance (if exists)
  - Always read directly from ci/ (no copying)

- **Project overrides (writable):** `ci-local/ai/*.md`
  - User/project-specific guidance
  - Developer customizations
  - Supplements (doesn't replace) core guidance

**Why this matters:**
- ✅ **Simpler:** No merge logic, no conflicts, no duplication
- ✅ **Single source of truth:** Core guidance always in ci/docs/standards/
- ✅ **Easy updates:** Pull ci/ submodule to get latest guidance
- ✅ **Flexibility:** Users can add custom guidance without modifying ci/

**When files ARE merged (exceptions only):**
- `STATE.md` - Appends CI documentation to bottom (marker: HYPERCI_STATE_MD)
- `.claude/settings.json` - Merges basic + tier-specific settings
- Both use markers to detect and replace sections cleanly

**When files are COPIED (versioned templates):**
- `.claude/commands/start.md` - Slash command (copy-overwrite, always latest)
- `.claude/commands/save.md` - Slash command (copy-overwrite, always latest)

**Default pattern for new files:** Read directly from ci/ (no copy, no merge)

### 4. Virtual Environment

**ONE unified .venv (project root):**
- Contains both project dependencies AND CI tools
- Managed by `uv` (fast, reliable)
- CI dependencies auto-installed by bootstrap:
  - dynaconf (config management)
  - pyyaml (YAML parsing)
  - tomli + tomli-w (TOML read/write)
  - python-semantic-release (versioning)

**CI scripts use .venv/bin/python:**
All CI tools run in the same venv as your project.

### 5. Bootstrap & Workflow

**Bootstrap (first-time setup):**
```bash
./ci/bootstrap install                # Install CI tools + Git hooks (RECOMMENDED)
./ci/bootstrap install --ai           # Install CI tools + Git hooks + AI setup
```

Creates .venv, installs dependencies, and sets up Git hooks. Use `--ai` to also install AI files.

**Run CI checks:**
```bash
./ci/run check       # All checks (tests, lint, type-check)
./ci/run test        # Tests only
./ci/run build       # Build package
```

**Git hooks (auto-installed by bootstrap):**
- `commit-msg` - Validates branch name, message format, removes AI attribution
- Blocks commits if invalid, warns about formatting issues

### 6. CI Script Locations

**New modular structure:**
```
ci/modules/
├── common/
│   ├── bootstrap.d/     # Bootstrap scripts (run during setup)
│   ├── run.d/           # Runtime checks (branch name, etc.)
│   ├── hooks/           # Git hooks (installed by bootstrap)
│   └── templates/       # File templates (.gitignore, etc.)
└── python/
    ├── bootstrap.d/     # Python bootstrap scripts
    └── run.d/           # Python CI checks (test, build, etc.)
```

**Execution:** All CI scripts run via bash wrappers using `.d` pattern
- `ci/bootstrap` orchestrates `bootstrap.d/*.py` scripts (includes git hooks)
- `ci/run` orchestrates `run.d/*.py` scripts

### 7. TODO Management

**Use TODO.md ONLY:**
- ✅ Add todos to `TODO.md` (project root)
- ❌ NEVER use `# TODO:` in code comments
- ❌ NEVER put TODOs in commit messages

### 8. Temporary Files

**Always use `./.tmp/`:**
- ✅ `./.tmp/` (project root, gitignored)
- ❌ NOT `/tmp`, `~/tmp`, or `/var/tmp`

### 9. Bash Command Execution

**See `ci/docs/standards/ai/CODE-ASSISTANT-COMMON.md` for complete bash usage guidance to minimize permission prompts.**

Quick summary:
- ❌ Avoid: `&&`, `||`, `;`, `|` (triggers permission prompts)
- ✅ Use: Separate Bash calls, `.tmp/` intermediate files, output redirection (`>`)

## Configuration Cascade

**Environment variables > .env > ci.yaml > defaults.yaml**

**Common env vars:**
- `CI_SKIP_HOOKS=true` - Skip git hook installation
- `CI=true` - Running in CI environment
- `BOOTSTRAP_INSTALL=1` - Enable bootstrap installation
- `CI_MERGE_MODE=overwrite` - Force template values to overwrite existing project values in TOML/JSON merges (default: no-overwrite)

## Quick Reference

**Update ci/ submodule:**
```bash
cd ci && git pull origin main && cd ..
git add ci && git commit -m "chore: update ci submodule"
```

**Contribute to HyperCI:**
1. Work in `ci/` directory (changes tracked in hs-ci repo)
2. Commit to `hypersec-io/hs-ci` repository
3. Update project's ci/ submodule reference

**Troubleshooting:**
- Bootstrap fails: Check `.env` has credentials
- Wrong venv: CI scripts enforce ci-local/.venv (will error)
- Submodule issues: `git submodule update --init --force`

---

**See also:**
- `ci/docs/standards/` - AI assistant guidance and coding standards
- `ci/docs/README.md` - Complete documentation
- `ci/docs/standards/GIT-WORKFLOW.md` - Git conventions
