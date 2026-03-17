---
name: rust-standards
description: Rust coding standards using Cargo, clippy, and idiomatic patterns. Use when writing Rust code, reviewing Rust, or setting up Rust projects.
paths:
  - "**/*.rs"
detect_markers:
  - "file:Cargo.toml"
  - "deep_file:Cargo.toml"
---

> **📌 Derek's Hot Path Hard Lessons**
>
> These patterns come from building high-throughput data pipelines that process
> PBs/hour. I've made the mistakes so you don't have to.
>
> **March 2026 update:** Major revision from Derek's "Derek Dump" — lessons
> learned from the dfe-* Rust projects and dropping Vector.dev from the hot path.
> Vector is excellent for routing/fan-out but its per-event overhead and GC-like
> allocation patterns made it unsuitable for PB-scale ingest where every
> microsecond of latency and every byte of allocation matters. The replacement:
> pure Rust pipelines built on `hyperi-rustlib` (transport, tiered-sink,
> resilience) with SIMD JSON parsing, zero-copy buffers, and direct Kafka/gRPC
> transports — no intermediary runtime.
>
> **Improvements are WELCOME.** Found a better pattern? Know something I got
> wrong? Fix it or ping me. This is a living document.

# Rust Standards for HyperI Projects

Standards for systems programming, CLI tools, and high-throughput data processing.

