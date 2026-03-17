---
paths:
  - "**/*.rs"
detect_markers:
  - "file:Cargo.toml"
  - "deep_file:Cargo.toml"
source: languages/RUST.md
---

<!-- override: manual -->
## Rust Version Policy

- Always use the latest stable Rust edition and compiler. **Never base version choices on LLM knowledge — always web-check.**
- Check current stable: `rustup check` or <https://releases.rs/>
- Minimum floor as of March 2026: **Edition 2024**, **rustc 1.94.0**
- Set `edition` in `Cargo.toml` and `rustfmt.toml` to the latest stable edition
- Pin `rust-toolchain.toml` to current stable — update regularly

## Design Philosophy

- **SIMD-first**: byte-volume operations (JSON parsing, string search, compression) use SIMD crates (`sonic-rs`, `memchr`, `simd-json`)
- **Zero-copy by default**: `&[u8]`, `Cow<'_, str>`, `Bytes`, memory-mapped files — allocate only when ownership is needed
- **Zero-allocation hot paths**: reuse buffers, arena allocators (`bumpalo`), pre-allocated pools
- If it's scaling and on the hot path, it's in Rust. Otherwise Python/TypeScript are fine.

## Edition 2024 Features

- **Async closures**: `async || { ... }` with `AsyncFn`/`AsyncFnMut`/`AsyncFnOnce` traits — use instead of `Fn() -> impl Future`
- **Let chains** (1.88.0+): `if let Some(x) = foo() && let Ok(y) = bar(x) && y > 0 { ... }`
- **`array_windows::<N>()`** (1.94.0): compile-time sliding windows — prefer over `windows(N)` for auto-vectorisation
- **`LazyLock::get()`** (1.87.0): non-blocking check if already initialised
- **Const math**: `usize::div_ceil`, `next_power_of_two` usable in `const` contexts (1.90.0+)

## Code Style

- Write a macro when you have 3+ similar `impl` blocks — no copy-paste
- Use `dbg!()` for debugging; remove before commit (CI: `clippy -D clippy::dbg_macro`)
- No `TODO` comments — use `todo!("description")` so it compiles but panics if reached; use `unreachable!()` for impossible paths
- Keep `main.rs` ~10 lines: parse args, load config, call `run()`
- `lib.rs` is module root: re-export public API, declare `pub mod prelude` with common imports, keep modules private by default
- Use `pub(crate)` over `pub` unless genuinely part of the external API
- Mark functions with `#[must_use]` when return values shouldn't be ignored
- Use "parse, don't validate" — newtype constructors that enforce invariants (e.g., `Port::new(value: u16) -> Result<Self>`)
- Use type-state pattern (PhantomData + zero-sized state types) for compile-time state machine enforcement
- Accept `impl AsRef<[u8]>`, `&str`, `&[T]` over owned types in function signatures
- Use `impl Into<String>` for constructors taking string-like args

## Required Tooling

- Every project: `Cargo.toml`, `Cargo.lock` (committed), `rustfmt.toml`, `clippy.toml`, `deny.toml`, `rust-toolchain.toml`, `.cargo/config.toml`
- rustfmt.toml: `edition="2024"`, `max_width=100`, `imports_granularity="Module"`, `group_imports="StdExternalCrate"`
- Pin toolchain in `rust-toolchain.toml` with components `rustfmt, clippy, llvm-tools-preview`
- Required tools: `cargo-nextest` (tests), `cargo-deny` (licenses/advisories), `cargo-tarpaulin` (coverage), `bacon` (continuous check), `cargo-chef` (Docker layer caching)
- Use `cargo nextest run` instead of `cargo test`
- CI must run: `cargo fmt --check`, `cargo clippy --all-targets --all-features -- -D warnings`, `cargo deny check`, `cargo nextest run --all-features`

## Error Handling

- **Libraries:** `thiserror` for custom error enums; **Applications:** `anyhow` for prototyping, migrate to proper types later
- Define `pub type Result<T> = std::result::Result<T, MyError>;`
- Use `?` for propagation — never verbose `match` on Result to re-return
- Use `.context()` / `.with_context(|| ...)` from anyhow for readable chains
- Hot path errors: avoid allocation — use fieldless or small-field enum variants
- Never `unwrap()` in production; `expect()` only for truly impossible cases with descriptive messages

