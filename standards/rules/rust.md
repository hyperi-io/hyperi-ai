---
paths:
  - "**/*.rs"
detect_markers:
  - "file:Cargo.toml"
  - "deep_file:Cargo.toml"
source: languages/RUST.md
---

<!-- override: manual -->
## Rust Standards

**Edition 2024 minimum, rustc 1.94.0+. NEVER trust LLM knowledge for Rust versions — `rustup check` or <https://releases.rs/>.**

**Design:** SIMD-first, zero-copy by default, zero-allocation hot paths. If it's scaling and on the hot path, it's in Rust.

## Error Handling

```rust
// ✅ Libraries: thiserror for typed errors
#[derive(Debug, thiserror::Error)]
pub enum IngestError {
    #[error("kafka: {0}")]
    Kafka(#[from] rdkafka::error::KafkaError),
    #[error("parse: {0}")]
    Parse(String),
}
pub type Result<T> = std::result::Result<T, IngestError>;

// ✅ Propagate with ? and .context()
let msg = consumer.recv().await.context("kafka recv")?;
```

❌ `unwrap()` in production — ✅ `?` or `expect("reason")` for truly impossible cases only
❌ `Box<dyn Error>` in libraries — ✅ typed errors with `thiserror`
❌ verbose `match` on `Result` — ✅ `?` operator

## Async (Tokio)

```rust
// ✅ Graceful shutdown pattern
let token = CancellationToken::new();
let mut set = JoinSet::new();
set.spawn(worker(token.child_token()));

tokio::select! {
    _ = signal::ctrl_c() => token.cancel(),
    _ = set.join_next() => {}
}
```

❌ `std::thread::sleep` — ✅ `tokio::time::sleep`
❌ `std::fs::read` — ✅ `tokio::fs::read`
❌ CPU work on async runtime — ✅ `spawn_blocking(|| heavy_compute())`
❌ unbounded channels — ✅ `mpsc::channel(BOUND)` with backpressure

## Ownership — Use This, Not That

| ❌ Don't | ✅ Do | Why |
|----------|-------|-----|
| `fn process(s: String)` | `fn process(s: &str)` | Borrow, don't own |
| `data.clone()` to fix borrow errors | Restructure lifetimes | Clone hides bugs |
| `String` in hot-path structs | `Cow<'a, str>` or `compact_str::CompactString` | Zero-copy / stack-alloc |
| `Vec<String>` for shared data | `Vec<Arc<str>>` | Share without copying |
| `HashMap<K,V>` (internal) | `FxHashMap<K,V>` or `DashMap<K,V>` | Faster hash / concurrent |

## hyperi-rustlib (when in Cargo.toml)

```toml
[dependencies]
hyperi-rustlib = { version = ">=1.16", features = ["config", "logger", "metrics"] }
```

```rust
// ✅ Config: 8-layer figment cascade (ENV > .env > YAML > defaults)
hyperi_rustlib::config::setup(config::ConfigOptions {
    env_prefix: "MYAPP".into(), ..Default::default()
})?;
// ✅ Logging: auto-detects container vs terminal, masks secrets
hyperi_rustlib::logger::setup_default()?;
```

| ❌ Don't | ✅ Use hyperi-rustlib | Feature |
|----------|----------------------|---------|
| Hand-rolled config | `config::setup()` | `config` |
| Raw tracing-subscriber | `logger::setup_default()` | `logger` |
| Bespoke Prometheus | `counter!`, `gauge!`, `histogram!` | `metrics` |
| Raw rdkafka | `transport-kafka` | `transport-kafka` |
| Raw tonic gRPC | `transport-grpc` | `transport-grpc` |
| Hand-rolled retry loops | tower-resilience circuit breaker + bulkhead | `resilience` |
| Direct Vault/AWS SDK | `secrets::Manager` | `secrets-vault` / `secrets-aws` |
| Raw OpenTelemetry setup | OTLP 0.31 via tonic | `otel` / `otel-metrics` |

