# HS-CI Infrastructure - Code Assistant Guidance

**⚠️ CRITICAL: This guidance applies ONLY when working on CI infrastructure.**

**For normal project work (99% of tasks), DO NOT read this file.**

**These sections apply ONLY when:**
- User explicitly asks you to modify CI scripts
- You're working inside ci/ directory (requires explicit permission)
- You're debugging CI failures
- User says "work on CI" or "fix the CI"

**For normal feature development, bug fixes, and project work:**
- Focus on CODE-ASSISTANT-COMMON.md and language-specific files
- Do not waste context reading CI-specific guidance

---

## Configuration and Template Files (No Hardcoding)

**NEVER embed configuration, templates, or multi-line content in Python scripts.**

### Embedded Content Rule

❌ **WRONG - Embedded in code:**
```python
gitignore_content = """
.venv/
dist/
"""
gitignore_path.write_text(gitignore_content)
```

✅ **RIGHT - Separate template file:**
```python
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
gitignore_content = (SCRIPT_DIR / "script-name.gitignore").read_text()
gitignore_path.write_text(gitignore_content)
```

### Naming Convention

**Pattern:** `{script-name}.{content-type}.{extension}`

**Examples:**
- `05-project-structure.gitignore` - Gitignore template
- `bootstrap.update-ci.sh` - Bash script template
- `25-nuitka.hints.yaml` - Dependency hints
- `90-semantic-release.commit.txt` - Commit message template

### Content Types

- `.gitignore` - Gitignore templates
- `.readme.md` - README templates
- `.config.yaml` - YAML configuration templates
- `.script.sh` - Bash script templates
- `.commit.txt` - Commit message templates
- `.hints.yaml` - Dependency hints

### Benefits

✅ Proper syntax highlighting (editors recognize file types)
✅ Easy to edit (no string escaping)
✅ Clean git diffs
✅ No hardcoding in scripts
✅ Self-documenting (filename shows purpose)

### For AI Assistants: NO cat << EOF

❌ **NEVER use `cat << EOF` or heredocs:**
```bash
# WRONG
cat << 'EOF' > file.txt
content here
EOF
```

✅ **ALWAYS use your AI assistant's file write/edit capabilities:**
```python
# RIGHT
from pathlib import Path
Path("file.txt").write_text("content here")
```

Or use your AI assistant's file creation tool directly (even better).

---

## Configuration Management (No Hardcoding)

**No hardcoding of values as the default position.**

All configuration values should ideally use the **HyperSec configuration cascade:**

```
CLI switch > ENV value (prefixed) > .env file > app-specific.yaml > default.yaml > hardcoded value
(leftmost has precedence)
```

**Not all steps apply in all scenarios**, but follow this hierarchy when designing configuration.

### Configuration Cascade Explained

**1. CLI switch** (highest priority)
```bash
./app --port 8080 --debug
```

**2. Environment variable (prefixed)**
```bash
MYAPP_PORT=8080 MYAPP_DEBUG=true ./app
```

**3. .env file**
```bash
# .env
MYAPP_PORT=8080
MYAPP_DEBUG=true
```

**4. App-specific YAML** (project-specific config)
```yaml
# config/production.yaml
port: 8080
debug: false
```

**5. Default YAML** (shipped defaults)
```yaml
# config/default.yaml
port: 3000
debug: false
```

**6. Hardcoded value** (last resort, lowest priority)
```python
PORT = int(os.getenv("MYAPP_PORT", 3000))  # 3000 is hardcoded default
```

### When Writing Code

**❌ WRONG - Hardcoded value:**
```python
def connect_database():
    host = "localhost"  # Hardcoded!
    port = 5432         # Hardcoded!
    return connect(host, port)
```

**✅ RIGHT - Configuration cascade:**
```python
def connect_database():
    # Cascade: ENV > config file > default
    host = os.getenv("MYAPP_DB_HOST", config.get("database.host", "localhost"))
    port = int(os.getenv("MYAPP_DB_PORT", config.get("database.port", 5432)))
    return connect(host, port)
```

