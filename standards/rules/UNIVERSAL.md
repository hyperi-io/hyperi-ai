<!-- override: manual -->
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

## Web Search Before Code (MANDATORY)

AI training data is months stale. NEVER use a dependency version from training data.

**Key rule:** ALWAYS web search for current versions before adding any dependency,
using any library API, or writing non-trivial implementations.

The full protocol is in the `bleeding-edge` skill (loads automatically for
dependency-related work). Quick reference of common traps:

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

**When in doubt, SEARCH.** 30 seconds of searching prevents hours of debugging.

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
| Version | `git describe --tags` or `VERSION` | STATE.md, agent memory |
| Tasks | `TODO.md` | STATE.md, agent memory |
| History | `git log` | STATE.md, agent memory |
| Changelog | `CHANGELOG.md` (semantic-release) | STATE.md, agent memory |
| Static context | `STATE.md` (symlinked as CLAUDE.md, CURSOR.md, etc.) | agent memory |
| Personal prefs | agent memory (if available) | STATE.md |

### STATE.md vs Agent Memory

STATE.md is the shared, committed, authoritative project context. Every
agent reads it (via its own symlink: CLAUDE.md, CURSOR.md, GEMINI.md, etc.).

If your agent has persistent memory across sessions, keep it separate:

- **STATE.md** — shared team knowledge: architecture, decisions, tech stack
- **Agent memory** — personal learning: user preferences, debugging insights
- Do NOT duplicate STATE.md content into agent memory — read STATE.md directly
- If agent memory contradicts STATE.md, **STATE.md wins**

## Licensing

- Default: FSL-1.1-ALv2
- Repos: always `--private` unless explicitly requested public
- No GPL/AGPL/SSPL dependencies permitted
- Never create custom LICENSE files — use the template

## Repository Naming

| Prefix | Scope |
|---|---|
| `hyperi-*` | Company-wide / product-agnostic |
| `dfe-*` | DFE product |
| `edge-*` | Edge Stream Hub |

- `hyperi-*` for shared libs and tooling that serve the whole company
- `dfe-*` for DFE-specific; `edge-*` for Edge Stream Hub
- When scope spans products, use `hyperi-*`
- External forks: retain upstream name (e.g. `ClickHouse`)
- Format: lowercase, hyphen-separated — no underscores, no camelCase
- 1–3 words after prefix; avoid redundant suffixes (`-service`, `-app`, `-repo`)

## Temporary Files

- Dev/CI: `./.tmp/` (project-scoped, gitignored)
- Production: use language tempfile libraries with auto-cleanup
- Never hardcode `/tmp`, never use predictable names

---

## Claude Code

Auto-memory lives at `~/.claude/projects/<hash>/memory/`. It persists
across sessions but is local and per-developer — never committed.

- Do NOT copy STATE.md content into memory — just read STATE.md
- Good memory entries: "user prefers X", "learned Y causes Z", "avoid W"
- Bad memory entries: project architecture, key files, tech stack (that's STATE.md)
- MEMORY.md is capped at 200 lines — keep it concise, link to topic files

## Cursor IDE

Cursor rules live in `.cursor/rules/*.mdc` (converted from standards/rules/).
Notepads are per-user and ephemeral — do not rely on them for shared context.

## Gemini Code

Gemini settings live in `.gemini/`. Memory features may vary by version —
same principle applies: do not duplicate STATE.md into agent-local storage.