## Performance — Hot Paths

```rust
// ✅ Zero-copy JSON field extraction (SIMD)
let value = sonic_rs::get_from_slice(payload, &["user_id"])?;

// ✅ SIMD byte search — never iter().position()
let newline = memchr::memchr(b'\n', data);

// ✅ Compile-time sliding window (1.94.0)
let matches: Vec<_> = data.array_windows::<4>()
    .enumerate()
    .filter(|(_, w)| *w == MAGIC)
    .collect();

// ✅ Arena allocator for batch-scoped work
let arena = bumpalo::Bump::new();
for batch in stream.chunks(BATCH_SIZE) {
    process_batch(&arena, batch);
    arena.reset();  // O(1) dealloc
}
```

- `#[inline]` on small hot functions; `#[cold] #[inline(never)]` on error paths
- Pre-allocate: `Vec::with_capacity`, `HashMap::with_capacity`
- `tikv-jemallocator` or `mimalloc` as global allocator for servers
- Profile first: `cargo flamegraph`, `perf record`

## Build & Release

```toml
[profile.release]
lto = "thin"          # Link-time optimisation
codegen-units = 1     # Better optimisation
strip = true          # Remove debug symbols
panic = "abort"       # No unwinding overhead
opt-level = 3         # Maximum optimisation
```

- LLD is default linker on Linux x86_64 since 1.90 (40% faster). mold is faster but verify with C++ deps (ClickHouse is a known issue).
- `sccache` for CI build caching. `cargo-pgo` for PGO+BOLT (15-35% runtime improvement).

## Observability

- `#[instrument(skip(large_args), fields(key = value))]` on all async functions
- Health: atomic `HealthState` (Starting→Ready→Draining→Stopped) on `/healthz`, `/readyz`
- Shutdown: `CancellationToken` + `tokio::signal` for SIGTERM; 15s drain period

## Traits (Advanced)

- Associated types for "one impl per type"; generic params for "multiple impls"
- **Sealed traits**: `mod private { pub trait Sealed {} }` — prevents external impl, enables non-breaking API additions
- **GATs**: `type Item<'a> where Self: 'a` — lending iterators, zero-copy internal buffer iteration
- Static dispatch on hot paths; `dyn Trait` only for heterogeneous collections

## Required Tooling

- Every project: `Cargo.toml`, `Cargo.lock`, `rustfmt.toml`, `clippy.toml`, `deny.toml`, `rust-toolchain.toml`
- CI: `cargo fmt --check && cargo clippy --all-targets --all-features -- -D warnings && cargo deny check && cargo nextest run`
- `#![forbid(unsafe_code)]` in application crates; all FFI via wrapper crates

## AI Pitfalls

> **CRITICAL: Web-search FIRST for ANY Rust crate.** AI models are consistently out of date. Check crates.io for current versions AND check for deprecated/superseded crates.

| ❌ Dead Crate | ✅ Use Instead | Why |
|--------------|----------------|-----|
| `serde_yaml` | `serde_yaml_ng` | Unmaintained since 2023 |
| `atty` | `std::io::IsTerminal` | In std since 1.70 |
| `actix-web` | `axum` (0.8+, `/{param}` syntax) | Ecosystem standard |
| `thiserror` v1 | `thiserror` >=2.0 | v2 removes proc-macro overhead |
| `warp` | `axum` | Maintenance mode |
| `structopt` | `clap` 4+ derive | Merged into clap |
| `dotenv` | `dotenvy` | Unmaintained |
| `chrono` (new) | `time` or `jiff` | Lighter, no C dependency |

❌ Hallucinate crate names — ✅ verify on crates.io before suggesting
❌ `String` params where `&str` works — ✅ borrow by default
❌ `.clone()` to fix borrow errors — ✅ restructure ownership
❌ Block in async — ✅ `spawn_blocking` for CPU/sync work
❌ `panic!` for errors — ✅ return `Result`