**✅ BETTER - Use configuration library:**
```python
from dynaconf import Dynaconf

config = Dynaconf(
    envvar_prefix="MYAPP",
    settings_files=["config/default.yaml", "config/production.yaml"],
)

def connect_database():
    return connect(config.database.host, config.database.port)
```

### For CI Scripts: Using get_config_value()

**HS-CI provides `get_config_value()` helper for standardized config cascade in CI scripts.**

**Import from ci_lib.py:**
```python
from ci_lib import get_config_value
```

**Function signature:**
```python
def get_config_value(
    config_path: str,       # Dot-notation path in ci.yaml (e.g., "ai.merge_mode")
    env_key: str | None,    # Environment variable name (e.g., "CI_AI_MERGE_MODE")
    default: Any            # Default value if not found
) -> Any:
    """
    Get configuration value using standardized cascade:
    ENV > .env > ci.yaml > default

    Args:
        config_path: Dot-notation path in ci.yaml (e.g., "nuitka.enabled")
        env_key: Environment variable to check (can be None to skip ENV check)
        default: Default value if not found anywhere

    Returns:
        Configuration value from highest priority source
    """
```

**Example - AI tool merge mode:**
```python
# modules/common/ai/src/20-merge-settings.py
merge_mode = get_config_value(
    config_path="ai.merge_mode",
    env_key="CI_AI_MERGE_MODE",
    default="skip"
)
# Cascade: ENV CI_AI_MERGE_MODE > .env > ci.yaml ai.merge_mode > "skip"
```

**❌ WRONG - Hardcoded environment variable:**
```python
import os
merge_mode = os.getenv("CI_AI_MERGE_MODE", "skip")  # No ci.yaml support!
```

**✅ RIGHT - Config cascade with get_config_value():**
```python
from ci_lib import get_config_value
merge_mode = get_config_value("ai.merge_mode", "CI_AI_MERGE_MODE", "skip")
# Supports: ENV > .env > ci.yaml > default
```

**Benefits:**
- ✅ **Consistent** - All CI scripts use same cascade logic
- ✅ **Documented** - config_path matches ci.yaml structure
- ✅ **Testable** - Can override via ENV or ci.yaml
- ✅ **Discoverable** - Easy to find what's configurable

### Principles

- ✅ **Make everything configurable** - Don't hardcode paths, URLs, timeouts
- ✅ **Use environment variables** - Prefix with app name (MYAPP_*)
- ✅ **Provide defaults** - But allow override at every level
- ✅ **Document configuration** - Show cascade in README or docs
- ❌ **Don't hardcode** - Especially not secrets, paths, URLs, timeouts

---

## Verification Requirements

**Before suggesting or modifying code, ALWAYS verify:**

✅ **Files exist** - Use Read or Glob before referencing files
✅ **Functions exist** - Use Grep to find definitions before calling them
✅ **Command success** - Check exit codes for every Bash command
✅ **Usages searched** - Use Grep before renaming/removing functions
✅ **Tools available** - Verify tools are installed (which, --version)
✅ **Code tested** - Run tests, builds, or execute before claiming it works
✅ **Dependencies checked** - Review pyproject.toml, uv.lock before adding packages

**Example - Refactoring safely:**
```bash
# WRONG: Rename without checking
# Just rename calculate_total() to compute_total()

# RIGHT: Search then rename
Grep "calculate_total" → finds 47 usages
Edit all 47 locations
Run tests to verify nothing broke
```

---

## Behavioral Rules

### Core Principles:

✅ **Do EXACTLY what's asked** - No scope creep, no unrequested improvements
✅ **Prefer editing existing files** - Don't create new files unnecessarily
✅ **Match existing code style** - Read similar files, follow established patterns
✅ **Follow existing patterns** - Use project's logging, error handling, import style
✅ **Preserve comments** - Keep existing comments, they explain "why"
✅ **Be concise** - Code speaks for itself, minimize explanations
✅ **STOP on errors** - Don't continue when commands fail
✅ **Handle errors explicitly** - No silent failures, always report issues
✅ **Complete implementations** - No "... rest of code", provide full working solutions
✅ **Clean up afterward** - Remove temp files, debug code, test artifacts

### Anti-Patterns:

