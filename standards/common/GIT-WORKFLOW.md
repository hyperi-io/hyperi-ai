# Git Workflow Standards (HS-CI)

**Auto-copied to `docs/standards/` by CI_CLAUDE_MERGE**

## Branch Naming Convention

**Format:** `<type>/<issue-ref>/<short-description>`

**Types:** _(lower-case, matches commit prefixes)_
- `feat` - New feature or capability
- `fix` - Bug fix, defect, or regression
- `chore` - Maintenance (dependencies, config, infra)
- `ci` - CI/CD configuration or workflows
- `cleanup` - Remove deprecated code/assets
- `data` - Data-model, ETL, schema, sample/synthetic data, analytics
- `debt` - Technical debt or legacy maintenance
- `design` - Architecture or UX design deliverable
- `docs` - Documentation (use plural per Conventional Commits)
- `infra` - Infrastructure or environment changes
- `meta` - Process/workflow improvements (not repo-specific)
- `migrated` - Ported from another repo/service
- `ops` - Infrastructure/platform/operational maintenance
- `perf` - Performance optimization
- `refactor` - Code restructure without functional change
- `release` - Release Minor or Major version (x.X.x or X.x.x)
- `review` - Internal review, audit, or validation
- `sec` - Security fixes, hardening, or audits
- `spike` - Research or proof-of-concept work
- `test` - Test coverage, automation, or QA
- `ui` - Frontend, layout, or visual work
- `hotfix` - Critical production fix requiring immediate release

**Issue Reference:**
- Ticket ID (e.g., `PROJ-123`)
- `no-ref` if no ticket

**Examples:**
```
feat/PROJ-123/add-oauth
fix/no-ref/memory-leak
chore/PROJ-456/update-deps
docs/no-ref/api-guide
```

## Commit Message Convention