## Ownership & Borrowing

- Prefer `&T` and `&[T]` over owned types in function params
- Clone only when you genuinely need owned data — never to satisfy the borrow checker
- Use `Cow<'a, str>` for conditional allocation (zero-copy when possible)

## Traits & Generics

- Use associated types for "one implementation per type"; generic params for "multiple implementations"
- Prefer static dispatch (`impl Trait` / generics) for hot paths; `dyn Trait` for heterogeneous collections and plugin systems
- **Sealed traits**: use `mod private { pub trait Sealed {} }` supertrait to prevent downstream impl — enables non-breaking method additions
- **GATs**: use `type Item<'a> where Self: 'a` for lending iterators / zero-copy iteration over internal buffers
- Extension traits add methods to foreign types — must be imported to use
- Orphan rule: you need either the trait or the type to be local

## Async (Tokio)

- **Never block in async code** — use `tokio::time::sleep`, `tokio::fs`, `tokio::task::spawn_blocking` for sync ops
- Use `JoinSet` for concurrent task groups
- Use `CancellationToken` + `tokio::select!` for graceful shutdown
- Use bounded `mpsc` channels with backpressure (semaphore-based)

## Testing

- `#[cfg(test)] mod tests` for unit tests; `tests/` dir for integration
- Use `proptest` for property-based testing; `criterion` for benchmarks (harness = false)
- Use `tempfile::TempDir` for filesystem fixtures

## Performance — Hot Paths

- Profile first: `cargo flamegraph`, `perf record`, `cargo instruments`
- `#[inline]` on small hot functions; `#[cold] #[inline(never)]` on error paths
- Avoid allocations: write to caller-provided buffers, return `Cow`, reuse `Vec` with `.clear()`
- Batch processing: `chunks(BATCH_SIZE)` with pre-allocated output vecs
- Pre-allocate: `Vec::with_capacity`, `HashMap::with_capacity`
- Use `FxHashMap`/`AHashMap` for internal hash maps; `DashMap` for concurrent access
- Use `bumpalo::Bump` arena for batch-scoped allocations; `.reset()` between batches
- Use object pools (`crossbeam::queue::ArrayQueue`) for hot-path buffer reuse
- Use `memchr`/`memchr2`/`memmem` for SIMD byte searching — never `iter().position()`
- Use `sonic_rs` over `serde_json` for SIMD JSON parsing; `get_from_slice` for zero-copy field extraction
- Use `compact_str::CompactString` for short strings (≤24 bytes, stack-allocated)
- Use `Arc<str>` for shared immutable strings across threads

## Memory & Allocators

- Use `tikv-jemallocator` or `mimalloc` as global allocator for long-running services
- Memory-map large files with `memmap2`; process slices directly
- Columnar batch layout for cache-friendly processing of homogeneous fields

## Concurrency

- `parking_lot::Mutex`/`RwLock` over `std::sync` equivalents (faster)
- `AtomicU64` with `Ordering::Relaxed` for stats counters
- `rayon::par_iter()` for CPU-bound parallel iteration
- `crossbeam::queue::SegQueue` for lock-free work queues

## FFI & Unsafe

- `#![forbid(unsafe_code)]` in application crates; all FFI via wrapper crates
- Minimal `unsafe` blocks — one operation per block
- Every `unsafe` block must have a `// SAFETY:` comment documenting invariants
- Every `pub unsafe fn` must have `# Safety` doc section listing preconditions
- Use `catch_unwind` in `extern "C"` functions to prevent panic unwinding across FFI
- Use `repr(C)` for FFI-shared structs; opaque handle pattern for complex types
- Use `bindgen` (C→Rust) and `cbindgen` (Rust→C) for binding generation
- Run `cargo +nightly miri test` on any unsafe code

## Clippy & Lints

- `clippy.toml`: `too-many-arguments-threshold = 7`, `cognitive-complexity-threshold = 25`
- In `lib.rs`: `#![warn(clippy::all, clippy::pedantic, clippy::nursery)]`, `#![deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)]`
- `#![allow(clippy::module_name_repetitions)]`
- `[lints.rust] unsafe_code = "forbid"` in `Cargo.toml`

