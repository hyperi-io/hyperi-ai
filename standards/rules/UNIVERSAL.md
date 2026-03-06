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
- No mocks — test against real dependencies (testcontainers, sandboxes, kind)
- If a test cannot run against the real thing, skip it — do not mock it

## Communication Style

- Direct, concise, technically accurate
- No LLM cheerleading: "Great question!", "I'd be happy to help!"
- No American marketing hype: "Amazing!", "Game-changing!", "World-class!"
- Australian understated: "This should help", "Performance is improved"

## Web Search Before Code (MANDATORY — HARD ENFORCEMENT)

AI models have stale training data (often 6-18+ months old). Our projects use
bleeding-edge tools and libraries. Using outdated dependencies, deprecated APIs,
or old patterns wastes significant engineering time on remediation.

### RULE: Web Search ALL Dependency Versions (NO EXCEPTIONS)

**Every time** you add, update, or recommend a package/library/dependency:

1. **Web search for the CURRENT latest version** of that specific package.
   Your training data version is almost certainly wrong.
2. **Web search whether the package itself has been superseded.** The entire
   library may have been replaced (e.g., psycopg2 → psycopg 3, requests → httpx).
3. **Use the version from the web search result**, not from your training data.

This applies to: pip packages, npm packages, cargo crates, go modules, Docker
base images, Helm charts, Terraform providers — ALL dependencies at ALL levels.

**The extra search time ALWAYS saves remediation time. No exceptions.**

### RULE: Web Search Before Significant Implementation

Before writing any non-trivial implementation:

1. **Web search for the LATEST approach** to the problem using the CURRENT YEAR
   (see injected date above). Do NOT rely on training data patterns.
2. **Check for breaking changes** in the latest major versions of frameworks and
   libraries you plan to use.

### Common Traps (Examples — Not Exhaustive)

These are examples your training data gets WRONG. There are many more — always search.

| Wrong (Training Data) | Correct (Current) | Why |
|---|---|---|
| `psycopg2` / `psycopg2-binary` | `psycopg[binary]` (psycopg 3) | psycopg2 is legacy |
| `python-jose` | `joserfc` or `PyJWT` | python-jose is unmaintained |
| `requests` | `httpx` | async support, HTTP/2, modern API |
| `datetime.utcnow()` | `datetime.now(UTC)` | deprecated in Python 3.12 |
| `pkg_resources` | `importlib.metadata` | deprecated, slow |
| React class components | functional components + hooks | classes are legacy |
| `moment.js` | `date-fns` or `Temporal` | moment is in maintenance mode |
| Webpack (new projects) | Vite | unless project already uses Webpack |
| `urllib3` directly | `httpx` or `requests` | low-level, not needed |
| `flask` (new APIs) | `fastapi` or `litestar` | unless project uses Flask |

**CRITICAL:** When in doubt, SEARCH. A 30-second web search prevents hours of
debugging deprecated APIs, missing features, or security vulnerabilities.

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
| Version | `git describe --tags` or `VERSION` | STATE.md, memory |
| Tasks | `TODO.md` | STATE.md, memory |
| History | `git log` | STATE.md, memory |
| Changelog | `CHANGELOG.md` (semantic-release) | STATE.md, memory |
| Static context | `STATE.md` (CLAUDE.md symlink) | memory |
| Personal prefs | auto-memory | STATE.md |

### STATE.md vs Auto-Memory

These are two separate persistence layers. Do not blur them.

**STATE.md** (shared, committed, loaded via CLAUDE.md symlink):
- Project architecture, decisions, tech stack, external deps
- Visible to the whole team — authoritative source of project context
- If memory contradicts STATE.md, **STATE.md wins**

**Auto-memory** (`~/.claude/projects/.../memory/`):
- Personal preferences, debugging insights, workflow patterns
- Per-developer, local only, never committed
- Do NOT duplicate STATE.md content into memory — read STATE.md directly
- Good for: "user prefers X", "learned that Y causes Z", "avoid pattern W"

## Licensing

- Default: FSL-1.1-ALv2
- Repos: always `--private` unless explicitly requested public
- No GPL/AGPL/SSPL dependencies permitted
- Never create custom LICENSE files — use the template

## Temporary Files

- Dev/CI: `./.tmp/` (project-scoped, gitignored)
- Production: use language tempfile libraries with auto-cleanup
- Never hardcode `/tmp`, never use predictable names
