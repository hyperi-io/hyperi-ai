# Git Standards

Branch naming and commit message conventions for all HyperSec projects.

---

## Branch Naming

**Format:** `<type>/<issue-ref>/<short-description>`

**Types:** (lowercase, matches commit types)

feat, fix, docs, test, chore, ci, cleanup, data, debt, design, infra, meta, ops, perf, refactor, review, sec, spike, ui, hotfix

**Issue Reference:**
- Ticket ID (e.g., `PROJ-123`, `AI-456`)
- `no-ref` if no ticket

**Examples:**

```bash
feat/AI-123/add-cursor-support
fix/no-ref/memory-leak
docs/no-ref/update-readme
chore/PROJ-456/update-deps
```

---

## Commit Messages

**Format:** Conventional Commits (https://www.conventionalcommits.org/)

```
<type>: <description>

[optional body]

[optional footer]
```

### Commit Types

**Trigger version bumps:**
- `feat:` - New feature (MINOR: 1.0.0 → 1.1.0)
- `fix:` - Bug fix (PATCH: 1.0.0 → 1.0.1)
- `perf:` - Performance (PATCH)
- `sec:` - Security (PATCH)
- `hotfix:` - Critical fix (PATCH)

**No version bump:**
- `docs:` - Documentation only
- `test:` - Tests only
- `chore:` - Maintenance, dependencies
- `ci:` - CI/CD configuration
- `refactor:` - Code restructure (no functional change)
- All other types listed above

**Breaking changes:**
- Add `BREAKING CHANGE:` footer to trigger MAJOR bump (1.0.0 → 2.0.0)

### Examples

```bash
# Good commits
feat: add support for cursor IDE
fix: handle missing template file
docs: update installation guide
test: add edge case tests
chore: update dependencies

# With body
fix: prevent null pointer in user lookup

Division by zero occurred when user list was empty.
Now returns empty array instead of crashing.

Fixes #123

# Breaking change
feat: change template directory structure

BREAKING CHANGE: Templates moved from templates/ to config/templates/
Users must re-run install.sh after updating.
```

### Commit Message Rules

**Subject line:**
- 50 characters or less
- Lowercase after type:
- No period at end
- Imperative mood ("add" not "added")

**Body:**
- Explain WHY, not WHAT
- Wrap at 72 characters
- Blank line after subject

**Footer:**
- `Fixes #123` - Closes issue
- `Refs #456` - References issue
- `BREAKING CHANGE:` - Major version bump

### AI Attribution

Git hooks automatically remove AI attribution:
- `Co-Authored-By: Claude <noreply@anthropic.com>`
- `Generated with Claude Code`
- Similar patterns from other AI tools

No need to manually remove - hooks handle this automatically.

