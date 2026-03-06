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
---

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

### Commit Messages Drive Releases

Semantic-release reads commit messages to determine version bumps.
Follow the project's commit conventions (see UNIVERSAL.md). Key points:

- `fix:` → PATCH bump (default — use this most of the time)
- `feat:` → MINOR bump (genuinely new user-facing features only)
- `BREAKING CHANGE:` in body → MAJOR bump
- `chore:`, `docs:`, `ci:`, `test:` → no release

Write commits for humans first, changelog second. Keep them short and
specific — the changelog is auto-generated from these messages.

## CI Workflows (Basics)

- Prefer reusable workflows and composite actions over copy-paste
- Pin actions to full SHA, not tags: `uses: actions/checkout@<sha>`
- Use `vars.*` for non-secret configuration, `secrets.*` for credentials
- Default runner: `${{ vars.GH_RUNNER_DEFAULT || 'ubuntu-latest' }}`
