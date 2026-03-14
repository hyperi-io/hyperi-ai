<!-- override: manual -->
# Testing Standards

## Structure and Coverage

- Organize tests: `tests/unit/`, `tests/integration/`, `tests/e2e/`
- Minimum 80% code coverage, enforced by CI
- All projects MUST have unit tests for core logic, integration tests for external dependencies
- Tests run before every build/release

## Frameworks

- Python: pytest
- Go: testing + testify
- JS/TS: Jest or Vitest
- Rust: cargo test
- Bash: BATS

## Test Naming and Scope

- Use clear, descriptive test names following language conventions
- Name explains WHAT is being tested
- 3–7 tests per function: happy path, error conditions, edge cases, business rules

## Test-Driven Development (TDD)

<!-- inspired-by: obra/superpowers test-driven-development (MIT) -->

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write the test first. Watch it fail. Write minimal code to pass.
If you didn't watch the test fail, you don't know if it tests the right thing.

### RED-GREEN-REFACTOR Cycle

1. **RED** — write ONE minimal test showing what should happen. Clear name,
   tests real behaviour, one thing only.
2. **Verify RED** — run the test. Confirm it fails for the expected reason
   (feature missing, not typos). Test passes immediately? You're testing
   existing behaviour — fix the test.
3. **GREEN** — write the SIMPLEST code to pass the test. Don't add features,
   refactor other code, or "improve" beyond what the test requires.
4. **Verify GREEN** — run the test. Confirm it passes. Confirm other tests
   still pass. Output clean (no errors, warnings).
5. **REFACTOR** — clean up (remove duplication, improve names, extract helpers).
   Keep tests green. Don't add behaviour.
6. **Repeat** — next failing test for next behaviour.

### When to Use TDD

- New features, bug fixes, refactoring, behaviour changes
- Write tests yourself; let AI implement to pass them — tests ARE the specification

**Exceptions (ask the user):** throwaway prototypes, generated code, config files.

### Wrote Code Before the Test?

Delete it. Start over. Don't keep it as "reference." Don't "adapt" it.
Implement fresh from tests.

### Test-First Workflow (Existing Code)

1. Understand current behaviour
2. Write tests for success criteria (including preserving existing behaviour)
3. Run tests — new tests should fail, existing-behaviour tests should pass
4. Implement changes
5. Run tests — all should pass

### Common TDD Rationalisations

| Excuse | Reality |
|---|---|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "Test hard = skip it" | Hard to test = hard to use. Listen to the test. |
| "TDD will slow me down" | TDD is faster than debugging. |
| "Manual test is faster" | Manual doesn't prove edge cases. Can't re-run. |

## Test Behaviour, Not Implementation

- ❌ `assert "for" in inspect.getsource(calculate_total)` — testing HOW
- ✅ `assert calculate_total([{"price": 10, "quantity": 2}]) == 20.0` — testing WHAT

## Incremental Test Cycle

- ❌ Write 10 tests → implement → run all (many failures)
- ✅ Write 1 test → implement → run → pass → commit → repeat

## Test Patterns

- **Regression tests:** Reference bug number in test name/docstring
- **Edge cases:** Empty input, zero values, large numbers, boundary conditions
- **Behaviour documentation:** Encode business rules as assertions with comments

## Language-Specific Guidance

### Python (pytest)

- Use classes to group related tests: `class TestCreateUser:`
- Use `pytest.raises(ExType, match="msg")` for error assertions
- Use fixtures in `conftest.py` for shared setup; yield for cleanup
- Fixture teardown via `yield` + rollback/cleanup after

### Go

- Use subtests: `t.Run("description", func(t *testing.T) { ... })`
- Use `require` for fatal preconditions, `assert` for test checks
- Use table-driven tests for input/output variations
- Use `assert.ErrorIs` / `assert.ErrorContains` for error checks

### JavaScript/TypeScript

- Use `describe`/`it` blocks; `beforeEach` for reset
- Use `await expect(...).rejects.toThrow("msg")` for async errors

### Rust

- Place tests in `#[cfg(test)] mod tests` inside source files
- Use `#[should_panic(expected = "msg")]` for panic assertions
- Use `.is_err()` and `.unwrap_err().to_string().contains()` for error checks

### Bash (BATS)

- Use `setup()` / `teardown()` for temp dirs and cleanup
- Use `run` to capture status and output: `[ "$status" -eq 0 ]`
- Use source guard pattern to enable BATS testing:
```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
```

## CI Integration

- Tests must pass before build: `./ci/run build` fails if tests fail
- Coverage threshold: 80% minimum in CI config