**Format:** Conventional Commits (https://www.conventionalcommits.org/)

```
<type>: <description>

[optional body]

[optional footer]
```

### Semantic Versioning Types (Trigger Version Bumps)

**Trigger automatic version bumps via semantic-release:**

- `feat:` - New feature **(MINOR: 1.0.0 → 1.1.0)**
- `fix:` - Bug fix **(PATCH: 1.0.0 → 1.0.1)**
- `perf:` - Performance optimization **(PATCH)**
- `hotfix:` - Critical production fix **(PATCH; may be escalated)**
- `release:` - Release Minor/Major version **(MINOR/MAJOR per semantic-release rules)**
- `BREAKING CHANGE:` - Footer to force **MAJOR bump**

### Non-Versioning Types (Context Only)

**Improve readability but do NOT trigger version bumps:**

- `chore:` – Maintenance (dependencies, config, infra)
- `ci:` – CI/CD configuration or workflows
- `cleanup:` – Remove deprecated code/assets
- `data:` – Data-model, ETL, schema, sample/synthetic data, analytics
- `debt:` – Technical debt or legacy maintenance
- `design:` – Architecture or UX design deliverable
- `docs:` – Documentation (plural per Conventional Commits)
- `infra:` – Infrastructure or environment changes
- `meta:` – Process/workflow improvements (not repo-specific)
- `migrated:` – Ported from another repo/service/JIRA
- `ops:` – Infrastructure/platform/operational maintenance
- `refactor:` – Code restructure without functional change
- `review:` – Internal review, audit, or validation
- `sec:` – Security fixes, hardening, or audits
- `spike:` – Research or proof-of-concept work
- `test:` – Test coverage, automation, or QA
- `ui:` – Frontend, layout, or visual work
- `task:` / `sub-task:` – Use sparingly when commit mirrors tracker items

> ⚠️ Avoid uppercase `TASK:` or `SUB-TASK:`. Use lower-case `task:` / `sub-task:` only when required by tooling.

### Warnings for Untagged Commits

Commits without a recognized prefix receive a **warning** (not fail) for consistency.

**Examples:**
```
feat: add user authentication module

Implements OAuth2 authentication with JWT tokens.

Closes #123
```

```
fix: prevent VERSION file corruption

Implement dual pre-sync strategy with pre-commit hook
and CI script to ensure VERSION is always correct.
```

```
BREAKING CHANGE: remove deprecated API endpoints

The /v1/old-endpoint has been removed. Use /v2/endpoint instead.
```

## Git Workflow

**1. Create feature branch:**
```bash
git checkout -b feat/PROJ-123/my-feature
```

**2. Make changes and commit:**
```bash
git add .
git commit -m "feat: implement my feature"  # Pre-commit hooks auto-run
```

**3. Push to remote:**
```bash
git push -u origin feat/PROJ-123/my-feature
```

**4. Create pull request:**
```bash
gh pr create --title "feat: implement my feature" --body "Description..."
```

**5. After PR merge, create release (on main):**
```bash
git checkout main && git pull
./ci/run release   # Creates tag, updates CHANGELOG, pushes, triggers CI
```

## Pre-commit Hooks

**HS-CI pre-commit hooks:**

1. **VERSION pre-sync** - Auto-syncs VERSION file on main/master (prevents template corruption)

**Skip hooks (not recommended):** `git commit --no-verify`

## Submodule Management

**ci/ is a READ-ONLY git submodule** - never commit directly to it.

**To update ci/ submodule:**
```bash
cd ci
git pull origin main  # Or: git checkout v1.2.0
cd ..
git add ci
git commit -m "chore: update ci/ submodule to latest"
```

**To contribute to HS-CI:**
```bash
cd ci
git checkout -b fix/my-improvement
# Make changes
git add .
git commit -m "fix: my improvement"
git push origin fix/my-improvement
# Create PR to hypersec-io/hs-ci
```

## Semantic Versioning

**Versions:** `MAJOR.MINOR.PATCH`

**Bumps:**
- `feat:` → MINOR (1.0.0 → 1.1.0)
- `fix:` → PATCH (1.0.0 → 1.0.1)
- `BREAKING CHANGE:` → MAJOR (1.0.0 → 2.0.0)
- Others (`chore:`, `docs:`) → No bump

**Managed by:** `python-semantic-release` (config in `pyproject.toml` [tool.semantic_release])

**See also:** conventionalcommits.org, semver.org, python-semantic-release.readthedocs.io

---

## Human-Style Git Commits (Not LLM Style)

**Write commits like humans, not AI assistants.**

### LLM Commit Anti-Patterns

**LLM commits:**
- ❌ Too verbose/marketing-style
- ❌ Unnecessarily enthusiastic
- ❌ Include AI attribution
- ❌ Over-explain obvious changes
- ❌ Unnatural phrasing
- ❌ Emoji without convention

**Examples of LLM-style commits to AVOID:**

```
❌ feat: ✨ Add amazing new discount calculation feature with comprehensive validation

This commit introduces a brand new discount calculation system that enables
users to calculate discounts with advanced validation logic. The implementation
includes robust error handling, comprehensive input validation, and extensive
test coverage to ensure reliability and maintainability.

Key improvements:
- Added discount calculation function
- Implemented validation for discount percentages
- Added comprehensive error messages
- Included extensive test coverage
- Enhanced code documentation

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Why bad:** Marketing language, states obvious, redundant lists, emoji without convention, AI attribution

### Human-Style Commits

**Human commits:**
- ✅ Concise, factual
- ✅ Imperative mood ("Add" not "Added")
- ✅ WHAT and WHY, not HOW
- ✅ No emoji (unless convention)
- ✅ No AI attribution

**Good human-style commit:**

```
✅ feat: add discount validation

Validate discount percent is 0-100 to prevent negative prices.

Fixes #123
```

**Why good:** Concise subject, explains WHY (business logic), references issue, no marketing/AI attribution

### Commit Message Guidelines

#### Subject Line

**Format:** `<type>: <what changed>`

**Keep it short:**
- ✅ 50 characters or less
- ✅ Lowercase after colon
- ✅ No period at end
- ✅ Imperative mood

**Examples:**

```
✅ fix: prevent null pointer in user lookup
✅ feat: add OAuth login
✅ docs: update API examples
✅ test: add discount edge cases
✅ refactor: extract validation to helper

❌ fix: Fixed a bug where the user lookup function was returning null pointers
❌ feat: Added OAuth login feature to the authentication system
❌ docs: Updated the API documentation with more examples.
❌ Refactored validation logic
```

#### Body (Optional)

**When to include:** Change not obvious, needs context/rationale, multiple changes (avoid)

**Guidelines:**
- ✅ Explain WHY, not WHAT (code shows what)
- ✅ Wrap at 72 characters
- ✅ Blank line after subject
- ✅ Bullet points for multiple items
- ✅ Reference issues/docs

**Good body examples:**

```
feat: add request rate limiting

Prevent API abuse by limiting requests to 100/hour per IP.
Uses Redis for distributed rate limit tracking.

Refs: #456
```

```
fix: handle empty cart total calculation

Division by zero occurred when cart was empty.
Now returns 0.0 for empty carts instead of crashing.

Fixes #789
```

**Bad body examples:**

```
❌ This commit implements a new feature that allows users to calculate
   discounts... (Too verbose - code shows this)

❌ Changed line 42 to add validation. Modified line 56...
   (Too implementation-focused - diff shows this)
```

#### Footer (Optional)

**Common footers:**

```
Fixes #123                          # Closes issue
Closes #123, #456                   # Multiple issues
Refs #789                           # Related issue
See-Also: https://example.com/doc   # External reference

BREAKING CHANGE: removed /v1/api endpoint
Use /v2/api instead.
```

**Guidelines:** Blank line before footer, one trailer per line, standard trailers only, NEVER Co-Authored-By (removed by hook)

### Commit Frequency

**Commit frequently (every 15-30 min):**

```
✅ git commit -m "feat: add discount function"
✅ git commit -m "feat: add discount validation"
✅ git commit -m "test: add discount edge cases"

❌ git commit -m "feat: complete entire discount feature with validation, tests, docs, and refactoring"
```

**Benefits:** Easy revert, clear progression, better reviews, natural checkpoints

**Rule:** Can't describe in <50 chars? Commit too big.

### Imperative Mood

**Use command form:**

```
✅ Add discount validation
✅ Fix null pointer bug
✅ Remove deprecated API

❌ Added discount validation     (past tense)
❌ Adds discount validation      (present tense)
❌ Adding discount validation    (gerund)
```

**Why:** Matches git's messages ("Merge branch", "Revert commit")

**Test:** Subject completes "This commit will ___"

### Scope (Optional)

```
feat(auth): add OAuth login
fix(api): handle timeout errors
docs(readme): update install steps
```

**Use when:** Large projects with modules, helps filter log, team convention

**Skip when:** Small projects (<10 files), obvious from path, no convention

### Real-World Examples

**Good human commits from actual projects:**

```
fix: prevent race condition in order processing

Fixes #234

---

feat: add bulk discount for orders > $1000

10% additional discount for bulk orders.
Business requirement from sales team.

Refs: SALES-456

---

perf: cache user permissions

Reduces DB queries by 80% for permission checks.
Cache expires after 5 minutes.

---

docs: clarify tax calculation examples

Previous examples were confusing - now shows step-by-step.

---

test: add timezone edge cases

Found bug in prod where UTC offset caused incorrect dates.
```

### AI Attribution and Co-Authoring

**NEVER include AI attribution or co-authoring:**

```
❌ Co-Authored-By: Claude <noreply@anthropic.com>
❌ Co-Authored-By: GitHub Copilot <noreply@github.com>
❌ Co-Authored-By: Name <email>
❌ Generated with Claude Code
❌ 🤖 AI-generated
```

**Why no AI attribution:**
- Git history tracks human authorship
- AI tools are aids, not co-authors
- Creates noise in attribution graphs
- Marketing behavior (zero developer value)
- Violates "Human-first design" principle

**Why no co-authoring:**
- Git `Author:` header already tracks authorship
- Pair programming doesn't need footers
- Credit in commit body/PR if needed
- Keeps history clean

**Allowed (body mentions):**
```
✅ "Used Claude to debug race condition"
✅ "Pair programmed with Alice on auth flow"
```

**Pre-commit hook:** Auto-removes `Co-Authored-By:`, `Generated with`, `🤖` markers, Claude Code links

**For AI assistants:** NEVER add `Co-Authored-By:` or `Generated with` markers

### Emoji Usage

**Default: NO emoji**

```
✅ feat: add OAuth login
❌ feat: ✨ add OAuth login
```

**Use only if:** Team convention, gitmoji.dev project, .gitmoji file exists

**If using gitmoji, be consistent:**
```
✨ feat: add OAuth login
🐛 fix: prevent null pointer
📝 docs: update README
```

### Breaking Changes

**Format for breaking changes:**

```
feat: remove deprecated v1 API

BREAKING CHANGE: /v1/users endpoint removed
Use /v2/users instead. Migration guide: docs/v2-migration.md

Closes #123
```

**Or in footer only:**

```
feat: update user model

BREAKING CHANGE: User.name split into first_name and last_name
```

**Triggers MAJOR version bump (1.x.x → 2.0.0).**

### Multiple Changes (Avoid)

**Split unrelated changes:**

```
❌ feat: add OAuth login and fix payment bug and update docs

✅ feat: add OAuth login
✅ fix: prevent payment timeout
✅ docs: update OAuth setup guide
```

**Exception - related changes:**
```
✅ refactor: extract validation to separate module

Moved validation from models.py to validators.py.
Updated imports in 5 files.
```

### Commit Message Checklist

**Before committing, verify:**

- [ ] Subject line < 50 characters
- [ ] Subject uses imperative mood ("Add" not "Added")
- [ ] Subject is lowercase after `type:`
- [ ] No period at end of subject
- [ ] Body explains WHY (if needed)
- [ ] Body wrapped at 72 characters
- [ ] References issue if applicable (Fixes #123)
- [ ] No marketing language ("amazing", "robust")
- [ ] No emoji (unless team convention)
- [ ] No AI attribution or Co-Authored-By footers
- [ ] Single logical change per commit

### Learning From Your Repo

**Learn team style from git log:**

```bash
git log --oneline -20                        # Recent commits
git log --author="Alice" --oneline -10       # Author commits
git log --oneline path/to/file.py            # File commits
```

**Match patterns:** Emoji? Scopes? Body verbosity? Ticket format?

### Common Mistakes

**Subject too long:**
```
❌ feat: add comprehensive user authentication system with OAuth2, JWT tokens, and RBAC
✅ feat: add OAuth authentication
```

**Wrong tense:**
```
❌ fix: fixed null pointer bug
✅ fix: prevent null pointer
```

**Too vague:**
```
❌ fix: update code
✅ fix: prevent division by zero in calculate_average
```

**Over-explaining:**
```
❌ fix: update the calculate_total function to handle the edge case...
✅ fix: return 0 for empty cart
```

**Implementation details:**
```
❌ fix: change line 42 from if/else to match/case
✅ fix: simplify status validation logic
```

### Examples Side-by-Side

**LLM style → Human style:**

```
❌ feat: ✨ Implement comprehensive discount calculation feature

This commit introduces an amazing new discount calculation system that
enables users to apply percentage-based discounts with robust validation.
The implementation includes comprehensive error handling and extensive
test coverage.

Features:
- Calculates discounted prices
- Validates percentage ranges
- Provides clear error messages
- Includes full test suite

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>

---

✅ feat: add discount calculation

Validate percent is 0-100 to prevent negative prices.

Fixes #123
```

**Saved:** 9 lines, 200+ unnecessary words (including AI attribution).

---

**See also:**
- https://www.conventionalcommits.org/
- https://chris.beams.io/posts/git-commit/
- https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
