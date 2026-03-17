---
source: common/ERROR-HANDLING.md
---

<!-- override: manual -->
# Error Handling Standards

## Security-First Error Handling

- **NEVER** display stack traces to end users
- **NEVER** expose database schemas, file paths, or system info in error messages
- **NEVER** show raw exception messages to users
- **ALWAYS** log full errors server-side with context
- **ALWAYS** show generic messages to users
- **ALWAYS** include request/correlation IDs in logs

❌ `return {"error": str(e)}  # Exposes "Table 'users' doesn't exist in database 'prod_db'"`
✅ `logger.error("DB query failed", user_id=user_id, error=str(e), exc_info=True); return {"error": "Unable to retrieve user"}`

## Error Log Context

- Required: user/session ID, operation name, timestamp (RFC3339+tz), request/transaction ID, full stack trace
- Optional: hashed client IP, user agent, sanitized input params, system state
- **NEVER** log passwords, tokens, API keys, card numbers, CVVs, SSNs, private keys, JWTs, PII

❌ `logger.info(f"User login: username={username}, password={password}")`
✅ `logger.info(f"User login attempt: username={username}")`

- Mask sensitive data when partial logging is needed: `f"****-****-****-{card_number[-4:]}"`
- Use `hyperi_pylib.logger` for automatic masking of passwords, API keys, bearer tokens, DB URLs, AWS keys, card numbers

## Exception Handling

- Catch specific exceptions first, generic last — order from most specific to broadest
- **NEVER** swallow exceptions silently

❌ `except Exception: pass`
✅ `except Exception as e: logger.exception("Critical operation failed"); raise`

- Create domain-specific exception hierarchies (e.g., `PaymentError` → `InsufficientFundsError`, `PaymentGatewayError`)
- Use appropriate severity levels: `warning` for user errors, `error` for service failures, `critical` for unexpected errors

## Error Response Format

- Use a consistent JSON error envelope for HTTP APIs:
```json
{"error": {"message": "User-facing message", "code": "ERROR_CODE", "request_id": "req_abc123"}}
```
- Use consistent error code constants: `INVALID_REQUEST`, `UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`, `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE`, `GATEWAY_TIMEOUT`
- Global exception handlers must log full details and return generic responses

## Monitoring and Alerting

- Track error rates with labeled counters (success/error)
- Alert thresholds: >1% warning, >5% critical, >50% change anomaly detection

## Language-Specific Rules

### Go
- Errors are values — always check returned `error` before using results
- Define sentinel errors with `errors.New()` for known failure modes
- Use wrapped errors with `fmt.Errorf("context: %w", err)` to preserve error chains
- Callers check with `errors.Is()` / `errors.As()`
- Use structured logging (`slog`) with typed fields for server-side error details
- Return generic user-facing error structs, never raw `err.Error()`

### TypeScript
- Define custom error classes extending a base `AppError` with `code` and `statusCode`
- Express/middleware error handlers: log full stack server-side, return `AppError` fields or generic 500
- Use `instanceof` checks to map internal errors to appropriate HTTP status codes
- Never expose raw `error.message` or `error.stack` in responses

### Rust
- Use `Result<T, E>` for all recoverable errors; use `thiserror` for custom error enums
- Implement `From<InternalError>` for `ApiError` to map internal details to generic user messages
- Use `tracing::error!` with structured fields for server-side logging
- Use `?` operator with proper error conversion via `map_err`
- Never serialize internal error sources into API responses

### Bash
- Always set `set -euo pipefail` at script start
- Define named exit code constants (`E_INVALID_INPUT=1`, `E_FILE_NOT_FOUND=2`, etc.)
- Use `trap 'error_handler ${LINENO}' ERR` for global error handling with cleanup
- Create a `die()` function that logs full details internally and shows generic message to stderr
- Validate inputs before use; check file existence and permissions explicitly
