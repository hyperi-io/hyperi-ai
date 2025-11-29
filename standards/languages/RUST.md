# Rust Standards for HyperSec Projects

**Rust coding standards for systems programming, CLI tools, and high-performance data processing**

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
```

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

---

## Error Handling

### Custom Error Types with thiserror

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ConfigError {
    #[error("failed to read config file '{path}': {source}")]
    ReadError {
        path: String,
        #[source]
        source: std::io::Error,
    },

    #[error("invalid config format: {0}")]
    ParseError(#[from] serde_yaml::Error),

    #[error("missing required field: {0}")]
    MissingField(String),

    #[error("invalid value '{value}' for {field}: {reason}")]
    InvalidValue {
        field: String,
        value: String,
        reason: String,
    },
}
```

### Result Type Alias

```rust
pub type Result<T> = std::result::Result<T, ConfigError>;

// Usage
pub fn load_config(path: &str) -> Result<Config> {
    let content = std::fs::read_to_string(path)
        .map_err(|e| ConfigError::ReadError {
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
use anyhow::{Context, Result};

fn main() -> Result<()> {
    let config = load_config("config.yaml")
        .context("failed to load configuration")?;

    let data = fetch_data(&config.url)
        .with_context(|| format!("failed to fetch from {}", config.url))?;

    process(data)?;
    Ok(())
}
```

---

## Ownership and Borrowing

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
fn process_and_keep(data: &Vec<String>) -> Vec<String> {
    let mut result = data.clone();  // OK - we need owned data
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
struct Config<'a> {
    name: &'a str,
    path: &'a Path,
}

// Prefer owned types for simplicity when possible
struct OwnedConfig {
    name: String,
    path: PathBuf,
}
```

---

## Structs and Enums

### Struct Definition

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub email: String,
    #[serde(default)]
    pub active: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<HashMap<String, String>>,
}

impl User {
    pub fn new(id: impl Into<String>, email: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            email: email.into(),
            active: true,
            metadata: None,
        }
    }

    pub fn is_valid(&self) -> bool {
        !self.id.is_empty() && self.email.contains('@')
    }
}
```

### Enums with Data

```rust
#[derive(Debug, Clone)]
pub enum Event {
    Created { id: String, timestamp: DateTime<Utc> },
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
}
```

### Builder Pattern

```rust
#[derive(Default)]
pub struct RequestBuilder {
    url: Option<String>,
    method: Method,
    headers: HashMap<String, String>,
    timeout: Duration,
}

impl RequestBuilder {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn url(mut self, url: impl Into<String>) -> Self {
        self.url = Some(url.into());
        self
    }

    pub fn header(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.headers.insert(key.into(), value.into());
        self
    }

    pub fn timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
        self
    }

    pub fn build(self) -> Result<Request, BuildError> {
        let url = self.url.ok_or(BuildError::MissingUrl)?;
        Ok(Request {
            url,
            method: self.method,
            headers: self.headers,
            timeout: self.timeout,
        })
    }
}

// Usage
let request = RequestBuilder::new()
    .url("https://api.example.com")
    .header("Authorization", "Bearer token")
    .timeout(Duration::from_secs(30))
    .build()?;
```

---

## Testing

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_user_validation() {
        let valid = User::new("123", "test@example.com");
        assert!(valid.is_valid());

        let invalid = User::new("", "test@example.com");
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

### Integration Tests

```rust
// tests/integration_test.rs
use mylib::{Client, Config};

#[tokio::test]
async fn test_client_connection() {
    let config = Config::default();
    let client = Client::new(config);

    let result = client.ping().await;
    assert!(result.is_ok());
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

### Concurrent Tasks

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

### Channels

```rust
use tokio::sync::mpsc;

async fn producer(tx: mpsc::Sender<Event>) {
    for i in 0..100 {
        tx.send(Event::new(i)).await.unwrap();
    }
}

async fn consumer(mut rx: mpsc::Receiver<Event>) {
    while let Some(event) = rx.recv().await {
        process_event(event).await;
    }
}

#[tokio::main]
async fn main() {
    let (tx, rx) = mpsc::channel(100);

    tokio::spawn(producer(tx));
    consumer(rx).await;
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
```

### Common Clippy Attributes

```rust
// Allow specific lints
#[allow(clippy::too_many_arguments)]
fn complex_function(a: i32, b: i32, c: i32, d: i32, e: i32, f: i32, g: i32, h: i32) {}

// Deny specific lints
#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]

// Warn on all pedantic lints
#![warn(clippy::pedantic)]
```

### CI Clippy Command

```bash
cargo clippy --all-targets --all-features -- -D warnings
```

---

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Crates | snake_case | `my_crate` |
| Modules | snake_case | `config`, `error` |
| Types | PascalCase | `UserConfig`, `HttpClient` |
| Traits | PascalCase | `Serialize`, `IntoIterator` |
| Functions | snake_case | `load_config`, `process_event` |
| Constants | SCREAMING_SNAKE | `MAX_RETRIES`, `DEFAULT_PORT` |
| Statics | SCREAMING_SNAKE | `GLOBAL_CONFIG` |
| Lifetimes | short lowercase | `'a`, `'ctx` |

---

## Common Patterns

### Option Handling

```rust
// ✅ Good - use combinators
let name = config.name.unwrap_or_default();
let port = config.port.unwrap_or(8080);
let value = opt.map(|v| v.to_string());

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

// Partition
let (active, inactive): (Vec<_>, Vec<_>) = users
    .into_iter()
    .partition(|u| u.active);

// Fold/reduce
let total: i32 = items.iter().map(|i| i.price).sum();
```

---

## Cargo.toml Best Practices

```toml
[package]
name = "my-project"
version = "0.1.0"
edition = "2021"
rust-version = "1.75"
description = "A brief description"
license = "Apache-2.0"

[dependencies]
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "1"
anyhow = "1"
tracing = "0.1"

[dev-dependencies]
tempfile = "3"
tokio-test = "0.4"

[profile.release]
lto = true
codegen-units = 1
strip = true

[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
pedantic = "warn"
unwrap_used = "deny"
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

// Structured logging
#[instrument(skip(password))]
fn process_request(user_id: u64, password: &str) {
    info!(user_id, "Processing request");
    // ...
    error!(error = %e, user_id, "Operation failed");
}
```

**Output Modes:**

| Context | Format | Colours |
|---------|--------|---------|
| Console (dev) | Human-friendly | Yes |
| Container/CI | RFC 3339 JSON | No |

**ENV overrides:** `RUST_LOG=debug`, `NO_COLOR=1`

---

## Resources

- The Rust Book: <https://doc.rust-lang.org/book/>
- Rust by Example: <https://doc.rust-lang.org/rust-by-example/>
- Clippy Lints: <https://rust-lang.github.io/rust-clippy/>
- Tokio Tutorial: <https://tokio.rs/tokio/tutorial>
- config-rs: <https://docs.rs/config/>
- tracing: <https://docs.rs/tracing/>

---

## For AI Code Assistants

The following sections are specific guidance for AI code assistants working with Rust.

---

## AI Pitfalls to Avoid

**Before generating Rust code, check these patterns:**

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
```