## Cargo.toml

- Set `rust-version`, `edition = "2024"`, `license`
- `[profile.release]`: `lto = "thin"`, `codegen-units = 1`, `strip = true`, `panic = "abort"`, `opt-level = 3`
- `[profile.bench]`: `lto = "thin"`, `codegen-units = 1`
- Use `[lints.clippy]` table for project-wide lint config
- **Build perf**: LLD is default on Linux x86_64 since 1.90 (40% faster linking). mold is faster but verify with C++ deps (ClickHouse is a known issue). Use `sccache` for CI. `cargo-pgo` for PGO+BOLT (15-35% runtime improvement on stable hot paths).

## hyperi-rustlib (when `hyperi-rustlib` is in Cargo.toml)

- Use `hyperi_rustlib::config` (8-layer figment cascade) instead of hand-rolled config
- Use `hyperi_rustlib::logger` (sensitive field masking, JSON/pretty auto-detect) instead of raw tracing-subscriber
- Use `hyperi_rustlib::metrics` (Prometheus) or `otel-metrics` (OpenTelemetry) instead of bespoke metrics
- Use `transport-kafka`/`transport-grpc`/`transport-memory` instead of raw rdkafka/tonic
- Use `resilience` (tower-resilience circuit breaker/bulkhead/retry) instead of hand-rolled retry loops
- Use `secrets`/`secrets-vault`/`secrets-aws` instead of direct Vault/AWS SDK calls
- Feature flags are additive — enable only what you need: `hyperi-rustlib = { version = ">=1.16", features = ["config", "logger", "metrics"] }`

## Observability

- **Tracing**: `tracing` + `tracing-subscriber` (JSON in containers, pretty on terminals); `#[instrument]` on async functions
- **OpenTelemetry**: hyperi-rustlib `otel` feature (OTLP 0.31 via tonic); `otel-metrics` for OTel metrics export
- **Prometheus**: hyperi-rustlib `metrics` feature; `counter!`, `gauge!`, `histogram!` macros
- **Health checks**: atomic `HealthState` (Starting→Ready→Draining→Stopped) exposed on `/healthz` and `/readyz`
- **Graceful shutdown**: `CancellationToken` + `tokio::signal` for SIGTERM; drain period (default 15s) before closing connections

## Logging

- Use `tracing` with `tracing-subscriber`; JSON + RFC 3339 in containers, pretty + ANSI on terminals
- Use `#[instrument(skip(large_args), fields(key = value))]` on async functions
- Use `debug!` in hot paths — disabled in release

## AI-Specific Pitfalls

> **CRITICAL: Web-search FIRST for ANY Rust crate before using it.** AI models are
> consistently out of date with Rust crates. Check crates.io for current versions,
> check if the crate is deprecated, and check for better modern alternatives.

- Never generate `unwrap()` or `expect()` without justification
- Never clone to work around borrow checker — restructure or borrow
- Never use `String` params where `&str` suffices
- Never block in async (`std::thread::sleep`, `std::fs`) — use tokio equivalents
- Never use `panic!` for error handling — return `Result`
- Never use `Box<dyn Error>` in library code — define typed errors with `thiserror`
- Always add lifetime params to structs holding references
- Verify crate names on crates.io — do not hallucinate crate names
- Prefer pure Rust crates: `rustls` over openssl, `prost` over protobuf-native, `lz4_flex` over C lz4

### Deprecated Crates — Do NOT Use

| Dead | Use Instead | Why |
|------|-------------|-----|
| `serde_yaml` | `serde_yaml_ng` | Unmaintained since 2023 |
| `atty` | `std::io::IsTerminal` | In std since 1.70 |
| `actix-web` | `axum` | axum is the ecosystem standard |
| `thiserror` v1 | `thiserror` >=2.0 | v2 removes proc-macro overhead |
| `warp` | `axum` | Warp is in maintenance mode |
| `structopt` | `clap` 4+ derive | structopt merged into clap |
| `dotenv` | `dotenvy` | dotenv is unmaintained |
| `chrono` (new code) | `time` or `jiff` | Lighter, no C dependency |
