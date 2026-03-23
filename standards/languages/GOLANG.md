---
name: golang-standards
description: Go coding standards using standard library patterns, error handling, and testing conventions. Use when writing Go code, reviewing Go, or setting up Go projects.
rule_paths:
  - "**/*.go"
detect_markers:
  - "file:go.mod"
  - "deep_file:go.mod"
paths:
  - "**/*.go"
---

# Go Standards for HyperI Projects

**Comprehensive Go coding standards for backend services, agents, and data processing**

---

## Quick Reference

```bash
go build ./...                  # Build
go test ./...                   # Test
go test -race ./...             # Test with race detector
golangci-lint run               # Lint
go mod tidy                     # Clean dependencies
```

---

## Project Structure

### Standard Layout

```text
myproject/
├── cmd/
│   └── myapp/
│       └── main.go             # Entry point
├── internal/                   # Private packages
│   ├── config/
│   ├── handlers/
│   └── service/
├── pkg/                        # Public packages (if needed)
├── go.mod
├── go.sum
└── Makefile
```

### Simple Agent Layout (like hyperi-agent-windows)

```text
myagent/
├── config/
│   ├── config.go
│   └── config_test.go
├── helpers/
├── httpclient/
├── go.mod
├── go.sum
└── main.go                     # Entry point at root
```

**Note:** Simple projects don't need cmd/internal/pkg. Use flat structure when appropriate.

---

## Error Handling

### Always Wrap Errors with Context

```go
// ✅ Good - wrap with context using %w
func LoadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("could not read config file '%s': %w", path, err)
    }

    cfg, err := parseConfig(data)
    if err != nil {
        return nil, fmt.Errorf("failed to parse config from '%s': %w", path, err)
    }

    return cfg, nil
}

// ❌ Bad - no context
func LoadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err  // Lost context - which file?
    }
    return parseConfig(data)
}
```

### Clear Validation Error Messages

```go
// ✅ Good - specific, actionable error
if strings.TrimSpace(ft.Name) == "" {
    return fmt.Errorf("fileTail entry at index %d is missing a 'name'", i)
}

if spLower != "end" && spLower != "beginning" {
    return fmt.Errorf("invalid startPosition '%s' for fileTail '%s' (index %d): must be 'beginning' or 'end'",
        ft.StartPosition, ft.Name, i)
}

// ❌ Bad - vague error
if ft.Name == "" {
    return errors.New("invalid config")
}
```

### Handle Errors Immediately

```go
// ✅ Good - handle immediately, reduce nesting
func ProcessData(data []byte) (Result, error) {
    cfg, err := parseConfig(data)
    if err != nil {
        return Result{}, err
    }

    validated, err := validate(cfg)
    if err != nil {
        return Result{}, err
    }

    return process(validated)
}

// ❌ Bad - nested error handling
func ProcessData(data []byte) (Result, error) {
    if cfg, err := parseConfig(data); err == nil {
        if validated, err := validate(cfg); err == nil {
            return process(validated)
        } else {
            return Result{}, err
        }
    } else {
        return Result{}, err
    }
}
```

### Custom Error Types

```go
// Custom errors for specific handling
type ConfigError struct {
    Path    string
    Message string
    Err     error
}

func (e *ConfigError) Error() string {
    return fmt.Sprintf("config error in %s: %s", e.Path, e.Message)
}

func (e *ConfigError) Unwrap() error {
    return e.Err
}
```

---

## Testing

### Directory Structure

Unit tests are co-located with source (Go convention). Integration and E2E go in `tests/`.

```text
cmd/
├── myapp/
│   └── main.go
internal/
├── config/
│   ├── config.go
│   └── config_test.go        # Unit test co-located
├── pipeline/
│   ├── pipeline.go
│   └── pipeline_test.go      # Unit test co-located
└── source/
    ├── aws.go
    └── aws_test.go            # Unit test co-located

tests/
├── common/
│   └── helpers.go             # Shared test helpers
├── fixtures/
│   └── sample_config.yaml     # Static test data
├── integration/
│   └── api_test.go            # Build tag: //go:build integration
├── e2e/
│   └── pipeline_test.go       # Build tag: //go:build e2e
└── smoke_test.go              # MANDATORY — startup smoke test
```

- Unit tests: co-located `_test.go` files (Go standard)
- Integration: use build tags (`//go:build integration`) for CI separation
- E2E: use build tags (`//go:build e2e`) — requires infrastructure
- Smoke test is mandatory — catches init panics before production does

### Startup Smoke Test (MANDATORY)

```go
// tests/smoke_test.go
package tests

func TestAppStartsWithDefaults(t *testing.T) {
    cfg := config.Default()
    app, err := NewApp(cfg)
    require.NoError(t, err, "app should start with default config")
    assert.True(t, app.IsReady())
}
```

### CI Stage Mapping (hyperi-ci)

| Location | CI Stage | Command | Trigger |
|----------|----------|---------|---------|
| `*_test.go` (no tags) | `quality` | `go test ./...` | Every push |
| `//go:build integration` | `test` | `go test -tags=integration ./tests/integration/` | Every push |
| `//go:build e2e` | `test:e2e` | `go test -tags=e2e ./tests/e2e/` | PR to `release` |
| `tests/smoke_test.go` | `test:smoke` | `go test ./tests/ -run Smoke` | Every push |

### Integration Tests with Testcontainers

