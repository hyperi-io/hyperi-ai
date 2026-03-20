---
name: ci-logs
description: >-
  Fetch and debug CI failure logs for hyperi-ci projects.
  Use when the user says /ci-logs, CI failed, or needs to debug a pipeline.
user-invocable: true
---

# CI Logs (hyperi-ci projects)

## Prerequisites

This skill is ONLY for projects using hyperi-ci. Verify `.hyperi-ci.yaml` exists.

## Commands

### Quick: Failed Job Logs Only

```bash
hyperi-ci logs --failed
```

This fetches only the logs from failed jobs — the most common need.

### Full Logs for a Specific Run

```bash
# List recent runs to find the ID
gh run list --limit 5

# View specific run details
gh run view <RUN_ID>

# Download logs for a specific run
gh run view <RUN_ID> --log-failed
```

### All Logs (verbose)

```bash
hyperi-ci logs
```

## Procedure

### 1. Identify the Failure

```bash
# See what failed
gh run list --limit 5 --json status,conclusion,name,headBranch,databaseId \
  --jq '.[] | select(.conclusion == "failure")'
```

### 2. Get Failed Logs

```bash
hyperi-ci logs --failed
```

Or for a specific run:
```bash
gh run view <RUN_ID> --log-failed
```

### 3. Diagnose

Common failure patterns:

| Stage | Typical Cause | Fix |
|-------|--------------|-----|
| **quality** | Lint/format/type errors | Run `hyperi-ci run quality` locally, fix issues |
| **test** | Test failures | Run `hyperi-ci run test` locally, fix tests |
| **build** | Compilation error, missing deps | Run `hyperi-ci run build` locally |
| **release** | No releasable commits | Ensure conventional commit messages |
| **publish** | Registry auth, network | Check secrets (JFROG_TOKEN, PYPI_TOKEN, etc.) |

### 4. Report to User

Provide:
- Which job failed and why (with the actual error from logs)
- Suggested fix
- Command to reproduce locally

### 5. Fix and Re-validate

After fixing, always run `hyperi-ci check` locally before pushing again.
Never push a "hopefully this fixes it" commit without local validation.
