---
name: git-standards
description: Branch naming, commit message conventions, and git workflow for all HyperI projects. Conventional Commits, semantic-release compatible.
rule_paths:
  - "**/.github/**"
  - "**/.gitignore"
  - "**/CHANGELOG.md"
paths:
  - "**/.github/**"
  - "**/.gitignore"
  - "**/CHANGELOG.md"
---

# Git Standards

Branch naming and commit message conventions for all HyperI projects.

---

## Default Branch

**Always use `main` as the default branch.** Never use `master`.

- All new repositories MUST use `main`
- Existing repos using `master` should be migrated
- CI/CD, semantic-release, and branch protection rules assume `main`

---

## Branch Flow

**Protected branches:** `main` and `release` are protected. Never commit
directly to `release`.

**Required flow:**

```
feature-branch → merge → main → PR → release
```

Or for simple changes:

```
main → PR → release
```

**Rules:**

- All feature work happens on topic branches off `main`
- Merge topic branches into `main` (via PR or direct merge)
- `release` is updated ONLY via PR from `main` — never direct commits
- Semantic-release runs on `release` (or `main` depending on project config)
- Hotfixes: branch from `main`, merge to `main`, PR to `release`

**NEVER:**

- Commit directly to `release` — always PR from `main`
- Push to `release` without a PR
- Rebase or force-push `release`
- Skip the `main → release` PR step for "quick fixes"

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

Aligned with `.releaserc.json` — this is the authoritative list. Semantic-release
reads these to determine version bumps.

**Trigger version bumps (semantic versioning):**

| Type | Use | Bump |
|------|-----|------|
| `feat:` | New significant user-facing feature (**RARELY** — AI assistants exaggerate importance) | MINOR |
| `fix:` | Bug fix, improvement, cleanup (**DEFAULT** — use this most of the time) | PATCH |
| `perf:` | Performance optimisation | PATCH |
| `refactor:` | Code restructure (no functional change) | PATCH |
| `hotfix:` | Critical production fix | PATCH |
| `sec:` | Security fix, hardening, audit action | PATCH |

**No version bump (no release triggered):**

| Type | Category | Use |
|------|----------|-----|
| `docs:` | Documentation | Documentation updates |
| `test:` | Quality | Test coverage or QA improvement |
| `chore:` | Maintenance | Dependencies, config, cleanup |
| `ci:` | Infrastructure | CI/CD configuration or workflow |
| `infra:` | Infrastructure | Infrastructure or environment changes |
| `ops:` | Infrastructure | Platform, operational maintenance |
| `cleanup:` | Quality | Remove deprecated code or assets |
| `debt:` | Quality | Technical debt or legacy maintenance |
| `spike:` | Development | Research or proof-of-concept work |
| `review:` | Quality | Internal review, audit, documentation validation |
| `ui:` | Design | Frontend, layout, visual improvements |
| `design:` | Design | Architecture or UX design deliverable |
| `data:` | Development | Data model, ETL, schema, analytics changes |
| `meta:` | Process | Process or workflow improvements |

**Breaking changes:**

- Add `BREAKING CHANGE:` in commit body footer → MAJOR bump (1.0.0 → 2.0.0)
- **NEVER write this automatically.** Always ask the user for explicit confirmation.
  This triggers a major version bump and must be a deliberate human decision.

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

### Pushing Commits

- **ALWAYS** run `git pull --rebase` before pushing. Semantic-release CI
  creates version commits that your local won't have.
- **ALWAYS** seek approval before ANY push. Show: (1) commit list,
  (2) projected version bump (e.g., 1.8.2 → 1.8.3)
- **NEVER** push without explicit approval
