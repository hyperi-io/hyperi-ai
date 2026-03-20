---
name: deps
description: >-
  Dependency update workflow: update all packages to latest, fix deprecations,
  resolve Dependabot/Renovate alerts, then research upstream health and
  replacement candidates. Use when the user says /deps or asks to update
  dependencies.
user-invocable: true
---

# Dependency Update Workflow

Two phases: **Update Existing** (mechanical, just do it) then **Upstream Checks**
(research-heavy, produces a report).

## Phase 1: Update Existing

This phase is mechanical. Work through it systematically with minimal developer
interaction. Only stop if something genuinely breaks.

### 1.1 Detect Package Ecosystem

Identify all dependency manifests in the project:

| File | Ecosystem | Update Tool | Lock File |
|---|---|---|---|
| `pyproject.toml` | Python | `uv lock --upgrade` | `uv.lock` |
| `Cargo.toml` | Rust | `cargo update` | `Cargo.lock` |
| `package.json` | Node | `npm update` / `yarn upgrade` | `package-lock.json` / `yarn.lock` |
| `go.mod` | Go | `go get -u ./...` | `go.sum` |

### 1.2 Check for Available Updates

Use the ecosystem's native tooling to list outdated packages:

```bash
# Python
uv pip list --outdated

# Rust
cargo outdated    # if installed, otherwise cargo update --dry-run

# Node
npm outdated

# Go
go list -m -u all
```

### 1.3 Web Search to Verify Latest Versions

For EVERY package being updated, web search for the current latest version.
Do NOT trust training data. Cross-reference against:
- PyPI / crates.io / npmjs.com / pkg.go.dev
- The package's GitHub releases page

### 1.4 Security Audit

Run ecosystem security audit tools:

```bash
# Python
uv pip audit    # or pip-audit

# Rust
cargo audit

# Node
npm audit

# Go
govulncheck ./...
```

Web search for any CVEs or advisories for packages that don't appear in audit
tools (especially transitive dependencies).

### 1.5 Resolve Dependabot / Renovate Alerts

Check for open dependency bot PRs or issues:

```bash
gh pr list --label dependencies --state open
gh issue list --label dependencies --state open
```

For each alert:
- If the update is safe: merge or incorporate into this update
- If intentionally deferred: close with a comment explaining why (e.g.
  "pinned to X because Y depends on it") so it stops respamming
- Never leave alerts open without a decision

### 1.6 Update Everything

Update all dependencies to their latest compatible versions:

```bash
# Python — update lock then sync
uv lock --upgrade
uv sync

# Rust — update then check
cargo update
cargo check

# Node
npm update
npm install

# Go
go get -u ./...
go mod tidy
```

### 1.7 Update Manifests

Update minimum version constraints in manifests to reflect the new versions:
- `pyproject.toml`: update `>=` ranges to match new minimums
- `Cargo.toml`: update version requirements
- `package.json`: update semver ranges
- `go.mod`: already handled by `go get -u`

Do NOT change pinning strategy (e.g. don't change `>=` to `==` unless there's
a reason documented in a comment).

### 1.8 Fix Deprecations

Search build output, test output, and compiler warnings for deprecation notices.
Fix them ALL immediately:

- Check the deprecation message for the recommended replacement
- Web search for the migration path if unclear
- Apply the fix — do not defer deprecations

Common patterns:
- Python: `DeprecationWarning` in test output, `deprecated` in type stubs
- Rust: `#[deprecated]` warnings from `cargo check`
- Node: `npm warn deprecated` messages
- Go: `// Deprecated:` comments in godoc

### 1.9 Build and Verify

Run the full build and test suite:

```bash
# Use hyperi-ci if available
hyperi-ci check

# Otherwise, ecosystem-specific
cargo build && cargo test
uv run pytest
npm run build && npm test
go build ./... && go test ./...
```

Fix any breakage. Repeat until clean.

### 1.10 Commit

Commit the update as a single atomic commit:

```
chore(deps): update all dependencies to latest
```

Include a body listing notable version bumps (major versions, security fixes).

---

## Phase 2: Upstream Checks

This phase is research and analysis. Use extended thinking / ultrathink for the
assessment. The output is a report for the developer to review — do NOT take
action without their approval.

### 2.1 Package Health Assessment

For each direct dependency, research:

| Signal | How to Check |
|---|---|
| Last release date | Package registry (PyPI, crates.io, npm) |
| Last commit date | GitHub/GitLab repo — check default branch |
| Commit frequency trend | Compare last 3 months vs previous 3 months |
| Open issues / PRs | GitHub — is the backlog growing or shrinking? |
| Maintainer activity | Are maintainers responding to issues? |
| Bus factor | How many active committers? |

### 2.2 Risk Classification

Classify each dependency:

| Status | Criteria | Action |
|---|---|---|
| **Healthy** | Active commits, responsive maintainers, regular releases | No action needed |
| **Watch** | Slowing commits, growing issue backlog, but still releasing | Note in report |
| **At Risk** | No releases in 6+ months, unresponsive maintainers | Research replacements |
| **Abandoned** | No commits in 12+ months, no response to issues/PRs | Recommend migration |

### 2.3 Replacement Research

For any dependency classified as Watch, At Risk, or Abandoned:

1. **Web search for direct replacements** — libraries that do the same thing
   but are actively maintained
2. **Web search for approach replacements** — entirely different ways to solve
   the same problem that may have emerged since the original dependency was
   chosen. Examples:
   - `interrogate` (docstring coverage) → `ruff` D-series rules
   - `setuptools` + `setup.py` → `uv` + `pyproject.toml`
   - `flake8` + `isort` + `black` → `ruff` (all-in-one)
   - `tslint` → `eslint` (tslint deprecated)
   - Custom Makefile CI → `hyperi-ci` (if applicable)
3. **Assess maturity** — we accept relatively bleeding-edge tools if:
   - They have a clear trajectory (growing adoption, responsive maintainers)
   - The migration path is not catastrophically complex
   - They solve the problem better, not just differently

### 2.4 Produce Report

Present findings to the developer in a structured format:

```markdown
## Dependency Health Report

### Healthy (no action)
- package-a (v1.2.3) — 3 releases this quarter, active maintainer
- package-b (v4.5.6) — healthy, 12 contributors

### Watch
- package-c (v2.0.0) — last release 4 months ago, commits slowing
  - No replacement needed yet, re-check next quarter

### Action Required
- package-d (v0.9.1) — ABANDONED, no commits since 2025-01
  - Recommended replacement: package-e (v1.0.0) — actively maintained, API-compatible
  - Migration effort: LOW (drop-in replacement)

- package-f (v3.2.0) — AT RISK, sole maintainer inactive
  - Recommended approach change: use built-in stdlib feature X instead
  - Migration effort: MEDIUM (requires refactoring Y module)

### New Tools Worth Considering
- tool-x has matured since we adopted tool-y — offers Z benefits
  - Adoption: 5K GitHub stars, used by [notable projects]
  - Migration path: [brief description]
```

Ask the developer what to do with each actionable item. Do NOT proceed with
replacements or migrations without explicit approval.

## What NOT to Do

- Never skip the web search verification step — training data versions are stale
- Never leave Dependabot/Renovate alerts open without a decision
- Never defer deprecation fixes — they compound
- Never replace a dependency without developer approval (Phase 2 is advisory)
- Never downgrade a dependency unless there's a specific breaking issue
- Never change version pinning strategy without documenting why