```go
// tests/integration/db_test.go
//go:build integration

package integration

import (
    "context"
    "testing"

    "github.com/stretchr/testify/require"
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/modules/postgres"
)

func TestDatabaseOperations(t *testing.T) {
    ctx := context.Background()

    pgContainer, err := postgres.Run(ctx, "postgres:16-alpine")
    require.NoError(t, err)
    defer pgContainer.Terminate(ctx)

    connStr, err := pgContainer.ConnectionString(ctx)
    require.NoError(t, err)

    db := connectDB(t, connStr)
    // test with real Postgres
}
```

### Table-Driven Tests

```go
func TestLoadConfig_FileTailsProcessing(t *testing.T) {
    tests := []struct {
        name             string
        fileTailsYAML    string
        expectedNumTails int
        expectedTails    []FileTailConfig
        expectError      bool
        errorContains    string
    }{
        {
            name:             "No fileTails section",
            fileTailsYAML:    "",
            expectedNumTails: 0,
            expectedTails:    nil,
        },
        {
            name: "Single fileTail with all fields",
            fileTailsYAML: `
fileTails:
  - name: "TestLog1"
    path: "/var/log/test1.log"
    startPosition: "beginning"
`,
            expectedNumTails: 1,
            expectedTails: []FileTailConfig{
                {Name: "TestLog1", Path: "/var/log/test1.log", StartPosition: "beginning"},
            },
        },
        {
            name: "Invalid startPosition value",
            fileTailsYAML: `
fileTails:
  - name: "InvalidStart"
    path: "invalid.log"
    startPosition: "middle"
`,
            expectError:   true,
            errorContains: "invalid startPosition 'middle'",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            cfg, err := LoadConfig(createTestConfig(t, tt.fileTailsYAML))

            if tt.expectError {
                require.Error(t, err)
                if tt.errorContains != "" {
                    assert.Contains(t, err.Error(), tt.errorContains)
                }
                return
            }

            require.NoError(t, err)
            assert.Len(t, cfg.FileTails, tt.expectedNumTails)
            if tt.expectedTails != nil {
                assert.Equal(t, tt.expectedTails, cfg.FileTails)
            }
        })
    }
}
```

### Test Helper Functions

```go
// Use t.Helper() for helper functions
func createTestConfig(t *testing.T, content string) string {
    t.Helper()  // Report errors at caller's line
    dir := t.TempDir()
    path := filepath.Join(dir, "test_config.yaml")
    err := os.WriteFile(path, []byte(content), 0644)
    require.NoError(t, err, "Failed to write test config")
    return path
}

// Use t.TempDir() for temp files (auto-cleaned)
func TestFileOperations(t *testing.T) {
    tmpDir := t.TempDir()  // Automatically cleaned up
    testFile := filepath.Join(tmpDir, "test.txt")
    // ...
}
```

### Test Naming

```go
// Format: TestFunction_Scenario or TestFunction_Scenario_SubScenario
func TestLoadConfig_ValidConfig(t *testing.T) { }
func TestLoadConfig_MissingFile_ReturnsError(t *testing.T) { }
func TestLoadConfig_InvalidYAML_ReturnsParseError(t *testing.T) { }
```

### Testify Assertions

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestExample(t *testing.T) {
    // require - stops test on failure
    require.NoError(t, err, "setup failed")
    require.NotNil(t, result)

    // assert - continues test on failure
    assert.Equal(t, expected, actual)
    assert.Len(t, items, 3)
    assert.Contains(t, err.Error(), "not found")
    assert.True(t, condition, "should be true")
}
```

---

## Configuration (HyperI Cascade)

Go implements the 7-layer config cascade using Viper:

```go
import (
    "github.com/spf13/viper"
    "github.com/spf13/cobra"
)

func initConfig() {
    // 7. Hard-coded defaults (lowest priority)
    viper.SetDefault("database.host", "localhost")
    viper.SetDefault("database.port", 5432)
    viper.SetDefault("log_level", "INFO")

    // 6. defaults.yaml
    viper.SetConfigName("defaults")
    viper.AddConfigPath("./config")
    _ = viper.MergeInConfig()

    // 5. settings.yaml
    viper.SetConfigName("settings")
    _ = viper.MergeInConfig()

    // 4. settings.{env}.yaml
    env := os.Getenv("APP_ENV")
    if env == "" {
        env = "development"
    }
    viper.SetConfigName("settings." + env)
    _ = viper.MergeInConfig()

    // 3. .env file (via AutomaticEnv)
    viper.SetConfigFile(".env")
    _ = viper.MergeInConfig()

    // 2. ENV variables (MYAPP_DATABASE_HOST)
    viper.SetEnvPrefix("MYAPP")
    viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
    viper.AutomaticEnv()

    // 1. CLI flags (highest priority) - via Cobra binding
}
```

### Struct Tags for YAML/JSON

```go
type Config struct {
    LogConfig struct {
        Channels    []string `yaml:"channels"`
        MinLogLevel string   `yaml:"minLogLevel,omitempty"`
        AgentLogFile string  `yaml:"agentLogFile,omitempty"`
    } `yaml:"logConfig"`

    ExportConfig struct {
        Hostname string `yaml:"hostname"`
        Port     string `yaml:"port"`
        Path     string `yaml:"path"`
    } `yaml:"exportConfig"`
}
```

### Default Values and Validation

```go
func processAndSetDefaults(config *Config) error {
    // Set defaults
    if strings.TrimSpace(config.LogConfig.MinLogLevel) == "" {
        config.LogConfig.MinLogLevel = "WARN"
    }

    // Validate with clear error messages
    levelUpper := strings.ToUpper(strings.TrimSpace(config.LogConfig.MinLogLevel))
    validLevels := map[string]bool{
        "TRACE": true, "DEBUG": true, "INFO": true,
        "WARN": true, "ERROR": true, "FATAL": true,
    }
    if !validLevels[levelUpper] {
        return fmt.Errorf("invalid minLogLevel '%s': must be one of TRACE, DEBUG, INFO, WARN, ERROR, FATAL",
            config.LogConfig.MinLogLevel)
    }
    config.LogConfig.MinLogLevel = levelUpper

    return nil
}
```

---

## Logging (HyperI Standard)

### RFC 3339 Timestamps (Required)

```go
import (
    "log/slog"
    "time"
)

