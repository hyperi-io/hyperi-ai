# HyperI Universal Coding Rules

Rules that apply to ALL code regardless of language. Language-specific
rules are injected automatically when editing matching files.

## Spelling Split

- **Code identifiers:** American English — `color`, `initialize`, `optimize`, `serialize`
- **Everything else:** Australian English — `colour`, `initialise`, `optimise`, `serialise`
- Applies to: docs, comments, docstrings, commits, chat, markdown

## Git Conventions

- Default branch: `main` (never `master`)
- Format: `<type>: <description>` — 50 chars max, lowercase, no period, imperative
- Default type: `fix:` — AI assistants exaggerate importance; if you think `feat:`, it's probably `fix:`
- Body: only for huge changes, 3 lines max
- No emojis in commits
- No AI attribution (Co-Authored-By removed by hooks)
- `git pull --rebase` before every push
- Seek approval before any push; show commit list and projected version bump
- Branch naming: `<type>/<issue>/<description>` or `<type>/<description>`

### Commit Types (Version Bump)

| Type | Use | Bump |
|------|-----|------|
| `fix:` | Fixes, improvements, refactors (DEFAULT) | PATCH |
| `feat:` | New significant user-facing features (SPARINGLY) | MINOR |
| `perf:` | Performance | PATCH |
| `sec:` | Security | PATCH |

No bump: `docs:`, `test:`, `chore:`, `ci:`, `refactor:`, `infra:`, `ops:`, `debt:`, `spike:`, `cleanup:`

## Code Style

- Clarity over cleverness — break compound operations into clear steps
- Comments explain WHY, never WHAT — never number comments
- Helper functions FIRST, main function LAST
- No decorative separators (`# ====`, `# ────`)
- No TODOs/FIXMEs in production code
- Complete implementations only — no placeholders, no `return True` stubs

## File Headers (All Languages)

```
# Project:   <NAME>
# File:      <FILENAME>
# Purpose:   <One sentence>
# Language:  <LANGUAGE>
#
# License:   FSL-1.1-ALv2
# Copyright: (c) <YEAR> HYPERI PTY LIMITED
```

Never include: version numbers, change dates, author names, modification history.

## Error Handling

- Never expose to users: stack traces, DB schemas, file paths, raw exceptions
- Always log full errors server-side with: who, what, tracking ID, stack trace
- Specific exceptions over generic `except Exception: pass`
- Never log: passwords, tokens, API keys, credit cards, PII, private keys

## Configuration Cascade

Priority (highest → lowest): CLI args → ENV vars → .env → settings.{env}.yaml → settings.yaml → defaults.yaml → hard-coded.
Always quote values in `.env` files.

## Security

- Validate ALL external input: type, range, format, sanitise
- Never commit secrets; use env vars or secret managers
- No `eval()`/`exec()` with external input
- Parameterised queries only (no f-string SQL)

## Testing

- 80% minimum coverage (90%+ for AI code)
- Test structure: `tests/unit/`, `tests/integration/`, `tests/e2e/`
- No mocking internal code — only mock external APIs, databases, network
- Fix root causes over mocking around problems

## Communication Style

- Direct, concise, technically accurate
- No LLM cheerleading: "Great question!", "I'd be happy to help!"
- No American marketing hype: "Amazing!", "Game-changing!", "World-class!"
- Australian understated: "This should help", "Performance is improved"

## AI Code of Conduct

### NEVER
- Placeholders in committed code (TODO, FIXME, PLACEHOLDER)
- Claim "finished" without testing
- Self-promote or use marketing language
- Hardcoded example data ("John Doe", "test@example.com")

### ALWAYS
- Verify operations succeeded before reporting success
- Test code before claiming it works
- Complete, working implementations
- Be concise and direct — skip pleasantries

## Three-Iteration Rule

```
Iteration 1: Generate implementation
Iteration 2: Fix issues (tests, validation)
Iteration 3: Polish (formatting, docs)
STOP — Commit or revert
```

Revert if: 3+ iterations with no progress, code more complex than start, tests failing with unclear cause.

## Source of Truth

| Data | Source | NOT From |
|------|--------|----------|
| Version | `git describe --tags` or `VERSION` | STATE.md |
| Tasks | `TODO.md` | STATE.md |
| History | `git log` | STATE.md |
| Changelog | `CHANGELOG.md` (semantic-release) | STATE.md |
| Static context | `STATE.md` | — |

## Licensing

- Default: FSL-1.1-ALv2
- Repos: always `--private` unless explicitly requested public
- No GPL/AGPL/SSPL dependencies permitted
- Never create custom LICENSE files — use the template

## Temporary Files

- Dev/CI: `./.tmp/` (project-scoped, gitignored)
- Production: use language tempfile libraries with auto-cleanup
- Never hardcode `/tmp`, never use predictable names
