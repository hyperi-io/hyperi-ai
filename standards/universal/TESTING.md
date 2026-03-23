---
name: testing-standards
description: Test organisation, directory structure, CI integration, and test-first development. Mandatory for all HyperI projects.
rule_paths:
  - "**/*.py"
  - "**/*.rs"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/tests/**"
  - "**/*_test.*"
  - "**/*.test.*"
  - "**/*.spec.*"
---

# Testing Standards

80% minimum coverage. Real dependencies over mocks. Every project gets a smoke test.

---

## Directory Structure

Every project uses the same layout. Language-specific adaptations below, but the directories are universal.

```text
tests/
├── common/           # Shared helpers, factories, skip macros
├── fixtures/         # Static test data (YAML, JSON, SQL, certs)
├── unit/             # Fast, isolated — no external deps
├── integration/      # Wiremock, API tests, config validation
├── e2e/              # Real infrastructure (Kafka, Docker, cloud APIs)
└── smoke.{ext}       # Startup smoke test (MANDATORY)
```

- `common/` is for helpers, NOT test cases
- `fixtures/` is for static data files, NOT code
- `smoke` test runs on every push — catches init panics before production does
- `e2e/` tests require infrastructure — marked `#[ignore]` (Rust) or `@pytest.mark.e2e` (Python)

### Language Adaptations

| Language | Unit tests | Integration/E2E tests | Shared helpers |
|----------|-----------|----------------------|----------------|
| Rust | Inline `#[cfg(test)]` in `src/` | `tests/integration/mod.rs` + submodules | `tests/common/mod.rs` |
| Python | `tests/unit/test_*.py` | `tests/integration/test_*.py` | `tests/conftest.py` (hierarchical) |
| Go | `*_test.go` co-located | `tests/integration/*_test.go` | `tests/common/helpers.go` |
| JS/TS | `*.test.ts` co-located | `tests/integration/*.test.ts` | `tests/common/setup.ts` |
| Bash | `tests/*.bats` | `tests/integration/*.bats` | Source guard pattern |

---

## Runtime SLOs

Enforce these. Slow tests don't get run. Tests that don't run don't exist.

| Category | Budget | Trigger | What fails if exceeded |
|----------|--------|---------|----------------------|
| Smoke | 1 min | Every push | CI blocks merge |
| Unit | 3 min | Every push | CI blocks merge |
| Integration | 5 min | Every push | CI blocks merge |
| E2E | 20 min | PR to `release` only | CI blocks release merge |
| Benchmarks | 10 min | Weekly / manual | Advisory only |

---

## Startup Smoke Test

**MANDATORY.** Highest-value single test in any project. Catches init panics, missing config defaults, broken dependency wiring — the things that cause production outages on deploy.

Every project gets one. It boots the app with default config and checks it doesn't crash.

```python
# Python
def test_app_boots_with_default_config():
    app = create_app(Config())
    assert app.is_ready()
```

```rust
// Rust
#[tokio::test]
async fn test_startup_boots_with_default_config() {
    let config = Config::default();
    let result = App::new(config).await;
    assert!(result.is_ok());
}
```

```go
// Go
func TestAppStartsWithDefaults(t *testing.T) {
    app, err := NewApp(DefaultConfig())
    require.NoError(t, err)
    assert.True(t, app.IsReady())
}
```

---

## CI Stage Mapping

### With hyperi-ci

The directory structure maps directly to CI stages. No extra config needed — hyperi-ci reads the structure.

| Directory | CI Stage | Trigger |
|-----------|----------|---------|
| Unit (inline / `tests/unit/`) | `quality` | Every push |
| `tests/integration/` | `test` | Every push |
| `tests/e2e/` | `test:e2e` | PR to `release` |
| Smoke | `test:smoke` | Every push (fast subset) |
| `benches/` | `benchmark` | Weekly / manual |

### Without hyperi-ci

Use filters/markers to separate categories:

```bash
# Rust
cargo nextest run                          # unit + integration
cargo nextest run -- --ignored             # e2e (needs infra)
cargo nextest run -E 'test(smoke)'         # smoke only

# Python
pytest tests/unit/ tests/integration/      # unit + integration
pytest tests/e2e/                          # e2e (needs infra)
pytest -m smoke                            # smoke only
```

---

## Shared Helpers (`tests/common/`)

Put reusable test infrastructure here. Not test cases — those go in `unit/`, `integration/`, `e2e/`.

**Goes in `common/`:**