// Custom handler with RFC 3339 timestamps
type RFC3339Handler struct {
    slog.Handler
}

func (h *RFC3339Handler) Handle(ctx context.Context, r slog.Record) error {
    // Ensure RFC 3339 format: 2025-01-20T14:30:00.123Z
    r.Time = r.Time.UTC()
    return h.Handler.Handle(ctx, r)
}

// Setup structured logger with RFC 3339
func setupLogger() *slog.Logger {
    opts := &slog.HandlerOptions{
        Level: slog.LevelInfo,
        ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
            if a.Key == slog.TimeKey {
                // RFC 3339 format
                return slog.String(slog.TimeKey, a.Value.Time().Format(time.RFC3339Nano))
            }
            return a
        },
    }
    return slog.New(slog.NewJSONHandler(os.Stdout, opts))
}
```

### Structured Logging with slog (Go 1.21+)

```go
import "log/slog"

// Setup structured logger
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
}))

// Log with context
logger.Info("processing request",
    "user_id", userID,
    "request_id", requestID,
    "operation", "update_profile",
)

logger.Error("operation failed",
    "error", err,
    "user_id", userID,
    "request_id", requestID,
)
```

### Console vs Container Output

```go
// Auto-detect output mode
func newLogger() *slog.Logger {
    var handler slog.Handler

    if isTerminal(os.Stderr) {
        // Console: human-friendly text
        handler = slog.NewTextHandler(os.Stderr, nil)
    } else {
        // Container/CI: JSON for log aggregators
        handler = slog.NewJSONHandler(os.Stderr, nil)
    }
    return slog.New(handler)
}

func isTerminal(f *os.File) bool {
    stat, _ := f.Stat()
    return (stat.Mode() & os.ModeCharDevice) != 0
}
```

### Using Standard log Package

```go
import "log"

// Simple logging
log.Printf("Attempting to load configuration from file: %s", path)
log.Printf("Configuration loaded successfully from file: %s", path)
log.Printf("Using decryption key for build. (first 3 chars): %s...\n", decryptionKey[:3])
```

---

## Naming Conventions

### Variables and Functions

```go
// camelCase for unexported, PascalCase for exported
var userCount int          // unexported
var UserCount int          // exported

func calculateTotal() {}   // unexported
func CalculateTotal() {}   // exported

// Acronyms stay uppercase
var httpClient *http.Client
var userID string
type HTTPClient struct {}
```

### Constants

```go
const (
    DefaultConfigName    = "config.yaml"
    DefaultStartPosition = "end"
    MaxRetries           = 3
)

// Iota for enums
type LogLevel int

const (
    LogLevelDebug LogLevel = iota
    LogLevelInfo
    LogLevelWarn
    LogLevelError
)
```

### File Names

```go
// snake_case for files
config.go
config_test.go
data_load.go
parse_xml_event.go
```

---

## Code Style

### Reduce Nesting

```go
// ✅ Good - early return
func ProcessItem(item Item) error {
    if item.ID == "" {
        return errors.New("item ID required")
    }

    if !item.IsValid() {
        return errors.New("invalid item")
    }

    return saveItem(item)
}

// ❌ Bad - nested
func ProcessItem(item Item) error {
    if item.ID != "" {
        if item.IsValid() {
            return saveItem(item)
        } else {
            return errors.New("invalid item")
        }
    } else {
        return errors.New("item ID required")
    }
}
```

### Receiver Names

```go
// Short, consistent receiver names
func (c *Config) Validate() error {}
func (c *Config) Save() error {}

// Not verbose
func (config *Config) Validate() error {}  // Too long
func (this *Config) Validate() error {}    // Not Go style
```

### Interface Design

```go
// Small, focused interfaces
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

// Compose when needed
type ReadWriter interface {
    Reader
    Writer
}
```

---

## Dependencies

### Go Modules

```go
// go.mod
module myproject

go 1.24.2

require (
    github.com/stretchr/testify v1.10.0
    gopkg.in/yaml.v3 v3.0.1
)
```

### Common Dependencies

| Package | Purpose |
|---------|---------|
| `gopkg.in/yaml.v3` | YAML parsing |
| `github.com/stretchr/testify` | Testing assertions |
| `gopkg.in/natefinch/lumberjack.v2` | Log rotation |
| `github.com/spf13/cobra` | CLI |
| `github.com/spf13/viper` | Configuration |

---

## Linting

### golangci-lint Configuration

```yaml
# .golangci.yml
linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
    - gofmt
    - goimports

linters-settings:
  errcheck:
    check-type-assertions: true
  govet:
    check-shadowing: true

