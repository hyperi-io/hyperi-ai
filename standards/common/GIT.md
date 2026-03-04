# Git Standards

Branch naming and commit message conventions for all HyperI projects.

---

## Default Branch

**Always use `main` as the default branch.** Never use `master`.

- All new repositories MUST use `main`
- Existing repos using `master` should be migrated
- CI/CD, semantic-release, and branch protection rules assume `main`

---

## Branch Naming

**Formats:** (choose based on your workflow)

```text
<type>/<issue-ref>/<short-description>    # With issue tracking
<type>/<short-description>                 # Without issue tracking
```

**Types:** (lowercase, matches commit types)

feat, fix, docs, test, chore, ci, cleanup, data, debt, design, infra, meta,
ops, perf, refactor, review, sec, spike, ui, hotfix

**Issue Reference (optional):**

- Include ticket ID when using issue tracking (e.g., `PROJ-123`, `AI-456`)
- Omit when no ticket exists or for quick fixes

**Examples:**

```bash
# With issue reference (preferred when tracking issues)
feat/AI-123/add-cursor-support
fix/PROJ-456/null-pointer-exception
chore/AI-789/update-deps

# Without issue reference (acceptable for quick fixes)
fix/memory-leak
docs/update-readme
refactor/extract-validation
test/add-payment-tests
```

**Guidelines:**

- Use issue reference when working with issue trackers (Jira, GitHub Issues, etc.)
- Omit issue reference for quick fixes, documentation updates, or solo work
- Keep descriptions short and descriptive (2-4 words)
- Use hyphens to separate words in description

---

## Commit Messages

**Format:** Conventional Commits (<https://www.conventionalcommits.org/>)

```text
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

---

## AI Assistant Guidance

### Commit Actions

- **ALWAYS** show the proposed commit message and request approval before
  committing (mature projects). User can override if annoying. Fast/spike
  projects don't need this.
- **ALWAYS** use human-like Australian low-key short concise messages.
  Prefer one line, 3 lines max for huge commits. Humans NEVER produce huge
  multi-line commits.
- **ALWAYS** err on the side of conservatism for type selection.
  AI assistants exaggerate importance. If you think it's a `feat:`, it's
  probably a `fix:`.
- **NEVER** use emojis in commit messages. EVER.

**Approval flow:** Offer three options:

1. **Yes** - commit as proposed
2. **No** - cancel the commit
3. **Change** - provide guidance to revise the message, then re-approve

### Local Build Before Push (ci submodule)

**Philosophy:** The local build IS the CI pipeline. By the time you push,
everything must already be green locally. CI is a formality — a second pair
of eyes on a known-good build. Nothing should fail on CI that has not
already passed locally.

If the `ci` submodule is attached, run the full local build as the **mandatory
final step** before seeking push approval:

```bash
# Check if ci is attached
ls ci/.git 2>/dev/null || echo "ci not attached — skip local build"

# If attached, run before every push
./ci/local-build.sh
```

This executes the identical quality → tests → build pipeline that CI runs,
using the same tooling and environment.

**Options:**

```bash
./ci/local-build.sh                # Full (quality + tests + build) — use this
./ci/local-build.sh --skip-build   # Quality + tests only (faster, no artefacts)
```

Default to the full build. Use `--skip-build` only when the user explicitly
wants a fast feedback loop and is not shipping artefacts.

**Push order:**

1. `./ci/local-build.sh` — must pass
2. `git pull --rebase`
3. Seek user approval (commit list + projected version bump)
4. `git push`

If the local build fails, fix the issues before pushing. Do NOT bypass
with `git push --no-verify` unless the user explicitly instructs it.

### Pushing Commits

- **ALWAYS** run `git pull --rebase` before pushing. Semantic-release CI
  creates version commits that your local won't have.
- **ALWAYS** seek approval before ANY push. Show: (1) commit list,
  (2) projected version bump (e.g., 1.8.2 → 1.8.3)
- **NEVER** push without explicit approval
