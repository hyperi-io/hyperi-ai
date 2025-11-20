# Coding Standards Quick Reference

**One-page cheat sheet for HyperSec projects**

---

## Language-Agnostic Standards

### Design Principles

**SOLID:**
- **S**ingle Responsibility - one class, one reason to change
- **O**pen/Closed - open for extension, closed for modification
- **L**iskov Substitution - subtypes must substitute base types
- **I**nterface Segregation - no fat interfaces
- **D**ependency Inversion - depend on abstractions

**DRY:** Don't Repeat Yourself (but don't force abstraction)
**KISS:** Keep It Simple, Stupid (simplicity > cleverness)
**YAGNI:** You Aren't Gonna Need It (build only what's needed NOW)

### Code Style

✅ **DO:**
- Break down complex operations into clear steps
- Use intermediate variables with descriptive names
- Helper functions FIRST, main function LAST
- Comments explain WHY, not WHAT
- Never number comments (hard to refactor)

❌ **DON'T:**
- Dense one-liners requiring mental parsing
- Nested comprehensions/lambda chains
- Clever tricks that sacrifice readability

### Error Handling

**Security-first:**
- ❌ NEVER show stack traces to users
- ❌ NEVER expose DB schemas/file paths
- ✅ ALWAYS log full errors server-side
- ✅ ALWAYS show generic messages to users
- ✅ ALWAYS include request context (user_id, request_id, timestamp)

**Exception handling:**
- Catch specific exceptions first, generic last
- Never silently swallow exceptions
- Use custom exception classes for domain errors

**Never log:**
- Passwords, tokens, API keys
- Credit cards, SSNs, PII
- Private keys, certificates

### Testing

**Required:**
- Unit tests for core logic
- Integration tests for dependencies
- Minimum 80% coverage
- Tests run before build/release

**Structure:**
```
tests/
├── unit/         # Fast, isolated
├── integration/  # Component integration
└── e2e/          # End-to-end
```

### No Mocks in Production

❌ **NEVER:**
- Commit mock implementations
- Leave TODO comments in src/
- Use placeholder values
- Ship example/demo code as real features

✅ **ALWAYS:**
- Complete functionality before committing
- Handle all error cases
- Validate inputs and outputs
- Add tests verifying complete behavior

---

## Python-Specific Standards

### PEP 8 Compliance

**Naming:**
- `snake_case` - variables, functions, methods
- `PascalCase` - classes
- `UPPER_SNAKE_CASE` - constants
- `_private` - internal members

**Format:**
- 4 spaces (no tabs)
- 88 char line length (Black default)
- Import order: stdlib → third-party → local

**Type hints required:**
```python
def get_user(user_id: int) -> dict[str, str]:  # ✅ Good
def get_user(user_id):                          # ❌ Bad
```

### HS-CI Enforcement

**Automated checks:**
- `ruff` - PEP 8, import sorting (I rules), naming (blocking)
- `black` - Code formatting (blocking)
- `pyright` - Type checking (warnings only)
- `bandit` - Security scanning (blocking)
- `vulture` - Dead code detection (blocking)

**Run via:** `./ci/run test`

### HS-Lib Infrastructure

**Always use hs-lib (not custom implementations):**

| Need | Use |
|------|-----|
| Logging | `from hs_lib import logger` |
| Config | `from hs_lib.config import settings` |
| Runtime paths | `from hs_lib import get_runtime_paths` |
| Database URLs | `from hs_lib import build_database_url` |
| Metrics | `from hs_lib import create_metrics` |
| CLI | `from hs_lib import Application` |

**Why:** Zero-config, container-aware, production-ready, ENV-based

### Application Types

**Choose the right type:**
- **API** - FastAPI web services
- **Daemon** - Long-running background services
- **CLI** - Command-line tools (Typer mandatory)
- **Oneshot** - k8s Jobs/CronJobs
- **MCP** - AI tool integration servers

### Python Code Style

**❌ Bad (nested comprehension):**
```python
result = [[f(x) for x in row] for row in data if len(row) > 0]
```

**✅ Good (clear steps):**
```python
non_empty_rows = [row for row in data if len(row) > 0]
result = [[f(x) for x in row] for row in non_empty_rows]
```

---

## AI Code Assistant Guidelines

### Quality Warning

⚠️ **Research findings:**
- 4x higher defect rates vs human code
- 19% longer completion time
- More security vulnerabilities

### Best Practices

**DO:**
- Always review suggestions (don't blindly accept)
- Test thoroughly (AI code needs more tests)
- Security scan all AI-generated code
- Simplify prompts (complex = worse code)

**DON'T use AI for:**
- Security-critical code (auth, crypto)
- Complex algorithms
- Performance-critical code
- Regulatory/compliance code

**AI is good for:**
- Boilerplate generation
- Test case generation
- Documentation
- Simple CRUD operations

### Platform Context Limits

- **Claude Code:** 200k tokens (best for long context)
- **GitHub Copilot:** 8k-128k tokens (model-dependent)
- **Google Gemini:** 1M-2M tokens (largest context window)
- **Cursor:** Similar to Copilot

---

## Git Workflow

### Commit Messages

**Format:** `<type>(<scope>): <description>`

**Types (UNDERSTATE, not overstate):**
- `fix:` - Bug fixes, improvements, refactors (DEFAULT)
- `feat:` - NEW significant features (use sparingly)
- `chore:` - Dependencies, config, maintenance
- `docs:` - Documentation only
- `test:` - Tests only
- `perf:` - Performance only

**Examples:**
```
fix: update CI documentation           # ✅ Good
feat: add OAuth authentication         # ✅ Good (significant new feature)
feat: fix typo in README              # ❌ Bad (should be fix: or docs:)
```

### Branch Naming

**Format:** `<type>/<short-description>`

```
fix/null-pointer-exception
feat/oauth-login
docs/update-readme
```

---

## Character Restrictions

**File/directory naming:**
- Alphanumeric + `_-.` only
- No spaces, special chars
- Lowercase preferred

**See:** `CHARS-POLICY.md` for details

---

## Temporary Files

**Development/CI:** Always use `./.tmp/` (project-scoped)

**Production:**
- **Python:** `tempfile` module
- **Go:** `os.MkdirTemp()`, `os.CreateTemp()`
- **Node.js:** `tmp` or `temp` packages

**Security rules:**
- ❌ NEVER hardcode `/tmp` paths
- ❌ NEVER use predictable filenames
- ✅ ALWAYS use language-standard libraries
- ✅ ALWAYS use auto-cleanup (context managers, defer)

---

## Documentation

**ALWAYS document:**
- Public APIs (functions, classes, modules)
- Complex algorithms
- Non-obvious business logic
- Security considerations

**DON'T document:**
- Obvious code
- Implementation details that change frequently
- WHAT code does (code should be self-documenting)

**DO document:**
- WHY code does what it does
- Edge cases and gotchas
- Assumptions and constraints

---

## Performance

**General principles:**
- Profile before optimizing
- Optimize hot path first
- Use appropriate data structures
- Cache expensive computations

**Avoid:**
- N+1 queries
- Unnecessary nested loops
- Memory leaks (unclosed resources)
- Blocking operations in hot paths
- Excessive logging in production
