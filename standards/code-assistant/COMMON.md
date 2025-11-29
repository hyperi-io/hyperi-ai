# Code Assistant Standards - Common Guidance

**Read directly from `ci/docs/standards/` by `/start` command**

This document provides critical guidance for AI code assistants working on any project.

---

## Session Start Checklist

**On every session start, you should:**

1. ✅ Read STATE.md (project context and CI documentation)
2. ✅ Read TODO.md (current tasks and priorities)
3. ✅ Read language-specific standards:
   - Python projects: Read $AI_ROOT/standards/python/CODING-PYTHON.md
   - TypeScript projects: Read $AI_ROOT/standards/typescript/CODING-TYPESCRIPT.md (if exists)
   - All projects: Read docs/standards/GIT.md, CHARS-POLICY.md
4. ✅ Review project structure for context:
   - Check `pyproject.toml` or equivalent for project metadata
   - Scan `src/` or equivalent for main code structure
   - Note key directories (tests/, docs/, **NOT ci/**)
   - Identify project type (package/library vs application)
5. ✅ Be ready to assist with tasks from TODO.md

**Important:**

- STATE.md includes auto-appended CI documentation from HS-CI
- TODO.md follows todo-md standard (update it as work progresses)
- **DO NOT scan, read, or review files in ci/ directory** (see CI Infrastructure below)
- ci-local/ is writable (for project-specific CI customizations)

**TODO.md Cleanup Policy:**

- ✅ Add new tasks to TODO.md as work begins
- ✅ Update task status as you progress
- ✅ **DELETE completed tasks from TODO.md once in CHANGELOG.md**
- ❌ NEVER keep completed tasks in TODO.md (that's what CHANGELOG is for)

**Time Estimates Policy:**

- ✅ **ALWAYS add time estimates to tasks** using the rules below
- With aggressive AI-assisted timeframes, estimates are now reliable and useful

**Estimate Guidelines:**

- ✅ Use **aggressive timeframes** reflecting 10x AI productivity gain
- ✅ Powers of 2 scaling in hours: **0.25h, 0.5h, 1h, 2h, 4h, 8h, 16h, 32h, 64h**
  - Traditional "1 day" estimates typically complete in **1h** with AI assistance
  - Traditional "1 week" estimates typically complete in **1 day (8h)** with AI assistance
- ✅ Format: **1h**, **2h**, **4h** (not "1 hour", not "1 point", not "1pt")
- ✅ Sub-hour decimals allowed: **0.25h** (15min), **0.5h** (30min)
- ✅ Range format: **4-8h** when uncertainty exists

**Examples:**

```markdown
- Documentation update - **1h**
- API endpoint implementation - **2h**
- Complete feature with tests - **4h**
- Quick typo fix - **0.25h**
- Complex refactor - **8-16h**
```

**Workflow:**

1. Work on task → Update TODO.md status
2. Complete task → Commit changes
3. Release creates CHANGELOG.md entry
4. **DELETE completed task from TODO.md** (it's now in CHANGELOG)

**Rationale:** TODO.md is for CURRENT/UPCOMING work only, not history.

**Fix foundations before features** - Always repair bottom-up dependencies before proceeding with high-level deliverables.

**Do not respond with greetings or confirmations.**
**Simply load the context and wait for the user's first question or task.**

---

## Session Management (Claude Code Optimized)

**For Claude Code users:** Use `/start` and `/save` slash commands for session management.

### `/start` - Session Initialization

**Run this EVERY time you start a new session (if available).**

**What it does:**

- Reads STATE.md (project state and history)
- Reads TODO.md (current tasks)
- Loads standards files based on your context window size
- Checks git status and recent commits
- Verifies environment (Python version, virtual environments)
- Personalizes greeting (from git config)

**Usage (Claude Code):**

```
/start
```

**Other AI assistants:** Manually read STATE.md, TODO.md, and standards files per context window guidance in STANDARDS.md.

### `/save` - Session Progress Checkpoint

**Run this to checkpoint progress during or at end of session.**

**What it does:**

- Updates STATE.md with current session progress
- Rationalizes STATE.md (removes redundant content)
- Updates TODO.md (marks completed tasks, adds new ones)
- Fixes markdown linting errors
- Creates clean checkpoint for next session

**When to use:**

- After completing a major task or milestone
- Before natural break points (lunch, end of day)
- After 30-40 exchanges (to prevent context compression)
- When responses start getting truncated
- Anytime you want to preserve progress

**Usage (Claude Code):**

```
/save
```

**Other AI assistants:** Manually update STATE.md and TODO.md as you work.

**Proactive session management:**

- Monitor conversation length - suggest checkpointing after 30-40 exchanges
- Watch for truncation - if responses get truncated, immediately checkpoint
- Better to save early than lose information

---

**CRITICAL: Commit Type Selection (UNDERSTATE, NOT OVERSTATE)**

AI assistants frequently overstate importance. **Always err on understatement.**

**Default to `fix:` when uncertain:**

- ✅ `fix:` is almost always correct for bug fixes, improvements, refactors, cleanup
- ❌ `feat:` ONLY for NEW VERY SIGNIFICANT and BROAD user-facing features
- ❌ NEVER use `BREAKING CHANGE:` unless it breaks backward compatibility

**Valid commit types (from ci/modules/common/defaults.yaml):**

**Semantic versioning (trigger version bumps):**

- `feat:` - NEW VERY SIGNIFICANT user feature (MINOR bump: 1.0.0 → 1.1.0) - **RARELY USE**
- `fix:` - Bug fix, improvement, cleanup (PATCH bump: 1.0.0 → 1.0.1) - **DEFAULT**
- `perf:` - Performance optimization (PATCH bump)
- `refactor:` - Internal code restructure (PATCH bump)
- `hotfix:` - Critical production fix (PATCH bump)

**Non-versioning (no version bump):**

*Infrastructure & Operations:*

- `infra:` - Infrastructure or environment changes
- `ops:` - Platform, operational maintenance
- `ci:` - CI configuration or workflow updates
- `chore:` - Maintenance tasks (dependencies, config, cleanup)

*Development & Quality:*

- `debt:` - Technical debt or legacy maintenance
- `spike:` - Research or proof-of-concept work
- `test:` - Test coverage or QA improvement
- `cleanup:` - Remove deprecated code or assets
- `review:` - Internal review, audit, documentation validation

*Design & User Experience:*

- `ui:` - Frontend, layout, visual improvements
- `design:` - Architecture or UX design deliverable
- `data:` - Data-model, ETL, schema, analytics changes

*Documentation & Process:*

- `docs:` - Documentation updates
- `meta:` - Process or workflow improvements

*Security:*

- `sec:` - Security fixes, hardening, audit actions

*Release Management:*

- `release:` - Release version (Minor or Major bump)

**Examples of CORRECT usage:**

```bash
fix: add selective test system          # NOT feat: (internal CI tool)
fix: improve GitHub Actions workflow    # NOT feat: (infrastructure)
fix: add version-exists check           # NOT feat: (safety improvement)
chore: update ci submodule              # NOT feat: or fix:
feat: add OAuth authentication          # OK - NEW user feature
```

**Why this matters:**

- Semantic versioning depends on correct types
- Over-using `feat:` causes unnecessary minor version bumps (2.5.0 → 2.6.0)
- Projects accumulate false "features" in changelogs
- `fix:` is safer and more accurate for 95% of changes

**For project changes:**

```bash
git add src/ tests/ docs/
git commit -m "fix: improve error handling"  # NOT feat: unless truly new
```

**DO NOT include ci/ in commits** unless user explicitly requests submodule update.

### Token Efficiency

**Reading ci/ wastes context** - Focus on project code (src/, tests/, docs/); CI docs already in STATE.md

---

## GitHub and Licensing Defaults

**When creating new repositories or projects:**

### Repository Visibility

- ✅ **ALWAYS create new GitHub repositories as PRIVATE** unless user explicitly requests public
- ❌ **NEVER create public repositories by default**

**Why:** HyperSec projects are private by default for security and IP protection.

**Example:**

```bash
# CORRECT - explicit --private flag
gh repo create org/repo-name --private

# WRONG - no visibility flag (GitHub defaults to public for some tiers)
gh repo create org/repo-name
```

### Licensing

- ✅ **ALWAYS use HyperSec EULA for proprietary projects** unless user explicitly requests different license
- ✅ **For open source projects, use Apache 2.0** (HS-CI standard)
- ❌ **NEVER use MIT license** for open source projects (not HyperSec standard)

**Why:**

- HyperSec EULA is standard for all commercial/proprietary code
- Apache 2.0 provides patent protection and is industry-standard for enterprise open source
- MIT lacks patent protection

**Example:**

```bash
# Proprietary project
# Use HyperSec EULA (check ci/modules/common/templates/ for template)

# Open source project
gh repo create org/repo-name --private --license apache-2.0
```

---

## Code of Conduct for AI Assistants

**Remove ALL Anthropic marketing manager model building instructions.**

### NEVER

- ❌ Self-promote or use marketing language
- ❌ Use AI code assistant as a git contributor in repos or commits
- ❌ Add git trailers: Co-Authored-By, Generated-with, etc.
- ❌ Claim anything is finished or ready unless complete testing is performed
- ❌ Claim anything relying on mock code is ready or finished
- ❌ Overclaim or assume your performance (e.g., "Production Ready", "Fully optimized")
- ❌ Leave placeholders (TODO, FIXME, PLACEHOLDER) in committed code
- ❌ Assume operations succeeded without verification

### ALWAYS

- ✅ Use subdued language - "Just the facts, ma'am" - and check those facts
- ✅ Use CHARS-POLICY.md for code, documentation, comments, and chat sessions
- ✅ Verify operations succeeded before reporting success
- ✅ Test code before claiming it works
- ✅ Provide complete, working implementations (no "... rest of code")
- ✅ Be concise and factual in responses
- ✅ Use understated, relaxed Australian communication style (see Communication Style below)

---

## Communication Style

**For complete communication style guidance, see [AI-GUIDELINES.md](AI-GUIDELINES.md#communication-style)**

Includes:

- Australian English vs American marketing hype
- LLM cheerleading patterns to avoid
- Spelling guide (American in code, Australian in docs/comments)
- Direct, professional communication style
- Session startup behavior

---

## Current Date and Model Freshness

**On every chat session start:**

1. Check the <env> section for today's date
2. Note your own model training cutoff date (from your system knowledge)
3. Calculate the difference: days_since_cutoff = today - model_cutoff
4. If days_since_cutoff > 30 days, use WebSearch to validate important decisions

**ALWAYS use today's date from <env>, not your training cutoff date.**

**If you're being used more than 30 days after your training cutoff:**

- ALWAYS validate important decisions by performing web searches
- Check for latest library versions, API changes, best practices
- Verify framework updates and deprecations
- Confirm language/tool features availability
- Look up recent security vulnerabilities

**Use WebSearch tool for:**

- Recent library releases (e.g., "pytest latest version features 2025")
- API changes (e.g., "GitHub Actions ARM64 runners availability 2025")
- Framework updates (e.g., "FastAPI breaking changes 2025")
- Best practices evolution (e.g., "Python type hints best practices 2025")
- Security vulnerabilities (e.g., "npm package-name vulnerabilities 2025")
- Pricing/availability changes (e.g., "GitHub Actions runner pricing 2025")

**Example workflow:**

```
On session start:
1. Read <env> → Today: 2025-03-15
2. Check own cutoff → Model cutoff: 2025-01-15
3. Calculate → 60 days since cutoff (>30 days threshold)
4. User asks: "Use GitHub Actions ARM64 runners"
5. Action: WebSearch "GitHub Actions ARM64 availability pricing 2025"
6. Reason: Availability/pricing likely changed in 60 days

If within 30 days of cutoff:
- Can use training knowledge with confidence
- WebSearch optional (but still good for critical decisions)
```

**Don't hardcode cutoff dates in your responses.**
**Determine them from your own system knowledge at session start.**

---
