---
name: release
description: >-
  Full release workflow for hyperi-ci projects: commit, push, PR to main,
  release-merge to release branch, follow through to GH Releases and R2.
  Use when the user says /release or asks to release/ship/deploy.
user-invocable: true
---

# Release Workflow (hyperi-ci projects)

## Prerequisites

This skill is ONLY for projects using hyperi-ci. Verify before proceeding:
- `.hyperi-ci.yaml` must exist in the project root
- `.github/workflows/release-merge.yml` must exist (or equivalent caller)
- `.releaserc.yaml` must exist

If any are missing, tell the user this project is not configured for hyperi-ci releases.

## The Flow

```
local checks → commit → push → CI green → release-merge → PR review → merge → GA release → verify
```

## Step-by-Step

### 1. Pre-flight Checks

Run `hyperi-ci check` (quality + test). Do NOT skip this.

```bash
hyperi-ci check
```

If it fails, fix the issues before proceeding. Never push broken code.

### 2. Commit and Push

Follow normal git commit conventions (conventional commits required for semantic-release):
- `feat:` → minor version bump
- `fix:` → patch version bump
- `feat!:` or `BREAKING CHANGE:` → major version bump
- `chore:`, `docs:`, `ci:` → no release

Stage, commit, and push to `main`. Wait for CI.

### 3. Wait for CI on Main

```bash
# Watch the CI run
gh run watch --repo $(gh repo view --json nameWithOwner -q .nameWithOwner)
```

CI must pass. On `main`, semantic-release creates a dev pre-release (e.g. `v1.15.0-dev.1`).
This is expected — it is NOT the GA release.

If CI fails:
```bash
# Get failed job logs
hyperi-ci logs --failed
```

Fix and re-push. Do not proceed until main CI is green.

### 4. Trigger Release Merge

The release-merge workflow merges `main` → `release` with automatic conflict resolution
for VERSION, Cargo.toml, pyproject.toml, package.json, and CHANGELOG.md files.

```bash
gh workflow run release-merge.yml
```

Wait for the workflow to complete:
```bash
gh run watch --repo $(gh repo view --json nameWithOwner -q .nameWithOwner)
```

This creates a PR from `main` → `release`. The PR title includes the commit summary.

### 5. Find and Report the PR

```bash
gh pr list --base release --state open
```

Report the PR URL to the user. The PR needs review before merge.

Ask the user: "Release PR created: <URL>. Ready to merge?"

### 6. Merge the Release PR

Only after user confirmation:
```bash
gh pr merge <PR_NUMBER> --merge --delete-branch=false
```

IMPORTANT: Do NOT delete the release branch. It is a permanent branch.

### 7. Watch Release CI

The merge to `release` triggers the full CI pipeline including:
- quality → test → build → **release** → **publish**

```bash
gh run watch --repo $(gh repo view --json nameWithOwner -q .nameWithOwner)
```

### 8. Verify Release Artifacts

Once CI completes, verify all artifacts were published:

```bash
# Check GitHub Release was created
gh release list --limit 3

# View the latest release details
gh release view $(gh release list --limit 1 --json tagName -q '.[0].tagName')
```

For projects with R2 publishing, verify the binary URLs are accessible
(the publish job logs will show the R2 upload paths).

### 9. Report to User

Provide a summary:
- GA version tag (e.g. `v1.15.0`)
- GitHub Release URL
- Published destinations (PyPI, crates.io, npm, R2, JFrog — based on `.hyperi-ci.yaml` publish config)
- Any warnings or issues from the CI run

## Error Recovery

| Problem | Action |
|---------|--------|
| `hyperi-ci check` fails | Fix issues, re-run |
| Main CI fails | `hyperi-ci logs --failed`, fix, re-push |
| Release-merge has conflicts | Workflow will fail with details — resolve manually |
| Release CI fails | Check logs, fix on main, re-run release-merge |
| Missing GitHub Release | Check semantic-release logs in CI — likely no releasable commits |

## What NOT to Do

- Never push directly to the `release` branch
- Never delete the `release` branch
- Never skip `hyperi-ci check` before pushing
- Never force-push to `main` or `release`
- Never manually create tags — semantic-release handles this
- Never merge `release` → `main` (flow is always main → release)
