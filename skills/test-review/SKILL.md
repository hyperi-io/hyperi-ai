---
name: test-review
description: >-
  Test workflow — audit existing tests AND add new ones. Forces edge cases,
  error paths, fuzzing decisions, the existing-or-docker fixture pattern, and
  coverage gates that LLMs reliably skip. Use when the user says /test-review,
  /add-tests, /tests, asks to review/add/write tests, after AI-generated code,
  or before/after implementing a feature.
user-invocable: true
---

# Test Workflow — Review & Add

Two phases: **Phase 1 — Audit** (review existing tests, find gaps) and
**Phase 2 — Add** (write new tests, TDD-style, with discipline LLMs skip).

The phases share a single source of truth — same coverage gates, same edge
case checklist, same fixture patterns. Run Phase 1 to find what's missing,
then Phase 2 to fix it. Or jump straight to Phase 2 if you already know what
needs writing (new feature, regression test, named coverage gap).

## When to Use

**Phase 1 (Audit) triggers:**
- After completing a feature branch (before PR)
- When the user asks to review test quality
- When coverage drops below 80%
- After AI-generated code has been committed (the tests are likely hollow)

**Phase 2 (Add) triggers:**
- "Add tests for module X"
- "Write tests for this feature"
- Before implementing a new feature (TDD)
- After Phase 1 identifies coverage or quality gaps
- Bug fix → write the regression test first

## Coverage Targets

- **80% floor** — repo-wide minimum, CI-enforced. Drops block merge.
- **90%+ goal** — what every project should aim at. Gap to 90% is tech debt.
- **≥90% hot path** — non-negotiable for `// HOT PATH` modules (parsers,
  transforms, pipeline core, SIMD).
- **90%+ AI-generated code** — extra scrutiny.

**Explicit exemptions** (must be configured in tool config, not implicit):
generated code (`*.pb.rs`, `_pb2.py`, codegen), test utilities (`tests/common/`,
`tests/fixtures/`), build scripts (`build.rs`, `setup.py`, `scripts/ci-*`),
vendored code (`vendor/`, `third_party/`).

## Phase 1: Audit Existing Tests

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

# TypeScript
pnpm vitest --coverage
```

**Floor: 80%.** Below 80% blocks merge — identify uncovered modules and add
tests via Phase 2 before proceeding.

**Goal: 90%+.** Anything between 80–90% is acceptable but flag the gap as
tech debt — note modules below 90% in the report.

**Hot path: ≥90% required.** Search for `HOT PATH` markers and verify each
marked module is at or above 90%:

```bash
grep -rn "HOT PATH" src/ | cut -d: -f1 | sort -u
```

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

### 7. Remediate Gaps → Phase 2

For each gap found in steps 4-6, switch to **Phase 2: Add Tests** below.

**Priority order:**
1. Startup smoke test (if missing) — single highest-value test
2. Error path tests (most likely to catch real bugs)
3. Hot path coverage gaps (must hit ≥90%)
4. Boundary value tests
5. Coverage gaps in critical modules
6. Concurrency tests for async code
7. Fuzz harnesses for parsers/byte-input handlers

Run Phase 2 once per gap. Commit each remediation separately so the audit
trail is clear.

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

---

## Phase 2: Add Tests

LLMs reliably know what good tests look like (the standards spell it out)
but reliably skip the discipline. This phase forces the gates: classify
category, identify external deps, enumerate edge cases, decide on fuzzing,
write one at a time, verify with mutation-style sanity check.

### 2.1 Identify Scope

What is being tested? Be specific:

- A new module / function / class
- A feature spanning multiple modules
- A bug fix (regression test FIRST, then fix)
- A coverage gap from Phase 1

If unclear, ASK — do not guess. Vague scope produces shallow tests.

### 2.2 Read the Implementation

Read the actual code. Identify:

- Public API surface (what callers actually use)
- Error paths — every `Err(...)`, `raise`, `throw`, returned error
- External dependencies — DB, HTTP, Kafka, file I/O, env vars
- Concurrency — async, threads, channels, locks
- Hot path markers — `// HOT PATH` comments (these need ≥90%)

### 2.3 Read Existing Test Patterns

REUSE existing fixtures and conventions. Do not re-invent.

```bash
ls tests/common/ tests/fixtures/ 2>/dev/null
cat tests/conftest.py 2>/dev/null            # Python
cat tests/common/mod.rs 2>/dev/null          # Rust
grep -rl "<nearby_module>" tests/            # Existing patterns
```

### 2.4 Web Search Test Library APIs

