---
name: bleeding-edge
description: >-
  Bleeding-edge dependency and API protection. MANDATORY before adding
  packages, using library APIs, or writing non-trivial implementations.
  AI training data is months stale — web search for current versions first.
  Use Context7 MCP if available for live library documentation.
user-invocable: false
---
<!-- Project: HyperI AI -->

# Bleeding-Edge Protection

## The Iron Law

```
NEVER USE A DEPENDENCY VERSION FROM TRAINING DATA
ALWAYS WEB SEARCH FOR THE CURRENT VERSION FIRST
```

AI models have stale training data (often 6-18+ months old). Our projects use
bleeding-edge tools and libraries. Using outdated dependencies, deprecated APIs,
or old patterns wastes significant engineering time on remediation.

**This is the single biggest source of AI coding errors in production.**

## Mandatory Triggers

This protocol is MANDATORY whenever you:
- Add, update, or recommend ANY package, library, or dependency
- Use ANY third-party API or framework feature
- Specify Docker base images or container versions
- Reference Helm charts, Terraform providers, or cloud service versions
- Write non-trivial implementations using external libraries
- Suggest a technology choice or migration path

## The Protocol

### Step 1: Web Search for Current Version

**Every time** you reference a dependency:

1. **Web search for the CURRENT latest version** of that specific package.
   Your training data version is almost certainly wrong.
2. **Web search whether the package itself has been superseded.** The entire
   library may have been replaced (e.g., psycopg2 -> psycopg 3, requests -> httpx).
3. **Use the version from the web search result**, not from your training data.

This applies to: pip packages, npm packages, cargo crates, go modules, Docker
base images, Helm charts, Terraform providers — ALL dependencies at ALL levels.

### Step 2: Context7 MCP (If Available)

If Context7 MCP server is configured (check available MCP tools):

1. Use `resolve-library-id` to match the library name to a Context7 identifier
2. Use `query-docs` to fetch current documentation for the specific API you need
3. Use the returned documentation, NOT training data knowledge

**Rate-limit handling:**
- Context7 free tier: 1,000 requests/month, 60/hour
- If a Context7 call returns a rate-limit error (429):
  - Log a SINGLE warning: "Context7 rate limit reached — falling back to web search"
  - Do NOT retry or spam the API
  - Fall back to web search for the remainder of the session
  - Do NOT mention the rate limit again unless the user asks
- For higher limits: set `CONTEXT7_API_KEY` in project `.env` file

**Fallback chain:** Context7 -> WebSearch -> explicitly state uncertainty

### Step 3: Web Search Before Implementation

Before writing any non-trivial implementation:

1. **Web search for the LATEST approach** to the problem using the CURRENT YEAR.
   Do NOT rely on training data patterns.
2. **Check for breaking changes** in the latest major versions of frameworks and
   libraries you plan to use.

## Common Traps (Training Data Gets These WRONG)

These are examples — there are many more. Always search.

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

**This table is illustrative, not exhaustive. Always search.**

## Version Pinning Rules

When adding dependencies:
- Pin to exact versions in lock files (uv.lock, package-lock.json, Cargo.lock)
- Use compatible ranges in manifests (pyproject.toml, package.json, Cargo.toml)
- Never use `latest` tag in Docker images — pin to specific version
- Document WHY a specific version was chosen if it's not the latest

## Red Flags — STOP and Search

If you catch yourself:
- Typing a version number from memory
- Using an API pattern you "know" works
- Recommending a library without checking if it's still maintained
- Assuming a Docker base image tag exists
- Using a CLI flag without checking the current version's options

**STOP. Search. 30 seconds of searching prevents hours of debugging.**

## Deprecation Detection

When web search reveals a dependency is:
- **Deprecated:** Find the recommended replacement. Migrate.
- **Unmaintained (no commits in 12+ months):** Flag to the user. Find alternatives.
- **Superseded (new major version):** Use the new version. Check migration guide.
- **Security advisory:** Flag immediately. Do not use.

## The Extra Search Time ALWAYS Saves Remediation Time

No exceptions. No shortcuts. No "I'm pretty sure." Search first, code second.