issues:
  exclude-rules:
    - path: _test\.go
      linters:
        - errcheck
```

### Running Linter

```bash
golangci-lint run                    # Lint all
golangci-lint run ./...              # Lint recursively
golangci-lint run --fix              # Auto-fix where possible
```

---

## Concurrency

### Goroutines and Channels

```go
// Use channels for communication
results := make(chan Result, 10)
errors := make(chan error, 1)

go func() {
    result, err := processAsync()
    if err != nil {
        errors <- err
        return
    }
    results <- result
}()

select {
case result := <-results:
    return result, nil
case err := <-errors:
    return Result{}, err
case <-time.After(5 * time.Second):
    return Result{}, errors.New("timeout")
}
```

### Context for Cancellation

```go
func ProcessWithContext(ctx context.Context, data []byte) (Result, error) {
    select {
    case <-ctx.Done():
        return Result{}, ctx.Err()
    default:
    }

    // Process data...
    return process(data)
}
```

### sync.WaitGroup

```go
var wg sync.WaitGroup

for _, item := range items {
    wg.Add(1)
    go func(item Item) {
        defer wg.Done()
        process(item)
    }(item)
}

wg.Wait()
```

### Mutex Patterns

```go
import "sync"

type SafeCounter struct {
    mu    sync.RWMutex
    count map[string]int
}

func NewSafeCounter() *SafeCounter {
    return &SafeCounter{
        count: make(map[string]int),
    }
}

// Write operation - exclusive lock
func (c *SafeCounter) Increment(key string) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count[key]++
}

// Read operation - shared lock (multiple readers OK)
func (c *SafeCounter) Get(key string) int {
    c.mu.RLock()
    defer c.mu.RUnlock()
    return c.count[key]
}

// ❌ Bad - holding lock during slow operation
func (c *SafeCounter) ProcessAll() {
    c.mu.Lock()
    defer c.mu.Unlock()
    for k, v := range c.count {
        slowOperation(k, v)  // Lock held too long!
    }
}

// ✅ Good - copy data, release lock, then process
func (c *SafeCounter) ProcessAll() {
    c.mu.RLock()
    snapshot := make(map[string]int, len(c.count))
    for k, v := range c.count {
        snapshot[k] = v
    }
    c.mu.RUnlock()

    for k, v := range snapshot {
        slowOperation(k, v)  // Lock released
    }
}
```

### sync.Once for Initialization

```go
type Service struct {
    once   sync.Once
    client *http.Client
}

func (s *Service) getClient() *http.Client {
    s.once.Do(func() {
        // Only runs once, even with concurrent calls
        s.client = &http.Client{Timeout: 30 * time.Second}
    })
    return s.client
}
```

### errgroup for Concurrent Error Handling

```go
import "golang.org/x/sync/errgroup"

func ProcessConcurrently(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)

    for _, item := range items {
        item := item  // Capture for goroutine
        g.Go(func() error {
            return processItem(ctx, item)
        })
    }

    // Wait for all goroutines, return first error
    return g.Wait()
}

// With concurrency limit
func ProcessWithLimit(ctx context.Context, items []Item, limit int) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(limit)  // Max concurrent goroutines

    for _, item := range items {
        item := item
        g.Go(func() error {
            return processItem(ctx, item)
        })
    }

    return g.Wait()
}
```

---

## Context Best Practices

### Propagating Context

```go
// ✅ Good - context as first parameter
func ProcessRequest(ctx context.Context, req *Request) (*Response, error) {
    // Check for cancellation early
    if err := ctx.Err(); err != nil {
        return nil, err
    }

    // Pass context to all downstream calls
    data, err := fetchData(ctx, req.ID)
    if err != nil {
        return nil, err
    }

    result, err := transform(ctx, data)
    if err != nil {
        return nil, err
    }

    return &Response{Data: result}, nil
}

// ❌ Bad - storing context in struct
type BadService struct {
    ctx context.Context  // Don't do this!
}

// ✅ Good - pass context per-call
type GoodService struct {
    client *http.Client
}

func (s *GoodService) Fetch(ctx context.Context, url string) ([]byte, error) {
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    // ...
}
```

### Context with Values

```go
// Define typed keys to avoid collisions
type contextKey string

const (
    requestIDKey contextKey = "requestID"
    userIDKey    contextKey = "userID"
)

func WithRequestID(ctx context.Context, id string) context.Context {
    return context.WithValue(ctx, requestIDKey, id)
}

func RequestIDFromContext(ctx context.Context) string {
    if id, ok := ctx.Value(requestIDKey).(string); ok {
        return id
    }
    return ""
}