Verify CURRENT versions and APIs of test libraries before generating code.
Training data drifts fast for testing libs:

- testcontainers (Python/Rust/Go) — image syntax, version
- hypothesis / proptest / fast-check — current API
- pytest-asyncio / nextest — config knobs
- vitest — coverage config

Use Context7 MCP if available, else web search. DO NOT trust training data
for testcontainers image names or fixture decorators — they change.

### 2.5 Classify Each Test

| Category | Trigger | Goes In |
|---|---|---|
| **Unit** | No external deps, fast (<100ms) | `tests/unit/` or co-located |
| **Integration** | External service (DB, broker, HTTP) | `tests/integration/` |
| **E2E** | Full stack, real infra | `tests/e2e/` (`#[ignore]` / `@e2e`) |
| **Smoke** | Boots app with default config | `tests/smoke*` (one per project) |

Wrong category = wrong CI stage = test never runs in the right place.

### 2.6 External Service Decision (Integration Tests)

If the test needs an external service, follow the **existing-or-docker**
pattern from TESTING.md. The fixture MUST:

1. Check for env var pointing at existing service (`POSTGRES_URL`,
   `KAFKA_BROKERS`, `CLICKHOUSE_HOST`, etc.)
2. If set → verify reachable, then connect to existing service
3. If unset → spin up via testcontainers with **pinned** image version

Same test code. Both paths. Document the env var in `tests/README.md`.

```python
# Python — pytest fixture
@pytest.fixture(scope="session")
def postgres_url():
    if url := os.getenv("POSTGRES_URL"):
        wait_for_postgres(url, timeout=5)
        return url
    with PostgresContainer("postgres:16") as pg:
        yield pg.get_connection_url()
```

```rust
// Rust — OnceLock-managed
fn kafka_brokers() -> &'static str {
    static BROKERS: OnceLock<String> = OnceLock::new();
    BROKERS.get_or_init(|| {
        std::env::var("KAFKA_BROKERS").unwrap_or_else(|_| {
            start_kafka_container().bootstrap_servers()
        })
    })
}
```

DO NOT skip this pattern. DO NOT only support Docker. DO NOT only support
existing services. Both must work — CI defaults to Docker, devs with shared
clusters use existing-service path.

**Pinned image versions:** `postgres:16.2`, never `postgres:latest`.

**Service matrix:**

| Service | Existing-service env var | Docker image |
|---|---|---|
| PostgreSQL | `POSTGRES_URL` / `DATABASE_URL` | `postgres:16` |
| Kafka | `KAFKA_BROKERS` | `confluentinc/cp-kafka` |
| Redis | `REDIS_URL` | `redis:7` |
| ClickHouse | `CLICKHOUSE_HOST` + `CLICKHOUSE_PORT` | `clickhouse/clickhouse-server` |
| OpenBao / Vault | `BAO_ADDR` + `BAO_TOKEN` | `openbao/openbao` |
| MinIO / S3 | `S3_ENDPOINT` + `S3_ACCESS_KEY` | `minio/minio` |

### 2.7 Fuzz Harness Decision

Does the code take untrusted bytes? Parsers, deserialisers, protocol
handlers, regex inputs from external sources, file format readers — all
need a fuzz harness alongside unit tests.

| Language | Tool | Location |
|---|---|---|
| Rust | `cargo fuzz add <target>` | `fuzz/fuzz_targets/` |
| Python | `hypothesis` (property), `atheris` (coverage-guided) | `tests/fuzz/` |
| Go | `func FuzzX(f *testing.F)` (Go 1.18+) | `*_test.go` |
| TypeScript | `fast-check` (property-based) | `*.test.ts` |
| C++ | `libFuzzer` / OSS-Fuzz | `fuzz/` |

If you decide NOT to add a fuzz target for parsing code, document the
reason in the PR description.

### 2.8 Build Test Checklist

For each function/method/path under test, enumerate required cases. Default
checklist (omit only with explicit justification):

- [ ] Happy path — valid input, expected output
- [ ] Each error variant — one test per `Err(...)` / exception class
- [ ] Boundary values: `0`, `1`, max, empty, `None`/`null`/`undefined`
- [ ] Numeric edges: `NaN`, infinity, overflow, negative
- [ ] Malformed input — wrong type, truncated, garbage bytes
- [ ] Unicode — non-ASCII, emoji, RTL, zero-width chars
- [ ] Large payload — at least one realistic-sized fixture
- [ ] If async: timeout, cancellation, concurrent calls
- [ ] If stateful: idempotency, ordering
- [ ] Configuration: default config works, env override works