New to Rust? Start with [The Rust Book](https://doc.rust-lang.org/book/) for basics.
This doc covers HyperI-specific patterns and hard-won lessons from production systems.

---

## Table of Contents

1. [HyperI Rust Design Philosophy](#hyperi-rust-design-philosophy) - why Rust, when Rust
2. [Rust 2024 Edition Features](#rust-2024-edition-features) - async closures, let chains, recent std stabilisations
3. [Code Style Rules](#code-style-rules) - the non-negotiables
4. [Required Tooling](#required-tooling)
5. [Quick Reference](#quick-reference)
6. [Project Structure](#project-structure)
7. [Error Handling](#error-handling)
8. [Traits and Generics](#traits-and-generics) - sealed traits, GATs, const generics
9. [Common Patterns](#common-patterns)
10. [Testing](#testing)
11. [Async with Tokio](#async-with-tokio)
12. [Configuration and Logging](#configuration-hyperi-cascade)
13. [hyperi-rustlib](#hyperi-rustlib) - org shared library (config, logging, metrics, transports, secrets)
14. [Observability](#observability) - OTel, Prometheus, tokio-console, health checks
15. [HTTP Service Patterns](#http-service-patterns-axum--tower) - axum 0.8 + tower middleware
16. [Graceful Shutdown](#graceful-shutdown-k8s-ready) - K8s-ready SIGTERM/drain
17. [External Libraries](#external-libraries-and-private-registries)
18. [High Performance](#at-scale-performance-patterns) - build perf, memory, zero-copy, SIMD, concurrency
19. [Data Pipeline Architecture](#data-pipeline-architecture)
20. [FFI and Unsafe](#ffi-and-unsafe-rust)
21. [Clippy Configuration](#clippy-configuration)
22. [Cargo.toml Best Practices](#cargotoml-best-practices)
23. [Coming from Other Languages](#coming-from-other-languages)
24. [For AI Assistants](#ai-pitfalls-to-avoid) - web-search-first enforcement, deprecated crate table
25. [Resources](#resources)

---

## Rust Version Policy

> **Always use the latest stable Rust edition and compiler version.**
>
> **NEVER rely on LLM/AI model knowledge for the current Rust version — it is always out of date.**
> Always web-check the current stable release at <https://releases.rs/> or run `rustup check`.

- Use the latest stable edition. Edition 2024 is the minimum as of March 2026.
- Set `edition` in `Cargo.toml` and `rustfmt.toml` to the latest stable edition.
- Pin `rust-toolchain.toml` to the current stable version (check `rustup check` or <https://releases.rs/>).
- Minimum acceptable floor as of March 2026: **Edition 2024**, **rustc 1.94.0**.
- There is no valid reason to use an older edition in new projects. Existing projects should migrate.

---

## HyperI Rust Design Philosophy

> **If it's scaling and on the hot path, it's in Rust.**
> If not, expressive languages with large library ecosystems (Python, TypeScript) are fine.

Rust at HyperI is for **high-throughput data pipelines, network services, and CPU-bound processing** where every cycle counts. We don't use Rust for glue scripts, admin dashboards, or one-off tools — Python or TypeScript are better there.

### Core Principles

1. **SIMD-first** — If the operation processes bytes at volume (JSON parsing, string search, compression, hashing), use SIMD-accelerated crates. Never hand-roll what `sonic-rs`, `memchr`, or `simd-json` already optimise.

2. **Zero-copy by default** — Borrow `&[u8]` and `&str` from source buffers. Allocate only when mutation is required. Use `Cow<'_, str>` for conditionally-owned data. Use `Bytes` for reference-counted buffer sharing across tasks.

3. **Zero-allocation hot paths** — Pre-allocate all structures during init. Use object pools (`crossbeam` bounded channels), arena allocators (`bumpalo`), and `CompactString` for short strings. The hot path should show zero in `perf record` for `malloc`.

4. **Measure, don't guess** — Profile with `cargo flamegraph` or `perf`. Benchmark with `criterion`. No optimisation is valid without measurement.

5. **Use `hyperi-rustlib`** — Never roll bespoke config, logging, metrics, or resilience patterns in HyperI projects. The shared library exists to eliminate this duplication. See the [hyperi-rustlib](#hyperi-rustlib) section.

6. **PyO3 bindings for Python** — If a Rust crate provides capability useful in Python, consider exposing it as a Python binding via PyO3/maturin rather than reimplementing in pure Python. You get Rust performance with Python ergonomics. Example: `common-expression-language` (CEL) in `hyperi-pylib` is a Rust crate exposed via PyO3.

---

## Rust 2024 Edition Features

Edition 2024 (stable since Rust 1.85.0, February 2025) is the largest edition release.
Use these features — they are the current standard.

### Async Closures (`AsyncFn` traits)

First-class async closures with `AsyncFn`, `AsyncFnMut`, `AsyncFnOnce` traits.
Use these instead of the old `Fn() -> impl Future<Output = T>` workaround.

```rust
// ❌ Old pattern — verbose, lifetime issues
fn retry<F, Fut, T>(f: F) -> T
where
    F: Fn() -> Fut,
    Fut: Future<Output = Result<T>>,
{ /* ... */ }

// ✅ Edition 2024 — async closures
fn retry<F: AsyncFn() -> Result<T>, T>(f: F) -> T { /* ... */ }

// ✅ Async closures capture environment correctly
let client = reqwest::Client::new();
let fetch = async || {
    client.get("https://api.example.com").send().await
};
```

### Let Chains (Rust 1.88.0+, Edition 2024 only)

Chain `let` patterns with `&&` in `if` and `while` expressions:

```rust
// ❌ Old pattern — nested if-let
if let Some(response) = get_response() {
    if let Ok(body) = response.text() {
        if body.len() > 0 {
            process(&body);
        }
    }
}

// ✅ Let chains — flat and readable
if let Some(response) = get_response()
    && let Ok(body) = response.text()
    && !body.is_empty()
{
    process(&body);
}
```

### Unsafe Changes

- `unsafe_op_in_unsafe_fn` is now **warn-by-default** — unsafe operations inside
  `unsafe fn` must be wrapped in explicit `unsafe {}` blocks.
- `extern` blocks require the `unsafe` keyword: `unsafe extern "C" { ... }`.
- Update existing FFI code accordingly.

```rust
// ❌ Edition 2021
extern "C" {
    fn external_func(ptr: *const u8) -> i32;
}

unsafe fn process(ptr: *const u8) -> i32 {
    external_func(ptr)  // Warning in 2024: unsafe op without block
}

// ✅ Edition 2024
unsafe extern "C" {
    fn external_func(ptr: *const u8) -> i32;
}

unsafe fn process(ptr: *const u8) -> i32 {
    unsafe { external_func(ptr) }  // Explicit unsafe block
}
```

### Recent std Stabilisations (Rust 1.85–1.94)

Notable additions to the standard library since Edition 2024 shipped.
Use these instead of external crate equivalents.

```rust
// LazyCell::get / LazyLock::get — check if already initialised (1.87.0)
use std::sync::LazyLock;

static CONFIG: LazyLock<Config> = LazyLock::new(|| load_config());

fn is_ready() -> bool {
    // Non-blocking check: returns Some(&Config) if already initialised
    LazyLock::get(&CONFIG).is_some()
}

// Peekable::next_if — conditional advance without consuming (stable)
fn skip_whitespace(iter: &mut std::iter::Peekable<std::str::Chars<'_>>) {
    while iter.next_if(|c| c.is_whitespace()).is_some() {}
}

// array_windows — compile-time sliding windows (1.94.0)
// See "array_windows" section under Real-World SIMD Patterns for full examples

// Const math functions (1.90.0+) — usable in const contexts
const MAX_BUFFER: usize = usize::next_power_of_two(4096);
const ALIGNED: usize = usize::div_ceil(100, 64) * 64;  // Round up to 64-byte alignment

// std::io::IsTerminal — replaces atty crate (stable since 1.70)
use std::io::IsTerminal;
let interactive = std::io::stderr().is_terminal();
```

---

## Code Style Rules

These apply to all Rust code. No exceptions.

### Macros Over Copy-Paste

When you find yourself writing the third similar `impl` block, stop. Write a macro.

```rust
// ❌ Don't do this
impl From<IoError> for AppError {
    fn from(e: IoError) -> Self { AppError::Io(e) }
}
impl From<ParseError> for AppError {
    fn from(e: ParseError) -> Self { AppError::Parse(e) }
}
impl From<DbError> for AppError {
    fn from(e: DbError) -> Self { AppError::Database(e) }
}

// ✅ Do this
macro_rules! impl_from_error {
    ($($variant:ident => $error:ty),+ $(,)?) => {
        $(
            impl From<$error> for AppError {
                fn from(e: $error) -> Self { AppError::$variant(e) }
            }
        )+
    };
}

impl_from_error! {
    Io => IoError,
    Parse => ParseError,
    Database => DbError,
}
```

Three or more similar blocks in a code review? Ask for a macro.

### Use `dbg!()` Freely

Sprinkle `dbg!()` everywhere when debugging. It's better than `println!` because
it shows file, line, and the expression itself.

```rust
let result = dbg!(calculate_value(x));  // [src/main.rs:42] calculate_value(x) = 123
let processed = dbg!(items.iter().filter(|x| dbg!(x.is_valid())).count());
```

Just remember to remove them before committing. CI runs `clippy -D clippy::dbg_macro`.

### No TODO Comments

TODO comments rot. If you need to mark incomplete code, use `todo!()` so it
won't compile silently and get forgotten.

```rust
// ❌ This will get lost
fn process() {
    // TODO: implement this
    unimplemented!()
}

// ✅ This panics at runtime if reached - you'll know
fn process() -> Result<Output> {
    todo!("implement processing logic - see TODO.md#processing")
}

// For code paths that genuinely can't happen
fn handle_impossible_case() {
    unreachable!("this variant is never constructed")
}
```

### Keep `main.rs` Tiny

`main.rs` should be ~10 lines. Argument parsing, config load, call `run()`, done.

```rust
// src/main.rs
#![forbid(unsafe_code)]

use myapp::{run, Config, Error};

#[tokio::main]
async fn main() -> Result<(), Error> {
    let config = Config::from_args()?;
    run(config).await
}
```

All the actual logic lives in `lib.rs` and modules.

### Module Organisation

`lib.rs` is the module root. Keep it clean:

```rust
// src/lib.rs
#![forbid(unsafe_code)]
#![warn(clippy::all, clippy::pedantic)]
#![allow(clippy::module_name_repetitions)]

// Public API - only what external users need
pub use config::Config;
pub use error::{Error, Result};
pub use pipeline::Pipeline;

// Prelude for internal use
pub mod prelude {
    pub use crate::error::{Error, Result};
    pub use crate::config::Config;
    pub use tracing::{debug, error, info, warn, instrument};
}

// Private by default
mod config;
mod error;
mod pipeline;
mod transform;
mod buffer;

// Public only when genuinely needed
pub mod types;

// Entry point
pub async fn run(config: Config) -> Result<()> {
    let pipeline = Pipeline::new(config)?;
    pipeline.run().await
}
```

### Prelude Pattern

A `prelude` module reduces import boilerplate:

```rust
// src/prelude.rs
pub use crate::error::{Error, Result};
pub use crate::types::{Record, Batch};
pub use std::sync::Arc;
pub use tracing::{debug, error, info, warn, instrument};

// Then in every other module:
use crate::prelude::*;
```

### Minimal Visibility - Only `pub` What's Needed

```rust
// ❌ BAD - Everything public
pub mod internal_helpers;
pub fn private_utility() { }
pub struct InternalState { pub field: i32 }

// ✅ GOOD - Minimal visibility
mod internal_helpers;           // Private module
fn private_utility() { }        // Private function
pub struct Config {             // Public struct
    pub(crate) internal: i32,   // Crate-visible field
    timeout: Duration,          // Private field
}
```

### `#[must_use]` Extensively

Mark functions whose return values shouldn't be ignored:

```rust
#[must_use]
pub fn calculate_hash(data: &[u8]) -> u64 {
    // ...
}

#[must_use = "this `Result` may contain an error that should be handled"]
pub fn try_connect(addr: &str) -> Result<Connection> {
    // ...
}

// Compiler warns if return value is ignored:
// calculate_hash(data);  // warning: unused return value of `calculate_hash` that must be used
```

### Parse Constructors for Validated Types

Use "parse, don't validate" pattern with constructors that enforce invariants:

```rust
/// Port number (1-65535)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Port(u16);

impl Port {
    /// Parse and validate port number
    pub fn new(value: u16) -> Result<Self, PortError> {
        if value == 0 {
            return Err(PortError::Zero);
        }
        Ok(Self(value))
    }

    pub fn get(self) -> u16 {
        self.0
    }
}

impl std::str::FromStr for Port {
    type Err = PortError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let value: u16 = s.parse().map_err(|_| PortError::Invalid)?;
        Self::new(value)
    }
}

// Usage: validation at boundary, trust internally
let port: Port = "8080".parse()?;  // Validated once
start_server(port);                 // No re-validation needed
```

### Type-State Pattern for Compile-Time Safety

Encode state transitions in the type system:

```rust
// States as zero-sized types
pub struct Unvalidated;
pub struct Validated;
pub struct Ready;

pub struct Request<State> {
    data: RequestData,
    _state: std::marker::PhantomData<State>,
}

impl Request<Unvalidated> {
    pub fn new(data: RequestData) -> Self {
        Self { data, _state: std::marker::PhantomData }
    }

    pub fn validate(self) -> Result<Request<Validated>, ValidationError> {
        validate_data(&self.data)?;
        Ok(Request { data: self.data, _state: std::marker::PhantomData })
    }
}

impl Request<Validated> {
    pub fn prepare(self) -> Request<Ready> {
        Request { data: self.data, _state: std::marker::PhantomData }
    }
}

impl Request<Ready> {
    pub async fn send(self) -> Result<Response> {
        // Only Ready requests can be sent
        send_request(self.data).await
    }
}

// Compile-time enforcement:
// Request::new(data).send().await;  // ERROR: no method `send` on Request<Unvalidated>
// Request::new(data).validate()?.prepare().send().await;  // OK
```

### Lean Into Traits and Generics

Use traits and generics extensively (without going overboard):

```rust
// ✅ GOOD - Generic over input types
pub fn process<T: AsRef<[u8]>>(input: T) -> Result<Output> {
    let bytes = input.as_ref();
    // Works with &[u8], Vec<u8>, Bytes, etc.
}

// ✅ GOOD - Trait for pluggable behaviour
pub trait Sink: Send + Sync {
    fn write(&self, batch: &Batch) -> Result<()>;
    fn flush(&self) -> Result<()>;
}

pub struct Pipeline<S: Sink> {
    sink: S,
}

// ✅ GOOD - Extension traits for ergonomics
pub trait ResultExt<T> {
    fn log_err(self) -> Result<T>;
}

impl<T, E: std::fmt::Display> ResultExt<T> for Result<T, E> {
    fn log_err(self) -> Result<T, E> {
        if let Err(ref e) = self {
            tracing::error!("{}", e);
        }
        self
    }
}
```

---

## Required Tooling

Every Rust project **MUST** have these files and tools configured.

### Required Files in Every Project

```text
myproject/
├── Cargo.toml              # Project manifest
├── Cargo.lock              # Locked dependencies (commit this!)
├── rustfmt.toml            # Formatter config
├── clippy.toml             # Linter config
├── deny.toml               # Dependency checker config
├── rust-toolchain.toml     # Toolchain pinning
├── .cargo/
│   └── config.toml         # Cargo config (registry, build flags)
└── src/
    ├── main.rs             # Entry point (small!)
    └── lib.rs              # Library root
```

### rustfmt.toml (Required)

```toml
# Rust formatter configuration
edition = "2024"
max_width = 100
tab_spaces = 4
use_small_heuristics = "Default"
imports_granularity = "Module"
group_imports = "StdExternalCrate"
reorder_imports = true
```

### rust-toolchain.toml (Required)

```toml
# Pin Rust toolchain for reproducible builds
# Always check current stable: rustup check or https://releases.rs/
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy", "llvm-tools-preview"]
targets = ["x86_64-unknown-linux-gnu"]
```

### deny.toml (Required)

```toml
# cargo-deny configuration
# Run: cargo deny check

[advisories]
db-path = "~/.cargo/advisory-db"
db-urls = ["https://github.com/rustsec/advisory-db"]
vulnerability = "deny"
unmaintained = "warn"
yanked = "warn"
notice = "warn"

[licenses]
unlicensed = "deny"
allow = [
    "FSL-1.1-ALv2",
    "MIT",
    "Apache-2.0",
    "Apache-2.0 WITH LLVM-exception",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "ISC",
    "Zlib",
    "MPL-2.0",
    "Unicode-DFS-2016",
]
copyleft = "warn"
default = "deny"

[bans]
multiple-versions = "warn"
wildcards = "deny"
highlight = "all"
skip = []

[sources]
unknown-registry = "deny"
unknown-git = "deny"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
```

### Required Development Tools

Install these tools for every Rust project:

```bash
# Essential tools (install once)
cargo install cargo-nextest      # Better test runner
cargo install cargo-deny         # License/advisory checker
cargo install cargo-tarpaulin    # Code coverage
cargo install bacon              # Background checker (like cargo-watch)
cargo install cargo-chef         # Docker layer caching

# Optional but recommended
cargo install cargo-audit        # Security audit
cargo install cargo-outdated     # Check for outdated deps
cargo install cargo-machete      # Find unused dependencies
```

### Development Workflow Commands

```bash
# Use bacon for continuous checking (replaces cargo watch)
bacon                           # Runs clippy on save
bacon test                      # Runs tests on save
bacon clippy                    # Runs clippy on save

# Use nextest for testing (faster, better output)
cargo nextest run               # Run all tests
cargo nextest run --no-capture  # Show println! output
cargo nextest run -E 'test(unit)'  # Filter by name

# Coverage with tarpaulin
cargo tarpaulin --out Html      # Generate HTML report
cargo tarpaulin --out Lcov      # For CI upload

# Dependency checking
cargo deny check                # Licenses, advisories, bans
cargo audit                     # Security vulnerabilities
cargo outdated                  # Check for updates
cargo machete                   # Find unused deps
```

### Docker Builds with cargo-chef

Use cargo-chef for efficient Docker layer caching:

```dockerfile
# Stage 1: Chef - prepare dependency recipe
FROM rust:1.83-slim AS chef
RUN cargo install cargo-chef
WORKDIR /app

# Stage 2: Planner - create recipe.json
FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# Stage 3: Builder - build dependencies (cached layer)
FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json
# Build application (only this layer rebuilds on code change)
COPY . .
RUN cargo build --release

# Stage 4: Runtime
FROM debian:bookworm-slim
COPY --from=builder /app/target/release/myapp /usr/local/bin/
CMD ["myapp"]
```

### CI Quality Pipeline

```yaml
# .github/workflows/ci.yml
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy

      - name: Format check
        run: cargo fmt --check

      - name: Clippy
        run: cargo clippy --all-targets --all-features -- -D warnings

      - name: Deny check
        run: cargo deny check

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable

      - name: Install nextest
        run: cargo install cargo-nextest

      - name: Run tests
        run: cargo nextest run --all-features

  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable

      - name: Install tarpaulin
        run: cargo install cargo-tarpaulin

      - name: Generate coverage
        run: cargo tarpaulin --out Lcov

      - name: Upload coverage
        uses: codecov/codecov-action@v4
```

---

## Quick Reference

```bash
# Essential commands
cargo build                     # Build debug
cargo build --release           # Build release
cargo nextest run               # Run tests (preferred over cargo test)
cargo clippy                    # Lint
cargo fmt                       # Format
cargo check                     # Type check (fast)
cargo doc --open                # Generate docs
cargo bench                     # Run benchmarks
cargo tree                      # Dependency tree
cargo deny check                # License/advisory check

# Development workflow
bacon                           # Continuous clippy (use instead of cargo watch)
bacon test                      # Continuous testing
cargo tarpaulin --out Html      # Coverage report
```

### Type Quick Reference

| Type | Size | Use Case |
|------|------|----------|
| `i8/u8` | 1 byte | Small integers, bytes |
| `i32/u32` | 4 bytes | Default integers |
| `i64/u64` | 8 bytes | Large integers, timestamps |
| `isize/usize` | pointer | Indexing, lengths |
| `f32` | 4 bytes | GPU, graphics |
| `f64` | 8 bytes | Default float, precision |
| `bool` | 1 byte | Boolean logic |
| `char` | 4 bytes | Unicode scalar |

### String Types

| Type | Ownership | Mutability | Use Case |
|------|-----------|------------|----------|
| `String` | Owned | Mutable | Building strings |
| `&str` | Borrowed | Immutable | String parameters |
| `&mut str` | Borrowed | Mutable | Rare, in-place |
| `Cow<'a, str>` | Either | Copy-on-write | Zero-copy with fallback |
| `Arc<str>` | Shared | Immutable | Shared across threads |

---

## Project Structure

### Binary Project

```text
myproject/
├── src/
│   ├── main.rs                 # Entry point
│   ├── lib.rs                  # Library code (optional)
│   ├── config.rs
│   └── error.rs
├── tests/
│   └── integration_test.rs
├── benches/
│   └── benchmark.rs
├── Cargo.toml
├── Cargo.lock
└── .cargo/
    └── config.toml
```

### Library Project

```text
mylib/
├── src/
│   ├── lib.rs                  # Public API
│   ├── types.rs
│   └── internal/
│       └── mod.rs
├── examples/
│   └── basic.rs
├── benches/
│   └── benchmark.rs
├── Cargo.toml
└── README.md
```

### High-Performance Data Pipeline

```text
data-pipeline/
├── src/
│   ├── main.rs
│   ├── lib.rs
│   ├── pipeline/
│   │   ├── mod.rs
│   │   ├── reader.rs           # Input parsing
│   │   ├── transformer.rs      # Data transformation
│   │   └── writer.rs           # Output handling
│   ├── types/
│   │   ├── mod.rs
│   │   ├── record.rs           # Core data types
│   │   └── batch.rs            # Batch containers
│   ├── utils/
│   │   ├── mod.rs
│   │   └── pool.rs             # Object pools
│   └── error.rs
├── benches/
│   ├── parsing.rs
│   └── throughput.rs
└── Cargo.toml
```

---

## Rust Foundations

For fundamentals (variables, types, control flow, functions), read [The Rust Book](https://doc.rust-lang.org/book/) chapters 3-5. It's better than anything I could write here.

What follows is the stuff The Book doesn't emphasise enough.

### Closures - Know Your Traits

```rust
// Fn     - borrows immutably (can call multiple times)
// FnMut  - borrows mutably (can call multiple times)
// FnOnce - takes ownership (can call once)

// Move closure - takes ownership of captured variables
let data = vec![1, 2, 3];
let closure = move || {
    println!("{:?}", data);  // Owns data now
};
// data is gone - moved into closure
```

When passing closures to functions, use `impl Fn...` for flexibility:

```rust
fn call_twice(f: impl Fn()) {
    f();
    f();
}
```

---

## Error Handling

Rust error handling is verbose until you learn the patterns. Then it's actually pleasant.

**Libraries:** Use `thiserror` for custom error types. **Applications:** Use `anyhow` for quick prototyping, then migrate to proper types when the code stabilises.

### Custom Error Types with thiserror

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum PipelineError {
    #[error("failed to read input '{path}': {source}")]
    ReadError {
        path: String,
        #[source]
        source: std::io::Error,
    },

    #[error("parse error at line {line}: {message}")]
    ParseError {
        line: usize,
        message: String,
    },

    #[error("invalid record format: {0}")]
    FormatError(#[from] serde_json::Error),

    #[error("transformation failed: {0}")]
    TransformError(String),

    #[error("output error: {0}")]
    OutputError(#[from] std::io::Error),
}
```

### Result Type Alias

```rust
pub type Result<T> = std::result::Result<T, PipelineError>;

// Usage
pub fn load_config(path: &str) -> Result<Config> {
    let content = std::fs::read_to_string(path)
        .map_err(|e| PipelineError::ReadError {
            path: path.to_string(),
            source: e,
        })?;

    let config: Config = serde_yaml::from_str(&content)?;
    validate(&config)?;
    Ok(config)
}
```

### Error Propagation with ?

```rust
// ✅ Good - use ? for propagation
fn process_file(path: &Path) -> Result<Data> {
    let content = std::fs::read_to_string(path)?;
    let parsed = parse(&content)?;
    let validated = validate(parsed)?;
    Ok(transform(validated))
}

// ❌ Bad - verbose unwrapping
fn process_file(path: &Path) -> Result<Data> {
    let content = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(e) => return Err(e.into()),
    };
    // ...
}
```

### anyhow for Applications

```rust
use anyhow::{Context, Result, bail, ensure};

fn main() -> Result<()> {
    let config = load_config("config.yaml")
        .context("failed to load configuration")?;

    let data = fetch_data(&config.url)
        .with_context(|| format!("failed to fetch from {}", config.url))?;

    // Conditional error
    ensure!(data.len() > 0, "received empty data");

    // Early return with error
    if !data.is_valid() {
        bail!("data validation failed");
    }

    process(data)?;
    Ok(())
}
```

### Error Handling in Hot Paths

```rust
// For hot paths, avoid allocating on error path
#[derive(Debug)]
pub enum FastError {
    InvalidInput,
    BufferTooSmall,
    ParseFailed { offset: usize },
}

// Return error info without allocation
fn parse_fast(input: &[u8]) -> Result<Record, FastError> {
    if input.is_empty() {
        return Err(FastError::InvalidInput);
    }
    // Parse logic...
}
```

---

## Ownership and Borrowing

This is the bit that makes Rust feel hard at first. But it's also why Rust code doesn't segfault or leak memory. The borrow checker is doing at compile time what you'd do in your head (and occasionally forget) in C.

### The Three Rules

Memorise these. Everything else flows from them:

1. **Each value has exactly one owner**
2. **When the owner goes out of scope, the value is dropped**
3. **You can have either one mutable reference OR any number of immutable references**

### Move Semantics

```rust
// Ownership is transferred (moved)
let s1 = String::from("hello");
let s2 = s1;  // s1 is moved to s2
// println!("{}", s1);  // Error! s1 no longer valid

// Copy types are copied, not moved
let x = 5;
let y = x;    // x is copied
println!("{}", x);  // OK! x is still valid

// Copy is implemented for:
// - All integer types (i32, u64, etc.)
// - bool, char
// - f32, f64
// - Tuples of Copy types
// - Fixed-size arrays of Copy types
```

### Borrowing Rules

```rust
// ✅ Good - immutable borrow for reading
fn print_user(user: &User) {
    println!("{}: {}", user.id, user.name);
}

// ✅ Good - mutable borrow for modification
fn update_name(user: &mut User, name: String) {
    user.name = name;
}

// ✅ Good - take ownership when needed
fn consume_user(user: User) -> String {
    format!("Consumed: {}", user.name)
}

// Multiple immutable borrows OK
let r1 = &data;
let r2 = &data;
println!("{} {}", r1, r2);

// Cannot mix mutable and immutable
let r1 = &data;
// let r2 = &mut data;  // Error!
```

### Clone vs Borrow

```rust
// ❌ Bad - unnecessary clone
fn process(data: &Vec<String>) {
    let cloned = data.clone();  // Expensive!
    for item in cloned {
        println!("{}", item);
    }
}

// ✅ Good - borrow instead
fn process(data: &[String]) {
    for item in data {
        println!("{}", item);
    }
}

// Clone when actually needed
fn process_and_modify(data: &[String]) -> Vec<String> {
    let mut result = data.to_vec();  // OK - we need owned data
    result.push("extra".to_string());
    result
}
```

### Lifetime Annotations

```rust
// Explicit lifetime when returning references
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}

// Struct with references
struct Parser<'a> {
    input: &'a str,
    position: usize,
}

impl<'a> Parser<'a> {
    fn new(input: &'a str) -> Self {
        Self { input, position: 0 }
    }

    fn remaining(&self) -> &'a str {
        &self.input[self.position..]
    }
}

// Multiple lifetimes
struct Context<'a, 'b> {
    config: &'a Config,
    buffer: &'b mut [u8],
}

// Static lifetime - lives for entire program
const GREETING: &'static str = "Hello";
fn get_static() -> &'static str {
    "This lives forever"
}
```

### Lifetime Elision Rules

```rust
// Rule 1: Each reference parameter gets its own lifetime
fn foo(x: &str)          // becomes fn foo<'a>(x: &'a str)
fn foo(x: &str, y: &str) // becomes fn foo<'a, 'b>(x: &'a str, y: &'b str)

// Rule 2: If exactly one input lifetime, it's assigned to all outputs
fn foo(x: &str) -> &str  // becomes fn foo<'a>(x: &'a str) -> &'a str

// Rule 3: If &self or &mut self, its lifetime is assigned to outputs
impl Foo {
    fn bar(&self) -> &str  // becomes fn bar<'a>(&'a self) -> &'a str
}
```

---

## Structs and Enums

### Struct Definition

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Record {
    pub id: String,
    pub timestamp: i64,
    #[serde(default)]
    pub active: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<HashMap<String, String>>,
}

impl Record {
    pub fn new(id: impl Into<String>, timestamp: i64) -> Self {
        Self {
            id: id.into(),
            timestamp,
            active: true,
            metadata: None,
        }
    }

    pub fn is_valid(&self) -> bool {
        !self.id.is_empty() && self.timestamp > 0
    }
}

impl Default for Record {
    fn default() -> Self {
        Self {
            id: String::new(),
            timestamp: 0,
            active: false,
            metadata: None,
        }
    }
}
```

### Enums with Data

```rust
#[derive(Debug, Clone)]
pub enum Event {
    Created { id: String, timestamp: i64 },
    Updated { id: String, fields: Vec<String> },
    Deleted { id: String },
}

impl Event {
    pub fn id(&self) -> &str {
        match self {
            Event::Created { id, .. } => id,
            Event::Updated { id, .. } => id,
            Event::Deleted { id } => id,
        }
    }

    pub fn is_destructive(&self) -> bool {
        matches!(self, Event::Deleted { .. })
    }
}
```

### Builder Pattern

```rust
#[derive(Default)]
pub struct PipelineBuilder {
    input_path: Option<PathBuf>,
    output_path: Option<PathBuf>,
    batch_size: usize,
    parallelism: usize,
}

impl PipelineBuilder {
    pub fn new() -> Self {
        Self {
            batch_size: 10_000,
            parallelism: num_cpus::get(),
            ..Default::default()
        }
    }

    pub fn input(mut self, path: impl Into<PathBuf>) -> Self {
        self.input_path = Some(path.into());
        self
    }

    pub fn output(mut self, path: impl Into<PathBuf>) -> Self {
        self.output_path = Some(path.into());
        self
    }

    pub fn batch_size(mut self, size: usize) -> Self {
        self.batch_size = size;
        self
    }

    pub fn parallelism(mut self, n: usize) -> Self {
        self.parallelism = n;
        self
    }

    pub fn build(self) -> Result<Pipeline, BuildError> {
        let input = self.input_path.ok_or(BuildError::MissingInput)?;
        let output = self.output_path.ok_or(BuildError::MissingOutput)?;

        Ok(Pipeline {
            input,
            output,
            batch_size: self.batch_size,
            parallelism: self.parallelism,
        })
    }
}

// Usage
let pipeline = PipelineBuilder::new()
    .input("data/input.json")
    .output("data/output.parquet")
    .batch_size(50_000)
    .build()?;
```

### Newtype Pattern

```rust
// Type-safe wrappers for primitive types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct UserId(pub u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Timestamp(pub i64);

impl Timestamp {
    pub fn now() -> Self {
        Self(chrono::Utc::now().timestamp_millis())
    }
}

// Prevents mixing up user_id and order_id
fn process_order(user: UserId, order: OrderId) { }
```

---

## Common Patterns

### Option Handling

```rust
// ✅ Good - use combinators
let name = config.name.unwrap_or_default();
let port = config.port.unwrap_or(8080);
let value = opt.map(|v| v.to_string());

// Map with fallible operation
let parsed: Option<i32> = opt.and_then(|s| s.parse().ok());

// ✅ Good - if let for side effects
if let Some(user) = get_user(id) {
    process_user(&user);
}

// ✅ Good - ? for Option in functions returning Option
fn get_name(user: Option<&User>) -> Option<&str> {
    Some(user?.name.as_str())
}

// ❌ Bad - unwrap in production code
let value = config.name.unwrap();  // Panics!

// Convert Option to Result
let value = opt.ok_or(Error::MissingValue)?;
let value = opt.ok_or_else(|| Error::missing("field_name"))?;
```

### Iterator Patterns

```rust
// Filter and transform
let active_names: Vec<String> = users
    .iter()
    .filter(|u| u.active)
    .map(|u| u.name.clone())
    .collect();

// Find single item
let admin = users.iter().find(|u| u.role == Role::Admin);

// Find with transformation
let admin_id = users.iter()
    .find(|u| u.role == Role::Admin)
    .map(|u| u.id);

// Partition
let (active, inactive): (Vec<_>, Vec<_>) = users
    .into_iter()
    .partition(|u| u.active);

// Fold/reduce
let total: i32 = items.iter().map(|i| i.price).sum();

// Chaining with flat_map
let all_tags: Vec<&str> = posts
    .iter()
    .flat_map(|p| p.tags.iter())
    .map(|s| s.as_str())
    .collect();

// Take while condition holds
let prefix: Vec<_> = items
    .iter()
    .take_while(|i| i.valid)
    .collect();

// Enumerate with index
for (i, item) in items.iter().enumerate() {
    println!("{}: {:?}", i, item);
}

// Zip two iterators
for (a, b) in list_a.iter().zip(list_b.iter()) {
    process(a, b);
}

// Chunk processing
for chunk in items.chunks(100) {
    process_batch(chunk);
}
```

### Pattern Matching

```rust
// Destructuring structs
let Point { x, y } = point;
let Point { x, .. } = point;  // Ignore other fields

// Matching nested structures
match event {
    Event::Created { id, timestamp } if timestamp > cutoff => {
        process_recent(id);
    }
    Event::Created { id, .. } => {
        process_old(id);
    }
    Event::Deleted { id } => {
        cleanup(id);
    }
    _ => {}
}

// @ bindings - bind while matching
match value {
    n @ 1..=100 => println!("Small: {}", n),
    n @ 101..=1000 => println!("Medium: {}", n),
    n => println!("Large: {}", n),
}

// Or patterns
match char {
    'a' | 'e' | 'i' | 'o' | 'u' => "vowel",
    _ => "consonant",
}
```

---

## Testing

Use `cargo nextest` instead of `cargo test`. It's faster, has better output, and runs tests in parallel properly. Install it: `cargo install cargo-nextest`.

For coverage, use `cargo tarpaulin`. For property-based testing, use `proptest`. For benchmarks, use `criterion`.

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_record_validation() {
        let valid = Record::new("123", 1000);
        assert!(valid.is_valid());

        let invalid = Record::new("", 1000);
        assert!(!invalid.is_valid());
    }

    #[test]
    fn test_parse_config() {
        let yaml = r#"
            name: test
            port: 8080
        "#;
        let config: Config = serde_yaml::from_str(yaml).unwrap();
        assert_eq!(config.name, "test");
        assert_eq!(config.port, 8080);
    }

    #[test]
    #[should_panic(expected = "missing field")]
    fn test_missing_field_panics() {
        let yaml = "name: test";  // missing port
        let _: StrictConfig = serde_yaml::from_str(yaml).unwrap();
    }

    #[test]
    fn test_result_error() {
        let result = parse_invalid_input();
        assert!(result.is_err());
        assert!(matches!(result, Err(ParseError::InvalidFormat(_))));
    }
}
```

### Test Fixtures

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn setup() -> (TempDir, PathBuf) {
        let dir = TempDir::new().unwrap();
        let config_path = dir.path().join("config.yaml");
        std::fs::write(&config_path, "name: test\nport: 8080").unwrap();
        (dir, config_path)
    }

    #[test]
    fn test_load_config() {
        let (_dir, path) = setup();
        let config = load_config(&path).unwrap();
        assert_eq!(config.name, "test");
    }
}
```

### Property-Based Testing

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_parse_roundtrip(s in "\\PC*") {
        if let Ok(parsed) = parse(&s) {
            let serialized = serialize(&parsed);
            let reparsed = parse(&serialized).unwrap();
            assert_eq!(parsed, reparsed);
        }
    }

    #[test]
    fn test_transform_preserves_count(
        records in prop::collection::vec(any::<Record>(), 0..1000)
    ) {
        let transformed = transform(&records);
        assert_eq!(records.len(), transformed.len());
    }
}
```

### Benchmarks with Criterion

```rust
// benches/throughput.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion, Throughput};

fn bench_parsing(c: &mut Criterion) {
    let data = generate_test_data(10_000);

    let mut group = c.benchmark_group("parsing");
    group.throughput(Throughput::Elements(10_000));

    group.bench_function("json_parse", |b| {
        b.iter(|| parse_json(black_box(&data)))
    });

    group.bench_function("simd_parse", |b| {
        b.iter(|| parse_simd(black_box(&data)))
    });

    group.finish();
}

criterion_group!(benches, bench_parsing);
criterion_main!(benches);
```

### Integration Tests

```rust
// tests/integration_test.rs
use mylib::{Pipeline, Config};

#[tokio::test]
async fn test_pipeline_end_to_end() {
    let config = Config::default();
    let pipeline = Pipeline::new(config);

    let input = vec![create_test_record()];
    let output = pipeline.process(input).await.unwrap();

    assert_eq!(output.len(), 1);
    assert!(output[0].processed);
}
```

---

## Async with Tokio

Rust async is different from Go goroutines or Python asyncio. You need a runtime (we use Tokio), and `async fn` returns a future that does nothing until awaited.

**Key rule:** Never block in async code. Use `tokio::time::sleep`, not `std::thread::sleep`. Use `tokio::fs`, not `std::fs`. If you must call blocking code, wrap it in `tokio::task::spawn_blocking`.

### Async Functions

```rust
use tokio::time::{sleep, Duration};

async fn fetch_data(url: &str) -> Result<String> {
    let response = reqwest::get(url).await?;
    let body = response.text().await?;
    Ok(body)
}

async fn fetch_with_retry(url: &str, max_retries: u32) -> Result<String> {
    let mut attempts = 0;
    loop {
        match fetch_data(url).await {
            Ok(data) => return Ok(data),
            Err(e) if attempts < max_retries => {
                attempts += 1;
                let delay = Duration::from_millis(100 * 2u64.pow(attempts));
                sleep(delay).await;
            }
            Err(e) => return Err(e),
        }
    }
}
```

### Concurrent Tasks with JoinSet

```rust
use tokio::task::JoinSet;

async fn process_urls(urls: Vec<String>) -> Vec<Result<String>> {
    let mut tasks = JoinSet::new();

    for url in urls {
        tasks.spawn(async move {
            fetch_data(&url).await
        });
    }

    let mut results = Vec::new();
    while let Some(result) = tasks.join_next().await {
        results.push(result.unwrap());
    }
    results
}
```

### Channels for Communication

```rust
use tokio::sync::mpsc;

async fn producer(tx: mpsc::Sender<Record>) {
    for i in 0..100 {
        if tx.send(Record::new(i)).await.is_err() {
            break;  // Receiver dropped
        }
    }
}

async fn consumer(mut rx: mpsc::Receiver<Record>) {
    while let Some(record) = rx.recv().await {
        process_record(record).await;
    }
}

#[tokio::main]
async fn main() {
    let (tx, rx) = mpsc::channel(100);

    tokio::spawn(producer(tx));
    consumer(rx).await;
}
```

### Graceful Shutdown

```rust
use tokio::sync::watch;
use tokio_util::sync::CancellationToken;

async fn worker(cancel: CancellationToken, mut rx: mpsc::Receiver<Work>) {
    loop {
        tokio::select! {
            _ = cancel.cancelled() => {
                tracing::info!("Shutdown requested, draining queue...");
                // Process remaining items
                while let Ok(work) = rx.try_recv() {
                    process(work).await;
                }
                break;
            }
            Some(work) = rx.recv() => {
                process(work).await;
            }
        }
    }
}

#[tokio::main]
async fn main() {
    let cancel = CancellationToken::new();
    let cancel_clone = cancel.clone();

    // Handle SIGTERM/SIGINT
    tokio::spawn(async move {
        tokio::signal::ctrl_c().await.ok();
        cancel_clone.cancel();
    });

    let (tx, rx) = mpsc::channel(100);
    let handle = tokio::spawn(worker(cancel.clone(), rx));

    // ... send work ...

    handle.await.unwrap();
}
```

### Async Anti-Patterns (The Things That Kill Throughput)

These are the most common async mistakes. Each one can silently halve your throughput.

```rust
// ❌ BLOCKING THE RUNTIME — the #1 async sin
async fn bad_read() -> String {
    std::fs::read_to_string("data.json").unwrap()  // Blocks a runtime thread!
}
// ✅ Use tokio's async fs, or spawn_blocking for heavy ops
async fn good_read() -> String {
    tokio::fs::read_to_string("data.json").await.unwrap()
}
async fn good_heavy_compute(data: Vec<u8>) -> ProcessedData {
    tokio::task::spawn_blocking(move || {
        cpu_intensive_transform(&data)  // Runs on blocking thread pool
    }).await.unwrap()
}

// ❌ Holding std::sync::Mutex across .await — deadlock risk
async fn bad_lock(cache: Arc<std::sync::Mutex<HashMap<String, String>>>) {
    let mut guard = cache.lock().unwrap();
    let value = fetch_remote(&guard["key"]).await;  // Blocks runtime thread while awaiting!
    guard.insert("result".into(), value);
}
// ✅ Option A: Minimise lock scope — grab data, drop lock, then await
async fn good_lock_minimal(cache: Arc<std::sync::Mutex<HashMap<String, String>>>) {
    let key = {
        let guard = cache.lock().unwrap();
        guard["key"].clone()
    };  // Lock dropped here
    let value = fetch_remote(&key).await;
    cache.lock().unwrap().insert("result".into(), value);
}
// ✅ Option B: Use tokio::sync::Mutex when lock must span .await
async fn good_lock_async(cache: Arc<tokio::sync::Mutex<HashMap<String, String>>>) {
    let mut guard = cache.lock().await;  // Yields, doesn't block
    let value = fetch_remote(&guard["key"]).await;
    guard.insert("result".into(), value);
}

// ❌ Unbounded channels — memory bomb at 3am
let (tx, rx) = mpsc::unbounded_channel();  // No backpressure!
// ✅ ALWAYS use bounded channels in production
let (tx, rx) = mpsc::channel(1024);  // Sender blocks when full = backpressure
```

### Backpressure Design

Backpressure is not optional in data pipelines. Without it, a slow consumer causes unbounded
memory growth until OOM. Bounded channels are the primary mechanism.

```rust
use tokio::sync::mpsc;

// Capacity = expected burst size, not sustained throughput
// Too small: sender blocks constantly, throughput drops
// Too large: memory wasted, latency spikes on drain
let (tx, rx) = mpsc::channel::<Batch>(64);  // 64 batches in flight

// For multi-stage pipelines, each stage gets its own bounded channel.
// Backpressure cascades upstream automatically:
//   [source] --64--> [transform] --32--> [sink]
//   If sink slows down, transform channel fills, source blocks.
```

**Channel sizing rules of thumb:**
- **CPU-bound stages:** 2-4x worker count
- **I/O-bound stages (network/disk):** 32-128 (absorb latency variance)
- **Never unbounded** — if you think you need unbounded, you have a design problem
- **Exception:** Result/completion channels can be unbounded to avoid deadlock in DAG schedulers

### Concurrency Limiting with Semaphores

Control how many concurrent operations hit a downstream resource:

```rust
use tokio::sync::Semaphore;
use std::sync::Arc;

struct RateLimitedClient {
    client: reqwest::Client,
    semaphore: Arc<Semaphore>,
}

impl RateLimitedClient {
    fn new(max_concurrent: usize) -> Self {
        Self {
            client: reqwest::Client::new(),
            semaphore: Arc::new(Semaphore::new(max_concurrent)),
        }
    }

    async fn fetch(&self, url: &str) -> Result<String> {
        // Acquire permit — blocks if max_concurrent requests in flight
        let _permit = self.semaphore.acquire().await.unwrap();
        let resp = self.client.get(url).send().await?;
        resp.text().await.map_err(Into::into)
        // permit dropped here — next waiter unblocked
    }
}
```

### `select!` vs `spawn` — When to Use Which

| Pattern | Use `select!` | Use `spawn` |
|---------|--------------|-------------|
| **Borrowing** | Can borrow local data (no `'static`) | Requires `'static` + `Send` |
| **Cancellation** | Branch cancelled when another completes | Must use `CancellationToken` or `JoinHandle::abort()` |
| **Scheduling** | Same task, interleaved (cooperative) | Independent tasks, truly concurrent |
| **Use case** | Timeout races, shutdown signals, first-of-N | Background work, parallel I/O, fan-out |

```rust
// select! — race a timeout against work (borrows local data)
let result = tokio::select! {
    output = do_work(&local_data) => output,
    _ = tokio::time::sleep(Duration::from_secs(5)) => {
        Err(Error::Timeout)
    }
};

// spawn — fan-out to parallel workers (must be 'static + Send)
let mut set = JoinSet::new();
for item in items {
    let client = client.clone();  // Arc or Clone
    set.spawn(async move { client.process(item).await });
}
// JoinSet drops remaining tasks when it goes out of scope = structured concurrency
```

### spawn_blocking — CPU-Bound Work

`spawn_blocking` moves work to a dedicated thread pool so it doesn't starve the async
runtime. Use it for compression, encryption, JSON parsing of large documents, or any
computation >1ms.

```rust
// ❌ CPU work on the async runtime — starves other tasks
async fn bad_compress(data: Vec<u8>) -> Vec<u8> {
    zstd::bulk::compress(&data, 3).unwrap()  // Blocks runtime thread
}

// ✅ Offload to blocking pool
async fn good_compress(data: Vec<u8>) -> Result<Vec<u8>> {
    tokio::task::spawn_blocking(move || {
        zstd::bulk::compress(&data, 3).map_err(Error::Compression)
    }).await?
}

// ⚠️ spawn_blocking tasks cannot be cancelled — they run to completion.
// Limit concurrency with a semaphore if spawning many:
let sem = Arc::new(Semaphore::new(num_cpus::get()));
for chunk in chunks {
    let permit = sem.clone().acquire_owned().await.unwrap();
    tokio::task::spawn_blocking(move || {
        let result = heavy_compute(chunk);
        drop(permit);
        result
    });
}
```

### Yielding in Long Computations

If you can't move work to `spawn_blocking` (e.g., iterating over data with async I/O
interleaved), yield periodically to keep the runtime responsive:

```rust
async fn process_large_dataset(records: &[Record]) -> Result<()> {
    for (i, record) in records.iter().enumerate() {
        process_record(record)?;

        // Yield every 1000 iterations so other tasks can run
        if i % 1000 == 0 {
            tokio::task::yield_now().await;
        }
    }
    Ok(())
}
```

### Structured Concurrency with JoinSet

`JoinSet` provides structured concurrency — all spawned tasks are cancelled when the
`JoinSet` is dropped. This prevents zombie tasks.

```rust
use tokio::task::JoinSet;

async fn fetch_all(urls: Vec<String>) -> Vec<Result<Response>> {
    let mut set = JoinSet::new();
    let client = reqwest::Client::new();

    for url in urls {
        let client = client.clone();
        set.spawn(async move {
            client.get(&url).send().await.map_err(Error::from)
        });
    }

    let mut results = Vec::with_capacity(set.len());
    while let Some(res) = set.join_next().await {
        match res {
            Ok(response) => results.push(response),
            Err(join_err) => {
                // Task panicked or was cancelled
                tracing::error!(error = %join_err, "Task failed");
            }
        }
    }
    results
}
// If fetch_all is dropped early (e.g., timeout), all in-flight tasks are cancelled.
```

### Async Stream Processing with Bounded Concurrency

Process a stream of items with controlled parallelism:

```rust
use futures::stream::{self, StreamExt};

async fn process_stream(items: Vec<Item>) -> Vec<Result<Output>> {
    stream::iter(items)
        .map(|item| async move {
            transform(item).await
        })
        .buffer_unordered(32)  // Max 32 concurrent transforms
        .collect()
        .await
}

// For ordered results, use .buffered(32) instead of .buffer_unordered(32)
```

---

## Hot Path Optimization

### Identifying Hot Paths

Hot paths are code sections that execute frequently and dominate runtime. In data pipelines:

- **Parsing loops** - deserializing millions of records
- **Transform functions** - applied to every record
- **Hash lookups** - dictionary encoding, deduplication
- **Serialization** - writing output

### Profiling First

```bash
# CPU profiling with perf
perf record --call-graph dwarf ./target/release/pipeline
perf report

# Flame graphs
cargo install flamegraph
cargo flamegraph --bin pipeline

# Memory profiling
cargo install cargo-instruments  # macOS
cargo instruments -t Allocations --bin pipeline
```

### NEVER Use Regex or Grok on Hot Paths

> **"If you want to spot an amateur, look for a regex on the hot path."** — Derek

**This is not a suggestion. Do not use `regex`, `fancy-regex`, or grok patterns on
any code path that processes data at volume.** Regex is a compiled state machine with
per-match overhead that destroys throughput. Every regex match allocates, branches
unpredictably, and thrashes the instruction cache.

Use direct string/byte operations instead. They are faster by 10-100x on the patterns
that appear in data pipelines.

```rust
// ❌ NEVER — regex for simple field extraction
use regex::Regex;
let re = Regex::new(r"user_id=(\w+)").unwrap();
let user_id = re.captures(line).and_then(|c| c.get(1)).map(|m| m.as_str());

// ✅ ALWAYS — direct byte operations
fn extract_field<'a>(line: &'a [u8], key: &[u8]) -> Option<&'a [u8]> {
    let start = memchr::memmem::find(line, key)? + key.len();
    let end = memchr::memchr2(b' ', b'\n', &line[start..])
        .map(|i| start + i)
        .unwrap_or(line.len());
    Some(&line[start..end])
}
let user_id = extract_field(line, b"user_id=");
```

**Common regex patterns and their high-performance replacements:**

| Regex Pattern | Replace With | Why |
|---|---|---|
| `Regex::new(r"\d+")` to find numbers | `memchr::memchr` + `is_ascii_digit()` loop | No compilation, no alloc |
| `Regex::new(r"key=(\w+)")` for KV extraction | `memmem::find` + scan to delimiter | SIMD substring search |
| `Regex::new(r"^\d{4}-\d{2}-\d{2}")` date prefix | `line.len() >= 10 && line[4] == b'-' && ...` | Constant-time check |
| `Regex::new(r"\s+")` to split on whitespace | `split_ascii_whitespace()` or `memchr_iter` | Zero-alloc iterator |
| `Regex::new(r"[,\t\|]")` delimiter detection | `memchr::memchr3(b',', b'\t', b'\|', data)` | SIMD 3-byte search |
| Grok `%{IP:client}` patterns | `memchr` to find field boundaries + `&[u8]` slicing | Zero-copy extraction |
| `line.contains("error")` on `&str` | `memchr::memmem::find(line, b"error")` | SIMD on bytes, not chars |

```rust
// ❌ Grok-style: parse syslog with regex
let re = Regex::new(
    r"<(\d+)>(\w+ +\d+ \S+) (\S+) (\S+)\[(\d+)\]: (.*)"
).unwrap();

// ✅ Positional parsing with memchr — zero-copy, zero-alloc
fn parse_syslog(line: &[u8]) -> Option<SyslogFields<'_>> {
    let pri_end = memchr::memchr(b'>', line)?;
    let priority = &line[1..pri_end];
    let rest = &line[pri_end + 1..];

    // Timestamp ends at first hostname (after 2nd space)
    let s1 = memchr::memchr(b' ', rest)?;
    let s2 = memchr::memchr(b' ', &rest[s1 + 1..])? + s1 + 1;
    let s3 = memchr::memchr(b' ', &rest[s2 + 1..])? + s2 + 1;
    let timestamp = &rest[..s3];
    let host = &rest[s3 + 1..memchr::memchr(b' ', &rest[s3 + 1..])? + s3 + 1];

    Some(SyslogFields { priority, timestamp, host, /* ... */ })
}
```

**When regex IS acceptable:**
- Configuration parsing (runs once at startup, not on hot path)
- User-facing search/filter features (user expects regex syntax)
- Test assertions
- Code that runs fewer than ~1000 times per second

**When regex is NEVER acceptable:**
- Per-event/per-record processing in data pipelines
- Log parsing at ingest volume
- Any `for record in stream` loop body
- Anything inside `#[inline]` or hot-path functions

### Inlining Strategy

```rust
// Always inline small, hot functions
#[inline(always)]
fn is_valid_char(c: u8) -> bool {
    c.is_ascii_alphanumeric() || c == b'_'
}

// Suggest inlining for frequently called functions
#[inline]
fn parse_field(input: &[u8]) -> Option<&[u8]> {
    // Fast path parsing
}

// Prevent inlining for cold error paths
#[cold]
#[inline(never)]
fn handle_parse_error(input: &[u8], pos: usize) -> ParseError {
    // Error construction (not performance critical)
    ParseError::InvalidInput {
        context: String::from_utf8_lossy(&input[pos.saturating_sub(20)..]).to_string(),
        position: pos,
    }
}
```

### Branch Prediction Hints

```rust
use std::intrinsics::{likely, unlikely};

// In nightly Rust
fn parse_record(input: &[u8]) -> Result<Record, Error> {
    if unlikely(input.is_empty()) {
        return Err(Error::Empty);
    }

    if likely(input[0] == b'{') {
        // Fast path - JSON object
        parse_json_object(input)
    } else {
        // Slow path - other formats
        parse_alternative(input)
    }
}

// Stable alternative: structure code so common path is first
fn parse_record(input: &[u8]) -> Result<Record, Error> {
    // Common case first, no branches
    if input.first() == Some(&b'{') {
        return parse_json_object(input);
    }

    // Less common cases
    if input.is_empty() {
        return Err(Error::Empty);
    }

    parse_alternative(input)
}
```

### Avoid Allocations in Hot Paths

```rust
// ❌ Bad - allocates on every call
fn process_record(record: &Record) -> String {
    format!("{}:{}", record.id, record.value)
}

// ✅ Good - write to provided buffer
fn process_record(record: &Record, buffer: &mut String) {
    use std::fmt::Write;
    buffer.clear();
    write!(buffer, "{}:{}", record.id, record.value).unwrap();
}

// ✅ Good - return Cow for conditional allocation
fn normalize_string(s: &str) -> Cow<'_, str> {
    if s.chars().all(|c| c.is_ascii_lowercase()) {
        Cow::Borrowed(s)  // No allocation
    } else {
        Cow::Owned(s.to_lowercase())  // Allocate only when needed
    }
}
```

### Batch Processing

```rust
// ❌ Bad - process one at a time
for record in records {
    let result = transform(record);
    output.write(result)?;
}

// ✅ Good - batch for amortized costs
const BATCH_SIZE: usize = 10_000;

for chunk in records.chunks(BATCH_SIZE) {
    let results: Vec<_> = chunk
        .iter()
        .map(transform)
        .collect();

    output.write_batch(&results)?;
}
```

---

## Zero-Copy Data Processing

### Understanding Zero-Copy

Zero-copy means processing data without copying it to new memory locations. Key techniques:

1. **References** - borrow instead of clone
2. **Slices** - views into existing data
3. **Memory mapping** - work directly with file contents
4. **Cow** - copy only when modification needed

### String Types for Zero-Copy

```rust
use std::borrow::Cow;
use std::sync::Arc;
use compact_str::CompactString;

// For short strings (≤24 bytes on stack)
// Avoids heap allocation for common cases like field names
let field: CompactString = CompactString::from("user_id");

// For shared immutable strings across threads
// Single allocation, reference counted
let shared: Arc<str> = Arc::from("shared_value");
let clone = Arc::clone(&shared);  // Just increments refcount

// For conditional ownership
// Borrow when possible, own when needed
fn process_field<'a>(input: &'a str, needs_transform: bool) -> Cow<'a, str> {
    if needs_transform {
        Cow::Owned(input.to_uppercase())
    } else {
        Cow::Borrowed(input)
    }
}

// For parsing - reference into original buffer
struct ParsedRecord<'a> {
    id: &'a str,
    name: &'a str,
    data: &'a [u8],
}
```

### Slice-Based Parsing

```rust
/// Parse without copying - return references into input
fn parse_csv_line(line: &str) -> Vec<&str> {
    line.split(',').collect()
}

/// Parse JSON field without allocation
fn extract_field<'a>(json: &'a str, field: &str) -> Option<&'a str> {
    let pattern = format!("\"{}\":\"", field);
    let start = json.find(&pattern)? + pattern.len();
    let end = start + json[start..].find('"')?;
    Some(&json[start..end])
}

/// Process bytes directly
fn count_newlines(data: &[u8]) -> usize {
    data.iter().filter(|&&b| b == b'\n').count()
}
```

### Memory-Mapped Files

```rust
use memmap2::{Mmap, MmapOptions};
use std::fs::File;

fn process_large_file(path: &Path) -> Result<Stats> {
    let file = File::open(path)?;
    let mmap = unsafe { MmapOptions::new().map(&file)? };

    // mmap is now a &[u8] backed by the file
    // OS handles paging - only loads what you access
    let data: &[u8] = &mmap;

    // Process directly without loading entire file
    let mut stats = Stats::default();
    for line in data.split(|&b| b == b'\n') {
        stats.process_line(line);
    }

    Ok(stats)
}

// For concurrent read access
fn parallel_process(path: &Path) -> Result<Vec<Stats>> {
    let file = File::open(path)?;
    let mmap = unsafe { MmapOptions::new().map(&file)? };
    let mmap = Arc::new(mmap);

    let chunk_size = mmap.len() / num_cpus::get();
    let handles: Vec<_> = (0..num_cpus::get())
        .map(|i| {
            let mmap = Arc::clone(&mmap);
            std::thread::spawn(move || {
                let start = i * chunk_size;
                let end = if i == num_cpus::get() - 1 {
                    mmap.len()
                } else {
                    (i + 1) * chunk_size
                };
                process_chunk(&mmap[start..end])
            })
        })
        .collect();

    handles.into_iter().map(|h| h.join().unwrap()).collect()
}
```

### Buffer Reuse

```rust
/// Reusable buffer pool for parsing
struct BufferPool {
    buffers: Vec<Vec<u8>>,
    buffer_size: usize,
}

impl BufferPool {
    fn new(count: usize, size: usize) -> Self {
        Self {
            buffers: (0..count).map(|_| Vec::with_capacity(size)).collect(),
            buffer_size: size,
        }
    }

    fn get(&mut self) -> Vec<u8> {
        self.buffers.pop().unwrap_or_else(|| Vec::with_capacity(self.buffer_size))
    }

    fn put(&mut self, mut buffer: Vec<u8>) {
        buffer.clear();
        if buffer.capacity() <= self.buffer_size * 2 {
            self.buffers.push(buffer);
        }
        // Drop oversized buffers
    }
}

// Usage
fn process_records(input: &[u8], pool: &mut BufferPool) -> Vec<Record> {
    let mut buffer = pool.get();
    let mut results = Vec::new();

    for chunk in input.chunks(1024) {
        buffer.extend_from_slice(chunk);
        if let Some(record) = try_parse(&buffer) {
            results.push(record);
            buffer.clear();
        }
    }

    pool.put(buffer);
    results
}
```

---

## SIMD and Vectorized Processing

### When to Use SIMD

SIMD (Single Instruction, Multiple Data) processes multiple values simultaneously. Effective for:

- Parsing (finding delimiters, validating characters)
- Searching (substring matching, filtering)
- Numeric operations (aggregations, transformations)
- Encoding/decoding (base64, UTF-8 validation)

### SIMD-Accelerated JSON Parsing

```rust
// sonic-rs provides SIMD-accelerated JSON parsing
use sonic_rs::{from_slice, to_string, JsonValueTrait};

// 2-4x faster than serde_json for large documents
fn parse_json_fast(data: &[u8]) -> Result<Value> {
    sonic_rs::from_slice(data).map_err(Into::into)
}

// For known structures
#[derive(Deserialize)]
struct Record {
    id: String,
    values: Vec<i64>,
}

fn parse_records(data: &[u8]) -> Result<Vec<Record>> {
    sonic_rs::from_slice(data).map_err(Into::into)
}
```

### SIMD String Search

```rust
// memchr uses SIMD for byte searching
use memchr::{memchr, memchr2, memchr3, memmem};

// Find single byte - much faster than iter().position()
fn find_newline(data: &[u8]) -> Option<usize> {
    memchr(b'\n', data)
}

// Find any of multiple bytes
fn find_delimiter(data: &[u8]) -> Option<usize> {
    memchr3(b',', b'\t', b'|', data)
}

// Substring search
fn find_pattern(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    memmem::find(haystack, needle)
}

// Iterate over all matches
fn count_lines(data: &[u8]) -> usize {
    memchr::memchr_iter(b'\n', data).count()
}

// Precompiled searcher for repeated searches
fn search_multiple(haystacks: &[&[u8]], pattern: &[u8]) -> Vec<Option<usize>> {
    let finder = memmem::Finder::new(pattern);
    haystacks.iter().map(|h| finder.find(h)).collect()
}
```

### Portable SIMD (Nightly)

```rust
#![feature(portable_simd)]
use std::simd::*;

// Process 32 bytes at a time
fn sum_bytes_simd(data: &[u8]) -> u64 {
    let mut sum = u64x8::splat(0);
    let chunks = data.chunks_exact(64);
    let remainder = chunks.remainder();

    for chunk in chunks {
        let a = u8x32::from_slice(&chunk[0..32]);
        let b = u8x32::from_slice(&chunk[32..64]);

        // Widen to u64 and accumulate
        let a_wide: u64x8 = a.cast();
        let b_wide: u64x8 = b.cast();
        sum += a_wide + b_wide;
    }

    // Handle remainder with scalar code
    let scalar_sum: u64 = remainder.iter().map(|&b| b as u64).sum();
    sum.reduce_sum() + scalar_sum
}

// Count matching bytes
fn count_char_simd(data: &[u8], target: u8) -> usize {
    let target_vec = u8x32::splat(target);
    let mut count = 0usize;

    for chunk in data.chunks_exact(32) {
        let v = u8x32::from_slice(chunk);
        let matches = v.simd_eq(target_vec);
        count += matches.to_bitmask().count_ones() as usize;
    }

    // Handle remainder
    count += data.chunks_exact(32).remainder()
        .iter()
        .filter(|&&b| b == target)
        .count();

    count
}
```

### Vectorized Transformations

```rust
// Process numeric data in batches
fn scale_values(data: &mut [f64], factor: f64) {
    // Compiler auto-vectorizes simple loops
    for x in data.iter_mut() {
        *x *= factor;
    }
}

// Explicit SIMD with safe abstraction
use wide::f64x4;

fn scale_values_explicit(data: &mut [f64], factor: f64) {
    let factor_vec = f64x4::splat(factor);
    let chunks = data.chunks_exact_mut(4);
    let remainder = chunks.into_remainder();

    for chunk in data.chunks_exact_mut(4) {
        let v = f64x4::from(chunk);
        let scaled = v * factor_vec;
        chunk.copy_from_slice(&scaled.to_array());
    }

    for x in remainder {
        *x *= factor;
    }
}
```

---

## Memory Management for Scale

### Choosing the Right Allocator

```rust
// Cargo.toml
[dependencies]
tikv-jemallocator = "0.5"

// main.rs - use jemalloc for better multi-threaded performance
#[global_allocator]
static GLOBAL: tikv_jemallocator::Jemalloc = tikv_jemallocator::Jemalloc;
```

### Pre-allocation Strategies

```rust
// ✅ Good - pre-allocate with known size
fn collect_ids(records: &[Record]) -> Vec<String> {
    let mut ids = Vec::with_capacity(records.len());
    for record in records {
        ids.push(record.id.clone());
    }
    ids
}

// ✅ Good - reserve for estimated size
fn parse_lines(input: &str) -> Vec<Line> {
    let estimated_lines = input.len() / 80;  // Assume ~80 chars per line
    let mut lines = Vec::with_capacity(estimated_lines);

    for line in input.lines() {
        lines.push(parse_line(line));
    }
    lines
}

// ✅ Good - pre-allocate HashMap
fn build_index(records: &[Record]) -> HashMap<String, usize> {
    let mut index = HashMap::with_capacity(records.len());
    for (i, record) in records.iter().enumerate() {
        index.insert(record.id.clone(), i);
    }
    index
}
```

### Faster Hash Maps

```rust
use rustc_hash::FxHashMap;
use indexmap::IndexMap;

// FxHashMap - faster for internal use (not cryptographically secure)
fn build_internal_index(records: &[Record]) -> FxHashMap<u64, usize> {
    let mut index = FxHashMap::default();
    index.reserve(records.len());

    for (i, record) in records.iter().enumerate() {
        index.insert(record.id, i);
    }
    index
}

// IndexMap - preserves insertion order
fn build_ordered_index(records: &[Record]) -> IndexMap<String, Record> {
    records.iter()
        .map(|r| (r.id.clone(), r.clone()))
        .collect()
}

// AHash - fast, DoS-resistant (good default)
use ahash::AHashMap;

fn build_safe_index(records: &[Record]) -> AHashMap<String, usize> {
    records.iter()
        .enumerate()
        .map(|(i, r)| (r.id.clone(), i))
        .collect()
}
```

### Arena Allocation

```rust
use bumpalo::Bump;

// Arena for batch processing - fast allocation, bulk deallocation
fn process_batch<'a>(bump: &'a Bump, input: &[u8]) -> Vec<&'a str> {
    let mut results = Vec::new();

    for line in input.split(|&b| b == b'\n') {
        // Allocate in arena - very fast
        let s = bump.alloc_str(std::str::from_utf8(line).unwrap());
        results.push(&*s);
    }

    results
}

// Usage - clear arena between batches
fn process_file(path: &Path) -> Result<Stats> {
    let bump = Bump::new();
    let mut stats = Stats::default();

    for chunk in read_chunks(path)? {
        let results = process_batch(&bump, &chunk);
        stats.update(&results);
        bump.reset();  // Free all allocations at once
    }

    Ok(stats)
}
```

### Object Pooling

```rust
use crossbeam::queue::ArrayQueue;
use std::sync::Arc;

/// Thread-safe object pool
pub struct Pool<T> {
    queue: ArrayQueue<T>,
    factory: Box<dyn Fn() -> T + Send + Sync>,
}

impl<T> Pool<T> {
    pub fn new(capacity: usize, factory: impl Fn() -> T + Send + Sync + 'static) -> Self {
        let queue = ArrayQueue::new(capacity);
        // Pre-populate
        for _ in 0..capacity {
            let _ = queue.push(factory());
        }
        Self {
            queue,
            factory: Box::new(factory),
        }
    }

    pub fn get(&self) -> Pooled<T> {
        let item = self.queue.pop().unwrap_or_else(|| (self.factory)());
        Pooled { pool: self, item: Some(item) }
    }
}

pub struct Pooled<'a, T> {
    pool: &'a Pool<T>,
    item: Option<T>,
}

impl<T> Drop for Pooled<'_, T> {
    fn drop(&mut self) {
        if let Some(item) = self.item.take() {
            let _ = self.pool.queue.push(item);
        }
    }
}

// Usage
let buffer_pool = Pool::new(16, || Vec::with_capacity(64 * 1024));

let mut buffer = buffer_pool.get();
buffer.extend_from_slice(data);
// buffer returned to pool on drop
```

---

## Concurrency Patterns

### Choosing Sync Primitives

| Primitive | Use Case | Lock Type |
|-----------|----------|-----------|
| `Mutex<T>` | General mutable access | Blocking |
| `RwLock<T>` | Read-heavy workloads | Blocking |
| `parking_lot::Mutex` | High-contention | Blocking (faster) |
| `tokio::sync::Mutex` | Async contexts | Async |
| `AtomicU64` | Simple counters | Lock-free |
| `crossbeam::channel` | Producer-consumer | Lock-free |
| `DashMap` | Concurrent HashMap | Fine-grained |

### Read-Heavy Access with RwLock

```rust
use parking_lot::RwLock;
use std::sync::Arc;

struct Cache {
    data: RwLock<HashMap<String, Value>>,
}

impl Cache {
    fn get(&self, key: &str) -> Option<Value> {
        // Multiple readers can access simultaneously
        self.data.read().get(key).cloned()
    }

    fn insert(&self, key: String, value: Value) {
        // Writers get exclusive access
        self.data.write().insert(key, value);
    }

    fn get_or_insert(&self, key: &str, f: impl FnOnce() -> Value) -> Value {
        // Upgrade pattern: try read first
        if let Some(v) = self.data.read().get(key) {
            return v.clone();
        }

        // Only take write lock if needed
        let mut write = self.data.write();
        // Double-check after acquiring write lock
        if let Some(v) = write.get(key) {
            return v.clone();
        }

        let value = f();
        write.insert(key.to_string(), value.clone());
        value
    }
}
```

### Lock-Free Data Structures

```rust
use dashmap::DashMap;
use crossbeam::queue::SegQueue;

// Concurrent HashMap - fine-grained locking
fn concurrent_index() {
    let map: DashMap<String, u64> = DashMap::new();

    // Can be safely shared across threads
    map.insert("key".to_string(), 42);

    // Entry API for atomic updates
    map.entry("counter".to_string())
        .and_modify(|v| *v += 1)
        .or_insert(1);

    // Parallel iteration
    map.par_iter().for_each(|entry| {
        println!("{}: {}", entry.key(), entry.value());
    });
}

// Lock-free queue for work distribution
fn work_queue() {
    let queue: Arc<SegQueue<Work>> = Arc::new(SegQueue::new());

    // Producer
    let q = Arc::clone(&queue);
    std::thread::spawn(move || {
        for work in generate_work() {
            q.push(work);
        }
    });

    // Consumer
    loop {
        if let Some(work) = queue.pop() {
            process(work);
        }
    }
}
```

### Atomic Operations

```rust
use std::sync::atomic::{AtomicU64, AtomicBool, Ordering};

struct Metrics {
    processed: AtomicU64,
    errors: AtomicU64,
    running: AtomicBool,
}

impl Metrics {
    fn new() -> Self {
        Self {
            processed: AtomicU64::new(0),
            errors: AtomicU64::new(0),
            running: AtomicBool::new(true),
        }
    }

    fn record_success(&self) {
        // Relaxed ordering OK for counters
        self.processed.fetch_add(1, Ordering::Relaxed);
    }

    fn record_error(&self) {
        self.errors.fetch_add(1, Ordering::Relaxed);
    }

    fn stop(&self) {
        // Release ordering ensures all prior writes are visible
        self.running.store(false, Ordering::Release);
    }

    fn is_running(&self) -> bool {
        // Acquire ordering ensures we see all writes before stop()
        self.running.load(Ordering::Acquire)
    }

    fn snapshot(&self) -> (u64, u64) {
        (
            self.processed.load(Ordering::Relaxed),
            self.errors.load(Ordering::Relaxed),
        )
    }
}
```

### Parallel Processing with Rayon

```rust
use rayon::prelude::*;

// Parallel iteration
fn process_parallel(records: &[Record]) -> Vec<Output> {
    records
        .par_iter()
        .map(|r| transform(r))
        .collect()
}

// Parallel with filtering
fn filter_parallel(records: &[Record]) -> Vec<&Record> {
    records
        .par_iter()
        .filter(|r| r.is_valid())
        .collect()
}

// Parallel fold/reduce
fn sum_parallel(values: &[i64]) -> i64 {
    values.par_iter().sum()
}

// Custom parallelism
fn process_with_chunks(data: &[u8]) -> Vec<Result> {
    data.par_chunks(1024 * 1024)  // 1MB chunks
        .map(|chunk| process_chunk(chunk))
        .collect()
}

// Control thread pool
fn configure_rayon() {
    rayon::ThreadPoolBuilder::new()
        .num_threads(8)
        .stack_size(4 * 1024 * 1024)
        .build_global()
        .unwrap();
}
```

---

## Data Pipeline Architecture

### Pipeline Stages

```rust
use tokio::sync::mpsc;

/// Stage trait for pipeline components
#[async_trait]
pub trait Stage: Send + Sync {
    type Input: Send;
    type Output: Send;

    async fn process(&self, input: Self::Input) -> Result<Self::Output>;
}

/// Connect stages with channels
pub struct Pipeline<I, O> {
    stages: Vec<Box<dyn Stage<Input = I, Output = O>>>,
}

impl<I: Send + 'static, O: Send + 'static> Pipeline<I, O> {
    pub async fn run(
        self,
        mut input: mpsc::Receiver<I>,
        output: mpsc::Sender<O>,
    ) -> Result<()> {
        while let Some(item) = input.recv().await {
            let mut current: Box<dyn Any + Send> = Box::new(item);

            for stage in &self.stages {
                current = Box::new(stage.process(
                    *current.downcast().unwrap()
                ).await?);
            }

            output.send(*current.downcast().unwrap()).await?;
        }
        Ok(())
    }
}
```

### Batch Processing Pipeline

```rust
/// Batch accumulator for efficient processing
pub struct BatchAccumulator<T> {
    batch: Vec<T>,
    capacity: usize,
}

impl<T> BatchAccumulator<T> {
    pub fn new(capacity: usize) -> Self {
        Self {
            batch: Vec::with_capacity(capacity),
            capacity,
        }
    }

    pub fn push(&mut self, item: T) -> Option<Vec<T>> {
        self.batch.push(item);
        if self.batch.len() >= self.capacity {
            Some(std::mem::replace(
                &mut self.batch,
                Vec::with_capacity(self.capacity),
            ))
        } else {
            None
        }
    }

    pub fn flush(&mut self) -> Option<Vec<T>> {
        if self.batch.is_empty() {
            None
        } else {
            Some(std::mem::replace(
                &mut self.batch,
                Vec::with_capacity(self.capacity),
            ))
        }
    }
}

// Usage
async fn batch_process(
    mut rx: mpsc::Receiver<Record>,
    tx: mpsc::Sender<Vec<Output>>,
) -> Result<()> {
    let mut accumulator = BatchAccumulator::new(10_000);

    while let Some(record) = rx.recv().await {
        if let Some(batch) = accumulator.push(record) {
            let outputs = process_batch(&batch).await?;
            tx.send(outputs).await?;
        }
    }

    // Flush remaining
    if let Some(batch) = accumulator.flush() {
        let outputs = process_batch(&batch).await?;
        tx.send(outputs).await?;
    }

    Ok(())
}
```

### Column-Wise Processing

```rust
/// Process data column-wise for better cache efficiency
pub struct ColumnarBatch {
    ids: Vec<u64>,
    timestamps: Vec<i64>,
    values: Vec<f64>,
    flags: Vec<u8>,
}

impl ColumnarBatch {
    pub fn with_capacity(cap: usize) -> Self {
        Self {
            ids: Vec::with_capacity(cap),
            timestamps: Vec::with_capacity(cap),
            values: Vec::with_capacity(cap),
            flags: Vec::with_capacity(cap),
        }
    }

    pub fn push(&mut self, record: &Record) {
        self.ids.push(record.id);
        self.timestamps.push(record.timestamp);
        self.values.push(record.value);
        self.flags.push(record.flags);
    }

    /// Filter by timestamp - operates on contiguous memory
    pub fn filter_by_time(&self, min: i64, max: i64) -> Vec<usize> {
        self.timestamps
            .iter()
            .enumerate()
            .filter(|(_, &ts)| ts >= min && ts <= max)
            .map(|(i, _)| i)
            .collect()
    }

    /// Aggregate values - cache-friendly sequential access
    pub fn sum_values(&self) -> f64 {
        self.values.iter().sum()
    }

    /// Vectorizable operation
    pub fn scale_values(&mut self, factor: f64) {
        for v in &mut self.values {
            *v *= factor;
        }
    }
}
```

### Backpressure Handling

```rust
use tokio::sync::{mpsc, Semaphore};
use std::sync::Arc;

/// Pipeline with backpressure control
pub struct BackpressuredPipeline {
    semaphore: Arc<Semaphore>,
    max_in_flight: usize,
}

impl BackpressuredPipeline {
    pub fn new(max_in_flight: usize) -> Self {
        Self {
            semaphore: Arc::new(Semaphore::new(max_in_flight)),
            max_in_flight,
        }
    }

    pub async fn process<T, F, Fut>(&self, items: Vec<T>, processor: F) -> Vec<Result<()>>
    where
        T: Send + 'static,
        F: Fn(T) -> Fut + Send + Sync + Clone + 'static,
        Fut: std::future::Future<Output = Result<()>> + Send,
    {
        let mut handles = Vec::with_capacity(items.len());

        for item in items {
            // Wait for permit - blocks if too many in flight
            let permit = self.semaphore.clone().acquire_owned().await.unwrap();
            let processor = processor.clone();

            let handle = tokio::spawn(async move {
                let result = processor(item).await;
                drop(permit);  // Release permit when done
                result
            });

            handles.push(handle);
        }

        let mut results = Vec::with_capacity(handles.len());
        for handle in handles {
            results.push(handle.await.unwrap());
        }
        results
    }
}
```

---

## 8 Common Rust Mistakes

### 1. Using String When &str Works

```rust
// ❌ Bad - forces allocation for callers
fn greet(name: String) {
    println!("Hello, {}!", name);
}

// Caller must allocate:
greet("world".to_string());  // Unnecessary allocation

// ✅ Good - accept reference
fn greet(name: &str) {
    println!("Hello, {}!", name);
}

// Works with both:
greet("world");                    // &str directly
greet(&my_string);                 // &String coerces to &str
greet(&format!("user_{}", id));    // Temporary works too
```

### 2. Excessive Cloning

```rust
// ❌ Bad - clone to avoid borrow checker
fn process(data: &Data) {
    let cloned = data.clone();  // Expensive copy
    for item in cloned.items {
        println!("{}", item);
    }
}

// ✅ Good - borrow instead
fn process(data: &Data) {
    for item in &data.items {
        println!("{}", item);
    }
}

// ❌ Bad - clone in loop
for item in &items {
    let owned = item.name.clone();  // N allocations
    results.push(owned);
}

// ✅ Good - clone only when needed
let results: Vec<&str> = items.iter()
    .map(|item| item.name.as_str())
    .collect();
```

### 3. Over-using unwrap()

```rust
// ❌ Bad - panic in production
fn get_user(id: u64) -> User {
    let user = database.get(id).unwrap();  // Panics if not found
    user
}

// ✅ Good - return Result
fn get_user(id: u64) -> Result<User, UserError> {
    database.get(id).ok_or(UserError::NotFound(id))
}

// ✅ Good - return Option
fn get_user(id: u64) -> Option<User> {
    database.get(id)
}

// ✅ OK - unwrap with guaranteed invariant
fn first_char(s: &str) -> char {
    assert!(!s.is_empty(), "precondition: non-empty string");
    s.chars().next().unwrap()  // Safe due to assertion
}

// ✅ OK - expect with clear message (for truly impossible cases)
let home = std::env::var("HOME")
    .expect("HOME environment variable must be set");
```

### 4. Manual Memory Management Mindset

```rust
// ❌ Bad - C-style thinking
let mut ptr = Box::new(value);
// ... use ptr ...
drop(ptr);  // Unnecessary - Rust drops automatically

// ❌ Bad - manual null checks
let mut data: Option<Box<Data>> = None;
// ...
if data.is_some() {
    // ...
}

// ✅ Good - let Rust manage it
{
    let data = Box::new(value);
    // ... use data ...
}  // Automatically dropped here

// ✅ Good - use pattern matching
if let Some(data) = &data {
    process(data);
}
```

### 5. Ignoring Compiler Errors

```rust
// The Rust compiler is your friend!

// ❌ Bad - ignore and add random &, *, clone
fn process(data: &Vec<String>) {
    let first = &*data[0].clone();  // Confused symbols

// ✅ Good - read the error message
// error[E0507]: cannot move out of index
// help: consider borrowing here: `&data[0]`

fn process(data: &[String]) {
    let first = &data[0];  // Follow compiler suggestion
}

// Compiler errors usually tell you exactly what to do:
// - "consider borrowing" -> add &
// - "consider using clone" -> add .clone() (but think first!)
// - "lifetime may not live long enough" -> check lifetime annotations
```

### 6. Complex Nested Loops Instead of Iterators

```rust
// ❌ Bad - imperative with nested loops
let mut result = Vec::new();
for user in &users {
    if user.active {
        for order in &user.orders {
            if order.total > 100.0 {
                result.push(order.id);
            }
        }
    }
}

// ✅ Good - iterator chain
let result: Vec<_> = users
    .iter()
    .filter(|u| u.active)
    .flat_map(|u| &u.orders)
    .filter(|o| o.total > 100.0)
    .map(|o| o.id)
    .collect();

// ❌ Bad - manual index tracking
let mut i = 0;
while i < data.len() {
    process(&data[i]);
    i += 1;
}

// ✅ Good - iterator
for item in &data {
    process(item);
}

// With index if needed
for (i, item) in data.iter().enumerate() {
    process(i, item);
}
```

### 7. Not Using rustfmt and clippy

```rust
// ❌ Bad - inconsistent formatting
fn process(x:i32,y:i32)->i32{
if x>y {x}else{y}}

// ✅ Good - run rustfmt
fn process(x: i32, y: i32) -> i32 {
    if x > y { x } else { y }
}

// Set up in your project:
// $ rustfmt --check src/**/*.rs  # CI
// $ cargo fmt                     # Auto-format

// Clippy catches common mistakes:
// $ cargo clippy -- -D warnings

// Example clippy catches:
// - .iter().map().collect() -> .to_vec()
// - if let Some(_) = x -> if x.is_some()
// - x.clone().clone() -> x.clone()
```

### 8. Fighting the Borrow Checker

```rust
// ❌ Bad - fighting with RefCell/Rc everywhere
use std::cell::RefCell;
use std::rc::Rc;

struct Node {
    value: i32,
    children: RefCell<Vec<Rc<RefCell<Node>>>>,
    parent: RefCell<Option<Rc<RefCell<Node>>>>,
}

// ✅ Good - restructure to work with ownership
// Option 1: Arena allocation
struct Tree {
    nodes: Vec<Node>,
}

struct Node {
    value: i32,
    children: Vec<usize>,  // Indices into nodes vec
    parent: Option<usize>,
}

// Option 2: Separate structure from references
struct TreeData {
    values: Vec<i32>,
    children: Vec<Vec<usize>>,
    parents: Vec<Option<usize>>,
}

// Option 3: Accept the ownership model
struct OwnedTree {
    value: i32,
    children: Vec<OwnedTree>,  // Children are owned
}

// ✅ Good - use indices for graph structures
struct Graph {
    nodes: Vec<NodeData>,
    edges: Vec<(usize, usize)>,
}
```

---

## Clippy Configuration

### clippy.toml

```toml
# Allow up to 7 arguments (default is 7)
too-many-arguments-threshold = 7

# Cognitive complexity threshold
cognitive-complexity-threshold = 25

# Allow large enum variants
enum-variant-size-threshold = 200
```

### Common Clippy Attributes

```rust
// Allow specific lints
#[allow(clippy::too_many_arguments)]
fn complex_function(a: i32, b: i32, c: i32, d: i32, e: i32, f: i32, g: i32, h: i32) {}

// Deny specific lints in module/crate
#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]

// Warn on all pedantic lints
#![warn(clippy::pedantic)]

// Allow in specific scope
#[allow(clippy::cast_possible_truncation)]
fn convert(x: u64) -> u32 {
    x as u32
}
```

### CI Clippy Command

```bash
cargo clippy --all-targets --all-features -- -D warnings
```

### Recommended Lints for Data Pipelines

```rust
// lib.rs or main.rs
#![warn(clippy::all)]
#![warn(clippy::pedantic)]
#![warn(clippy::nursery)]
#![allow(clippy::module_name_repetitions)]
#![allow(clippy::must_use_candidate)]

// Deny dangerous patterns
#![deny(clippy::unwrap_used)]
#![deny(clippy::panic)]
#![deny(clippy::expect_used)]
```

---

## Cargo.toml Best Practices

```toml
[package]
name = "data-pipeline"
version = "0.1.0"
edition = "2024"
rust-version = "1.94.0"  # Current stable as of March 2026; always use latest stable
description = "High-performance data processing pipeline"
license = "Apache-2.0"

[dependencies]
# Async runtime
tokio = { version = "1", features = ["full"] }

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"
sonic-rs = "0.3"  # SIMD JSON

# Error handling
thiserror = "1"
anyhow = "1"

# Logging
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["json", "env-filter"] }

# Performance
memchr = "2"           # SIMD string search
compact_str = "0.7"    # Small string optimization
rustc-hash = "1"       # Fast hashing
parking_lot = "0.12"   # Faster locks
dashmap = "5"          # Concurrent HashMap
rayon = "1"            # Parallel iterators

# Memory
bumpalo = "3"          # Arena allocation
tikv-jemallocator = "0.5"

[dev-dependencies]
tempfile = "3"
criterion = { version = "0.5", features = ["html_reports"] }
proptest = "1"

[profile.release]
lto = true
codegen-units = 1
strip = true
panic = "abort"

[profile.bench]
lto = true
codegen-units = 1

[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
pedantic = "warn"
unwrap_used = "deny"
expect_used = "deny"

[[bench]]
name = "throughput"
harness = false
```

### Version Pinning & Update Policy

**General rule: use `>=X.Y` compatible ranges, pin only when forced.**

```toml
# Cargo.toml
[dependencies]
tokio = { version = ">=1.50, <2" }           # ✅ >= range with semver bound
serde = { version = ">=1.0.228, <2" }        # ✅ >= with upper bound
hyperi-rustlib = { version = ">=1.16" }       # ✅ >= range
rdkafka = { version = "=0.39.0" }            # ⚠️ Pinned — document WHY
```

**Rules:**
- `>=X.Y, <Z` — default for all dependencies. Accept patches and minors
  within the major version. Cargo semver compatibility handles this naturally.
- `=X.Y.Z` — pin ONLY when a specific version has a known regression.
  Always add a `# pinned: reason` comment.
- `Cargo.lock` — always committed for binaries and applications. This IS
  your reproducible build. Libraries omit `Cargo.lock` (consumers resolve).
- `cargo deny check` in CI — catches license violations and security advisories.

**Update cadence:**
- Dependencies MUST be updated with every code review. Run `cargo update`
  and check for `cargo audit` advisories.
- `cargo deny check advisories` in CI — fails on known vulnerabilities.
- When updating, run the full test suite + clippy. If clean, update is safe.

```bash
# Update all deps to latest compatible versions
cargo update

# Check for security advisories
cargo audit

# Check licenses and advisories (CI)
cargo deny check
```

**Deprecation warnings MUST be fixed immediately.** If `cargo clippy`,
`cargo build`, or test output shows a deprecation warning, address it
in the current PR — do not defer. Deprecations become compile errors
on the next Rust edition or dependency major release.

**Risk mitigation for `>=` ranges:**

| Risk | Mitigation |
|---|---|
| Breaking upstream release | `Cargo.lock` pins exact versions — reproducible builds |
| Security vulnerability | `cargo audit` + `cargo deny` in CI — blocks merge |
| Yanked crate version | `cargo update` resolves to latest non-yanked |
| Stale deps | Mandatory `cargo update` at every code review |
| Incompatible transitive deps | Cargo resolver handles this — conflicts caught at build |

---

## Configuration (HyperI Cascade)

Rust implements the 7-layer config cascade using `config-rs`:

```rust
use config::{Config, Environment, File};

fn load_config() -> Result<Config, config::ConfigError> {
    Config::builder()
        // 7. Hard-coded defaults (lowest priority)
        .set_default("database.host", "localhost")?
        .set_default("database.port", 5432)?
        .set_default("log_level", "info")?
        .set_default("batch_size", 10_000)?
        .set_default("parallelism", num_cpus::get())?

        // 6. defaults.toml
        .add_source(File::with_name("config/defaults").required(false))

        // 5. settings.toml
        .add_source(File::with_name("config/settings").required(false))

        // 4. settings.{env}.toml
        .add_source(
            File::with_name(&format!(
                "config/settings.{}",
                std::env::var("APP_ENV").unwrap_or_else(|_| "development".into())
            ))
            .required(false),
        )

        // 3. .env file (via dotenvy)
        // dotenvy::dotenv().ok(); // Call at start of main()

        // 2. ENV variables (MYAPP_DATABASE_HOST)
        .add_source(Environment::with_prefix("MYAPP").separator("_"))

        // 1. CLI args via clap (applied after Config::build())
        .build()
}
```

---

## Logging (HyperI Standard)

Use `tracing` with RFC 3339 timestamps:

```rust
use std::io::IsTerminal;
use tracing::{info, error, warn, debug, instrument};
use tracing_subscriber::{fmt, EnvFilter, layer::SubscriberExt, util::SubscriberInitExt};

fn init_logging() {
    let is_terminal = std::io::stderr().is_terminal();

    let subscriber = tracing_subscriber::registry()
        .with(EnvFilter::from_default_env().add_directive("info".parse().unwrap()));

    if is_terminal {
        // Console: human-friendly with colours
        subscriber
            .with(fmt::layer().with_ansi(true).pretty())
            .init();
    } else {
        // Container/CI: JSON with RFC 3339 timestamps
        subscriber
            .with(fmt::layer().json().with_timer(fmt::time::UtcTime::rfc_3339()))
            .init();
    }
}

// Structured logging with spans
#[instrument(skip(data), fields(record_count = data.len()))]
async fn process_batch(data: &[Record]) -> Result<ProcessResult> {
    info!("Starting batch processing");

    for record in data {
        if let Err(e) = process_record(record).await {
            error!(error = %e, record_id = %record.id, "Failed to process record");
        }
    }

    info!("Batch complete");
    Ok(ProcessResult::default())
}

// Performance-sensitive logging
fn hot_path(data: &[u8]) {
    // Use debug! for hot paths - disabled in release
    debug!(bytes = data.len(), "Processing chunk");

    // Or check log level first
    if tracing::enabled!(tracing::Level::DEBUG) {
        debug!(first_bytes = ?&data[..8.min(data.len())], "Chunk preview");
    }
}
```

**Output Modes:**

| Context | Format | Colours |
|---------|--------|---------|
| Console (dev) | Human-friendly | Yes |
| Container/CI | RFC 3339 JSON | No |

**ENV overrides:** `RUST_LOG=debug`, `NO_COLOR=1`

---

## hyperi-rustlib

> **This section applies when `hyperi-rustlib` is in `Cargo.toml`.**
> For non-HyperI projects (e.g., open-source tools like claudemeter), skip this section
> and use the generic patterns from the rest of this document.

`hyperi-rustlib` is the shared Rust utility library for all HyperI Rust applications.
It provides config, logging, metrics, observability, transports, resilience, secrets,
and more. Available on crates.io. **Use it — never roll bespoke versions of what it provides.**

### Quick Start

```toml
# Cargo.toml
[dependencies]
hyperi-rustlib = { version = ">=1.16", features = [
    "config", "logger", "metrics", "env", "runtime"
]}
```

```rust
use hyperi_rustlib::{config, logger, env};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let environment = env::Environment::detect();
    logger::setup_default()?;
    config::setup(config::ConfigOptions {
        env_prefix: "MYAPP".into(),
        ..Default::default()
    })?;

    // Or use the convenience init:
    // hyperi_rustlib::init("MYAPP")?;

    tracing::info!("Running in {environment:?}");
    Ok(())
}
```

### Feature Selection Guide

Enable only what you need — features are additive and pull in their dependencies.

| Feature | Use When | Provides |
|---------|----------|----------|
| `config` | Always (default) | 8-layer figment cascade, .env, YAML, TOML, JSON, env vars |
| `config-reload` | Config changes at runtime | `SharedConfig<T>` + `ConfigReloader` hot-reload |
| `config-postgres` | Config stored in PostgreSQL | `PostgresConfigSource` with sqlx |
| `logger` | Always (default) | Structured logging, JSON/text auto-detect, sensitive field masking |
| `metrics` | Prometheus metrics | `MetricsManager`, process/container metrics, `/metrics` endpoint |
| `otel` | OpenTelemetry tracing | OTLP export (gRPC/HTTP), distributed tracing |
| `otel-metrics` | OTel + Prometheus metrics | OTel metrics bridge, OTLP metrics export |
| `http-server` | Serve HTTP | Axum HTTP server with health endpoints (`/healthz`, `/readyz`) |
| `http` | Call HTTP APIs | reqwest client with retry middleware |
| `resilience` | Downstream protection | Circuit breaker, retry with backoff, bulkhead (tower-resilience) |
| `transport-kafka` | Kafka producer/consumer | rdkafka wrapper (dynamic-linking against system librdkafka) |
| `transport-grpc` | gRPC services | tonic/prost transport |
| `transport-memory` | Testing | In-memory transport for test harnesses |
| `secrets` | Secret management | Core provider interface, file provider |
| `secrets-vault` | OpenBao/Vault | OpenBao/Vault secret provider |
| `secrets-aws` | AWS Secrets Manager | AWS Secrets Manager provider |
| `tiered-sink` | Resilient delivery | Hot buffer + disk spillover + circuit breaker |
| `spool` | Disk queue | Async FIFO queue (yaque + zstd compression) |
| `scaling` | KEDA autoscaling | Back-pressure primitives, scaling pressure calculation |
| `cli` | CLI applications | Standard clap framework with version/env integration |
| `top` | TUI dashboard | ratatui-based metrics dashboard |
| `dlq` | Dead letter queue | File-backed DLQ |
| `dlq-kafka` | DLQ to Kafka | Kafka DLQ backend |
| `deployment` | CI contract checks | Helm chart + Dockerfile contract validation |
| `expression` | CEL expressions | CEL expression evaluation (DFE expression profiles) |
| `full` | Everything | All features enabled |

### Use This, Not That

**If `hyperi-rustlib` is a dependency, ALWAYS use its features instead of bespoke code.**

| Need | Use (hyperi-rustlib) | NOT (bespoke) |
|------|---------------------|---------------|
| Config cascade | `config::setup()` + `config::get()` | Hand-rolling figment/dotenvy |
| Logging | `logger::setup_default()` | Manual `tracing_subscriber` setup |
| Sensitive field masking | `logger` (automatic) | Regex-based log scrubbing |
| Prometheus metrics | `MetricsManager::new("app")` | Raw `metrics-exporter-prometheus` |
| OTel tracing | `otel` feature | Manual `opentelemetry-otlp` setup |
| HTTP server + health | `HttpServer` with `http-server` feature | Bespoke axum + health routes |
| Circuit breaker | `resilience` feature | Hand-rolled state machines |
| Kafka producer/consumer | `transport-kafka` feature | Raw `rdkafka` ClientConfig |
| Secret rotation | `SecretsManager` | Direct vault/AWS SDK calls |
| Config hot-reload | `SharedConfig<T>` + `ConfigReloader` | Custom file watcher |
| Disk spillover | `TieredSink` with `tiered-sink` | Custom spool logic |
| CLI framework | `DfeApp` with `cli` feature | Manual clap setup |
| Environment detection | `env::Environment::detect()` | Checking env vars manually |
| KEDA scaling signals | `ScalingPressure` with `scaling` | Custom pressure math |

### Config Cascade (8 Layers)

Priority (highest first):
1. CLI arguments
2. Environment variables (`{PREFIX}_DATABASE_HOST`)
3. `.env` file
4. `settings.{environment}.yaml`
5. `settings.yaml`
6. `defaults.yaml`
7. Embedded defaults
8. Hard-coded fallbacks

```rust
use hyperi_rustlib::config;

config::setup(config::ConfigOptions {
    env_prefix: "MYAPP".into(),
    config_dir: Some("./config".into()),
    ..Default::default()
})?;

let cfg = config::get();
let db_host: String = cfg.get_string("database.host")?;
let db_port: u16 = cfg.get("database.port")?;
```

### Metrics Quick Reference

```rust
use hyperi_rustlib::MetricsManager;

let mgr = MetricsManager::new("dfe_loader");
let counter = mgr.counter("messages_processed_total", "Messages processed");
let histogram = mgr.histogram("batch_duration_seconds", "Batch processing duration");

// Record
counter.increment(1);
histogram.record(elapsed.as_secs_f64());
```

### Native System Dependencies

When using features that link C libraries, install system packages:

| Feature | Build Package | Runtime Package |
|---------|--------------|-----------------|
| `transport-kafka` | `librdkafka-dev` (Confluent APT) | `librdkafka1` |
| `directory-config-git` | `libgit2-dev` | `libgit2-1.7` |
| `spool`, `tiered-sink` | `libzstd-dev` | `libzstd1` |
| `secrets-aws` | (compiled from source) | (statically linked) |

---

## Observability

Logging alone is insufficient for production services. Use the three pillars: **traces**, **metrics**, **logs** — all exported via OpenTelemetry OTLP.

> **HyperI projects:** Use `hyperi-rustlib` features `otel`, `otel-metrics`, `otel-tracing`, `metrics`.
> See the [hyperi-rustlib](#hyperi-rustlib) section. Only roll bespoke setup for non-HyperI projects.

### OpenTelemetry Distributed Tracing

```rust
use opentelemetry::trace::TracerProvider;
use opentelemetry_otlp::SpanExporter;
use opentelemetry_sdk::trace::SdkTracerProvider;
use tracing_opentelemetry::OpenTelemetryLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

fn init_tracing() -> Result<SdkTracerProvider, Box<dyn std::error::Error>> {
    // OTLP exporter — sends to collector at localhost:4317 by default
    // Override with OTEL_EXPORTER_OTLP_ENDPOINT env var
    let exporter = SpanExporter::builder()
        .with_tonic()
        .build()?;

    let provider = SdkTracerProvider::builder()
        .with_batch_exporter(exporter)
        .build();

    let tracer = provider.tracer("my-service");
    let otel_layer = OpenTelemetryLayer::new(tracer);

    tracing_subscriber::registry()
        .with(EnvFilter::from_default_env())
        .with(otel_layer)
        .with(tracing_subscriber::fmt::layer().json())
        .init();

    Ok(provider)
}
```

### Prometheus Metrics

```rust
use metrics::{counter, gauge, histogram};
use metrics_exporter_prometheus::PrometheusBuilder;

fn init_metrics() -> Result<(), Box<dyn std::error::Error>> {
    // Serve /metrics on :9090
    PrometheusBuilder::new()
        .with_http_listener(([0, 0, 0, 0], 9090))
        .install()?;
    Ok(())
}

// Usage in hot paths — macros are zero-cost when no exporter is installed
fn process_message(msg: &Message) {
    counter!("messages_processed_total", "status" => "success").increment(1);
    histogram!("message_size_bytes").record(msg.len() as f64);
    gauge!("queue_depth").set(get_queue_depth() as f64);
}
```

### tokio-console (Async Debugging)

Interactive debugger for async tasks — like `htop` for your Tokio runtime.

```toml
# Cargo.toml — dev-only
[dependencies]
console-subscriber = { version = ">=0.4", optional = true }

[features]
tokio-console = ["console-subscriber"]
```

```rust
// Enable with: RUSTFLAGS="--cfg tokio_unstable" cargo run --features tokio-console
#[cfg(feature = "tokio-console")]
fn init_console() {
    console_subscriber::init();
}
```

```bash
# In another terminal:
tokio-console  # Shows tasks, polls, wakers, resource contention
```

### Health Checks (K8s Liveness/Readiness)

```rust
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

#[derive(Clone)]
pub struct HealthState {
    ready: Arc<AtomicBool>,
    alive: Arc<AtomicBool>,
}

impl HealthState {
    pub fn new() -> Self {
        Self {
            ready: Arc::new(AtomicBool::new(false)),
            alive: Arc::new(AtomicBool::new(true)),
        }
    }

    pub fn set_ready(&self)    { self.ready.store(true, Ordering::Release); }
    pub fn set_draining(&self) { self.ready.store(false, Ordering::Release); }
    pub fn set_dead(&self)     { self.alive.store(false, Ordering::Release); }

    pub fn is_ready(&self) -> bool { self.ready.load(Ordering::Acquire) }
    pub fn is_alive(&self) -> bool { self.alive.load(Ordering::Acquire) }
}

// Wire into axum:
// GET /healthz  -> 200 if alive, 503 if dead
// GET /readyz   -> 200 if ready, 503 if draining
```

---

## HTTP Service Patterns (axum + tower)

axum 0.8+ is the standard HTTP framework. It uses tower middleware natively —
no framework-specific middleware system to learn.

> **Path syntax changed in axum 0.8:** `/{param}` not `/:param`, `/{*wildcard}` not `/*wildcard`.

### Production Router

```rust
use axum::{Router, routing::get, extract::State};
use tower_http::{
    compression::CompressionLayer,
    cors::CorsLayer,
    timeout::TimeoutLayer,
    trace::TraceLayer,
};
use std::time::Duration;

fn build_router(state: AppState) -> Router {
    let api = Router::new()
        .route("/api/v1/records/{id}", get(get_record).post(create_record))
        .route("/api/v1/records", get(list_records));

    let health = Router::new()
        .route("/healthz", get(liveness))
        .route("/readyz", get(readiness))
        .route("/metrics", get(metrics_handler));

    Router::new()
        .merge(api)
        .merge(health)
        .layer(TraceLayer::new_for_http())
        .layer(TimeoutLayer::new(Duration::from_secs(30)))
        .layer(CompressionLayer::new())
        .layer(CorsLayer::permissive())  // Tighten for production
        .with_state(state)
}
```

### Resilience Middleware (tower-resilience)

```rust
use tower::ServiceBuilder;
use tower_resilience::{CircuitBreakerLayer, RetryLayer, BulkheadLayer};

// Stack resilience layers for downstream calls
let service = ServiceBuilder::new()
    .layer(BulkheadLayer::new(100))           // Max 100 concurrent
    .layer(RetryLayer::new(3))                // Retry up to 3 times
    .layer(CircuitBreakerLayer::default())    // Circuit breaker
    .service(downstream_client);
```

---

## Graceful Shutdown (K8s-Ready)

K8s sends SIGTERM, then waits `terminationGracePeriodSeconds` (default 30s) before SIGKILL.
Your service must: stop accepting new work, drain in-flight requests, then exit cleanly.

```rust
use tokio::sync::watch;
use tokio_util::sync::CancellationToken;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

pub struct GracefulShutdown {
    cancel: CancellationToken,
    health: HealthState,
    drain_timeout: Duration,
}

impl GracefulShutdown {
    pub fn new(health: HealthState, drain_timeout: Duration) -> Self {
        Self {
            cancel: CancellationToken::new(),
            health,
            drain_timeout,
        }
    }

    pub async fn run(self) {
        // Listen for SIGTERM (K8s) and SIGINT (Ctrl+C)
        let cancel = self.cancel.clone();
        tokio::spawn(async move {
            let mut sigterm = tokio::signal::unix::signal(
                tokio::signal::unix::SignalKind::terminate()
            ).expect("SIGTERM handler");

            tokio::select! {
                _ = tokio::signal::ctrl_c() => {}
                _ = sigterm.recv() => {}
            }
            cancel.cancel();
        });

        // Wait for shutdown signal
        self.cancel.cancelled().await;
        tracing::info!("Shutdown signal received, draining...");

        // Phase 1: Mark unhealthy so K8s stops routing traffic
        self.health.set_draining();

        // Phase 2: Wait for in-flight requests to complete
        tokio::time::sleep(self.drain_timeout).await;

        // Phase 3: Mark dead
        self.health.set_dead();
        tracing::info!("Drain complete, exiting");
    }

    pub fn token(&self) -> CancellationToken {
        self.cancel.clone()
    }
}
```

---

## Traits and Generics

### Trait Basics

```rust
/// Define behaviour that types can implement
pub trait Processor {
    /// Associated type - implementor chooses the concrete type
    type Output;

    /// Required method - must be implemented
    fn process(&self, input: &[u8]) -> Self::Output;

    /// Provided method - default implementation, can be overridden
    fn name(&self) -> &'static str {
        "unnamed"
    }
}

/// Implement trait for a type
struct JsonProcessor;

impl Processor for JsonProcessor {
    type Output = serde_json::Value;

    fn process(&self, input: &[u8]) -> Self::Output {
        serde_json::from_slice(input).unwrap_or_default()
    }

    fn name(&self) -> &'static str {
        "json"
    }
}
```

### The Orphan Rule

You can only implement a trait on a type if **either** the trait **or** the type is local to your crate:

```rust
// ✅ OK - your trait on external type
impl MyTrait for Vec<i32> { }

// ✅ OK - external trait on your type
impl Display for MyType { }

// ❌ ERROR - both trait and type are external
impl Display for Vec<i32> { }  // Orphan rule violation
```

This ensures code coherence and prevents conflicting implementations across crates.

### Generic Functions

```rust
// Single trait bound
fn process<T: Processor>(processor: T, data: &[u8]) -> T::Output {
    processor.process(data)
}

// Multiple bounds with +
fn process_and_log<T: Processor + Debug>(processor: T, data: &[u8]) -> T::Output {
    println!("Using processor: {:?}", processor);
    processor.process(data)
}

// Where clause for complex bounds
fn transform<T, U>(input: T, transformer: U) -> U::Output
where
    T: AsRef<[u8]>,
    U: Processor + Send + Sync + 'static,
{
    transformer.process(input.as_ref())
}

// impl Trait in argument position (syntactic sugar)
fn process_any(processor: impl Processor) {
    let _ = processor.process(b"data");
}

// impl Trait in return position - single concrete type
fn create_processor() -> impl Processor<Output = String> {
    StringProcessor::new()
}
```

### Trait Objects (Dynamic Dispatch)

```rust
// Box<dyn Trait> for runtime polymorphism
fn process_dynamic(processor: Box<dyn Processor<Output = String>>) -> String {
    processor.process(b"input")
}

// &dyn Trait for borrowed trait objects
fn process_borrowed(processor: &dyn Processor<Output = String>) -> String {
    processor.process(b"input")
}

// Vec of trait objects - heterogeneous collection
fn process_many(processors: Vec<Box<dyn Processor<Output = String>>>) {
    for p in processors {
        println!("{}: {}", p.name(), p.process(b"data"));
    }
}

// Object safety rules - trait must be object-safe to use as dyn Trait:
// ✅ Methods with &self or &mut self receiver
// ✅ Methods with no type parameters
// ❌ Methods returning Self
// ❌ Methods with generic type parameters
// ❌ Static methods (no self)

// ❌ NOT object-safe
trait NotObjectSafe {
    fn clone_self(&self) -> Self;  // Returns Self
    fn generic<T>(&self, t: T);    // Generic method
}

// ✅ Object-safe
trait ObjectSafe {
    fn process(&self) -> Box<dyn ObjectSafe>;  // Returns trait object, not Self
    fn name(&self) -> &str;
}
```

### When to Use Static vs Dynamic Dispatch

```rust
// ✅ Static dispatch (generics) - use when:
// - Performance is critical (no vtable lookup)
// - Types known at compile time
// - Monomorphization acceptable (larger binary)
fn fast_process<T: Processor>(p: T, data: &[u8]) -> T::Output {
    p.process(data)  // Direct call, inlined
}

// ✅ Dynamic dispatch (trait objects) - use when:
// - Need heterogeneous collections
// - Plugin systems / runtime loading
// - Reducing binary size
// - API boundary stability
fn flexible_process(p: &dyn Processor<Output = String>, data: &[u8]) -> String {
    p.process(data)  // vtable lookup
}

// Pattern: Store trait objects, process with generics
struct Pipeline {
    stages: Vec<Box<dyn Stage>>,  // Dynamic storage
}

impl Pipeline {
    fn add<S: Stage + 'static>(&mut self, stage: S) {
        self.stages.push(Box::new(stage));  // Generic addition
    }
}
```

### Associated Types vs Generic Parameters

```rust
// Associated type - one implementation per type
trait Iterator {
    type Item;  // Determined by implementor
    fn next(&mut self) -> Option<Self::Item>;
}

// Each type has exactly one Item type
impl Iterator for Counter {
    type Item = u32;  // Counter always yields u32
    fn next(&mut self) -> Option<u32> { ... }
}

// Generic parameter - multiple implementations per type
trait Converter<T> {
    fn convert(&self) -> T;
}

// Same type can implement multiple conversions
impl Converter<String> for MyType {
    fn convert(&self) -> String { ... }
}
impl Converter<i32> for MyType {
    fn convert(&self) -> i32 { ... }
}

// Rule of thumb:
// - Associated type: "A type HAS one X" (Iterator has one Item type)
// - Generic param: "A type can BE converted to many X" (can convert to String, i32, etc.)
```

### Supertraits and Trait Inheritance

```rust
// Supertrait - require another trait
trait Serializable: Debug + Clone {
    fn serialize(&self) -> Vec<u8>;
}

// Implementors must also implement Debug and Clone
#[derive(Debug, Clone)]
struct Record { id: u64 }

impl Serializable for Record {
    fn serialize(&self) -> Vec<u8> {
        format!("{:?}", self).into_bytes()
    }
}

// Multiple supertraits
trait Service: Send + Sync + 'static {
    fn handle(&self, request: Request) -> Response;
}
```

### Marker Traits

```rust
// Marker traits have no methods - they mark capabilities
// Standard library markers:

// Send - safe to transfer between threads
// Sync - safe to share references between threads (&T is Send)
// Copy - can be copied bitwise (no Drop)
// Sized - has known size at compile time (default bound)
// Unpin - can be moved after being pinned

// Auto traits - implemented automatically unless opted out
struct ThreadSafeData {
    value: i32,  // i32 is Send + Sync, so ThreadSafeData is too
}

// Opt out with negative impl (nightly) or PhantomData
use std::marker::PhantomData;
use std::cell::UnsafeCell;

struct NotSync {
    _marker: PhantomData<UnsafeCell<()>>,  // UnsafeCell is !Sync
}

// Custom marker trait
trait DatabaseConnection: Send + Sync {}

fn spawn_with_db<D: DatabaseConnection>(db: D) {
    std::thread::spawn(move || {
        // db is guaranteed Send + Sync
    });
}
```

### Default Trait Implementations

```rust
// The Default trait
#[derive(Default)]
struct Config {
    port: u16,
    host: String,
    #[default]  // Requires nightly or manual impl
    timeout_ms: u64,
}

// Manual Default implementation
impl Default for Config {
    fn default() -> Self {
        Self {
            port: 8080,
            host: "localhost".to_string(),
            timeout_ms: 30_000,
        }
    }
}

// Using Default
let config = Config::default();
let config = Config { port: 9000, ..Default::default() };

// Default in generics
fn create_with_defaults<T: Default>() -> T {
    T::default()
}
```

### Extension Traits

```rust
// Add methods to existing types without modifying them
trait StringExt {
    fn truncate_with_ellipsis(&self, max_len: usize) -> String;
}

impl StringExt for str {
    fn truncate_with_ellipsis(&self, max_len: usize) -> String {
        if self.len() <= max_len {
            self.to_string()
        } else {
            format!("{}...", &self[..max_len.saturating_sub(3)])
        }
    }
}

// Usage - must import the trait!
use crate::StringExt;
let short = "Hello, World!".truncate_with_ellipsis(8);  // "Hello..."

// Common pattern: extension traits for Result/Option
trait ResultExt<T, E> {
    fn log_err(self) -> Result<T, E>;
}

impl<T, E: std::fmt::Display> ResultExt<T, E> for Result<T, E> {
    fn log_err(self) -> Result<T, E> {
        if let Err(ref e) = self {
            tracing::error!("Error: {}", e);
        }
        self
    }
}
```

### Generic Structs and Enums

```rust
// Generic struct
struct Container<T> {
    value: T,
}

impl<T> Container<T> {
    fn new(value: T) -> Self {
        Self { value }
    }

    fn into_inner(self) -> T {
        self.value
    }
}

// Methods only for specific types
impl Container<String> {
    fn len(&self) -> usize {
        self.value.len()
    }
}

// Methods with additional bounds
impl<T: Clone> Container<T> {
    fn cloned(&self) -> T {
        self.value.clone()
    }
}

// Multiple type parameters
struct Pair<K, V> {
    key: K,
    value: V,
}

// Generic enum
enum Result<T, E> {
    Ok(T),
    Err(E),
}

// PhantomData for unused type parameters
use std::marker::PhantomData;

struct TypedId<T> {
    id: u64,
    _marker: PhantomData<T>,  // T not used in fields
}

// Different types even though same underlying data
type UserId = TypedId<User>;
type OrderId = TypedId<Order>;
```

### Const Generics

```rust
// Generic over constant values (not just types)
struct Buffer<const N: usize> {
    data: [u8; N],
}

impl<const N: usize> Buffer<N> {
    fn new() -> Self {
        Self { data: [0; N] }
    }

    fn len(&self) -> usize {
        N
    }
}

// Usage
let small: Buffer<64> = Buffer::new();
let large: Buffer<4096> = Buffer::new();

// Const generic in functions
fn copy_fixed<const N: usize>(src: &[u8; N], dst: &mut [u8; N]) {
    dst.copy_from_slice(src);
}

// Combine with type generics
struct Matrix<T, const ROWS: usize, const COLS: usize> {
    data: [[T; COLS]; ROWS],
}
```

### Blanket Implementations

```rust
// Implement trait for all types that satisfy bounds
// From std: impl<T: Display> ToString for T

trait Describable {
    fn describe(&self) -> String;
}

// Blanket impl: any Debug type is Describable
impl<T: std::fmt::Debug> Describable for T {
    fn describe(&self) -> String {
        format!("{:?}", self)
    }
}

// Now ALL Debug types have describe()
let x = 42;
println!("{}", x.describe());  // "42"

// Common blanket impls in ecosystem:
// - impl<T: Error> From<T> for Box<dyn Error>
// - impl<T: AsRef<str>> From<T> for String
// - impl<T: Iterator> IntoIterator for T
```

---

## FFI and Unsafe Rust

### When Unsafe is Necessary

Unsafe Rust is required for:

1. Dereferencing raw pointers
2. Calling unsafe functions (including FFI)
3. Accessing/modifying mutable statics
4. Implementing unsafe traits
5. Accessing fields of unions

### Raw Pointers

```rust
// Creating raw pointers is safe, dereferencing is unsafe
let x = 42;
let ptr: *const i32 = &x;      // Immutable raw pointer
let mut y = 42;
let mut_ptr: *mut i32 = &mut y; // Mutable raw pointer

// Rust 2024+: Use raw borrow operators (preferred)
let ptr: *const i32 = &raw const x;
let mut_ptr: *mut i32 = &raw mut y;

// Dereferencing requires unsafe
unsafe {
    println!("Value: {}", *ptr);
    *mut_ptr = 100;
}

// Null pointers
let null_ptr: *const i32 = std::ptr::null();
let null_mut: *mut i32 = std::ptr::null_mut();

// Check for null before dereferencing
if !ptr.is_null() {
    unsafe { println!("{}", *ptr); }
}

// Pointer arithmetic
unsafe {
    let arr = [1, 2, 3, 4, 5];
    let ptr = arr.as_ptr();
    let third = *ptr.add(2);  // arr[2]
    let second = *ptr.offset(1);  // arr[1]
}
```

### FFI Basics - Calling C from Rust

```rust
// Link to C library (Rust 2024 edition: all items in unsafe extern are unsafe)
#[link(name = "c")]
unsafe extern "C" {
    fn strlen(s: *const std::ffi::c_char) -> usize;
    fn printf(format: *const std::ffi::c_char, ...) -> i32;

    // Mark known-safe functions explicitly
    safe fn abs(input: i32) -> i32;
}

// Pre-2024 edition syntax (still valid)
#[link(name = "mylib")]
extern "C" {
    fn my_function(x: i32) -> i32;  // Implicitly unsafe to call
}

// Safe wrapper around unsafe FFI
pub fn safe_strlen(s: &std::ffi::CStr) -> usize {
    unsafe { strlen(s.as_ptr()) }
}

// Usage
use std::ffi::CString;

fn main() {
    let s = CString::new("Hello").expect("CString::new failed");
    let len = safe_strlen(&s);
    println!("Length: {}", len);
}
```

### C String Handling

```rust
use std::ffi::{CStr, CString, c_char};

// Rust string to C string (owned, null-terminated)
fn rust_to_c(s: &str) -> CString {
    CString::new(s).expect("String contains null byte")
}

// C string to Rust (borrowed)
unsafe fn c_to_rust<'a>(ptr: *const c_char) -> &'a str {
    CStr::from_ptr(ptr)
        .to_str()
        .expect("Invalid UTF-8")
}

// C string to owned Rust String
unsafe fn c_to_rust_owned(ptr: *const c_char) -> String {
    CStr::from_ptr(ptr)
        .to_string_lossy()  // Replaces invalid UTF-8 with �
        .into_owned()
}

// Pattern: C callback with string
extern "C" fn log_callback(message: *const c_char) {
    let msg = unsafe {
        if message.is_null() {
            return;
        }
        CStr::from_ptr(message).to_string_lossy()
    };
    tracing::info!("{}", msg);
}
```

### Exposing Rust to C

```rust
// Prevent name mangling
#[no_mangle]
pub extern "C" fn rust_add(a: i32, b: i32) -> i32 {
    a + b
}

// Return allocated string to C (caller must free)
#[no_mangle]
pub extern "C" fn rust_greeting(name: *const c_char) -> *mut c_char {
    let name = unsafe {
        if name.is_null() {
            return std::ptr::null_mut();
        }
        CStr::from_ptr(name).to_string_lossy()
    };

    let greeting = format!("Hello, {}!", name);
    CString::new(greeting)
        .map(|s| s.into_raw())  // Transfer ownership to C
        .unwrap_or(std::ptr::null_mut())
}

// Free function for C to call
#[no_mangle]
pub extern "C" fn rust_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));  // Reclaim and drop
        }
    }
}
```

### repr(C) for C-Compatible Structs

```rust
// Ensure C-compatible memory layout
#[repr(C)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

#[repr(C)]
pub struct Buffer {
    pub data: *mut u8,
    pub len: usize,
    pub capacity: usize,
}

// Opaque types - hide Rust implementation from C
#[repr(C)]
pub struct OpaqueHandle {
    _private: [u8; 0],  // Zero-sized, prevents construction in C
}

// Create/destroy pattern for opaque types
#[no_mangle]
pub extern "C" fn processor_new() -> *mut OpaqueHandle {
    let processor = Box::new(RealProcessor::new());
    Box::into_raw(processor) as *mut OpaqueHandle
}

#[no_mangle]
pub extern "C" fn processor_free(ptr: *mut OpaqueHandle) {
    if !ptr.is_null() {
        unsafe {
            drop(Box::from_raw(ptr as *mut RealProcessor));
        }
    }
}

#[no_mangle]
pub extern "C" fn processor_process(
    ptr: *mut OpaqueHandle,
    data: *const u8,
    len: usize,
) -> i32 {
    let processor = unsafe {
        if ptr.is_null() { return -1; }
        &mut *(ptr as *mut RealProcessor)
    };

    let slice = unsafe {
        if data.is_null() { return -1; }
        std::slice::from_raw_parts(data, len)
    };

    match processor.process(slice) {
        Ok(_) => 0,
        Err(_) => -1,
    }
}
```

### Bindgen for Automatic Bindings

```rust
// build.rs - generate Rust bindings from C headers
fn main() {
    println!("cargo:rerun-if-changed=wrapper.h");

    let bindings = bindgen::Builder::default()
        .header("wrapper.h")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        // Allowlist specific functions/types
        .allowlist_function("mylib_.*")
        .allowlist_type("MyLib.*")
        // Block problematic items
        .blocklist_item("FILE")
        .generate()
        .expect("Unable to generate bindings");

    let out_path = std::path::PathBuf::from(std::env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings");
}

// src/lib.rs - include generated bindings
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));
```

### cbindgen for C Header Generation

```toml
# cbindgen.toml
language = "C"
include_guard = "MY_LIB_H"
no_includes = true
sys_includes = ["stdint.h", "stdbool.h"]

[export]
include = ["Point", "Buffer", "processor_.*"]
```

```bash
# Generate header
cbindgen --config cbindgen.toml --output include/mylib.h
```

### Unsafe Traits

```rust
// Unsafe trait - implementor guarantees invariants
unsafe trait TrustedLen: Iterator {
    // Implementor guarantees size_hint() is exact
}

// Unsafe impl - "I promise this is correct"
unsafe impl<T> TrustedLen for std::vec::IntoIter<T> {}

// Common unsafe traits:
// - Send: safe to transfer to another thread
// - Sync: safe to share between threads
// - GlobalAlloc: custom allocator

// Implementing Send/Sync manually
struct MyWrapper(*mut u8);

// "I guarantee this is safe to send between threads"
unsafe impl Send for MyWrapper {}
unsafe impl Sync for MyWrapper {}
```

### Sealed Traits

Prevent downstream crates from implementing your public trait. Essential
for library API design where adding new methods must not be a breaking
change.

```rust
// The sealed pattern: public trait, private supertrait

mod private {
    pub trait Sealed {}
}

/// Public trait that external crates cannot implement.
/// New methods can be added without a semver-breaking change.
pub trait Transport: private::Sealed {
    fn send(&self, payload: &[u8]) -> Result<(), TransportError>;
    fn max_payload_size(&self) -> usize;
}

// Only types in THIS crate can implement Sealed, therefore Transport
pub struct KafkaTransport { /* ... */ }
impl private::Sealed for KafkaTransport {}
impl Transport for KafkaTransport {
    fn send(&self, payload: &[u8]) -> Result<(), TransportError> { /* ... */ }
    fn max_payload_size(&self) -> usize { 1_048_576 }  // 1 MiB
}

pub struct GrpcTransport { /* ... */ }
impl private::Sealed for GrpcTransport {}
impl Transport for GrpcTransport {
    fn send(&self, payload: &[u8]) -> Result<(), TransportError> { /* ... */ }
    fn max_payload_size(&self) -> usize { 4_194_304 }  // 4 MiB
}
```

Use sealed traits when:
- The trait is part of a public API and you need to add methods later
- You want exhaustive matching over implementors (enum-like behaviour)
- The trait has safety invariants that external impls could violate

Do NOT seal traits that are genuinely meant for extension (e.g., user-defined
serialisers, plugin interfaces).

### Generic Associated Types (GATs)

GATs allow associated types with their own generic parameters. This
enables patterns that were previously impossible — streaming iterators,
collection traits, and lending iterators.

```rust
/// A lending iterator — borrows from self, not from the item
trait LendingIterator {
    type Item<'a> where Self: 'a;

    fn next(&mut self) -> Option<Self::Item<'_>>;
}

/// Streaming reader that yields borrowed slices from an internal buffer
struct ChunkedReader {
    data: Vec<u8>,
    pos: usize,
    chunk_size: usize,
}

impl LendingIterator for ChunkedReader {
    type Item<'a> = &'a [u8] where Self: 'a;

    fn next(&mut self) -> Option<Self::Item<'_>> {
        if self.pos >= self.data.len() {
            return None;
        }
        let end = (self.pos + self.chunk_size).min(self.data.len());
        let chunk = &self.data[self.pos..end];
        self.pos = end;
        Some(chunk)
    }
}

/// Collection trait — generic over the element type stored
trait Collection {
    type Iter<'a, T: 'a>: Iterator<Item = &'a T> where Self: 'a;

    fn iter<T>(&self) -> Self::Iter<'_, T>;
}
```

GATs are particularly useful in data pipeline code where you want
zero-copy iteration over internal buffers without `unsafe`. If you
find yourself reaching for `unsafe` to return references to internal
data from an iterator, try GATs first.

### Safe Abstractions Over Unsafe

```rust
/// Safe wrapper around raw buffer
pub struct SafeBuffer {
    ptr: *mut u8,
    len: usize,
    capacity: usize,
}

impl SafeBuffer {
    /// Creates a new buffer. All unsafe operations are encapsulated.
    pub fn new(capacity: usize) -> Self {
        let layout = std::alloc::Layout::array::<u8>(capacity).unwrap();
        let ptr = unsafe { std::alloc::alloc(layout) };
        if ptr.is_null() {
            std::alloc::handle_alloc_error(layout);
        }
        Self { ptr, len: 0, capacity }
    }

    /// Safe slice access
    pub fn as_slice(&self) -> &[u8] {
        unsafe { std::slice::from_raw_parts(self.ptr, self.len) }
    }

    /// Safe mutable slice access
    pub fn as_mut_slice(&mut self) -> &mut [u8] {
        unsafe { std::slice::from_raw_parts_mut(self.ptr, self.len) }
    }

    /// Push with bounds checking
    pub fn push(&mut self, byte: u8) -> Result<(), BufferFull> {
        if self.len >= self.capacity {
            return Err(BufferFull);
        }
        unsafe {
            self.ptr.add(self.len).write(byte);
        }
        self.len += 1;
        Ok(())
    }
}

impl Drop for SafeBuffer {
    fn drop(&mut self) {
        if !self.ptr.is_null() {
            let layout = std::alloc::Layout::array::<u8>(self.capacity).unwrap();
            unsafe { std::alloc::dealloc(self.ptr, layout) };
        }
    }
}

// Implement Send/Sync if safe
unsafe impl Send for SafeBuffer {}
unsafe impl Sync for SafeBuffer {}
```

### Unsafe Code Guidelines

```rust
// ❌ Bad - unsafe block too large
unsafe {
    let ptr = get_pointer();
    validate_something();  // Safe code in unsafe block
    process_data();        // Safe code in unsafe block
    *ptr = 42;             // Only this needs unsafe
}

// ✅ Good - minimal unsafe scope
let ptr = get_pointer();
validate_something();
process_data();
unsafe { *ptr = 42; }  // Only unsafe operation

// ❌ Bad - no safety comment
unsafe impl Send for MyType {}

// ✅ Good - document safety invariants
// SAFETY: MyType contains only thread-safe types (AtomicU64, Arc).
// The raw pointer field is never dereferenced, only used as an identifier.
unsafe impl Send for MyType {}

// ❌ Bad - unsafe function without safety docs
pub unsafe fn process_raw(ptr: *mut u8, len: usize) {
    // ...
}

// ✅ Good - document preconditions in doc comment
/// Processes raw bytes in place.
///
/// # Safety
///
/// - `ptr` must be valid for reads and writes of `len` bytes
/// - `ptr` must be properly aligned for u8
/// - The memory must not be accessed by other threads during this call
pub unsafe fn process_raw(ptr: *mut u8, len: usize) {
    // ...
}

// ✅ Good - SAFETY comment before unsafe block (for callers)
fn safe_wrapper(data: &mut [u8]) {
    let ptr = data.as_mut_ptr();
    let len = data.len();

    // SAFETY: ptr and len come from a valid slice, so ptr is valid for
    // len bytes, properly aligned, and we have exclusive access via &mut.
    unsafe {
        process_raw(ptr, len);
    }
}
```

### Unwinding Across FFI Boundaries

```rust
// If panics or foreign exceptions may cross an FFI boundary,
// use -unwind ABI variants to avoid undefined behaviour

// ❌ Dangerous - panic across FFI is UB without -unwind
#[no_mangle]
pub extern "C" fn might_panic() {
    panic!("This causes UB if it unwinds into C!");
}

// ✅ Safe - use catch_unwind to prevent unwinding
use std::panic::catch_unwind;

#[no_mangle]
pub extern "C" fn safe_function() -> i32 {
    match catch_unwind(|| {
        // Rust code that might panic
        risky_operation()
    }) {
        Ok(result) => result,
        Err(_) => -1,  // Return error code instead of unwinding
    }
}

// ✅ Safe - use C-unwind if unwinding is intentional (Rust 2024+)
#[no_mangle]
pub extern "C-unwind" fn can_unwind() {
    panic!("This can safely unwind through C++ code");
}

// Calling foreign functions that might throw
unsafe extern "C-unwind" {
    fn cpp_function_that_throws();
}
```

### Common FFI Patterns

```rust
// Error handling across FFI boundary
#[repr(C)]
pub enum ErrorCode {
    Success = 0,
    NullPointer = -1,
    InvalidArgument = -2,
    BufferTooSmall = -3,
    InternalError = -99,
}

// Thread-local error message
thread_local! {
    static LAST_ERROR: std::cell::RefCell<Option<String>> = std::cell::RefCell::new(None);
}

fn set_last_error(msg: String) {
    LAST_ERROR.with(|e| *e.borrow_mut() = Some(msg));
}

#[no_mangle]
pub extern "C" fn get_last_error() -> *const c_char {
    LAST_ERROR.with(|e| {
        e.borrow()
            .as_ref()
            .map(|s| s.as_ptr() as *const c_char)
            .unwrap_or(std::ptr::null())
    })
}

// Callback pattern
type Callback = extern "C" fn(data: *const u8, len: usize, user_data: *mut std::ffi::c_void);

#[no_mangle]
pub extern "C" fn process_with_callback(
    input: *const u8,
    input_len: usize,
    callback: Callback,
    user_data: *mut std::ffi::c_void,
) -> ErrorCode {
    if input.is_null() || input_len == 0 {
        return ErrorCode::NullPointer;
    }

    let data = unsafe { std::slice::from_raw_parts(input, input_len) };

    // Process and invoke callback
    let result = process_internal(data);
    callback(result.as_ptr(), result.len(), user_data);

    ErrorCode::Success
}
```

### Miri for Unsafe Code Verification

```bash
# Install Miri
rustup +nightly component add miri

# Run tests under Miri (detects undefined behaviour)
cargo +nightly miri test

# Run specific test
cargo +nightly miri test test_unsafe_buffer

# Common issues Miri catches:
#
# - Use after free
# - Out of bounds access
# - Invalid pointer alignment
# - Data races
# - Uninitialised memory reads
```

---

## Coming from Other Languages

If you're new to Rust from another language, here's what will trip you up.

### From Python

**The borrow checker will hurt at first.** In Python everything is a reference and the GC sorts it out. In Rust you must think about ownership. Start by cloning liberally (it's fine for learning), then optimise once you understand the patterns.

```rust
// ❌ Fails - data moved
let data = vec![1, 2, 3];
process(data);
process(data);  // Error: value used after move

// ✅ Clone when learning (refactor later)
let data = vec![1, 2, 3];
process(data.clone());
process(data);

// ✅ Better: borrow
fn process(data: &[i32]) { ... }
process(&data);
process(&data);
```

**No exceptions.** Use `Result<T, E>` and the `?` operator. It's actually nicer than try/catch once you get used to it.

**No `None` as a default.** `Option<T>` is explicit. No `AttributeError` at runtime.

### From Go

**Error handling is similar** - Rust's `Result<T, E>` is like Go's `(T, error)` but type-safe. You can't ignore errors without explicitly calling `.unwrap()`.

```rust
// Go-ish pattern
result := doThing()
if result.Err != nil {
    return result.Err
}

// Rust - cleaner with ?
let result = do_thing()?;  // Returns early if Err
```

**No nil.** Rust has `Option<T>` which forces you to handle the `None` case. No more nil pointer panics.

**Generics are more powerful** but also more complex. Start simple, add bounds when the compiler complains.

**No goroutines.** Rust async is different - you need a runtime (Tokio). Threads are also available if you prefer the Go mental model.

### From TypeScript/JavaScript

**Types are not optional.** Every value has a concrete type at compile time. No `any` escape hatch.

**No garbage collection.** Ownership rules replace the GC. Variables are dropped when they go out of scope.

**String handling is explicit.** `String` vs `&str` - owned vs borrowed. Coming from JS where strings just work, this takes adjustment.

```rust
// ❌ Won't compile
fn greet(name: String) { ... }
greet("world");  // &str not String

// ✅ Accept reference
fn greet(name: &str) { ... }
greet("world");
greet(&my_string);
```

**No null or undefined.** Use `Option<T>` for "might not exist".

### From C/C++

**You'll feel at home** but safer. The borrow checker does at compile time what you did mentally (or forgot and got a segfault).

**No manual memory management.** Forget `malloc`/`free`. Rust handles it. You can opt into manual control with `unsafe` but you shouldn't need it for most code.

**No header files.** Modules and `pub` visibility handle API exposure.

**Macros are different.** Rust macros are hygienic and operate on the AST, not text substitution. They're powerful but different from C preprocessor macros.

### Common Gotchas for Everyone

| Coming From | Gotcha | Rust Way |
|-------------|--------|----------|
| Python | Everything is mutable | `let mut` for mutability |
| Go | `nil` everywhere | `Option<T>` is explicit |
| TypeScript | `any` escape hatch | No escape - fix the types |
| C | Manual memory management | Ownership system |
| Java | Everything is a reference | Value types by default |
| All | Exceptions | `Result<T, E>` + `?` |

### The Mindset Shift

Rust will reject your first attempts. This is normal. The compiler is teaching you patterns that prevent bugs. Once you stop fighting it and start listening, code that compiles tends to work.

Key realisation: **The compiler is your pair programmer.** Read the error messages - they usually tell you exactly what to fix.

---

## AI Pitfalls to Avoid

The following sections are specific guidance for AI code assistants working with Rust.

> **CRITICAL: Web Search Before ANY Crate Usage**
>
> AI models are ALWAYS out of date with the Rust ecosystem. Your training data
> contains deprecated crates, old API patterns, and superseded libraries.
> **EVERY TIME** you reference a crate, dependency, or Rust API:
>
> 1. **Web search for the current version** — your training data version is wrong
> 2. **Web search whether the crate has been superseded** — entire libraries get
>    replaced (serde_yaml → serde_yaml_ng, atty → std::io::IsTerminal)
> 3. **Web search for the current API** — axum 0.8 changed path syntax from
>    `/:param` to `/{param}`, thiserror 2.x has different derives, etc.
>
> Do NOT rely on "I know this crate" — you don't know the CURRENT version.
> See the [Deprecated / Superseded Crates](#deprecated--superseded-crates--do-not-use)
> table above. That table is illustrative, not exhaustive. **Always search.**
>
> For HyperI projects: check if `hyperi-rustlib` already provides what you need
> before reaching for any third-party crate. See [hyperi-rustlib](#hyperi-rustlib).

### DO NOT Generate

```rust
// ❌ Using unwrap() in production code
let value = some_option.unwrap();  // Panics on None
let data = result.unwrap();        // Panics on Err
// ✅ Handle errors properly
let value = some_option.ok_or_else(|| Error::MissingValue)?;
let value = some_option.unwrap_or_default();
let data = result.map_err(|e| Error::Processing(e))?;

// ❌ Using expect() without good reason
let config = load_config().expect("config");  // Cryptic panic
// ✅ Meaningful error or proper handling
let config = load_config().expect("Failed to load config from config.toml");
let config = load_config()?;  // Propagate error

// ❌ Cloning to avoid borrow checker
let data = expensive_data.clone();  // Performance hit
process(&data);
// ✅ Use references properly
process(&expensive_data);  // Borrow instead

// ❌ Using String when &str works
fn greet(name: String) {  // Forces allocation
// ✅ Accept reference
fn greet(name: &str) {    // Works with &String, &str, String

// ❌ Blocking in async code
async fn fetch() {
    std::thread::sleep(Duration::from_secs(1));  // Blocks executor
}
// ✅ Use async sleep
async fn fetch() {
    tokio::time::sleep(Duration::from_secs(1)).await;
}

// ❌ Using panic! for errors
if !valid {
    panic!("Invalid input");  // Crashes program
}
// ✅ Return Result
if !valid {
    return Err(Error::InvalidInput);
}
```

### Lifetime Patterns

```rust
// ❌ Incorrect lifetime annotations
fn longest(x: &str, y: &str) -> &str {  // Missing lifetime
// ✅ Explicit lifetimes
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {

// ❌ Storing references in structs without lifetimes
struct Parser {
    input: &str,  // Won't compile
}
// ✅ Add lifetime parameter
struct Parser<'a> {
    input: &'a str,
}
// Or use owned types
struct Parser {
    input: String,
}
```

### Error Handling Pitfalls

```rust
// ❌ Using Box<dyn Error> in libraries
fn process() -> Result<(), Box<dyn std::error::Error>> {
// ✅ Define custom error type
#[derive(Debug, thiserror::Error)]
enum ProcessError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Parse error: {0}")]
    Parse(#[from] serde_json::Error),
}
fn process() -> Result<(), ProcessError> {

// ❌ Ignoring Result
let _ = file.write_all(data);  // Silently ignores errors
// ✅ Handle or propagate
file.write_all(data)?;
```

### Crate Verification

```rust
// ❌ These may be hallucinations - verify on crates.io:
use tokio_utils::...;        // Check if it exists
use serde_helpers::...;      // Often wrong
use actix_web_extras::...;   // Version may differ

// ✅ Well-known crates:
// tokio, serde, anyhow, thiserror, tracing, clap, axum, reqwest
// rayon, dashmap, parking_lot, memchr, sonic-rs, criterion
```

### Deprecated / Superseded Crates — Do NOT Use

| Wrong (Stale) | Correct (Current) | Why |
|---|---|---|
| `serde_yaml` | `serde_yaml_ng` (or `serde_yml`) | `serde_yaml` archived March 2024, unmaintained |
| `atty` | `std::io::IsTerminal` (std since 1.70) | `atty` unmaintained, has unaligned read bug |
| `actix-web` (new projects) | `axum` 0.8+ | axum is the ecosystem standard, tower-native |
| `thiserror` 1.x | `thiserror` 2.x | Major version with improved derives |
| `warp` | `axum` | warp is maintenance-only |
| `hyper` directly | `axum` (uses hyper internally) | Unless you need raw HTTP/2 control |
| `structopt` | `clap` 4.x with derive | structopt merged into clap |
| `dotenv` | `dotenvy` | dotenv unmaintained, dotenvy is the fork |
| `chrono` (new code) | `time` or `jiff` | chrono works but `time` is lighter; `jiff` for civil time |
| `reqwest` blocking in async | `reqwest` async client | Never use `reqwest::blocking` inside tokio |

### Recommended Crate Stack (March 2026)

| Category | Crate | Version | Notes |
|---|---|---|---|
| **Async runtime** | `tokio` | >=1.50 | Multi-threaded, LTS releases |
| **HTTP framework** | `axum` | >=0.8.8 | `/{param}` syntax (not `/:param`) |
| **HTTP middleware** | `tower-http` | >=0.6.8 | timeout, trace, compression, cors |
| **HTTP client** | `reqwest` | >=0.12 | Async, HTTP/2, JSON |
| **Serialisation** | `serde` + `serde_json` | >=1.0 | Universal |
| **SIMD JSON** | `sonic-rs` | >=0.5 | SIMD-accelerated, zero-copy, `Bytes` integration |
| **YAML** | `serde_yaml_ng` | >=0.10 | Maintained fork of serde_yaml |
| **Error (libraries)** | `thiserror` | >=2.0 | Custom error types with derive |
| **Error (apps)** | `anyhow` | >=1.0 | Context-rich error propagation |
| **Tracing** | `tracing` + `tracing-subscriber` | >=0.1 / >=0.3 | Structured logging + spans |
| **OTel** | `opentelemetry` + `opentelemetry-otlp` | >=0.31 | OTLP export, retry with backoff |
| **Metrics** | `metrics` + `metrics-exporter-prometheus` | >=0.24 | Prometheus native |
| **CLI** | `clap` | >=4.5 | Derive macros, env support |
| **SQL** | `sqlx` | >=0.8 | Compile-time checked queries |
| **String search** | `memchr` | >=2.7 | SIMD byte/string search |
| **Concurrency** | `dashmap`, `parking_lot`, `crossbeam` | latest | Lock-free maps, faster mutexes |
| **Small strings** | `compact_str` | >=0.8 | 24-byte SSO, no heap for short strings |
| **Resilience** | `tower-resilience` | >=0.4 | Circuit breaker, bulkhead, retry |
| **Arena alloc** | `bumpalo` | >=3.16 | Bump allocation for batch lifetimes |
| **Benchmarks** | `criterion` | >=0.5 | Statistical benchmarking |
| **Coverage** | `cargo-tarpaulin` | latest | Code coverage |
| **Test runner** | `cargo-nextest` | latest | Parallel, better output |

---

## External Libraries and Private Registries

### Private Cargo Registry Configuration

For enterprise environments using private artifact repositories:

```toml
# .cargo/config.toml
[registries.hyperi]
index = "sparse+https://hyperi.jfrog.io/artifactory/api/cargo/hyperi-cargo-virtual/index/"

[build]
# Optional: Use mold linker for faster builds
# rustflags = ["-C", "link-arg=-fuse-ld=mold"]

[target.x86_64-unknown-linux-gnu]
rustflags = ["-C", "force-frame-pointers=yes"]  # Better profiling

[target.aarch64-unknown-linux-gnu]
rustflags = ["-C", "force-frame-pointers=yes"]
```

```toml
# Cargo.toml - using private registry
[dependencies]
hyperi-rustlib = { version = ">=1.3", registry = "hyperi", features = [
    "config", "logger", "metrics", "transport-kafka", "http-server"
]}
```

### Linking C Libraries via Wrapper Crates

For C libraries like librdkafka, use safe Rust wrapper crates:

```toml
# Cargo.toml - rdkafka with C library compilation
[dependencies]
rdkafka = { version = ">=0.38", features = [
    "cmake-build",  # Compile librdkafka from source
    "ssl",          # Link OpenSSL for TLS
    "sasl",         # Link SASL for Kerberos/PLAIN auth
]}

# Pure Rust compression alternatives
lz4_flex = ">=0.11"     # Pure Rust LZ4 (preferred over C binding)
snap = ">=1.1"          # Pure Rust Snappy
zstd = ">=0.13"         # Rust wrapper around libzstd C library
```

### Safe Wrappers for C Libraries

Pattern: Configure C library through safe Rust API without direct FFI:

```rust
use rdkafka::ClientConfig;
use rdkafka::producer::FutureProducer;

fn create_kafka_producer(config: &KafkaConfig) -> Result<FutureProducer> {
    let mut client_config = ClientConfig::new();

    // All configuration passed safely to underlying librdkafka
    client_config.set("bootstrap.servers", config.brokers.join(","));
    client_config.set("batch.size", config.batch_size.to_string());
    client_config.set("compression.type", &config.compression);
    client_config.set("acks", &config.acks);
    client_config.set("message.max.bytes", "8388608");  // 8MiB

    // TLS configuration for librdkafka
    if config.tls.enabled {
        client_config.set("security.protocol", "ssl");
        client_config.set("ssl.ca.location", &config.tls.ca_path);
        client_config.set("ssl.certificate.location", &config.tls.cert_path);
        client_config.set("ssl.key.location", &config.tls.key_path);
    }

    // SASL authentication
    if let Some(ref sasl) = config.sasl {
        client_config.set("security.protocol", "sasl_ssl");
        client_config.set("sasl.mechanism", &sasl.mechanism.to_uppercase());
        client_config.set("sasl.username", &sasl.username);
        client_config.set("sasl.password", &sasl.password);
    }

    // Create producer - initialises librdkafka safely
    client_config.create().map_err(Error::Kafka)
}
```

### Pure Rust vs C Library Trade-offs

| Category | Pure Rust | C Wrapper | Recommendation |
|----------|-----------|-----------|----------------|
| **TLS** | rustls | OpenSSL bindings | Pure Rust (rustls) |
| **JSON** | serde_json, sonic-rs | - | Pure Rust (sonic-rs for SIMD) |
| **Compression** | lz4_flex, snap | zstd, flate2 | Pure Rust when available |
| **Kafka** | - | rdkafka | C wrapper (no pure Rust alternative) |
| **Protobuf** | prost | protobuf-native | Pure Rust (prost) |

```rust
// Prefer pure Rust TLS
use rustls::ServerConfig;
use tokio_rustls::TlsAcceptor;

// Not: OpenSSL bindings
// use openssl::ssl::SslAcceptor;
```

### Forbid Unsafe in Application Code

```rust
// src/lib.rs and src/main.rs
#![forbid(unsafe_code)]

// All FFI is handled by wrapper crates
// No direct unsafe blocks in application code
```

---

## At-Scale Performance Patterns

Production patterns from HyperI data pipelines handling PB/s scale.

### Global Allocator Selection

```rust
// main.rs - jemalloc for long-running servers
#[cfg(feature = "jemalloc")]
#[global_allocator]
static GLOBAL: tikv_jemallocator::Jemalloc = tikv_jemallocator::Jemalloc;

// Fallback to mimalloc (often faster for mixed workloads)
#[cfg(all(feature = "mimalloc", not(feature = "jemalloc")))]
#[global_allocator]
static GLOBAL_MIMALLOC: mimalloc::MiMalloc = mimalloc::MiMalloc;
```

```toml
# Cargo.toml features
[features]
default = ["jemalloc"]
jemalloc = ["dep:tikv-jemallocator", "dep:tikv-jemalloc-ctl"]
mimalloc = ["dep:mimalloc"]
```

### Lock-Free Concurrent Data Structures

```rust
use dashmap::DashMap;
use parking_lot::{Mutex, RwLock};
use rustc_hash::FxHashMap;
use std::sync::atomic::{AtomicU64, AtomicBool, Ordering};

pub struct BufferManager {
    // DashMap: lock-free concurrent HashMap (fine-grained sharding)
    hot_buffers: DashMap<CompactString, TableBuffer>,

    // FxHashMap: faster than std HashMap for internal use
    schemas: FxHashMap<String, TableSchema>,

    // parking_lot: faster than std::sync for LRU tracking
    lru: Mutex<LruTracker>,

    // Atomics: lock-free counters (Relaxed ordering for stats)
    messages_buffered: AtomicU64,
    bytes_buffered: AtomicU64,
    under_pressure: AtomicBool,
}

impl BufferManager {
    #[inline]
    pub fn record_message(&self, bytes: usize) {
        // No lock needed - atomic increment
        self.messages_buffered.fetch_add(1, Ordering::Relaxed);
        self.bytes_buffered.fetch_add(bytes as u64, Ordering::Relaxed);
    }

    pub fn stats(&self) -> BufferStats {
        // Snapshot with relaxed ordering (eventual consistency OK for stats)
        BufferStats {
            messages: self.messages_buffered.load(Ordering::Relaxed),
            bytes: self.bytes_buffered.load(Ordering::Relaxed),
        }
    }
}
```

### Tiered Buffer Architecture

Two-tier system: hot (memory) + cold (disk spool) with LRU eviction:

```rust
use compact_str::CompactString;
use crossbeam_channel::{Sender, Receiver};

pub struct TieredBufferManager {
    // Tier 1: Hot buffers (LRU-bounded, in-memory)
    hot_buffers: DashMap<CompactString, HotBuffer>,
    max_hot_buffers: usize,  // e.g., 64 buffers × 1MB = 64MB bound
    lru: Mutex<LruTracker>,

    // Tier 2: Cold spool (disk-backed, compressed)
    spool_tx: Sender<StagedBatch>,
    max_spool_bytes: u64,     // e.g., 10GB
    min_free_disk_bytes: u64, // e.g., 1GB reserved

    // Concurrency control
    writer_semaphore: Arc<Semaphore>,  // Max concurrent writers
}

struct HotBuffer {
    messages: Vec<Vec<u8>>,
    offsets: Vec<KafkaOffset>,
    size: usize,
    last_access: Instant,
    created_at: Instant,
}

impl HotBuffer {
    /// Zero-copy drain: steals ownership without copying
    fn drain(&mut self) -> (Vec<Vec<u8>>, Vec<KafkaOffset>) {
        (
            std::mem::take(&mut self.messages),
            std::mem::take(&mut self.offsets),
        )
    }
}
```

### Batch Processing with Pre-allocation

```rust
const RECV_BATCH_SIZE: usize = 100;
const FLUSH_BATCH_SIZE: usize = 10_000;

impl BufferManager {
    pub fn get_ready_for_flush(&mut self) -> Vec<FlushBatch> {
        // Count first to pre-allocate exact capacity
        let ready_count = self.buffers.values()
            .filter(|buf| buf.should_flush())
            .count();

        // Single allocation with exact size
        let mut batches = Vec::with_capacity(ready_count);

        for (table, buffer) in self.buffers.iter_mut() {
            if buffer.should_flush() {
                let (messages, offsets) = buffer.drain();
                batches.push(FlushBatch {
                    table: CompactString::from(table.as_str()),
                    messages,
                    offsets,
                });
            }
        }

        batches
    }
}

/// NDJSON batch creation with single allocation
fn create_ndjson_batch(messages: Vec<Vec<u8>>) -> Vec<u8> {
    // Calculate exact size needed
    let total_size: usize = messages.iter().map(|m| m.len() + 1).sum();
    let mut data = Vec::with_capacity(total_size);

    // Sequential write (cache-friendly)
    for msg in messages {
        data.extend_from_slice(&msg);
        data.push(b'\n');
    }

    data
}
```

### Object Pooling for Hot Paths

```rust
use crossbeam_channel::{bounded, Sender, Receiver};

pub trait Poolable: Default {
    fn reset(&mut self);
}

pub struct ObjectPool<T: Poolable> {
    available_rx: Receiver<T>,
    return_tx: Sender<T>,
    creates: AtomicUsize,
    hits: AtomicUsize,
}

impl<T: Poolable> ObjectPool<T> {
    pub fn new(capacity: usize) -> Self {
        let (return_tx, available_rx) = bounded(capacity);

        // Pre-populate pool
        for _ in 0..capacity {
            let _ = return_tx.try_send(T::default());
        }

        Self {
            available_rx,
            return_tx,
            creates: AtomicUsize::new(0),
            hits: AtomicUsize::new(0),
        }
    }

    pub fn get(&self) -> Pooled<T> {
        let obj = match self.available_rx.try_recv() {
            Ok(obj) => {
                self.hits.fetch_add(1, Ordering::Relaxed);
                obj
            }
            Err(_) => {
                self.creates.fetch_add(1, Ordering::Relaxed);
                T::default()
            }
        };

        Pooled {
            inner: Some(obj),
            return_tx: self.return_tx.clone(),
        }
    }
}

pub struct Pooled<T: Poolable> {
    inner: Option<T>,
    return_tx: Sender<T>,
}

impl<T: Poolable> Drop for Pooled<T> {
    fn drop(&mut self) {
        if let Some(mut obj) = self.inner.take() {
            obj.reset();  // Clear for reuse
            let _ = self.return_tx.try_send(obj);  // Return to pool
        }
    }
}

impl<T: Poolable> std::ops::Deref for Pooled<T> {
    type Target = T;
    fn deref(&self) -> &T {
        self.inner.as_ref().unwrap()
    }
}

impl<T: Poolable> std::ops::DerefMut for Pooled<T> {
    fn deref_mut(&mut self) -> &mut T {
        self.inner.as_mut().unwrap()
    }
}
```

### Kafka Offset Management (At-Least-Once)

```rust
#[derive(Debug, Clone)]
pub struct KafkaOffset {
    pub topic: Arc<str>,  // Shared across thousands of offsets
    pub partition: i32,
    pub offset: i64,
}

impl KafkaOffset {
    /// Share existing topic Arc (cheap clone - refcount increment only)
    pub fn with_shared_topic(topic: Arc<str>, partition: i32, offset: i64) -> Self {
        Self { topic, partition, offset }
    }
}

/// Commit only max offset per partition (not per message)
pub fn commit_kafka_offsets(offsets: &[KafkaOffset]) -> Result<()> {
    // Group by topic/partition, keep max offset
    let mut max_offsets: HashMap<(Arc<str>, i32), i64> = HashMap::new();

    for off in offsets {
        max_offsets
            .entry((off.topic.clone(), off.partition))
            .and_modify(|existing| {
                if off.offset > *existing {
                    *existing = off.offset;
                }
            })
            .or_insert(off.offset);
    }

    // Single commit per partition batch
    commit_offsets(&max_offsets)
}
```

### Lazy Allocation Patterns

```rust
/// Only allocate timestamp string if field is missing
fn add_timestamp_if_missing(data: &mut Map<String, Value>) {
    static TIMESTAMP_FIELD: &str = "@timestamp";

    if !data.contains_key(TIMESTAMP_FIELD) {
        // Lazy allocation - only format if needed
        let ts = chrono::Utc::now().to_rfc3339();
        data.insert(TIMESTAMP_FIELD.into(), Value::String(ts));
    }
}

/// Zero-allocation key sanitisation when no changes needed
fn sanitize_key_owned(key: String, strip_at: bool, collapse_underscores: bool) -> String {
    let needs_change = (strip_at && key.starts_with('@'))
        || (collapse_underscores && key.contains("__"));

    // Fast path: return original (zero allocation)
    if !needs_change {
        return key;  // Move, not copy
    }

    // Slow path: modify only when needed
    let mut result = if strip_at && key.starts_with('@') {
        key[1..].to_string()
    } else {
        key
    };

    if collapse_underscores && result.contains("__") {
        // Single-pass O(n) collapse
        let mut collapsed = String::with_capacity(result.len());
        let mut prev_underscore = false;
        for c in result.chars() {
            if c == '_' {
                if !prev_underscore {
                    collapsed.push(c);
                }
                prev_underscore = true;
            } else {
                collapsed.push(c);
                prev_underscore = false;
            }
        }
        result = collapsed;
    }

    result
}
```

### Release Profile for Production

```toml
[profile.release]
lto = "thin"          # Link-time optimisation (thin = faster compile)
codegen-units = 1     # Single codegen unit = better optimisation
strip = true          # Remove debug symbols
panic = "abort"       # No unwinding overhead
opt-level = 3         # Maximum optimisation

[profile.bench]
lto = "thin"
codegen-units = 1

# Advanced options (documented, not default):
# - PGO: cargo pgo build (10-20% improvement)
# - BOLT: post-link optimisation (additional 5-15%)
# - Fat LTO: lto = true (slower compile, sometimes faster runtime)
```

### Build Performance

#### Linker Selection

LLD became the default linker on Linux x86_64 since Rust 1.90 — roughly
40% faster linking than GNU ld. No configuration needed on modern Rust.

For even faster linking, mold is available:

```toml
# .cargo/config.toml
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]
```

> **Caveat:** mold can have backward-compatibility issues with some C++
> dependencies. ClickHouse C++ client libraries are a known culprit.
> Before switching to mold in a project that links C++ code, build and
> run the full test suite first. If you hit linker errors or runtime
> crashes, fall back to LLD (the default). Not a hard no — just verify.

#### Distributed Build Caching (sccache)

```bash
# Install
cargo install sccache --locked

# Configure in .cargo/config.toml or environment
export RUSTC_WRAPPER=sccache

# Or in .cargo/config.toml:
# [build]
# rustc-wrapper = "sccache"
```

sccache supports S3, GCS, and Redis backends for CI cache sharing.
First compile is normal speed; subsequent compiles of unchanged crates
are near-instant. Essential for CI pipelines.

#### Profile-Guided Optimisation (PGO) + BOLT

PGO uses runtime profiling data to optimise hot paths. BOLT is a
post-link optimiser that re-arranges binary layout for cache locality.
Combined: 15-35% runtime improvement on data pipeline workloads.

```bash
# Install
cargo install cargo-pgo --locked

# Step 1: Build instrumented binary
cargo pgo build

# Step 2: Run representative workload to collect profile data
./target/x86_64-unknown-linux-gnu/release/my-binary --benchmark

# Step 3: Build optimised binary using profile data
cargo pgo optimize

# Step 4 (optional): Apply BOLT post-link optimisation
cargo pgo optimize -- --bolt
```

PGO is most impactful for long-running services with stable hot paths
(ingest pipelines, query engines). Not worth the complexity for CLI
tools or short-lived processes.

### Inline Hints on Hot Paths

```rust
// Always inline small, frequently-called functions
#[inline]
pub fn validate(&self, payload: &Bytes) -> ValidationResult {
    // Hot path validation
}

#[inline]
pub fn route(&self, payload: &Bytes) -> RouteResult {
    // Hot path routing
}

#[inline]
fn has_field(&self, payload: &Bytes, field: &str) -> bool {
    // Zero-copy field check
    sonic_rs::get_from_slice(payload, [field].as_slice()).is_ok()
}
```

---

## Real-World SIMD Patterns

### Multi-Architecture SIMD with Runtime Detection

Pattern from dfe-loader's Mison JSON parser:

```rust
use std::sync::OnceLock;

#[derive(Debug, Clone, Copy)]
pub enum SimdCapability {
    Avx2,
    Sse42,
    Neon,
    Scalar,
}

static SIMD_CAPABILITY: OnceLock<SimdCapability> = OnceLock::new();

pub fn get_simd_capability() -> SimdCapability {
    *SIMD_CAPABILITY.get_or_init(|| {
        #[cfg(target_arch = "x86_64")]
        {
            if is_x86_feature_detected!("avx2") {
                return SimdCapability::Avx2;
            }
            if is_x86_feature_detected!("sse4.2") {
                return SimdCapability::Sse42;
            }
        }
        #[cfg(target_arch = "aarch64")]
        {
            // NEON is always available on aarch64
            return SimdCapability::Neon;
        }
        SimdCapability::Scalar
    })
}

/// Dispatch to best available implementation
pub fn build_character_bitmaps(chunk: &[u8; 64]) -> CharacterBitmaps {
    match get_simd_capability() {
        SimdCapability::Avx2 => unsafe { build_character_bitmaps_avx2(chunk) },
        SimdCapability::Sse42 => unsafe { build_character_bitmaps_sse42(chunk) },
        SimdCapability::Neon => unsafe { build_character_bitmaps_neon(chunk) },
        SimdCapability::Scalar => build_character_bitmaps_scalar(chunk),
    }
}
```

### AVX2 Structural Character Detection (256-bit)

```rust
#[cfg(target_arch = "x86_64")]
use std::arch::x86_64::*;

#[derive(Debug, Clone, Copy, Default)]
pub struct CharacterBitmaps {
    pub quote: u64,      // "
    pub backslash: u64,  // \
    pub colon: u64,      // :
    pub comma: u64,      // ,
    pub open_brace: u64, // {
    pub close_brace: u64,// }
    pub open_bracket: u64,  // [
    pub close_bracket: u64, // ]
}

/// Process 64 bytes at once using AVX2
/// Returns bitmaps where bit N is set if character found at position N
#[target_feature(enable = "avx2")]
unsafe fn build_character_bitmaps_avx2(chunk: &[u8; 64]) -> CharacterBitmaps {
    // Broadcast each target character to all 32 lanes
    let quote_vec = _mm256_set1_epi8(b'"' as i8);
    let colon_vec = _mm256_set1_epi8(b':' as i8);
    let comma_vec = _mm256_set1_epi8(b',' as i8);
    let open_brace_vec = _mm256_set1_epi8(b'{' as i8);
    let close_brace_vec = _mm256_set1_epi8(b'}' as i8);

    // Load two 32-byte halves
    let data0 = _mm256_loadu_si256(chunk.as_ptr() as *const __m256i);
    let data1 = _mm256_loadu_si256(chunk.as_ptr().add(32) as *const __m256i);

    // Parallel comparison: 32 bytes at a time
    // cmpeq returns 0xFF for match, 0x00 for miss
    let quote0 = _mm256_movemask_epi8(_mm256_cmpeq_epi8(data0, quote_vec)) as u32;
    let quote1 = _mm256_movemask_epi8(_mm256_cmpeq_epi8(data1, quote_vec)) as u32;

    let colon0 = _mm256_movemask_epi8(_mm256_cmpeq_epi8(data0, colon_vec)) as u32;
    let colon1 = _mm256_movemask_epi8(_mm256_cmpeq_epi8(data1, colon_vec)) as u32;

    // ... repeat for other characters

    // Combine into 64-bit bitmaps
    CharacterBitmaps {
        quote: (quote0 as u64) | ((quote1 as u64) << 32),
        colon: (colon0 as u64) | ((colon1 as u64) << 32),
        // ... other fields
        ..Default::default()
    }
}
```

### sonic-rs for SIMD JSON Parsing

```rust
use sonic_rs::{from_slice, get_from_slice, LazyValue};
use std::borrow::Cow;

/// Full SIMD-accelerated parse (when you need the whole document)
pub fn parse_json_fast(data: &[u8]) -> Result<serde_json::Value> {
    sonic_rs::from_slice(data).map_err(|e| Error::Json(e.to_string()))
}

/// Zero-copy field extraction (4-8x faster than full DOM parse)
#[inline]
pub fn extract_field<'a>(payload: &'a [u8], field: &str) -> Option<&'a str> {
    let lazy: LazyValue = get_from_slice(payload, &[field]).ok()?;
    lazy.as_str()
}

/// Nested field extraction with dot notation
#[inline]
pub fn extract_nested_field<'a>(payload: &'a [u8], path: &str) -> Option<&'a str> {
    let parts: Vec<&str> = path.split('.').collect();
    let lazy: LazyValue = get_from_slice(payload, parts.as_slice()).ok()?;
    lazy.as_str()
}

/// Zero-copy with Cow: borrowed when possible, owned only for escaped strings
pub fn extract_field_cow<'a>(payload: &'a [u8], field: &str) -> Option<Cow<'a, str>> {
    let lazy: LazyValue = get_from_slice(payload, &[field]).ok()?;
    let raw_cow = lazy.as_raw_cow();

    match raw_cow {
        Cow::Borrowed(s) if !s.contains('\\') => {
            // No escapes = true zero-copy from payload bytes
            Some(Cow::Borrowed(&s[1..s.len()-1]))  // Strip quotes
        }
        _ => {
            // Escaped = must allocate for unescaping
            lazy.as_str().map(|s| Cow::Owned(s.to_string()))
        }
    }
}

/// Validate JSON structure without building DOM
#[inline]
pub fn validate_json(payload: &[u8]) -> bool {
    sonic_rs::from_slice::<LazyValue>(payload).is_ok()
}
```

### `array_windows` — Compile-Time Sliding Windows (Rust 1.94.0+)

`array_windows` provides zero-cost sliding windows with compile-time
known size. Unlike `windows()` which returns slices, `array_windows`
returns fixed-size array references — enabling the compiler to
auto-vectorise and use SIMD instructions without manual intrinsics.

```rust
// Sliding window over byte stream — compiler knows window size at compile time
fn find_crlf_positions(data: &[u8]) -> Vec<usize> {
    data.array_windows::<2>()
        .enumerate()
        .filter(|(_, w)| *w == [b'\r', b'\n'])
        .map(|(i, _)| i)
        .collect()
}

// 4-byte magic number detection in binary formats
fn find_magic(data: &[u8], magic: [u8; 4]) -> Option<usize> {
    data.array_windows::<4>()
        .position(|w| *w == magic)
}

// Rolling hash / checksum over fixed-size blocks
fn block_checksums(data: &[u8]) -> Vec<u32> {
    data.array_windows::<64>()
        .map(|block| crc32fast::hash(block))
        .collect()
}
```

Prefer `array_windows::<N>()` over `windows(N)` when the window size
is a compile-time constant. The fixed-size array enables better
optimisation: loop unrolling, SIMD vectorisation, and elimination of
bounds checks.

### SIMD String Search with memchr

```rust
use memchr::{memchr, memchr2, memchr3, memmem};

/// Find newline - much faster than iter().position()
#[inline]
pub fn find_newline(data: &[u8]) -> Option<usize> {
    memchr(b'\n', data)
}

/// Find any delimiter (CSV/TSV flexible parsing)
#[inline]
pub fn find_delimiter(data: &[u8]) -> Option<usize> {
    memchr3(b',', b'\t', b'|', data)
}

/// Count lines efficiently
pub fn count_lines(data: &[u8]) -> usize {
    memchr::memchr_iter(b'\n', data).count()
}

/// Precompiled searcher for repeated pattern matching
pub struct PatternMatcher {
    finder: memmem::Finder<'static>,
}

impl PatternMatcher {
    pub fn new(pattern: &'static [u8]) -> Self {
        Self {
            finder: memmem::Finder::new(pattern),
        }
    }

    #[inline]
    pub fn find(&self, haystack: &[u8]) -> Option<usize> {
        self.finder.find(haystack)
    }
}
```

---

## Resources

### Official Documentation

- The Rust Book: <https://doc.rust-lang.org/book/>
- Rust by Example: <https://doc.rust-lang.org/rust-by-example/>
- Rust Reference: <https://doc.rust-lang.org/reference/>
- Rustonomicon (unsafe): <https://doc.rust-lang.org/nomicon/>

### Tools

- Clippy Lints: <https://rust-lang.github.io/rust-clippy/>
- Rust Playground: <https://play.rust-lang.org/>

### Async and Concurrency

- Tokio Tutorial: <https://tokio.rs/tokio/tutorial>
- Async Book: <https://rust-lang.github.io/async-book/>

### Performance

- The Rust Performance Book: <https://nnethercote.github.io/perf-book/>
- Criterion Benchmarking: <https://bheisler.github.io/criterion.rs/book/>

### Crate Documentation

- config-rs: <https://docs.rs/config/>
- tracing: <https://docs.rs/tracing/>
- rayon: <https://docs.rs/rayon/>
- tokio: <https://docs.rs/tokio/>
