---
name: ci-standards
description: CI/CD standards including hyperi-ci, semantic-release, and GitHub Actions.
paths:
  - "**/.github/workflows/*.yml"
  - "**/.github/workflows/*.yaml"
  - "**/.releaserc"
  - "**/.releaserc.*"
  - "**/release.config.*"
  - "**/VERSION"
  - "**/CHANGELOG.md"
  - "**/package.json"
  - "**/pyproject.toml"
  - "**/Cargo.toml"
  - "**/.hyperi-ci.yaml"
  - "**/Makefile"
detect_markers:
  - "file:.releaserc"
  - "glob:.releaserc.*"
  - "glob:release.config.*"
  - "file:VERSION"
  - "dir:.github"
  - "file:.hyperi-ci.yaml"
  - "dir:ci"
---


> **⚠️ hyperi-ci is under active development.** This document reflects the
> current state but the tool evolves frequently. Always check the
> [hyperi-ci repo](https://github.com/hyperi-io/hyperi-ci) `/docs` and
> `CHANGELOG.md` for the latest commands, config format, and features.

## hyperi-ci (Polyglot CI/CD Tool)

**Detection:** `.hyperi-ci.yaml` in project root.

When `.hyperi-ci.yaml` is present, the project uses **hyperi-ci** — a unified
CI/CD CLI that runs the same locally and in GitHub Actions. All CI operations
go through this tool.

### Install

```bash
uv tool install hyperi-ci
```

If `uv` is not available: `pip install --user hyperi-ci`

### CLI Commands

| Command | Purpose |
|---|---|
| `hyperi-ci check` | **Pre-push validation (quality + test) — run before every push** |
| `hyperi-ci check --quick` | Quality checks only (skip tests) |
| `hyperi-ci check --full` | Quality + test + build (native target) |
| `hyperi-ci run quality` | Lint, format, type check, security audit |
| `hyperi-ci run test` | Run test suite with coverage |
| `hyperi-ci run build` | Build artifacts |
| `hyperi-ci run publish` | Publish (CI only — do not run locally) |
| `hyperi-ci detect` | Show detected language |
| `hyperi-ci config` | Show merged config as JSON |
| `hyperi-ci trigger` | Trigger GitHub Actions workflow |
| `hyperi-ci trigger --watch` | Trigger and watch to completion |
| `hyperi-ci watch` | Watch latest CI run |
| `hyperi-ci logs` | Show latest run logs |
| `hyperi-ci logs --failed` | Show only failed job logs |
| `hyperi-ci init` | Scaffold a new project (generates .hyperi-ci.yaml, Makefile, workflow, .releaserc.yaml) |

### Prefer hyperi-ci Over Direct Tool Invocation

When `.hyperi-ci.yaml` exists, use `hyperi-ci run <stage>` instead of
calling tools directly. The CI tool handles config, flags, and tool
selection automatically:

| Instead of... | Use... |
|---|---|
| `ruff check .` | `hyperi-ci run quality` or `make quality` |
| `pytest` | `hyperi-ci run test` or `make test` |
| `cargo build` | `hyperi-ci run build` or `make build` |
| Manual linter invocations | `hyperi-ci run quality` |

### Makefile Targets

Projects using hyperi-ci have a generated `Makefile` with standard targets:

```bash
make check      # Pre-push validation (quality + test) — USE THIS
make quality    # Run all quality checks
make test       # Run tests
make build      # Build artifacts
make ci         # Run quality + test + build (full local CI)
```

Always prefer `make <target>` or `hyperi-ci run <stage>` over raw tool commands.

### MANDATORY: Run `hyperi-ci check` Before Every Push

When `.hyperi-ci.yaml` is present, **ALWAYS run `hyperi-ci check` before
pushing code.** This catches quality and test failures locally before they
hit CI, saving time and CI minutes.

**Workflow:**
1. Write code on topic branch or `main` — NEVER on `release`
2. `hyperi-ci check` (runs quality + test locally)
3. Fix any failures, amend or new commit
4. `git pull --rebase origin main` (sync semantic-release commits)
5. `git push origin main` (or merge topic branch into main)
6. Create PR: `main -> release` (NEVER push directly to release)

**Variants:**
- `hyperi-ci check` — default: quality + test
- `hyperi-ci check --quick` — quality only (fast, for WIP pushes)
- `hyperi-ci check --full` — quality + test + build (for release branches)
- `make check` — same as `hyperi-ci check` (Makefile target)

**NEVER push without running check first.** If the user asks to push,
run `hyperi-ci check` first. If it fails, fix the issues before pushing.
Only skip check if the user explicitly says to skip it.

## Semantic Release

Most HyperI projects use **semantic-release** via GitHub Actions. When
semantic-release is present, it owns versioning and changelogs entirely.

**Detection:** `.releaserc`, `release.config.*`, `VERSION` file, or a
workflow referencing `semantic-release`.

### NEVER Do (semantic-release handles these)

- Edit `VERSION` — semantic-release writes it via `@semantic-release/exec`
- Edit `CHANGELOG.md` — generated from commits by `@semantic-release/changelog`
- Bump version in `package.json`, `pyproject.toml`, `Cargo.toml`, etc.
- Create git tags — semantic-release creates them
- Create GitHub releases — semantic-release creates them
- Suggest version bumps in PRs — the commit type determines the bump

### Local Branch Is Usually 1 Commit Behind Upstream

After a push to `main`, semantic-release creates a version commit
(`chore(release): X.Y.Z [skip ci]`) and pushes it back. This means
your local `main` is typically **one commit behind** `origin/main`.

**Before every push:** `git pull --rebase origin main`

This is expected and normal — not a conflict. The extra commit only
changes `VERSION`, `CHANGELOG.md`, and possibly `package.json` version
fields. Never force-push over it.

### Commit Messages Drive Releases

Semantic-release reads commit messages to determine version bumps.
Follow the project's commit conventions (see UNIVERSAL.md). Key points:

- `fix:` → PATCH bump (default — use this most of the time)
- `feat:` → MINOR bump (genuinely new user-facing features only)
- `BREAKING CHANGE:` in body → MAJOR bump — **NEVER write this
  automatically.** Always ask the user for explicit confirmation
  before committing any breaking change. This triggers a major
  version bump and must be a deliberate human decision.
- `chore:`, `docs:`, `ci:`, `test:` → no release

Write commits for humans first, changelog second. Keep them short and
specific — the changelog is auto-generated from these messages.

## CI Workflows (Basics)

- Prefer reusable workflows and composite actions over copy-paste
- Pin actions to full SHA, not tags: `uses: actions/checkout@<sha>`
- Use `vars.*` for non-secret configuration, `secrets.*` for credentials
- Default runner: `${{ vars.GH_RUNNER_DEFAULT || 'ubuntu-latest' }}`

### Authentication — Prefer GitHub Apps

**Use GitHub App tokens over PATs for CI push-back and cross-repo access.**

```yaml
- name: Generate GitHub App token
  id: app-token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.GH_APP_ID }}
    private-key: ${{ secrets.GH_APP_PRIVATE_KEY }}

- uses: actions/checkout@v4
  with:
    token: ${{ steps.app-token.outputs.token }}
```

App tokens are scoped, auditable, and don't expire with a person's account.
PATs (`GIT_TOKEN`) are fallback only.

### Python Type Checking — ty first, pyright fallback

hyperi-ci uses **ty** (Astral's Rust-based type checker) as the primary
type checker, with pyright as fallback if ty is not available. Both are
configured via `.hyperi-ci.yaml`:

```yaml
quality:
  python:
    ty: blocking       # Primary (Astral, Rust-based, fast)
    pyright: disabled   # Fallback only if ty unavailable
```

## Legacy CI Submodule (Upgrade Path)

**Detection:** A `ci/` directory that is a git submodule (typically
pointing to `hyperi-io/ci`).

If `ci/` submodule is present but `.hyperi-ci.yaml` is NOT, this project
uses the **legacy CI system** which has been superseded by `hyperi-ci`.

**Recommend migration:** `hyperi-ci migrate` automates the conversion:
- Generates `.hyperi-ci.yaml` from the old config
- Creates a modern `Makefile` and GitHub Actions workflow
- The old `ci/` submodule can then be removed

Tell the user: "This project uses the legacy ci/ submodule. The new
`hyperi-ci` CLI replaces it. Run `hyperi-ci migrate` to upgrade."

Do NOT attempt to use scripts from the `ci/` submodule directly — they
are deprecated and may not work correctly with current tooling.
