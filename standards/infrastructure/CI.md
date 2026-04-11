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

# Pushing (ALWAYS prefer over bare 'git push')
hyperi-ci push               # Check, rebase, push
hyperi-ci push --release     # Push + auto-publish if CI passes
hyperi-ci push --no-ci       # Push, skip CI (amends last commit with [skip ci])
hyperi-ci push -n            # Dry-run
hyperi-ci push -f            # Skip pre-push checks (doesn't force-push)

# Stages (CI runs these, you can run locally)
hyperi-ci run quality        # Lint, format, type check, security audit
hyperi-ci run test           # Tests with coverage
hyperi-ci run build          # Build artifacts

# CI runs
hyperi-ci trigger            # Dispatch a workflow run
hyperi-ci watch              # Watch latest run (auto-detects branch)
hyperi-ci logs --failed      # Fetch failed step logs

# Publishing
hyperi-ci release --list     # Show unpublished version tags
hyperi-ci release v1.3.0     # Trigger publish for a tag
hyperi-ci release latest     # Publish most recent unpublished tag

# Config inspection
hyperi-ci config             # Show merged config (YAML)
hyperi-ci config --json      # Show merged config (JSON, for scripts)

# Commit validation
hyperi-ci check-commit --list    # Show all accepted commit types
git config core.hooksPath .githooks  # Activate local hook

# Project setup
hyperi-ci init               # Scaffold .hyperi-ci.yaml, Makefile, workflow, .releaserc.yaml, .githooks/
```

### Global Conventions

All commands follow these short-flag conventions:

| Flag | Long form | Meaning |
|------|-----------|---------|
| `-V` | `--version` | Show version and exit (top-level only) |
| `-C` | `--project-dir` | Project root directory |
| `-n` | `--dry-run` | Show what would happen without executing |
| `-f` | `--force` | Skip confirmations; semantics documented per-command |

`-n` is reserved for `--dry-run` project-wide. `-C` is reserved for `--project-dir`.
`--force` has command-specific semantics (`init` = overwrite files, `push` = skip
pre-checks, NOT force-push) — always check `<cmd> --help`.

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

### Major Version Policy (Torvalds Two-Hands Rule)

When the minor version exceeds 20, bump to the next major. Humans count on
fingers and toes — version numbers past 20 are a smell that a major bump was
overdue. This is a version hygiene rule, not a semver override.

**Trigger:** Minor reaches 20 AND at least one genuine `BREAKING CHANGE:` exists
in the accumulated commits since the last major. Do NOT fabricate breaking changes
just to bump — wait for a real API change (signature change, removed public type,
behaviour change that requires consumer code updates).

**How:** Add a commit with `BREAKING CHANGE:` in the footer describing the real
breaking change. Semantic-release handles the rest.

**Example:** `hyperi-rustlib` graduated from v1.22 to v2.0.0 when
`DfeMetrics::register()` changed signature (real breaking change) and the minor
had exceeded 20 (hygiene trigger).

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

**Manual (two-step):**
```bash
# 1. Push to main — CI runs, semantic-release creates a tag
hyperi-ci push

# 2. Wait for CI, then check available tags
hyperi-ci release --list

# 3. Publish whichever tag you want
hyperi-ci release v1.3.0
```

**Automatic (one command):**
```bash
# Push + watch CI + auto-publish in one shot
hyperi-ci push --release
```
This chains: check → rebase → push → watch CI → detect new tag → dispatch publish
→ watch publish. If CI fails, publish is not attempted. If no version bump commits
are in the push, it exits cleanly with a message.

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

## Prefer hyperi-ci Over Native Tools

When hyperi-ci is installed, use its wrappers instead of bare `gh` and `git` commands.
The wrappers add project-aware logic: auto-detection, config resolution, structured output.

| ❌ Native tool | ✅ hyperi-ci | Why |
|---|---|---|
| `git push` | `hyperi-ci push` | Pre-push checks, auto-rebase, `--release`/`--no-ci` |
| `gh run watch` | `hyperi-ci watch` | Auto-detects latest run on current branch |
| `gh run list` | `hyperi-ci watch` | Same — finds the latest CI run |
| `gh run view --log-failed` | `hyperi-ci logs --failed` | Filter by `--job`, `--step`, `--grep`, `--tail` |
| `gh workflow run ci.yml` | `hyperi-ci trigger` | Resolves workflow from config, supports `--watch` |
| `gh release create/delete` | `hyperi-ci release <tag>` | Full publish pipeline (build, GH Release, registries, R2) |

**Read-only commands stay native:** `gh release view`, `gh run list --json`, `gh pr list`,
`git status`/`log`/`diff`/`show`, etc. These have no hyperi-ci wrapper and don't need one.

**Enforcement:** A PreToolUse hook in hyperi-ai intercepts bare `gh run`/`gh workflow run`/
`gh release create` calls and redirects them to hyperi-ci equivalents. The hook only
activates when hyperi-ci is on PATH — projects without hyperi-ci are unaffected.

**Escape hatch:** `HYPERCI_ALLOW_NATIVE=1 gh run watch 12345`

---

## hyperi-ci Architecture

```
src/hyperi_ci/
├── cli.py               # Typer CLI entry point
├── push.py              # Push wrapper (pre-checks, --release, --no-ci)
├── config.py            # CIConfig, OrgConfig, config cascade loader
├── common.py            # Logging, subprocess helpers, GH Actions output
├── detect.py            # Language detection from file markers
├── dispatch.py          # Stage dispatcher → language handlers
├── init.py              # Project scaffolding (config, Makefile, workflow, hooks)
├── release.py           # Tag-based publish dispatch
├── publish_binaries.py  # GH Release creation + R2/JFrog binary upload
├── gh.py                # GitHub CLI helpers
├── trigger.py           # Workflow trigger command
├── watch.py             # Run watch command
├── logs.py              # Log fetch command
├── upgrade.py           # Self-upgrade and auto-update
├── quality/
│   ├── gitleaks.py      # Secret scanning
│   └── commit_validation.py  # Conventional commit enforcement
└── languages/
    ├── python/          # quality, test, build, publish
    ├── rust/            # quality, test, build, publish
    ├── typescript/      # quality, test, build, publish
    └── golang/          # quality, test, build, publish
```

---

## Common Operations

| Task | Command |
|------|---------|
| Pre-push check | `hyperi-ci check` or `make check` |
| Quality only | `hyperi-ci check --quick` |
| Full local CI | `hyperi-ci check --full` or `make ci` |
| **Push** | **`hyperi-ci push`** (NEVER bare `git push`) |
| Push + auto-release | `hyperi-ci push --release` |
| Push, skip CI | `hyperi-ci push --no-ci` |
| Trigger CI run | `hyperi-ci trigger` |
| Watch CI run | `hyperi-ci watch` |
| View failed logs | `hyperi-ci logs --failed` |
| Show config | `hyperi-ci config` (YAML) / `hyperi-ci config --json` |
| List unpublished tags | `hyperi-ci release --list` |
| Publish a version | `hyperi-ci release v1.3.0` |
| Validate commit message | `echo "fix: something" \| hyperi-ci check-commit` |
| List accepted types | `hyperi-ci check-commit --list` |
| Scaffold a project | `hyperi-ci init` |
| Upgrade hyperi-ci | `hyperi-ci upgrade` |
