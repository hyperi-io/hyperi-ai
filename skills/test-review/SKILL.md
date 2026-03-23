---
name: test-review
description: >-
  Test coverage review and remediation. Audits test structure, coverage gaps,
  AI-generated test quality, missing edge cases, and enforces 80% coverage.
  Use when the user says /test-review, asks to review tests, or after major
  feature work.
user-invocable: true
---

# Test Coverage Review & Remediation

Audit tests for structure compliance, coverage gaps, AI-generated test quality
traps, and missing edge/failure/boundary cases. Fix what's found.

## When to Use

- After completing a feature branch (before PR)
- When the user asks to review test quality
- When coverage drops below 80%
- After AI-generated code has been committed (the tests are likely hollow)

## Procedure

### 1. Check Test Structure

Verify the project follows the standard test directory layout.

**Rust:**
```
tests/
├── common/mod.rs or common/main.rs  # Shared helpers
├── fixtures/                         # Static test data
├── integration/main.rs              # Single binary, submodules
├── e2e/main.rs                      # Real infra, #[ignore]
└── smoke.rs                         # Mandatory startup test
```

**Python:**
```
tests/
├── conftest.py                      # Shared fixtures
├── unit/                            # Fast, isolated
├── integration/                     # External deps
├── e2e/                             # Full stack
├── fixtures/                        # Static data
└── smoke/test_startup.py            # Mandatory startup test
```

**If structure doesn't match:** Propose restructure. Integration tests in a
single binary (Rust) or directory (Python) — not flat files.

### 2. Verify Mandatory Smoke Test

Every project MUST have a startup smoke test that boots the app with default
config and checks it doesn't crash. This is the single highest-value test.

```bash
# Check it exists
# Rust:
grep -r "test_startup\|smoke" tests/smoke.rs tests/integration/ 2>/dev/null
# Python:
find tests/smoke/ -name "test_startup*" 2>/dev/null
```

**If missing:** Write one immediately. It takes 5 minutes and catches the
regressions that cause production outages on deploy.

### 3. Run Coverage

```bash
# Rust
cargo tarpaulin --skip-clean --out Html 2>&1 | tail -5

# Python
uv run pytest --cov=src --cov-report=term-missing | tail -20

# Go
go test -cover ./... | grep -E "coverage:|ok"
```

**Threshold: 80% minimum.** If below 80%, identify the uncovered modules and
add tests before proceeding.

### 4. Map Test Coverage by Module

List every source module and count its tests. Identify modules with zero or
insufficient test coverage.

```bash
# Rust — list modules with inline tests
grep -rl '#\[cfg(test)\]' src/ | sort

# Rust — list modules WITHOUT inline tests
comm -23 \
  <(find src -name "*.rs" -not -name "mod.rs" | sort) \
  <(grep -rl '#\[cfg(test)\]' src/ | sort)

# Python — list source files without corresponding test files
# Compare src/**/*.py against tests/**/test_*.py
```

For each uncovered module, assess:
- Does it contain logic worth testing? (Skip pure re-exports, trivial wrappers)
- What are the key functions/methods?
- What are the error paths?

### 5. AI Test Quality Audit

> Derek's hard lessons learned from trusting AI-generated test suites.

Check every test file for these traps:

| Trap | How to detect | Fix |
|------|--------------|-----|
| **Happy-path only** | No tests with invalid/error inputs | Add failure tests for every error path |
| **Assertion-free** | `grep -c "assert" test_file` = 0 | Every test MUST assert something |
| **Mirror tests** | Assertion recalculates the same logic as implementation | Assert against known constants or business rules |
| **Missing boundaries** | No tests with 0, empty, MAX, overflow, None/null | Add boundary value tests |
| **No error path tests** | Count error variants vs tests that trigger them | At least one test per error variant |
| **Shallow coverage** | Tests only call top-level functions | Test internal edge cases via focused unit tests |
| **Missing concurrency** | Async code with no timeout/cancel/race tests | Add `tokio::time::pause()` or equivalent tests |

**Quick check command:**

```bash
# Rust — ratio of assert! to #[test] (should be ≥2:1)
echo "Tests: $(grep -rc '#\[test\]' tests/ src/ | awk -F: '{s+=$NF} END{print s}')"
echo "Asserts: $(grep -rc 'assert' tests/ src/ | awk -F: '{s+=$NF} END{print s}')"

# Python
echo "Tests: $(grep -rc 'def test_' tests/ | awk -F: '{s+=$NF} END{print s}')"
echo "Asserts: $(grep -rc 'assert' tests/ | awk -F: '{s+=$NF} END{print s}')"
```

If assert:test ratio is below 2:1, the tests are likely hollow.

### 6. Check Test Variety

For each tested module, verify the test suite covers:

- [ ] **Happy path** — normal operation with valid input
- [ ] **Error paths** — every error variant/exception triggered
- [ ] **Boundary values** — zero, one, empty, max, overflow
- [ ] **Invalid input** — malformed, wrong type, null/None
- [ ] **Edge cases** — unicode, special chars, very large payloads
- [ ] **Concurrency** — timeouts, cancellation, race conditions (if async)
- [ ] **Configuration** — default config loads, env overrides work
- [ ] **Startup** — app boots without panic on default config

### 7. Remediate Gaps

For each gap found in steps 4-6:

1. Write the missing test (test-first — write it, verify it fails against broken code)
2. Run the test (verify it passes against current code)
3. Commit

**Priority order:**
1. Startup smoke test (if missing)
2. Error path tests (most likely to catch real bugs)
3. Boundary value tests
4. Coverage gaps in critical modules
5. Concurrency tests for async code

### 8. Re-run Coverage

After remediation, re-run coverage and verify ≥80%.

```bash
# Rust
cargo tarpaulin --skip-clean 2>&1 | grep "coverage:"

# Python
uv run pytest --cov=src --cov-fail-under=80
```

### 9. Report

Present a summary table:

```
Module              | Tests | Coverage | Gaps Fixed
--------------------|-------|----------|------------
config/             |    18 |    92%   | Added filter validation edge case
pipeline/           |     8 |    85%   | Added error path for missing output
scheduler/          |     9 |    88%   | Added backpressure stall test
...
TOTAL               |   161 |    83%   | 7 gaps remediated
```

## Integration with CI

If the project uses hyperi-ci, coverage is enforced automatically:

```yaml
# .hyperi-ci.yaml
test:
  coverage_threshold: 80
```

Coverage below threshold blocks the merge. No exceptions.

## Anti-Patterns This Skill Catches

- "Tests pass" with 30% coverage
- AI-generated test suite with 100 happy-path tests and zero failure tests
- Test files that exist but contain no assertions
- Integration test files that compile as separate binaries (Rust compile-time waste)
- Missing startup smoke test
- Tests that never run in CI (not wired into any stage)
