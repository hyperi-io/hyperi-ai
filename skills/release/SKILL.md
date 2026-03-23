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
- `.releaserc.yaml` must exist
- `hyperi-ci` must be installed (`uvx hyperi-ci --version` or `hyperi-ci --version`)

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

Run the release-merge command. This clones to a temp directory, merges main into
release with automatic conflict resolution for VERSION/Cargo.toml/CHANGELOG.md,
pushes a merge branch, and creates a PR. Never touches your working tree.

```bash
hyperi-ci release-merge
```

If `gh` CLI is not available, the command prints manual git/gh commands to run instead.

### 5. Find and Report the PR

The release-merge command outputs the PR URL directly. If needed:

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

### 7. Ask: Follow the Release?

After merge, ask the user:

> "Release merged. Want me to follow this all the way through to completion?
> I'll check every 2 minutes and report status until artifacts are published."

- **If yes:** proceed to steps 8–10 (monitoring loop)
- **If no:** report the merge and stop

### 8. Monitor Release CI (every 2 minutes)

The merge to `release` triggers the full CI pipeline:
quality → test → build → **release** → **publish**

Poll every 2 minutes and report status. Use the `/loop` pattern:

```bash
# Get the run triggered by the merge
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
RUN_ID=$(gh run list --repo "$REPO" --branch release --limit 1 --json databaseId -q '.[0].databaseId')

# Check status
gh run view "$RUN_ID" --repo "$REPO"
```

Each check, report to the user:
- Which jobs have completed, which are running, which are queued
- Any failures (with the failing job name and a one-line summary)
- Elapsed time since merge

Continue until the run reaches a terminal state (completed/failed/cancelled).

If the run fails, fetch logs immediately:
```bash
hyperi-ci logs --failed
```

### 9. Verify Release Artifacts

Once CI completes successfully, verify all artifacts were published:

```bash
# Check GitHub Release was created
gh release list --limit 3

# View the latest release details
gh release view $(gh release list --limit 1 --json tagName -q '.[0].tagName')
```

For projects with R2 publishing, verify the binary URLs are accessible
(the publish job logs show the R2 upload paths).

For JFrog publishing, check the publish job logs for upload confirmation.

### 10. Final Report

Provide a complete summary:
- GA version tag (e.g. `v1.15.0`)
- GitHub Release URL
- Published destinations (PyPI, crates.io, npm, R2, JFrog — based on `.hyperi-ci.yaml` publish config)
- Total time from merge to artifacts published
- Any warnings or issues from the CI run

## Error Recovery

| Problem | Action |
|---------|--------|
| `hyperi-ci check` fails | Fix issues, re-run |
| Main CI fails | `hyperi-ci logs --failed`, fix, re-push |
| Release-merge has conflicts | Command resolves VERSION/Cargo.toml/CHANGELOG.md automatically; other conflicts require manual resolution |
| Release CI fails | Check logs, fix on main, re-run `hyperi-ci release-merge` |
| Missing GitHub Release | Check semantic-release logs in CI — likely no releasable commits |
| `gh` CLI not installed | `hyperi-ci release-merge` prints manual commands to run |

## What NOT to Do

- Never push directly to the `release` branch
- Never delete the `release` branch
- Never skip `hyperi-ci check` before pushing
- Never force-push to `main` or `release`
- Never manually create tags — semantic-release handles this
- Never merge `release` → `main` (flow is always main → release)
