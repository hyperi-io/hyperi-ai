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

## Integration Tests: Use Real Binaries, Not Emulation

Integration tests SHOULD use the actual external tool binary where feasible. Don't write local emulation code to simulate what a real tool does — you'll spend more time maintaining the emulator than the tests, and the emulator will diverge from the real tool's behaviour.

**The pattern:**

1. Write a `scripts/fetch-{tool}.sh` that downloads the latest binary release, caches it in `.tmp/`, and prints the path to stdout
2. Test code calls the fetch script once per test run (cached via `OnceLock` / module-level fixture)
3. Falls back to the tool in system PATH if the fetch fails
4. Tests skip gracefully if the binary isn't available — not fail

**Reference implementation:** dfe-receiver's Vector and Filebeat integration tests. Vector is auto-downloaded, started as a subprocess, pointed at the running server, and the test verifies real events flow through the real protocol.

### When to Use Real Binaries vs Docker

| Approach | Use when | Example |
|----------|----------|---------|
| **Real binary (preferred)** | Tool is a single binary, no server state needed | Vector, Filebeat, Logstash, curl, openssl |
| **Docker (testcontainers)** | Tool requires a running server with state | Kafka, PostgreSQL, Redis, ClickHouse |
| **Emulation (last resort)** | No binary available, can't Docker, proprietary API | Cloud API wiremock stubs |

**The hierarchy:** Real binary > Docker container > Wiremock stub > Skip test. Never write a local emulator.

### Fetch Script Pattern

```bash
#!/usr/bin/env bash
# scripts/fetch-{tool}.sh — download and cache {tool} binary
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${REPO_ROOT}/.tmp/{tool}"
ARCH="$(uname -m)"

# Check cached version
cached_version() {
    local bin="${CACHE_DIR}/bin/{tool}"
    [[ -x "$bin" ]] && "$bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# Fetch latest from GitHub releases (or pin via {TOOL}_VERSION env var)
# Download → extract → cache in .tmp/{tool}/bin/
# Print absolute path to binary on stdout (last line)
```

- `.tmp/` is gitignored — binaries are never committed
- Script is idempotent — re-running reuses the cache unless a newer version is available
- Pin a specific version via env var (`VECTOR_VERSION=0.43.0 ./scripts/fetch-vector.sh`) for CI reproducibility
- Default: latest release (developer machines always test against the current version)

### Using the Binary in Tests

```rust
// Rust — OnceLock for one-time fetch
fn tool_binary_path() -> Option<&'static PathBuf> {
    static BIN: OnceLock<Option<PathBuf>> = OnceLock::new();
    BIN.get_or_init(|| {
        let script = Path::new(env!("CARGO_MANIFEST_DIR")).join("scripts/fetch-tool.sh");
        Command::new("bash").arg(&script).output().ok()
            .filter(|o| o.status.success())
            .and_then(|o| {
                let path = String::from_utf8_lossy(&o.stdout).trim().lines().last()?.to_string();
                let p = PathBuf::from(&path);
                p.exists().then_some(p)
            })
            .or_else(|| {
                // Fallback: check system PATH
                Command::new("tool").arg("--version").output().ok()
                    .filter(|o| o.status.success())
                    .map(|_| PathBuf::from("tool"))
            })
    }).as_ref()
}

#[tokio::test]
async fn test_tool_integration() {
    let Some(bin) = tool_binary_path() else {
        eprintln!("Skipping: tool binary not available");
        return;
    };
    // Start your server, run the tool as subprocess, verify results
}
```

```python
# Python — module-level fixture
import subprocess, shutil
from pathlib import Path

@pytest.fixture(scope="session")
def tool_binary():
    script = Path(__file__).parent.parent / "scripts" / "fetch-tool.sh"
    if script.exists():
        result = subprocess.run(["bash", str(script)], capture_output=True, text=True)
        if result.returncode == 0:
            path = result.stdout.strip().splitlines()[-1]
            if Path(path).exists():
                return path
    # Fallback: system PATH
    if shutil.which("tool"):
        return "tool"
    pytest.skip("tool binary not available")
```

