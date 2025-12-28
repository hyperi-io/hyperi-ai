---
name: rust-standards
description: Rust coding standards using Cargo, clippy, and idiomatic patterns. Use when writing Rust code, reviewing Rust, or setting up Rust projects.
---

# Rust Standards for HyperSec Projects

**Rust coding standards for systems programming, CLI tools, and high-performance data processing**

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Project Structure](#project-structure)
3. [Rust Foundations](#rust-foundations)
4. [Error Handling](#error-handling)
5. [Ownership and Borrowing](#ownership-and-borrowing)
6. [Structs and Enums](#structs-and-enums)
7. [Common Patterns](#common-patterns)
8. [Testing](#testing)
9. [Async with Tokio](#async-with-tokio)
10. [Hot Path Optimization](#hot-path-optimization)
11. [Zero-Copy Data Processing](#zero-copy-data-processing)
12. [SIMD and Vectorized Processing](#simd-and-vectorized-processing)
13. [Memory Management for Scale](#memory-management-for-scale)
14. [Concurrency Patterns](#concurrency-patterns)
15. [Data Pipeline Architecture](#data-pipeline-architecture)
16. [8 Common Rust Mistakes](#8-common-rust-mistakes)
17. [Clippy Configuration](#clippy-configuration)
18. [Cargo.toml Best Practices](#cargotoml-best-practices)
19. [Configuration (HyperSec Cascade)](#configuration-hypersec-cascade)
20. [Logging (HyperSec Standard)](#logging-hypersec-standard)
21. [AI Pitfalls to Avoid](#ai-pitfalls-to-avoid)
22. [Resources](#resources)

---

## Quick Reference

```bash
cargo build                     # Build debug
cargo build --release           # Build release
cargo test                      # Run tests
cargo clippy                    # Lint
cargo fmt                       # Format
cargo check                     # Type check (fast)
cargo doc --open                # Generate docs
cargo bench                     # Run benchmarks
cargo tree                      # Dependency tree
cargo audit                     # Security audit
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

### Variables and Mutability

```rust
// Immutable by default
let x = 5;
// x = 6;  // Error!

// Explicitly mutable
let mut y = 5;
y = 6;  // OK

// Shadowing - create new variable with same name
let x = "hello";        // Now a &str, not i32
let x = x.len();        // Now a usize

// Constants - computed at compile time
const MAX_CONNECTIONS: u32 = 1000;
const TIMEOUT_MS: u64 = 30_000;

// Static - has fixed memory address
static VERSION: &str = "1.0.0";
```

### Primitive Types

```rust
// Integers
let byte: u8 = 255;
let signed: i32 = -42;
let large: u64 = 1_000_000_000;
let index: usize = vec.len();

// Floats
let pi: f64 = 3.14159265359;
let approx: f32 = 3.14;

// Boolean
let active: bool = true;

// Character (Unicode scalar, 4 bytes)
let c: char = '🦀';

// Unit type (empty tuple)
let unit: () = ();
```

### Compound Types

```rust
// Tuple - fixed size, mixed types
let point: (i32, i32) = (10, 20);
let (x, y) = point;              // Destructuring
let first = point.0;             // Index access

// Array - fixed size, same type, stack allocated
let arr: [i32; 5] = [1, 2, 3, 4, 5];
let zeros = [0; 100];            // 100 zeros
let first = arr[0];
let slice: &[i32] = &arr[1..3];  // Slice

// Vec - dynamic size, heap allocated
let mut vec: Vec<i32> = Vec::new();
let vec = vec![1, 2, 3];
vec.push(4);
```

### Control Flow

```rust
// if/else - expression, not statement
let status = if count > 0 { "active" } else { "empty" };

// match - exhaustive pattern matching
match result {
    Ok(value) => println!("Got: {}", value),
    Err(e) => eprintln!("Error: {}", e),
}

// match with guards
match number {
    n if n < 0 => "negative",
    0 => "zero",
    n if n < 10 => "small",
    _ => "large",
}

// if let - single pattern match
if let Some(value) = optional {
    println!("Has value: {}", value);
}

// while let
while let Some(item) = iter.next() {
    process(item);
}

// loop with break value
let result = loop {
    if condition {
        break computed_value;
    }
};

// for with ranges
for i in 0..10 { }           // 0 to 9
for i in 0..=10 { }          // 0 to 10 inclusive
for (i, item) in vec.iter().enumerate() { }
```

### Functions

```rust
// Basic function
fn add(a: i32, b: i32) -> i32 {
    a + b  // No semicolon = return value
}

// Early return
fn divide(a: f64, b: f64) -> Option<f64> {
    if b == 0.0 {
        return None;
    }
    Some(a / b)
}

// Generic function
fn first<T>(slice: &[T]) -> Option<&T> {
    slice.first()
}

// Multiple generic bounds
fn process<T: Clone + Debug>(item: T) { }

// Where clause for complex bounds
fn process<T, U>(t: T, u: U)
where
    T: Clone + Send + 'static,
    U: Debug + Default,
{ }
```

### Closures

```rust
// Inferred types
let add = |a, b| a + b;

// Explicit types
let add: fn(i32, i32) -> i32 = |a, b| a + b;

// Capturing environment
let multiplier = 3;
let multiply = |x| x * multiplier;  // Borrows multiplier

// Move closure - takes ownership
let data = vec![1, 2, 3];
let closure = move || {
    println!("{:?}", data);  // Owns data
};

// Closure traits:
// Fn     - borrows immutably (can call multiple times)
// FnMut  - borrows mutably (can call multiple times)
// FnOnce - takes ownership (can call once)
```

---

## Error Handling

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

### The Three Rules

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
edition = "2021"
rust-version = "1.75"
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

---

## Configuration (HyperSec Cascade)

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

## Logging (HyperSec Standard)

Use `tracing` with RFC 3339 timestamps:

```rust
use tracing::{info, error, warn, debug, instrument};
use tracing_subscriber::{fmt, EnvFilter, layer::SubscriberExt, util::SubscriberInitExt};

fn init_logging() {
    let is_terminal = atty::is(atty::Stream::Stderr);

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

## AI Pitfalls to Avoid

The following sections are specific guidance for AI code assistants working with Rust.

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
