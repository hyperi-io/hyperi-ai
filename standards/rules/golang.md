---
paths:
  - "**/*.go"
detect_markers:
  - "file:go.mod"
  - "deep_file:go.mod"
source: languages/GOLANG.md
---

<!-- override: manual -->
## Commands

- `go build ./...` / `go test ./...` / `go test -race ./...`
- `golangci-lint run` / `go mod tidy` / `govulncheck ./...`

## Project Structure

- Use `cmd/myapp/main.go` + `internal/` + `pkg/` for larger projects
- Simple projects: flat structure with `main.go` at root is fine

## Error Handling

- Always wrap errors with context using `%w`: `return fmt.Errorf("loading config %s: %w", path, err)`
- Never use `%s` for error wrapping — it breaks `errors.Is`/`errors.As` chain
- Handle errors immediately with early returns; avoid nesting
- Provide specific, actionable validation messages including index/value context
- Never `panic` in library code — always return errors
- Never ignore errors with `_` unless explicitly justified
- Custom error types: implement `Error() string` and `Unwrap() error`

## Testing

- Use table-driven tests with `t.Run(tt.name, ...)`
- Use `github.com/stretchr/testify/require` for fatal checks, `assert` for non-fatal
- Name tests: `TestFunction_Scenario` or `TestFunction_Scenario_SubScenario`
- Use `t.Helper()` in helper functions, `t.TempDir()` for temp files
- Run benchmarks: `go test -bench=. -benchmem ./...`

## Naming

- `camelCase` unexported, `PascalCase` exported
- Acronyms uppercase: `userID`, `HTTPClient`, `httpClient`
- Constants: `PascalCase` (e.g., `DefaultConfigName`, `MaxRetries`)
- Files: `snake_case.go`, `snake_case_test.go`
- Receivers: short, consistent (e.g., `c` for `*Config`), never `this`/`self`

## Context

- Always accept `context.Context` as first parameter for any I/O or long operation
- Never store `context.Context` in structs — pass per-call
- Never use `context.Background()` mid-function (loses parent cancellation)
- `context.TODO()` only during refactoring, never in production
- Use typed keys for context values: `type contextKey string`
- Always `defer cancel()` after `context.WithTimeout`/`WithCancel`

## Concurrency

- Use `errgroup.WithContext` for concurrent work with error handling; `g.SetLimit(n)` for bounded concurrency
- Use `sync.WaitGroup` when errors aren't needed
- Use `sync.RWMutex` — `RLock` for reads, `Lock` for writes
- Copy data under lock then release before slow operations
- Use `sync.Once` for lazy initialization
- Use buffered channels or context to prevent goroutine leaks
- Sender closes channels, never receiver
- Pass loop variables as goroutine parameters (even post Go 1.22 for clarity)
- Always test with `-race` flag

## Defer Pitfalls

- Never `defer` in loops — extract to a function so `defer` runs per iteration

## Nil Slice vs Empty Slice

- Nil slice marshals to JSON `null`; use `make([]T, 0)` if `[]` needed

## Logging

- Use `log/slog` (Go 1.21+) with structured key-value pairs
- Use RFC 3339 timestamps (`time.RFC3339Nano`)
- JSON handler for containers, text handler for terminals
- Never log secrets; truncate sensitive values (e.g., `key[:3]+"..."`)

## Configuration

- YAML/JSON struct tags: `yaml:"fieldName"` / `json:"fieldName,omitempty"`
- Set defaults programmatically, validate with clear error messages
- Viper + Cobra for layered config cascade if needed

## HTTP

- Always set `Timeout` on `http.Client` (e.g., 30s)
- Use `http.NewRequestWithContext` — never request without context
- Always `defer resp.Body.Close()`
- Check status codes explicitly; read limited error body on failure
- Retry with exponential backoff; cap delay; don't retry 4xx

## JSON/XML

- Use struct tags; validate required fields after unmarshalling
- Use `json.NewDecoder` for streaming large inputs
- Use `encoding/xml` with attribute tags for XML (e.g., Windows Event Log)

## Interfaces

- Keep interfaces small and focused (1-3 methods)
- Define interfaces where consumed, not where implemented
- Use interface-based dependency injection; mock interfaces in tests

## File Operations

- Use atomic writes (temp file + `Sync` + `Rename`) for critical files
- File permissions: `0644` files, `0755` directories
- Handle file rotation (size < offset → reset to beginning)

## Security

- Use `exec.Command("cmd", "arg1", "arg2")` — never `sh -c` with interpolation
- Validate and bound all inputs (empty, length)
- Run `govulncheck ./...` in CI

## Build

- Use build tags: `//go:build windows`
- Embed version via `-ldflags "-X main.version=..."`
- Use `-race` and `-cover` in test targets

## Deprecated APIs — Never Use

- ❌ `io/ioutil` → ✅ `os.ReadFile`, `io.ReadAll`

## Graceful Shutdown

- Catch `SIGINT`/`SIGTERM`, call `server.Shutdown(ctx)` with timeout
- Worker pattern: close `done` channel, `wg.Wait()`

## Linting Config

- Enable: `errcheck`, `gosimple`, `govet`, `ineffassign`, `staticcheck`, `unused`, `gofmt`, `goimports`
- Enable `check-type-assertions` for errcheck, `check-shadowing` for govet
- Exclude `errcheck` in `_test.go` files

## Functional Options Pattern

- Use `type Option func(*Config)` with `WithX` constructors for flexible APIs