Present the checklist to the user. Confirm before writing.

### 2.9 Write One Test at a Time

TDD workflow:

1. Write ONE test
2. Run it — verify it fails the way you expect (or passes against current
   correct code, but ONLY if it would fail against broken code — see 2.10)
3. If implementing alongside: write impl, re-run, pass
4. Commit
5. Repeat

DO NOT batch — never write 10 tests then implement. Each test in isolation.

### 2.10 Mutation-Style Sanity Check

After writing each test, ask: **"If I broke the implementation, would this
test fail?"**

If the answer isn't an obvious yes, the test is mirror-style and worthless.
Rewrite to assert observable behaviour, not the implementation.

Quick check: temporarily corrupt the impl (negate a condition, return wrong
value, swap operator). Test should fail. Restore impl.

### 2.11 No Mocks Policy

Per HyperI policy: no mocks. Test against real dependencies.

- DB: testcontainers Postgres, not a mock
- Kafka: testcontainers Kafka, not a fake broker
- HTTP server-under-test: real handler, real client
- HTTP downstream: wiremock ONLY for proprietary cloud APIs

Exception: time. Use `time-machine` (Python), `tokio::time::pause()` (Rust),
`time.Now()` injection (Go).

### 2.12 Smoke Test First

If the project lacks a smoke test, write it FIRST before anything else:

```python
def test_app_boots_with_default_config():
    app = create_app(Config())
    assert app.is_ready()
```

Same shape for Rust/Go/TS. Highest-value single test.

### 2.13 Verify

After writing tests, verify:

```bash
# Coverage delta vs baseline — must NOT have dropped
cargo tarpaulin --skip-clean              # Rust
uv run pytest --cov=src --cov-fail-under=80    # Python
go test -cover ./...                      # Go
pnpm vitest --coverage                    # TS

# Smoke test still passes
cargo nextest run -E 'test(smoke)'        # Rust
uv run pytest tests/smoke/ -v             # Python

# Full suite green
hyperi-ci check
```

Verify CI wiring — the new tests MUST be picked up:

```bash
cargo nextest list | grep <new_test_name>          # Rust
uv run pytest --collect-only | grep <new_test_name>    # Python
```

Tests outside the standard `tests/` directories will not run in CI.

---

## Integration with CI

If the project uses hyperi-ci, coverage is enforced automatically:

```yaml
# .hyperi-ci.yaml
test:
  coverage_threshold: 80
```

Coverage below threshold blocks the merge. No exceptions.

## Anti-Patterns This Skill Catches

**Audit catches (Phase 1):**
- "Tests pass" with 30% coverage
- AI-generated test suite with 100 happy-path tests and zero failure tests
- Test files that exist but contain no assertions
- Integration test files that compile as separate binaries (Rust compile-time waste)
- Missing startup smoke test
- Tests that never run in CI (not wired into any stage)
- Hot path modules below 90% coverage
- Coverage exemptions configured implicitly (or not at all)

**Writing catches (Phase 2):**
- Mocks instead of real dependencies via testcontainers
- Integration tests that only support Docker (no existing-service env var path)
- Integration tests that only support existing services (no Docker fallback)
- Latest-tagged Docker images (`postgres:latest` instead of `postgres:16.2`)
- Parsers / byte-input handlers shipped without a fuzz harness
- Batch test writing (10 tests then impl) instead of one-at-a-time TDD
- Mirror-style tests where assertion duplicates implementation logic
- Test library APIs guessed from training data (testcontainers fixture names drift)
- Tests placed outside standard `tests/` directories (never picked up by CI)

## What NOT to Do

- Never skip the existing-or-docker fixture pattern for integration tests
- Never write mocks — use real dependencies via testcontainers
- Never batch test writing (write 10, then implement) — one at a time
- Never write assertion-free tests
- Never write mirror tests (assertion duplicates impl logic)
- Never claim done without running coverage delta + smoke
- Never put tests outside the standard `tests/` directories
- Never skip fuzzing for parsers / byte-input handlers (or document why)
- Never trust LLM knowledge of test library APIs — web search / Context7
- Never write only happy-path tests — error paths are the point

## Related Skills

- **`bleeding-edge`** — verify test library versions and APIs are current.
  Composes with Phase 2.4.
- **`verification-before-completion`** — runs coverage and smoke before
  claiming done. Phase 2.13 calls this discipline out explicitly.
- **`superpowers:test-driven-development`** — TDD discipline (test before
  impl). Phase 2.9 embeds this workflow.
