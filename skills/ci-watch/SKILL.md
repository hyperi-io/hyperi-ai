---
name: ci-watch
description: >-
  Trigger or watch GitHub Actions CI runs for hyperi-ci projects.
  Use when the user says /ci-watch, wants to monitor CI, or check run status.
user-invocable: true
---

# CI Watch (hyperi-ci projects)

## Prerequisites

This skill is ONLY for projects using hyperi-ci. Verify `.hyperi-ci.yaml` exists.

## Commands

### Watch the Latest Run

```bash
gh run watch
```

This streams live status of the most recent workflow run.

### Trigger a New Run and Watch

```bash
gh workflow run ci.yml && sleep 3 && gh run watch
```

### List Recent Runs

```bash
gh run list --limit 5
```

### Check a Specific Run

```bash
gh run view <RUN_ID>
```

## Procedure

### 1. Determine Intent

- **"watch CI" / "is CI passing?"** → `gh run list --limit 3` then `gh run watch` on the latest
- **"trigger CI"** → `gh workflow run ci.yml` then watch
- **"what happened?"** → `gh run list --limit 5` to see recent status

### 2. Report Status

Tell the user:
- Which workflow ran (CI, release-merge, etc.)
- Current status (in_progress, completed, failed)
- Which jobs passed/failed
- Duration

### 3. On Failure

If a run failed, offer to use `/ci-logs` to fetch the failure details.
Do NOT guess at the failure cause — read the actual logs.

## Watching Release Pipelines

After a release-merge PR is merged, the release CI runs with additional jobs:
- `quality` → `test` → `build` → `release` → `publish`

The `release` job creates the GitHub Release. The `publish` job uploads artifacts.
Both only run on `main` and `release` branch pushes.

```bash
# Watch specifically the release branch run
gh run list --branch release --limit 3
gh run watch <RUN_ID>
```
