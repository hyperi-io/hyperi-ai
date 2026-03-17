---
source: common/TESTING.md
---

<!-- override: manual -->
# Testing Standards

## Coverage and Structure

- 80% minimum coverage (90%+ for AI code), enforced by CI
- Structure: `tests/unit/`, `tests/integration/`, `tests/e2e/`
- Frameworks: pytest (Python), testing+testify (Go), Jest/Vitest (JS/TS), cargo test (Rust), BATS (Bash)

## Test-First Development

- Write tests BEFORE implementation — tests are your specification
- Run tests after each change, not in batches
- 3-7 tests per function: happy path, error conditions, edge cases, business rules

## Real Dependencies Only

- No mocks, patches, fakes, stubs, or test doubles
- Use testcontainers/Docker for databases, sandbox endpoints for APIs, kind/k3s for K8s
- If a test cannot run against the real dependency, skip it — do not mock it
- Time control (freezegun, faketime) is acceptable — it controls the environment, not a dependency

## Test Behaviour, Not Implementation

- Test WHAT code does, not HOW it does it
- Never inspect source code in tests
- Use regression tests with bug references for fixed issues

## CI Integration

- Tests must pass before build — `./ci/run build` fails if tests fail
- Coverage enforcement is automatic at 80% threshold
