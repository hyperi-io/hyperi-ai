---
name: ci-standards
description: CI/CD pipeline standards using hyperi-ci. Covers single versioning, dispatch-triggered publishing, channel system, commit message enforcement, and semantic release configuration.
rule_paths:
  - "**/.github/workflows/*.yml"
  - "**/.github/workflows/*.yaml"
  - "**/.releaserc*"
  - "**/release.config.*"
  - "**/.hyperi-ci.yaml"
  - "**/VERSION"
  - "**/CHANGELOG.md"
  - "**/Makefile"
detect_markers:
  - "file:.hyperi-ci.yaml"
  - "file:.releaserc.yaml"
  - "file:VERSION"
  - "dir:.github"
paths:
  - "**/.github/workflows/*.yml"
  - "**/.github/workflows/*.yaml"
  - "**/.releaserc*"
  - "**/.hyperi-ci.yaml"
---

# CI/CD Standards

**hyperi-ci pipeline architecture, versioning, publishing, and commit conventions**

---

## Quick Reference

```bash
# Install
uv tool install hyperi-ci

# Day-to-day
hyperi-ci check              # Pre-push: quality + test (MANDATORY before every push)
hyperi-ci check --quick      # Quality only
hyperi-ci check --full       # Quality + test + build

# Stages (CI runs these, you can run locally)
hyperi-ci run quality        # Lint, format, type check, security audit
hyperi-ci run test           # Tests with coverage
hyperi-ci run build          # Build artifacts

# Publishing
hyperi-ci release --list     # Show unpublished version tags
hyperi-ci release v1.3.0     # Trigger publish for a tag

# Commit validation
hyperi-ci check-commit --list    # Show all accepted commit types
git config core.hooksPath .githooks  # Activate local hook

# Project setup
hyperi-ci init               # Scaffold .hyperi-ci.yaml, Makefile, workflow, .releaserc.yaml, .githooks/
```

---

## How Versioning Works

### Single Versioning on Main

Every version is determined on the `main` branch by semantic-release. There is no
release branch. The version in the source code (VERSION file, Cargo.toml, pyproject.toml)
is always the real version -- never a prerelease suffix like `-dev.8`.

```
Developer pushes to main
    -> CI runs quality, test, build
    -> semantic-release determines next version (e.g. 1.3.0)
    -> Updates VERSION + manifest, commits, creates git tag v1.3.0
    -> Tag exists on main. Nothing published yet.

Developer decides to ship:
    -> hyperi-ci release v1.3.0
    -> Dispatches workflow: quality -> test -> build (full) -> publish
    -> Creates GH Release, uploads binaries to R2, publishes to registries
```

### Why This Matters

The binary `--version` output always matches the GH Release version because the
version is baked into the source code before the build step runs. The build
compiles from the tagged commit which already has the correct version.

### Skipped Versions Are Normal

Not every version on main needs to be published. Tags accumulate -- you publish
whichever ones you want:

```
main tags:  v1.3.0, v1.4.0, v1.5.0
published:  v1.3.0, v1.5.0           (v1.4.0 was never shipped -- fine)
```

---

## Publishing Channels

The publish channel controls where artifacts go. Set it in `.hyperi-ci.yaml`:

```yaml
publish:
  enabled: true
  target: both          # internal, oss, or both
  channel: release      # spike | alpha | beta | release
```

| Channel | GH Release | R2 Path | Registries (PyPI, crates.io) |
|---------|------------|---------|------------------------------|
| spike | Marked as prerelease | `/{project}/spike/v1.3.0/` | Skipped |
| alpha | Marked as prerelease | `/{project}/alpha/v1.3.0/` | Skipped |
| beta | Marked as prerelease | `/{project}/beta/v1.3.0/` | Skipped |
| release | GA release | `/{project}/v1.3.0/` | Published |

Projects progress through channels: `spike -> alpha -> beta -> release`.
To graduate, change one line in `.hyperi-ci.yaml`. No code changes needed.

---

## Commit Message Format

All commits must follow conventional commit format. This is enforced by:
- A **git hook** (`.githooks/commit-msg`) that validates locally before the commit is accepted
- The **CI quality stage** that validates all commits in the push range

### Accepted Types

**Trigger a version bump:**

| Type | Bump | When to use |
|------|------|-------------|
| `feat:` | MINOR | Genuinely new user-facing feature (use sparingly) |
| `fix:` | PATCH | Bug fix, defect, improvement (use most of the time) |
| `perf:` | PATCH | Performance optimisation |
| `hotfix:` | PATCH | Critical production fix |
| `security:` / `sec:` | PATCH | Security fix or hardening |

**No version bump (maintenance):**

| Type | When to use |
|------|-------------|
| `docs:` | Documentation only |
| `test:` | Test coverage or QA |
| `refactor:` | Internal restructure, no functional change |
| `style:` | Formatting, linting, cosmetic |
| `build:` | Build system or tooling |
| `ci:` | CI/CD configuration |
| `chore:` | Maintenance, config, cleanup |
| `deps:` | Dependency updates |
| `revert:` | Revert a previous commit |
| `wip:` | Work in progress (squash before merge) |
| `cleanup:` | Dead code removal |
| `data:` | Data migrations or seed data |
| `debt:` | Technical debt reduction |
| `design:` | Design system or UX |
| `infra:` | Infrastructure changes |
| `meta:` | Repository metadata |
| `ops:` | Operational tooling |
| `review:` | Code review feedback |
| `spike:` | Experimental investigation |
| `ui:` | Frontend or visual changes |