### AI Guidance

When generating integration tests for external tools, AI assistants MUST:

1. **Web search** for the tool's binary distribution — check if a standalone binary exists, how to download it, and what platforms are supported
2. **Prefer the real binary** over writing emulation code — the emulator will be wrong
3. **Write a fetch script** following the pattern above if one doesn't exist
4. **Check Docker feasibility** only if a standalone binary isn't available (tool requires a running server)
5. **Fall back to wiremock/stubs** only for proprietary cloud APIs with no local alternative

---

## Integration Tests Are Mandatory

Unit tests prove functions work in isolation. Integration tests prove the system works with its actual dependencies — the database it queries, the broker it publishes to, the API it calls. **Skipping integration tests is the single biggest source of "works on my machine" production failures.**

Every project that talks to an external service MUST have integration tests against that service.

### External Service Pattern: Existing-or-Docker

When an integration test needs an external service (Postgres, Kafka, Redis, ClickHouse, OpenBao, etc.), follow this resolution order:

1. **Check for existing-service config** — env vars or settings pointing at a real instance (`POSTGRES_URL`, `KAFKA_BROKERS`, `CLICKHOUSE_HOST`, etc.)
2. **If set → use the existing service** — skip Docker, connect directly, run against the real thing
3. **If unset → spin up Docker via testcontainers** — auto-managed lifecycle, deterministic version, parallel-safe

**Why both:** Developers running tests against a shared dev cluster shouldn't pay the Docker startup cost. CI without an external cluster shouldn't fail to run integration tests. Both paths must work.

```python
# Python example — pytest fixture
@pytest.fixture(scope="session")
def postgres_url():
    if url := os.getenv("POSTGRES_URL"):
        # Existing service path — verify reachable, then use
        wait_for_postgres(url, timeout=5)
        return url
    # Docker fallback
    with PostgresContainer("postgres:16") as pg:
        yield pg.get_connection_url()
```

```rust
// Rust example — OnceLock-managed
fn kafka_brokers() -> &'static str {
    static BROKERS: OnceLock<String> = OnceLock::new();
    BROKERS.get_or_init(|| {
        std::env::var("KAFKA_BROKERS").unwrap_or_else(|_| {
            // Docker fallback via testcontainers
            start_kafka_container().bootstrap_servers()
        })
    })
}
```

### Rules

- **Same test code, both paths.** The test must not branch on which service it's hitting — the fixture handles resolution.
- **Document required env vars** in `tests/README.md` — what to set, what version is expected.
- **Pin Docker image versions** in fixtures — `postgres:16.2`, never `postgres:latest`.
- **Tear down test data, not the service** — when using existing services, tests must clean up (drop test schemas, delete topics, etc.) but never `DROP DATABASE` shared infrastructure.
- **CI defaults to Docker.** Existing-service mode is for local fast iteration and dedicated test clusters.

### Service Selection Matrix

| Service | Existing-service env var | Docker image (testcontainers) |
|---------|-------------------------|------------------------------|
| PostgreSQL | `POSTGRES_URL` / `DATABASE_URL` | `postgres:16` |
| Kafka | `KAFKA_BROKERS` | `confluentinc/cp-kafka` |
| Redis | `REDIS_URL` | `redis:7` |
| ClickHouse | `CLICKHOUSE_HOST` + `CLICKHOUSE_PORT` | `clickhouse/clickhouse-server` |
| OpenBao / Vault | `BAO_ADDR` + `BAO_TOKEN` | `openbao/openbao` |
| MinIO / S3 | `S3_ENDPOINT` + `S3_ACCESS_KEY` | `minio/minio` |

---

## E2E Tests: Where Relevant, If at All