// Usage in middleware
func RequestIDMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        id := r.Header.Get("X-Request-ID")
        if id == "" {
            id = uuid.New().String()
        }
        ctx := WithRequestID(r.Context(), id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

### Timeout and Deadline Patterns

```go
func ProcessWithTimeout(data []byte) (Result, error) {
    // Create context with timeout
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()  // Always call cancel to release resources

    return process(ctx, data)
}

func process(ctx context.Context, data []byte) (Result, error) {
    resultCh := make(chan Result, 1)
    errCh := make(chan error, 1)

    go func() {
        result, err := heavyComputation(data)
        if err != nil {
            errCh <- err
            return
        }
        resultCh <- result
    }()

    select {
    case result := <-resultCh:
        return result, nil
    case err := <-errCh:
        return Result{}, err
    case <-ctx.Done():
        return Result{}, fmt.Errorf("processing cancelled: %w", ctx.Err())
    }
}
```

---

## Security

### Vulnerability Scanning

```bash
# Check dependencies for known vulnerabilities
govulncheck ./...

# Run in CI pipeline
govulncheck -format json ./...
```

### Input Validation

```go
func ValidateInput(input string) error {
    if strings.TrimSpace(input) == "" {
        return errors.New("input required")
    }
    if len(input) > MaxInputLength {
        return fmt.Errorf("input exceeds maximum length of %d", MaxInputLength)
    }
    return nil
}
```

### Avoid Command Injection

```go
// ✅ Good - use exec.Command with separate args
cmd := exec.Command("grep", pattern, filename)

// ❌ Bad - shell injection risk
cmd := exec.Command("sh", "-c", "grep "+pattern+" "+filename)
```

### Secure File Permissions

```go
const (
    FileModePermissionFile = os.FileMode(0644)
    FileModePermissionDir  = os.FileMode(0755)
)

err := os.WriteFile(path, data, FileModePermissionFile)
err := os.MkdirAll(dir, FileModePermissionDir)
```

---

## Common Patterns

### Functional Options

```go
type Option func(*Config)

func WithTimeout(d time.Duration) Option {
    return func(c *Config) {
        c.Timeout = d
    }
}

func WithRetries(n int) Option {
    return func(c *Config) {
        c.Retries = n
    }
}

func NewClient(opts ...Option) *Client {
    cfg := defaultConfig()
    for _, opt := range opts {
        opt(&cfg)
    }
    return &Client{config: cfg}
}

// Usage
client := NewClient(WithTimeout(5*time.Second), WithRetries(3))
```

### Constructor Functions

```go
func NewConfig(path string) (*Config, error) {
    cfg := &Config{
        // defaults
    }
    if err := cfg.load(path); err != nil {
        return nil, err
    }
    if err := cfg.validate(); err != nil {
        return nil, err
    }
    return cfg, nil
}
```

---

## HTTP Clients

### Basic HTTP Client with Timeout

```go
import (
    "context"
    "net/http"
    "time"
)

// Create client with sensible defaults
func NewHTTPClient() *http.Client {
    return &http.Client{
        Timeout: 30 * time.Second,
        Transport: &http.Transport{
            MaxIdleConns:        100,
            MaxIdleConnsPerHost: 10,
            IdleConnTimeout:     90 * time.Second,
        },
    }
}

// Make request with context
func (c *Client) Get(ctx context.Context, url string) (*Response, error) {
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil {
        return nil, fmt.Errorf("creating request for %s: %w", url, err)
    }

    req.Header.Set("User-Agent", "hyperi-agent/1.0")
    req.Header.Set("Accept", "application/json")

    resp, err := c.httpClient.Do(req)
    if err != nil {
        return nil, fmt.Errorf("executing request to %s: %w", url, err)
    }
    defer resp.Body.Close()

    if resp.StatusCode < 200 || resp.StatusCode >= 300 {
        body, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
        return nil, fmt.Errorf("unexpected status %d from %s: %s",
            resp.StatusCode, url, string(body))
    }

    var result Response
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return nil, fmt.Errorf("decoding response from %s: %w", url, err)
    }

    return &result, nil
}
```

### Retry with Exponential Backoff

```go
func (c *Client) GetWithRetry(ctx context.Context, url string, maxRetries int) (*Response, error) {
    var lastErr error
    baseDelay := 100 * time.Millisecond

    for attempt := 0; attempt <= maxRetries; attempt++ {
        if attempt > 0 {
            delay := baseDelay * time.Duration(1<<uint(attempt-1)) // Exponential backoff
            if delay > 10*time.Second {
                delay = 10 * time.Second // Cap at 10 seconds
            }

            select {
            case <-ctx.Done():
                return nil, ctx.Err()
            case <-time.After(delay):
            }
        }

        resp, err := c.Get(ctx, url)
        if err == nil {
            return resp, nil
        }

        lastErr = err

        // Don't retry on client errors (4xx)
        if isClientError(err) {
            return nil, err
        }
    }

    return nil, fmt.Errorf("after %d retries: %w", maxRetries, lastErr)
}
```

---

## JSON and XML Handling

### JSON Serialization

```go
import "encoding/json"

// Struct with JSON tags
type Event struct {
    ID        string    `json:"id"`
    Timestamp time.Time `json:"timestamp"`
    Source    string    `json:"source"`
    Data      any       `json:"data,omitempty"`
    Tags      []string  `json:"tags,omitempty"`
}

// Marshal with indentation for debugging
func (e *Event) PrettyJSON() (string, error) {
    data, err := json.MarshalIndent(e, "", "  ")
    if err != nil {
        return "", fmt.Errorf("marshaling event %s: %w", e.ID, err)
    }
    return string(data), nil
}

// Unmarshal with validation
func ParseEvent(data []byte) (*Event, error) {
    var event Event
    if err := json.Unmarshal(data, &event); err != nil {
        return nil, fmt.Errorf("parsing event JSON: %w", err)
    }

    if event.ID == "" {
        return nil, errors.New("event missing required field 'id'")
    }

    return &event, nil
}

// Streaming JSON decoder for large files
func ParseEventsFromReader(r io.Reader) ([]Event, error) {
    var events []Event
    decoder := json.NewDecoder(r)

    for {
        var event Event
        if err := decoder.Decode(&event); err == io.EOF {
            break
        } else if err != nil {
            return nil, fmt.Errorf("decoding event: %w", err)
        }
        events = append(events, event)
    }

    return events, nil
}
```

### XML Parsing (Windows Event Logs)

```go
import "encoding/xml"

// XML struct for Windows Event Log
type WindowsEvent struct {
    XMLName xml.Name `xml:"Event"`
    System  struct {
        Provider struct {
            Name string `xml:"Name,attr"`
            GUID string `xml:"Guid,attr"`
        } `xml:"Provider"`
        EventID     int    `xml:"EventID"`
        Level       int    `xml:"Level"`
        TimeCreated struct {
            SystemTime string `xml:"SystemTime,attr"`
        } `xml:"TimeCreated"`
        Computer string `xml:"Computer"`
        Channel  string `xml:"Channel"`
    } `xml:"System"`
    EventData struct {
        Data []struct {
            Name  string `xml:"Name,attr"`
            Value string `xml:",chardata"`
        } `xml:"Data"`
    } `xml:"EventData"`
}

func ParseWindowsEvent(xmlData string) (*WindowsEvent, error) {
    var event WindowsEvent
    if err := xml.Unmarshal([]byte(xmlData), &event); err != nil {
        return nil, fmt.Errorf("parsing Windows event XML: %w", err)
    }
    return &event, nil
}
```

---

## Graceful Shutdown

### HTTP Server Shutdown

```go
import (
    "context"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func main() {
    server := &http.Server{
        Addr:         ":8080",
        Handler:      setupRoutes(),
        ReadTimeout:  15 * time.Second,
        WriteTimeout: 15 * time.Second,
        IdleTimeout:  60 * time.Second,
    }

    // Start server in goroutine
    go func() {
        log.Printf("Starting server on %s", server.Addr)
        if err := server.ListenAndServe(); err != http.ErrServerClosed {
            log.Fatalf("Server error: %v", err)
        }
    }()

    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down server...")

    // Give outstanding requests 30 seconds to complete
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := server.Shutdown(ctx); err != nil {
        log.Fatalf("Server forced to shutdown: %v", err)
    }

    log.Println("Server stopped gracefully")
}
```

### Worker Shutdown Pattern

```go
type Worker struct {
    done    chan struct{}
    tasks   chan Task
    wg      sync.WaitGroup
}

func NewWorker(numWorkers int) *Worker {
    w := &Worker{
        done:  make(chan struct{}),
        tasks: make(chan Task, 100),
    }

    for i := 0; i < numWorkers; i++ {
        w.wg.Add(1)
        go w.run(i)
    }

    return w
}

func (w *Worker) run(id int) {
    defer w.wg.Done()

    for {
        select {
        case <-w.done:
            log.Printf("Worker %d stopping", id)
            return
        case task := <-w.tasks:
            if err := task.Process(); err != nil {
                log.Printf("Worker %d: task failed: %v", id, err)
            }
        }
    }
}

func (w *Worker) Stop() {
    close(w.done)
    w.wg.Wait()
}
```

---

## File Operations

### Safe File Writing

```go
// Write atomically using temp file + rename
func WriteFileAtomic(path string, data []byte, perm os.FileMode) error {
    dir := filepath.Dir(path)

    // Create temp file in same directory (ensures same filesystem for rename)
    tmp, err := os.CreateTemp(dir, ".tmp-*")
    if err != nil {
        return fmt.Errorf("creating temp file in %s: %w", dir, err)
    }
    tmpPath := tmp.Name()

    // Clean up temp file on any error
    success := false
    defer func() {
        if !success {
            os.Remove(tmpPath)
        }
    }()

    // Write data
    if _, err := tmp.Write(data); err != nil {
        tmp.Close()
        return fmt.Errorf("writing to temp file: %w", err)
    }

    // Sync to disk
    if err := tmp.Sync(); err != nil {
        tmp.Close()
        return fmt.Errorf("syncing temp file: %w", err)
    }

    if err := tmp.Close(); err != nil {
        return fmt.Errorf("closing temp file: %w", err)
    }

    // Set permissions before rename
    if err := os.Chmod(tmpPath, perm); err != nil {
        return fmt.Errorf("setting permissions: %w", err)
    }

    // Atomic rename
    if err := os.Rename(tmpPath, path); err != nil {
        return fmt.Errorf("renaming %s to %s: %w", tmpPath, path, err)
    }

    success = true
    return nil
}
```

### File Tailing (like hyperi-agent)

```go
type FileTailer struct {
    path     string
    file     *os.File
    offset   int64
    callback func(line string)
}

func NewFileTailer(path string, startFromEnd bool, callback func(string)) (*FileTailer, error) {
    f, err := os.Open(path)
    if err != nil {
        return nil, fmt.Errorf("opening %s: %w", path, err)
    }

    t := &FileTailer{
        path:     path,
        file:     f,
        callback: callback,
    }

    if startFromEnd {
        offset, err := f.Seek(0, io.SeekEnd)
        if err != nil {
            f.Close()
            return nil, fmt.Errorf("seeking to end of %s: %w", path, err)
        }
        t.offset = offset
    }

    return t, nil
}

func (t *FileTailer) Poll() error {
    // Check if file was rotated
    info, err := t.file.Stat()
    if err != nil {
        return fmt.Errorf("stat %s: %w", t.path, err)
    }

    if info.Size() < t.offset {
        // File was truncated/rotated, start from beginning
        t.offset = 0
        if _, err := t.file.Seek(0, io.SeekStart); err != nil {
            return fmt.Errorf("seeking to start: %w", err)
        }
    }

    reader := bufio.NewReader(t.file)
    for {
        line, err := reader.ReadString('\n')
        if err == io.EOF {
            break
        }
        if err != nil {
            return fmt.Errorf("reading line: %w", err)
        }

        t.offset += int64(len(line))
        t.callback(strings.TrimRight(line, "\n\r"))
    }

    return nil
}
```

---

## Dependency Injection

### Interface-Based DI

```go
// Define interfaces for dependencies
type Logger interface {
    Info(msg string, args ...any)
    Error(msg string, args ...any)
}

type ConfigLoader interface {
    Load(path string) (*Config, error)
}

type EventExporter interface {
    Export(ctx context.Context, events []Event) error
}

// Service with injected dependencies
type Agent struct {
    logger   Logger
    config   ConfigLoader
    exporter EventExporter
}

func NewAgent(logger Logger, config ConfigLoader, exporter EventExporter) *Agent {
    return &Agent{
        logger:   logger,
        config:   config,
        exporter: exporter,
    }
}

// Production implementations
type FileConfigLoader struct{}

func (f *FileConfigLoader) Load(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("reading config: %w", err)
    }
    var cfg Config
    if err := yaml.Unmarshal(data, &cfg); err != nil {
        return nil, fmt.Errorf("parsing config: %w", err)
    }
    return &cfg, nil
}

// Test implementation
type MockConfigLoader struct {
    Config *Config
    Err    error
}

func (m *MockConfigLoader) Load(path string) (*Config, error) {
    return m.Config, m.Err
}
```

---

## Benchmarking

### Writing Benchmarks

```go
func BenchmarkParseEvent(b *testing.B) {
    data := []byte(`{"id":"test-123","timestamp":"2024-01-01T00:00:00Z","source":"test"}`)

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _, err := ParseEvent(data)
        if err != nil {
            b.Fatal(err)
        }
    }
}

func BenchmarkParseEvent_Parallel(b *testing.B) {
    data := []byte(`{"id":"test-123","timestamp":"2024-01-01T00:00:00Z","source":"test"}`)

    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            _, err := ParseEvent(data)
            if err != nil {
                b.Fatal(err)
            }
        }
    })
}

// Run benchmarks
// go test -bench=. -benchmem ./...
// go test -bench=BenchmarkParseEvent -benchtime=5s -count=3 ./...
```

### Memory Profiling

```go
import "runtime/pprof"

func main() {
    // CPU profiling
    f, _ := os.Create("cpu.prof")
    pprof.StartCPUProfile(f)
    defer pprof.StopCPUProfile()

    // Memory profiling
    defer func() {
        f, _ := os.Create("mem.prof")
        pprof.WriteHeapProfile(f)
        f.Close()
    }()

    // Run application...
}

// Analyze with: go tool pprof cpu.prof
```

---

## Build and Release

### Build Tags

```go
//go:build windows
// +build windows

package main

// Windows-specific code here
```

```go
//go:build linux || darwin
// +build linux darwin

package main

// Unix-specific code here
```

### Version Embedding

```go
// main.go
var (
    version   = "dev"
    commit    = "unknown"
    buildTime = "unknown"
)

func main() {
    if len(os.Args) > 1 && os.Args[1] == "version" {
        fmt.Printf("Version: %s\nCommit: %s\nBuilt: %s\n", version, commit, buildTime)
        return
    }
    // ...
}

// Build with:
// go build -ldflags "-X main.version=1.0.0 -X main.commit=$(git rev-parse HEAD) -X main.buildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### Makefile

```makefile
.PHONY: build test lint clean

VERSION ?= $(shell git describe --tags --always --dirty)
COMMIT  ?= $(shell git rev-parse HEAD)
DATE    ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS := -X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.buildTime=$(DATE)

build:
    go build -ldflags "$(LDFLAGS)" -o bin/myapp ./cmd/myapp

test:
    go test -race -cover ./...

lint:
    golangci-lint run

clean:
    rm -rf bin/
```

---

## Common Pitfalls

### Nil Slice vs Empty Slice

```go
// ✅ Good - nil slice is fine for most cases
var items []string  // nil slice
items = append(items, "a")  // Works fine

// JSON difference:
// nil slice  -> null
// empty slice -> []

// If you need [] in JSON:
items := make([]string, 0)  // or []string{}
```

### Goroutine Leaks

```go
// ❌ Bad - goroutine leaks if nobody reads from ch
func process() chan Result {
    ch := make(chan Result)
    go func() {
        ch <- heavyComputation()  // Blocked forever if nobody reads
    }()
    return ch
}

// ✅ Good - use buffered channel or context
func process(ctx context.Context) chan Result {
    ch := make(chan Result, 1)  // Buffered - won't block
    go func() {
        select {
        case ch <- heavyComputation():
        case <-ctx.Done():
        }
    }()
    return ch
}
```

### Loop Variable Capture

```go
// ❌ Bad (pre Go 1.22) - all goroutines see same value
for _, item := range items {
    go func() {
        process(item)  // All goroutines process last item!
    }()
}

// ✅ Good - pass as parameter
for _, item := range items {
    go func(item Item) {
        process(item)
    }(item)
}

// Note: Go 1.22+ fixes this, but explicit parameter is still clearer
```

### defer in Loops

```go
// ❌ Bad - defers accumulate, files not closed until function returns
for _, path := range paths {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close()  // Won't close until loop finishes!
    process(f)
}

// ✅ Good - use closure or explicit close
for _, path := range paths {
    if err := processFile(path); err != nil {
        return err
    }
}

func processFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close()
    return process(f)
}
```

---

## AI Test Generation Traps

> **Derek's hard lessons learned from trusting AI-generated test suites.**
> The tests looked great. CI was green. Production broke anyway.

### Traps to Watch For

| Trap | What AI does | What you need |
|------|-------------|---------------|
| **Happy-path only** | Table tests with all-valid inputs | Table tests MUST include error cases, zero values, nil |
| **Mirror tests** | Assertions that duplicate implementation logic | Assertions that check observable behaviour |
| **Missing error rows** | `wantErr: false` on every table row | At least half your table rows should have `wantErr: true` |
| **No nil/zero tests** | Tests with populated structs only | Tests with nil pointers, zero-value structs, empty slices |
| **Missing goroutine tests** | Sequential-only tests for concurrent code | Tests with `t.Parallel()`, data races caught by `-race` |
| **No startup smoke test** | Tests for individual functions, nothing for app boot | `TestAppStartsWithDefaults` in `tests/smoke_test.go` |
| **Shallow testify usage** | Only `assert.Equal` | Use `require.NoError` for setup, `assert` for verification |

### Test Quality Checklist (Apply After AI Generation)

- [ ] Every error return path has at least one test that triggers it
- [ ] Table-driven tests include error cases (not just success cases)
- [ ] nil, zero-value, and empty inputs are tested
- [ ] Concurrent code tested with `-race` flag and `t.Parallel()`
- [ ] The test actually fails when you break the implementation
- [ ] Test names follow `TestFunction_Scenario` convention
- [ ] `require` used for setup assertions, `assert` for test assertions
- [ ] Startup smoke test exists

**Treat AI-generated tests as drafts.** Add the error rows, nil cases, and race condition tests yourself.

---

## Resources

- Effective Go: <https://go.dev/doc/effective_go>
- Go Code Review Comments: <https://go.dev/wiki/CodeReviewComments>
- Uber Go Style Guide: <https://github.com/uber-go/guide/blob/master/style.md>
- Google Go Style Guide: <https://google.github.io/styleguide/go/>

---

## For AI Code Assistants

The following sections are specific guidance for AI code assistants working with Go.

---

## AI Pitfalls to Avoid

**Before generating Go code, check these patterns:**

### DO NOT Generate

```go
// ❌ Ignoring errors
result, _ := doSomething()  // NEVER ignore errors
// ✅ Always handle errors
result, err := doSomething()
if err != nil {
    return fmt.Errorf("doSomething failed: %w", err)
}