### Format

```
<type>: <description>
<type>(scope): <description>
```

- Description: 3-100 characters, starts with lowercase, imperative mood
- Breaking changes: add `BREAKING CHANGE:` in the commit body (never automatically)

### What Happens When You Get It Wrong

```
Computer says no.

  Your commit message doesn't start with a recognised type prefix.

  You wrote:
    "updated the config parser"

  It should look like:
    "fix: update the config parser"

  Accepted prefixes:
    Triggers a release:  feat, fix, perf, hotfix, security, sec
    No release:          docs, test, refactor, chore, ci, build, deps,
                         style, revert, wip, cleanup, data, debt, design,
                         infra, meta, ops, review, spike, ui

  Format:  <type>: <description>
           <type>(scope): <description>
```

The message tells you exactly what went wrong and how to fix it.

---

## Semantic Release Configuration

Every project needs a `.releaserc.yaml`. This is generated by `hyperi-ci init`.

### Key Points

- `branches: [main]` -- semantic-release runs only on main
- No `@semantic-release/github` plugin -- GH Release is created by the publish step
- `prepareCmd` updates VERSION and the language manifest (Cargo.toml, pyproject.toml, etc.)
- `@semantic-release/git` commits the changes with `[skip ci]` to prevent infinite loops

### Things Semantic-Release Owns (Never Touch Manually)

- `VERSION` file
- `CHANGELOG.md`
- Version fields in `Cargo.toml` / `pyproject.toml` / `package.json`
- Git tags

### 1 Commit Behind After Push -- Normal

After you push, semantic-release pushes a version commit back. Before your next push:

```bash
git pull --rebase origin main
```

---

## Workflow Architecture

### For Consumer Projects

Consumer projects have a thin `ci.yml` that calls the reusable workflow:

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: ["**"]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  ci:
    uses: hyperi-io/hyperi-ci/.github/workflows/rust-ci.yml@main
    with:
      publish-target: both
    secrets: inherit
```

The reusable workflow handles everything: quality, test, build, release (on main), publish (on dispatch).

### Pipeline Flow

**On push to main:**
```
quality -> test -> build (validation) -> semantic-release (tag + commit)
```

**On workflow_dispatch (publish):**
```
checkout tag -> quality -> test -> build (full cross-compile) -> publish
```

The publish pipeline is a complete standalone run from the tag. No artifacts are shared
from the main push -- the tag checkout guarantees the source has the correct version.

### Build Matrix

- **Main push:** amd64 only (validation build)
- **Publish dispatch:** amd64 + arm64 (full cross-compile for shipping)

---

## Project Setup

### New Project

```bash
cd my-project
hyperi-ci init
```

This creates:
- `.hyperi-ci.yaml` -- CI configuration
- `Makefile` -- quality/test/build targets
- `.github/workflows/ci.yml` -- GitHub Actions workflow
- `.releaserc.yaml` -- semantic-release config
- `.githooks/commit-msg` -- commit validation hook

Then activate the hook:
```bash
git config core.hooksPath .githooks
```

### Publishing a Release

```bash
# 1. Make sure your changes are on main and CI passed
hyperi-ci check
git push origin main

# 2. Wait for semantic-release to tag
# (watch CI or check: git tag --list 'v*' --sort=-version:refname | head -5)

# 3. See what's available
hyperi-ci release --list

# 4. Publish
hyperi-ci release v1.3.0
```

---

## Configuration

### .hyperi-ci.yaml

```yaml
language: rust          # auto-detected if omitted

publish:
  enabled: true
  target: both          # internal | oss | both
  channel: release      # spike | alpha | beta | release

build:
  strategies: [native]
  rust:
    targets:
      - x86_64-unknown-linux-gnu
      - aarch64-unknown-linux-gnu

quality:
  enabled: true
  gitleaks: blocking
```

### Config Cascade (highest wins)

```
CLI flags -> ENV vars (HYPERCI_*) -> .hyperi-ci.yaml -> config/defaults.yaml -> hardcoded
```

---

## Common Operations

| Task | Command |
|------|---------|
| Pre-push check | `hyperi-ci check` or `make check` |
| Quality only | `hyperi-ci check --quick` |
| Full local CI | `hyperi-ci check --full` or `make ci` |
| Watch CI run | `hyperi-ci watch` |
| View failed logs | `hyperi-ci logs --failed` |
| List unpublished tags | `hyperi-ci release --list` |
| Publish a version | `hyperi-ci release v1.3.0` |
| Validate commit message | `echo "fix: something" \| hyperi-ci check-commit` |
| List accepted types | `hyperi-ci check-commit --list` |
| Scaffold a project | `hyperi-ci init` |
| Upgrade hyperi-ci | `hyperi-ci upgrade` |