**❌ NO scope creep:**
```
User: "Fix the login bug"
WRONG: Rewrites entire authentication system
RIGHT: Fixes the specific login bug mentioned
```

**❌ NO incomplete code:**
```python
# WRONG
def process_data(data):
    # ... rest of implementation
    pass

# RIGHT
def process_data(data):
    if not data:
        return None
    result = []
    for item in data:
        result.append(item.strip())
    return result
```

**❌ NO unsolicited optimization:**
```
User: "Fix the crash in parse_file()"
WRONG: Rewrites function with "better" algorithm
RIGHT: Fixes the specific crash, preserves working logic
```

---

## Context Awareness

### ALWAYS:

✅ **Read documentation FIRST** - STATE.md, TODO.md, docs/standards/ before starting
✅ **Understand project stack** - Check pyproject.toml, package dependencies
✅ **Check existing dependencies** - Review uv.lock before suggesting new packages
✅ **Preserve user's working code** - Don't replace unless explicitly asked
✅ **Remember conversation context** - Track constraints and decisions mentioned earlier
✅ **Respect TODO.md priorities** - Focus on Active tasks, not Backlog items

### DON'T Assume:

❌ Files exist (verify with Read/Glob first)
❌ Functions exist (verify with Grep before calling)
❌ Tools are installed (check with which before using)
❌ Operations succeeded (verify with status checks)
❌ You understand requirements (ask if unclear)
❌ Your interpretation is correct (confirm ambiguous requests)

---

## Ambiguity Handling

**When requirements are unclear or ambiguous:**

✅ **ASK for clarification** before implementing
✅ **Present options** if multiple valid approaches exist
✅ **State assumptions** you're making explicitly
✅ **Confirm before destructive operations** (delete, overwrite, large refactors)

❌ **Don't guess** what the user wants
❌ **Don't implement** the "most likely" interpretation without confirming
❌ **Don't proceed** with ambiguous requirements

**Example:**
```
User: "Fix the database connection"

WRONG: Assumes PostgreSQL, rewrites connection logic
RIGHT: "I see database connections in dbconn.py. Are you referring to:
        1. PostgreSQL connection pooling?
        2. Connection retry logic?
        3. Something else?
        Please clarify which issue to fix."
```

---

## Temporary Files Policy

**CRITICAL: ALWAYS use `./.tmp/` for ALL temporary operations**

**Applies to:**
- ✅ Temporary files (logs, cache, intermediate build artifacts)
- ✅ **Test project directories** (NOT `/tmp/test-*`)
- ✅ Scratch workspaces for testing
- ✅ ANY temporary content created during development, testing, or CI

**Forbidden:**
- ❌ `/tmp` (system temp - NOT project-scoped)
- ❌ `~/tmp` (user temp - NOT project-scoped)
- ❌ `/var/tmp` (system temp - NOT project-scoped)

