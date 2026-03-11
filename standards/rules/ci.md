---
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
<!-- override: manual -->

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
make quality    # Run all quality checks
make test       # Run tests
make build      # Build artifacts
make ci         # Run quality + test + build (full local CI)
```

Always prefer `make <target>` or `hyperi-ci run <stage>` over raw tool commands.

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