// ❌ Naked goroutines without sync
go func() {
    process(data)  // No way to know when done or if error
}()
// ✅ Use errgroup or WaitGroup
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error {
    return process(ctx, data)
})
if err := g.Wait(); err != nil {
    return err
}

// ❌ Missing context propagation
func fetchData() (Data, error) {  // No context
// ✅ Context as first parameter
func fetchData(ctx context.Context) (Data, error) {

// ❌ Panic for errors
if err != nil {
    panic(err)  // NEVER in library code
}
// ✅ Return error
if err != nil {
    return nil, fmt.Errorf("operation failed: %w", err)
}

// ❌ Using deprecated ioutil
import "io/ioutil"  // Deprecated since Go 1.16
data, _ := ioutil.ReadFile(path)
// ✅ Use io and os
import "os"
data, err := os.ReadFile(path)

// ❌ Race condition with map
var cache map[string]Value  // Concurrent access unsafe
// ✅ Use sync.Map or mutex
var cache sync.Map
cache.Store(key, value)
```

### Context Rules

```go
// ❌ Creating background context mid-function
ctx := context.Background()  // Loses parent cancellation
// ✅ Accept context from caller
func Process(ctx context.Context, ...) error {

// ❌ Context.TODO in production code
ctx := context.TODO()  // Only for refactoring
// ✅ Proper context from caller or Background at entry point

// ❌ Storing context in struct
type Service struct {
    ctx context.Context  // WRONG - context should flow
}
// ✅ Pass context to methods
func (s *Service) Process(ctx context.Context) error {
```

### Error Wrapping

```go
// ❌ Losing error context
if err != nil {
    return err  // Where did it fail?
}
// ✅ Wrap with context
if err != nil {
    return fmt.Errorf("loading config from %s: %w", path, err)
}

// ❌ String formatting errors
return fmt.Errorf("failed: %s", err)  // Loses error chain
// ✅ Use %w for wrapping
return fmt.Errorf("failed: %w", err)  // Preserves chain
```

### Concurrency Pitfalls

```go
// ❌ Closing channel from receiver
go func() {
    for v := range ch {
        process(v)
    }
    close(ch)  // WRONG - sender should close
}()
// ✅ Sender closes channel
go func() {
    defer close(ch)
    for _, v := range items {
        ch <- v
    }
}()

// ❌ Loop variable capture (pre-Go 1.22)
for _, item := range items {
    go func() {
        process(item)  // Captures last value only
    }()
}
// ✅ Pass as parameter or use Go 1.22+
for _, item := range items {
    go func(item Item) {
        process(item)
    }(item)
}
```