**Reasons:**
1. Keeps temp files in project context (easy to find)
2. Automatically cleaned by project cleanup scripts
3. Gitignored by default (`.tmp/` in `.gitignore`)
4. Consistent across all developers and CI environments
5. No permission issues (project-owned directory)
6. **Test isolation** (test projects don't pollute system temp)

**Examples:**
```bash
# ✅ CORRECT - Create temporary directory
mkdir -p .tmp

# ✅ CORRECT - Test project in ./.tmp
mkdir -p ./.tmp/test-myproject
cd ./.tmp/test-myproject
git init
# ... test bootstrap, etc.

# ❌ WRONG - Test project in /tmp
mkdir /tmp/test-myproject  # NEVER DO THIS

# ✅ CORRECT - Write temporary files
python script.py > .tmp/output.log
echo "test" > .tmp/test-data.txt

# ❌ WRONG - System temp
python script.py > /tmp/output.log  # NEVER DO THIS

# ✅ CORRECT - Use in scripts
BUILD_DIR=.tmp/build
```

**Cleanup:**
```bash
# Clean all temp files
rm -rf .tmp/*

# Or let git clean do it
git clean -fdX  # Removes gitignored files including .tmp/
```

---

## READ-ONLY ci/ Directory

**The ci/ directory is a git submodule and is COMPLETELY READ-ONLY:**

- ✅ **READ from:** `ci/` (scripts, docs, templates, configurations)
- ✅ **EXECUTE:** Scripts from `ci/` (they read-only, safe to run)
- ✅ **WRITE to:** `ci-local/` (project-specific CI customizations)
- ❌ **NEVER write:** Any files to `ci/` directory
- ❌ **NEVER create:** `ci/.venv` (ci/ is read-only, use project root `.venv`)
- ❌ **NEVER modify:** Scripts in `ci/` (commit to hs-ci repo instead)
- ❌ **NEVER run:** `pip install` targeting `ci/` directory

**Enforcement:**
- AI code assistant permissions include: `"deny": ["Write(ci/**)", "Edit(ci/**)"]`
- This prevents accidental modifications to READ-ONLY ci/ submodule

**To contribute improvements to HS-CI:**
```bash
cd ci
git checkout -b fix/my-improvement
# Make changes in ci/ (this is a git repo)
git add .
git commit -m "fix: my improvement"
git push origin fix/my-improvement
# Create PR to hypersec-io/hs-ci repository

# After merge, update your project
cd ..
git add ci
git commit -m "chore: update ci/ submodule with my-improvement"
```

---

## Project Structure Recognition

**AI assistants should recognize these directories:**

- `ci/` - HS-CI scripts (READ-ONLY git submodule)
- `ci-local/` - Project CI customizations (writable)
- `src/` - Source code (varies by language)
- `tests/` - Test suite
- `docs/` - Documentation
- `.venv` - Development virtual environment
- `.tmp/` - Temporary files (gitignored)
- `dist/` - Build artifacts (gitignored)

**Configuration files:**
- `ci.yaml` - Project CI configuration (HS-CI settings)
- `pyproject.toml` - Python project metadata and dependencies
- `uv.lock` - Locked project dependencies
- `ci-local/pyproject.toml` - CI tool dependencies
- `ci-local/uv.lock` - Locked CI tool dependencies

---

## Active Checking Strategy (GitHub Actions & JFrog)

**PROBLEM:** Waiting with long timeouts (e.g., 10 minutes) only to discover the task failed in the first 2 seconds wastes time.

**SOLUTION:** Use active checking instead of passive waiting.

### Tools Available

**GitHub CLI (`gh`):**
```bash
gh run list --limit 5                    # List recent runs
gh run view <run_id>                     # View run details
gh run view <run_id> --log              # View logs in real-time
gh run watch <run_id>                    # Watch run progress
gh workflow view <workflow_name>         # View workflow status
```

**JFrog CLI (`jf`):**
```bash
# Check if package exists
jf rt search "hypersec-pypi-local/package/*" --count

# Verify specific version
jf rt download "hypersec-pypi-local/package/1.0.0/*.whl" --dry-run
```

**Git status:**
```bash
git log --oneline origin/main..HEAD     # Unpushed commits
git status                               # Local changes
```

### Best Practices for AI Assistants

1. ✅ **Push and immediately check:** After `git push`, run `gh run list` to verify workflow started
2. ✅ **Check every 30-60 seconds:** Use `gh run view <run_id>` to monitor status, don't wait blindly
3. ✅ **Fail fast:** If logs show errors, stop waiting and investigate immediately
4. ✅ **Verify artifacts:** After build, check JFrog with `jf rt search` to confirm upload
5. ❌ **DON'T:** Set a 10-minute timer and hope for the best
6. ❌ **DON'T:** Assume success without verification

### Example Active Checking Workflow

```bash
# 1. Push changes
git push origin main

# 2. Immediately check if workflow started (within 10 seconds)
gh run list --limit 1

# 3. Get run ID and monitor
RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
echo "Watching run: $RUN_ID"

# 4. Check every 30 seconds (don't wait 10 minutes!)
while true; do
  STATUS=$(gh run view $RUN_ID --json status,conclusion --jq '.status')
  echo "Status: $STATUS"

  if [ "$STATUS" = "completed" ]; then
    CONCLUSION=$(gh run view $RUN_ID --json conclusion --jq '.conclusion')
    echo "Conclusion: $CONCLUSION"
    break
  fi

  sleep 30
done

# 5. If successful, verify in JFrog immediately
jf rt search "hypersec-pypi-local/package/1.0.0/*.whl" --count
```

### Why This Matters

**GitHub Actions can fail due to:**
- Missing secrets (ARTIFACTORY_USERNAME, GH_PAT, etc.)
- Workflow syntax errors
- Runner unavailable
- Build errors (caught early with active checking)

**JFrog uploads can fail due to:**
- Invalid credentials
- Network issues
- Duplicate version (version already exists)
- Repository permissions

**Early detection saves time and prevents cascading failures.**

---

## Bash Tool Usage: Minimize Permission Prompts

**CRITICAL:** Compound commands (`&&`, `||`, `;`) and pipes (`|`) trigger permission prompts even when individual commands are pre-approved.

### The Problem

Permission patterns match single commands, not compound expressions:

- ✅ Approved: `Bash(git add *)`, `Bash(git commit *)`
- ❌ **Triggers prompt:** `Bash(git add . && git commit -m "msg")` ← new pattern!

### Solutions (in order of preference)

**1. Separate shell command calls** (preferred):
```bash
# Instead of: git add . && git commit -m "message"
git add .
git commit -m "message"
```

**2. Use intermediate files in `.tmp/`** (for pipes):
```bash
# Instead of: jq '.foo' file | grep bar
jq '.foo' file.json > .tmp/output.json
grep bar .tmp/output.json
```

**3. Output redirection** (SAFE - no prompt):
```bash
# These DON'T trigger prompts:
command > .tmp/output.txt
command >> .tmp/output.txt
command 2> .tmp/error.log
command 2>&1
```

### When Compound Commands ARE Acceptable

**ONLY when technically required:**

✅ `cd dir && command` - cd doesn't persist across Bash calls
✅ `export VAR=val && command` - env vars don't persist
✅ Critical cleanup: `operation || cleanup`

❌ Everything else - use separate calls or `.tmp/` intermediate files

### Key Points

- **Redirection (`>`, `>>`, `2>`)**: SAFE, no extra prompts
- **Pipes (`|`)**: Use `.tmp/` intermediate files instead
- **Compound (`&&`, `||`, `;`)**: Use separate Bash calls
- **Default strategy**: Separate calls + `.tmp/` files for chaining


---

## For More Information (CI Infrastructure)

**ONLY read these if user explicitly requests CI infrastructure work:**

**HS-CI Documentation (in STATE.md):**
- STATE.md contains auto-appended CI documentation (read there, not ci/ source)
- Complete HS-CI architecture documented in STATE.md
- CI workflows and commands explained in STATE.md

**Project Standards (in docs/standards/):**
- docs/standards/GIT-WORKFLOW.md - Git conventions
- docs/standards/CHARS-POLICY.md - Character usage
- docs/standards/python-coding-standards.md (Python projects)

**DO NOT read ci/docs/ directly** - Information already in STATE.md

---

## Tool Preferences: Avoid Bash Loops

**CRITICAL: Modern tools avoid bash loops and compound commands (which trigger approval prompts).**

### Recommended Tools (Install if Missing)

**File Operations:**

- **fd** over find: `fd -e py` instead of `find . -name "*.py"`
- **rg** (ripgrep) over grep: `rg "pattern"` instead of `grep -r "pattern"`
- **bat** over cat: `bat file.py` for syntax-highlighted output

**Data Processing:**

- **jq** for JSON: Parse JSON without bash loops
- **yq** for YAML: Parse YAML without bash loops
- **parallel** for batch operations: Replace for loops with parallel execution

**Why:** These tools eliminate need for bash loops, which require compound commands (&& or ;)

### Check Availability First

```bash
# Check if tool exists
command -v fd

# If missing, suggest installation (don't auto-install)
# Example: "fd not found. Install with: sudo apt install fd-find"
```

### Example: Avoid Bash Loops

❌ **BAD (requires approval, uses loop):**

```bash
for f in $(find . -name "*.py"); do
  grep -l "import logger" "$f"
done
```

**Problems:**

- Bash loop requires compound commands
- Triggers approval prompt
- Slower execution

✅ **GOOD (no approval, faster):**

```bash
fd -e py . | rg "import logger" --files-with-matches
```

**Why:**

- Single atomic command
- No approval needed
- 10-100x faster
- Modern tool handles iteration internally

### More Examples

**Processing JSON:**

❌ **BAD:**

```bash
cat data.json | grep "name" | sed 's/.*://' | tr -d '",'
```

✅ **GOOD:**

```bash
jq -r '.[] | .name' data.json
```

**Batch file operations:**

❌ **BAD:**

```bash
for f in *.txt; do
  mv "$f" "backup/$f"
done
```

✅ **GOOD:**

```bash
fd -e txt -x mv {} backup/{}
```

Or use parallel:

```bash
fd -e txt | parallel mv {} backup/{}
```

### Installation Suggestions

If tool is missing, suggest (don't auto-install):

```text
Tool not found: fd
Install:
  Ubuntu/Debian: sudo apt install fd-find
  macOS: brew install fd
  Fedora: sudo dnf install fd-find
```

**Never auto-install** - always ask user first

## Critical: Atomic Command Pattern

**NEVER use compound commands - they trigger user approval prompts.**

### What Triggers Approval (AVOID)

These patterns require user approval in settings.json:

- `command1 && command2` - AND chains
- `command1 || command2` - OR operators
- `command1 ; command2` - Semicolon sequences

### The Solution: Atomic Commands

One Bash call = One operation

❌ **BAD (requires 3 approvals):**

```bash
git add . && git commit -m "message" && git push
```

✅ **GOOD (no approvals):**

```bash
# Call 1:
git add .

# Call 2:
git commit -m "message"

# Call 3:
git push origin main
```

### Directory Navigation: NEVER use cd

**Problem:** Each Bash call is a separate subprocess with NO persistent state.

❌ **BAD (doesn't work + requires approval):**

```bash
cd /projects/hyperlib/ci && git status
```

**Problems:**

1. cd doesn't persist to next Bash call
2. && triggers approval prompt

✅ **GOOD (works + no approval):**

```bash
# Call 1: Establish context
pwd

# Call 2: Use absolute path
git -C /projects/hyperlib/ci status
```

### The Three Golden Rules

1. **pwd first** - Start every multi-step task with `pwd` (establishes context, prevents getting lost)

2. **Absolute paths** - Use `git -C /absolute/path`
   - NOT: `cd path && git` (approval required)
   - YES: `git -C /absolute/path` (allowed)

3. **Atomic commands** - One operation per call
   - NOT: `cmd1 && cmd2` (approval required)
   - YES: Multiple calls (allowed)

### Example: Submodule Workflow

```bash
# Start with pwd (establish context)
pwd  # /projects/hyperlib

# Work in ci/ submodule (atomic + absolute)
git -C /projects/hyperlib/ci add file.py
git -C /projects/hyperlib/ci commit -m "fix: update"
git -C /projects/hyperlib/ci push origin main

# Update parent (atomic + absolute)
git -C /projects/hyperlib add ci
git -C /projects/hyperlib commit -m "chore: update ci"
git -C /projects/hyperlib push origin main
```

**Result:** Zero approval prompts, never get lost

### File Operations: Prefer Tools

❌ **BAD (requires approval):**

```bash
echo "content" > file.txt && cat file.txt
```

✅ **GOOD (no approval):**

```bash
# Use your AI assistant's file write capability
write_file("/projects/hyperlib/file.txt", "content")

# Use your AI assistant's file read capability
read_file("/projects/hyperlib/file.txt")
```

**Why:** Explicit, tracked by IDE/editor, no approval needed

### Temporary Files

Use `.tmp/` with atomic operations:

```bash
# Write (allowed)
echo "data" > .tmp/temp.txt

# Process (separate call, allowed)
python process.py .tmp/temp.txt

# Note: rm requires approval, use carefully
```

### File References in Communication

When referencing files in text (not commands):
- Use paths relative to project root: `src/hyperlib/app.py`
- Makes context clear for both humans and AI
- Consistent with how users think about project structure

---

**End of HS-CI-specific guidance.**
