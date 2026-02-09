# Code Review Standards

**Purpose:** Condensed code review checklist from common standards. Load with language-specific standards for full context.

---

## Critical Issues (REJECT)

### Error Handling

```text
❌ Swallowed errors (empty catch, ignored Result/error)
❌ Generic error messages ("An error occurred")
❌ Missing error context (no file path, line number, input values)
❌ Panic/exit in library code (only allowed in main/CLI)
❌ Logging errors without returning/propagating them
```

**Required pattern:**

```text
✅ Errors include: what failed + why + context (inputs, state)
✅ Errors propagate up with added context at each layer
✅ User-facing errors are actionable ("File X not found" not "IO error")
```

### Security

```text
❌ Hardcoded secrets, API keys, passwords
❌ SQL/command injection (string concatenation with user input)
❌ Path traversal (../../../etc/passwd)
❌ Deserialising untrusted data without validation
❌ Logging sensitive data (passwords, tokens, PII)
❌ Disabled TLS verification (skip_verify, INSECURE flags)
```

**Required pattern:**

```text
✅ Secrets from environment variables or secret managers
✅ Parameterised queries, not string interpolation
✅ Input validation at system boundaries
✅ Structured logging with PII fields excluded
```

### Testing

```text
❌ No tests for new functionality
❌ Tests that mock the thing being tested
❌ Tests with hardcoded sleeps (time.sleep, setTimeout)
❌ Tests that depend on execution order
❌ Flaky tests (pass sometimes, fail sometimes)
```

**Required pattern:**

```text
✅ Real implementations over mocks (use fakes, test DBs, containers)
✅ Tests are deterministic and isolated
✅ Test names describe the scenario, not the method
✅ Edge cases covered: empty, null, boundary values, errors
```

---

## Code Quality (IMPROVE)

### Design Principles

```text
⚠️ Functions >50 lines (extract helpers)
⚠️ >3 levels of nesting (early returns, extract)
⚠️ Magic numbers/strings (use named constants)
⚠️ Boolean parameters (use enums or options objects)
⚠️ Comments explaining "what" not "why"
⚠️ Dead code, unused imports, TODO comments in production
```

**Preferred patterns:**

```text
✅ Single responsibility - functions do one thing
✅ Early returns reduce nesting
✅ Self-documenting names over comments
✅ Composition over inheritance
✅ Immutability by default
```

### Code Style

```text
⚠️ Inconsistent naming (mixedCase vs snake_case)
⚠️ Overly clever one-liners (prefer readable)
⚠️ Deep callback nesting (use async/await, promises, channels)
⚠️ Repeated code blocks (extract function or use language idioms)
```

---

## Review Output Format

When reviewing code, structure findings as:

```markdown
## 🔴 Critical Issues (must fix before merge)
- [file:line] Issue description → Suggested fix

## 🟡 Improvements (should fix)
- [file:line] Issue description → Suggested fix

## 🟢 Suggestions (nice to have)
- [file:line] Minor improvement

## ✅ What's Good
- Positive observations (testing coverage, clean patterns, etc.)
```

---

## Quick Reference

| Category | Red Flag | Fix |
|----------|----------|-----|
| Errors | Empty catch/except | Log + rethrow or handle properly |
| Errors | `.unwrap()` / `panic!` in lib | Return Result, propagate `?` |
| Security | `password = "..."` | Use env var or secret manager |
| Security | `f"SELECT * FROM {table}"` | Use parameterised query |
| Testing | `@mock.patch` everything | Use real impl or test double |
| Testing | `time.sleep(5)` | Use polling with timeout |
| Design | 100-line function | Extract into smaller functions |
| Design | `if x: if y: if z:` | Early returns or guard clauses |
| Style | `# increment counter` | Delete obvious comments |
| Style | Copy-paste code blocks | Extract function or macro |

---

**Full standards:** `ai/standards/common/` (individual files for deep dives)