- Test mode detection (Docker vs remote cluster)
- Infrastructure connection helpers (Kafka config, DB sessions)
- Skip macros/decorators for missing infrastructure
- Test data factories
- Custom assertion helpers

**Does NOT go in `common/`:**

- Actual test cases
- Static data files (use `fixtures/`)
- App configuration (use `fixtures/`)

### Why subdirectory, not top-level file

- **Rust:** `tests/common.rs` compiles as a separate test binary (shows "running 0 tests"). `tests/common/mod.rs` does not.
- **Python:** Root-level `conftest.py` is fine (pytest auto-discovers). Per-directory `conftest.py` scopes fixtures.
- **General:** Keeps the test runner output clean. Only actual test files at the top level.

---

## Coverage

- 80% minimum for all projects (CI-enforced)
- 90% for AI-generated code
- Measure with: `cargo tarpaulin` (Rust), `pytest-cov` (Python), `go test -cover` (Go)
- Coverage that never runs in CI is fiction

---

## Test-First Development

Write tests BEFORE implementation. Not after. Not "later". Before.

**Workflow:**

1. Understand the current behaviour
2. Write tests defining success criteria
3. Run tests — new features should fail, existing behaviour should pass
4. Implement
5. Run tests — all pass
6. Commit

**One test at a time.** Write 1 test, implement, run, pass, commit. Not 10 tests then implement.

| Don't | Do | Why |
|-------|-----|-----|
| Write 10 tests then implement | 1 test, implement, pass, commit, repeat | Isolates failures |
| Let AI write your tests | Write tests yourself, let AI implement | Tests are YOUR specification |
| Test how code works internally | Test what it does (observable behaviour) | Refactoring shouldn't break tests |

---

## Language-Specific Patterns

### Python (pytest)

```text
tests/
├── conftest.py           # Session-scoped shared fixtures
├── unit/
│   ├── conftest.py       # Unit-specific fixtures
│   └── test_models.py
├── integration/
│   ├── conftest.py       # Integration fixtures (testcontainers)
│   └── test_api.py
├── e2e/
│   ├── conftest.py
│   └── test_workflows.py
├── fixtures/
│   └── sample_data.json
└── smoke/
    └── test_startup.py
```

**Fixture scoping:**

| Scope | Use for | Example |
|-------|---------|---------|
| `function` (default) | Isolated per-test state | DB transactions |
| `module` | Shared within file | Expensive resource init |
| `session` | Shared across entire run | DB engine, HTTP pool |

**Rules:**

- Use `yield` for teardown (not `return`)
- Never import `conftest.py` directly — pytest auto-discovers it
- Per-directory `conftest.py` scopes fixtures to that subtree
- Use marks (`@pytest.mark.integration`, `@pytest.mark.e2e`, `@pytest.mark.slow`) for CI filtering
- `conftest.py` at root level for broadly shared fixtures, per-directory for localised ones

### Rust (cargo nextest)

See the **Rust Standards** document for the full test section, including:

- Single-binary integration test pattern (3x compile-time win)
- `tests/common/mod.rs` shared helpers
- `#[ignore]` for infrastructure-dependent tests
- Nextest process-per-test model (safe `env::set_var`)
- Property-based testing with `proptest`
- Benchmarks with `criterion`

### Go (testing + testify)

- Co-locate unit tests (`*_test.go` next to source)
- Table-driven tests as the standard pattern
- `testify/assert` + `testify/require` for assertions
- `t.Run()` for subtests

### Bash (BATS)

- Source guard pattern required (`if [[ "${BASH_SOURCE[0]}" == "${0}" ]]`)
- `setup()` / `teardown()` for fixtures
- Use `run` for capturing exit codes

---

## Anti-Patterns

| Anti-pattern | Fix |
|-------------|-----|
| Tests that pass when run alone but fail together | Shared mutable state — use proper fixtures |
| Flaky tests left in the suite | Fix immediately or delete. Flaky tests erode trust. |
| Slow test suite nobody runs | Enforce runtime SLOs. Parallelise. |
| No smoke test | Add one now. Single highest-value test. |
| Tests only in CI, never run locally | If it doesn't run locally, developers won't write them |
| Mocking everything | Test against real dependencies. Mocks hide bugs. |

---

## CI Enforcement

```bash
# hyperi-ci
hyperi-ci check         # quality + test stages

# Manual
cargo nextest run       # Rust
pytest                  # Python
go test ./...           # Go
```

**Coverage threshold: 80% minimum.** CI blocks merge if coverage drops below threshold.
