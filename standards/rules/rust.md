---
paths:
  - "**/*.rs"
---

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
- rustfmt.toml: `edition="2021"`, `max_width=100`, `imports_granularity="Module"`, `group_imports="StdExternalCrate"`
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

- Set `rust-version`, `edition = "2021"`, `license`
- `[profile.release]`: `lto = "thin"`, `codegen-units = 1`, `strip = true`, `panic = "abort"`, `opt-level = 3`
- `[profile.bench]`: `lto = "thin"`, `codegen-units = 1`
- Use `[lints.clippy]` table for project-wide lint config

## Logging

- Use `tracing` with `tracing-subscriber`; JSON + RFC 3339 in containers, pretty + ANSI on terminals
- Use `#[instrument(skip(large_args), fields(key = value))]` on async functions
- Use `debug!` in hot paths — disabled in release

## AI-Specific Pitfalls

- Never generate `unwrap()` or `expect()` without justification
- Never clone to work around borrow checker — restructure or borrow
- Never use `String` params where `&str` suffices
- Never block in async (`std::thread::sleep`, `std::fs`) — use tokio equivalents
- Never use `panic!` for error handling — return `Result`
- Never use `Box<dyn Error>` in library code — define typed errors with `thiserror`
- Always add lifetime params to structs holding references
- Verify crate names on crates.io — do not hallucinate crate names
- Prefer pure Rust crates: `rustls` over openssl, `prost` over protobuf-native, `lz4_flex` over C lz4