E2E tests run the full system against real infrastructure end-to-end. They are **slow, flaky, expensive to maintain** — and irreplaceable for validating user-facing workflows that span multiple services.

### When to write E2E tests

- The project has user-facing workflows that traverse 3+ services (ingest → transform → store → query)
- Releases ship to production without a manual QA pass
- Integration tests can't catch interaction bugs (auth flows, distributed transactions, end-to-end backpressure)

### When to skip E2E entirely

- Pure libraries — `hyperi-rustlib`, `hyperi-pylib`. Integration tests against real downstream services are sufficient.
- CLI tools with no service dependencies
- Internal utilities used only by other code (covered by callers' tests)

### Rules when E2E exists

- Marked `#[ignore]` (Rust), `@pytest.mark.e2e` (Python), `//go:build e2e` (Go) — never run in default test invocation
- Trigger only on PR to `release` branch — never on every push
- 20-minute SLO — exceeds budget → split, parallelise, or cut scope
- One environment, one truth — point at a dedicated staging cluster, not whatever a developer happens to have running
- Failures block the release merge, not feature merges to main

---

## Coverage

- **80% floor** — repo-wide minimum (CI-enforced). Drops below this block merge.
- **90%+ goal** — what every project should be aiming at. Treat the gap between current and 90% as technical debt.
- **≥90% hot path** — non-negotiable for performance-critical code (parsers, transforms, pipeline core, SIMD paths). Mark with `// HOT PATH` and enforce per-module thresholds.
- **90%+ for AI-generated code** — extra scrutiny for machine-written logic.
- Coverage that never runs in CI is fiction — measure in CI, fail on regression.

### Explicit Exemptions

The following are excluded from coverage thresholds. Configure exclusions **explicitly** in your coverage tool — implicit exemption is invisible exemption.

| Category | Examples | Why |
|----------|----------|-----|
| **Generated code** | `*.pb.rs`, `_pb2.py`, OpenAPI clients, `gen/**`, `target/**` | Tested upstream, not authored by us |
| **Test utilities** | `tests/common/`, `tests/fixtures/`, `conftest.py` helpers | Tests test code, not test infrastructure |
| **Build scripts** | `build.rs`, `setup.py`, packaging glue, `scripts/ci-*` | Validated by the build itself |
| **Vendored code** | `vendor/`, `third_party/` | Owned externally |

Configure in `.tarpaulin.toml` (Rust), `pyproject.toml [tool.coverage.run] omit` (Python), `.golangci.yml` / coverage profile filtering (Go), or `vitest.config.ts coverage.exclude` (TS).

### Coverage ≠ Test Quality

Hitting 80% with `assert(true)` is worse than 60% with real tests. **Coverage is a floor, not a goal.** Tests at any threshold MUST include:

- **Expected failures** — every error path, every exception variant, every `Err(...)` branch tested with the input that triggers it
- **Complex data sets** — realistic payloads, malformed input, boundary values: `0`, `1`, max, empty, `None`/`null`, `NaN`, overflow, unicode edge cases
- **Fuzzing where applicable** — anything that parses untrusted bytes (deserialisers, protocol handlers, regex inputs, file format readers) gets a fuzz harness
- **Adversarial input** — what does it do with the worst input you can think of?

Tools:

| Language | Coverage | Fuzzing |
|----------|----------|---------|
| Rust | `cargo tarpaulin --out Html` | `cargo fuzz` (libFuzzer), `proptest` for property-based |
| Python | `pytest --cov=src --cov-fail-under=80` | `hypothesis`, `atheris` |
| Go | `go test -cover -coverprofile=cover.out ./...` | `go test -fuzz=Fuzz` (Go 1.18+) |
| TypeScript | `vitest --coverage` (v8) | `fast-check` (property-based) |
| C++ | `llvm-cov` | `libFuzzer`, OSS-Fuzz |

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
