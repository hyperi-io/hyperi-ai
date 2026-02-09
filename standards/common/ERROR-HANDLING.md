# Error Handling Standards

**Comprehensive guide for security-first error handling**

---

## Security-First Error Handling

### The Security Risk

**NEVER expose implementation details to users**

Exposing errors creates vulnerabilities: reveals database schemas, file paths, software versions, internal logic.

### Rules

❌ **NEVER** display stack traces to end users
❌ **NEVER** expose database schemas in error messages
❌ **NEVER** reveal file paths or system information
❌ **NEVER** show raw exception messages to users

✅ **ALWAYS** log full errors server-side
✅ **ALWAYS** show generic messages to users
✅ **ALWAYS** include request context in logs

### Examples

**❌ Bad (security risk):**

```python
try:
    user = db.query("SELECT * FROM users WHERE id = ?", user_id)
except Exception as e:
    # DANGER: Exposes database details to user
    return {"error": str(e)}
    # User sees: "Table 'users' doesn't exist in database 'prod_db'"
```

**✅ Good (secure):**

```python
try:
    user = db.query("SELECT * FROM users WHERE id = ?", user_id)
except DatabaseError as e:
    # Log full details server-side
    logger.error(
        "Database query failed",
        user_id=user_id,
        error=str(e),
        exc_info=True  # Full stack trace in logs
    )
    # Generic message to user
    return {"error": "Unable to retrieve user"}
    # User sees: "Unable to retrieve user"
```

**❌ Bad (exposes file paths):**

```python
try:
    config = load_config("/etc/myapp/config.yaml")
except FileNotFoundError as e:
    return {"error": str(e)}
    # User sees: "File '/etc/myapp/config.yaml' not found"
```

**✅ Good (generic message):**

```python
try:
    config = load_config("/etc/myapp/config.yaml")
except FileNotFoundError as e:
    logger.error(f"Config file not found: {e}")
    return {"error": "Configuration error"}
    # User sees: "Configuration error"
```

---

## Comprehensive Error Logging

### Required Context

**ALWAYS log errors with context:**

```python
logger.error(
    "Operation failed",
    user_id=user_id,           # Who
    operation="update_profile", # What
    timestamp=datetime.now(),   # When
    request_id=request_id,      # Request tracking
    exc_info=True               # Full stack trace
)
```

### Context Checklist

**Required fields:**

- [ ] User/session identifier (NOT passwords!)
- [ ] Operation being performed
- [ ] Timestamp (RFC3339 with timezone format)
- [ ] Request/transaction ID for tracing
- [ ] Full stack trace (exc_info=True)

**Optional but recommended:**

- [ ] Client IP address (hashed for privacy)
- [ ] User agent / client version
- [ ] Input parameters (sanitized!)
- [ ] System state (memory, CPU, disk)

### Example: Complete Error Logging

```python
from hyperi_pylib import logger
import traceback

def process_payment(user_id, amount, card_token, request_id):
    try:
        # Process payment
        charge = stripe.Charge.create(
            amount=int(amount * 100),
            currency="usd",
            source=card_token,
        )
        return {"success": True, "charge_id": charge.id}

    except stripe.error.CardError as e:
        # User error (declined card)
        logger.warning(
            "Card declined",
            user_id=user_id,
            amount=amount,
            request_id=request_id,
            decline_code=e.code,
            decline_message=e.user_message,
        )
        return {"success": False, "error": "Card declined"}

    except stripe.error.RateLimitError as e:
        # Stripe rate limit
        logger.error(
            "Stripe rate limit exceeded",
            user_id=user_id,
            amount=amount,
            request_id=request_id,
            exc_info=True,
        )
        return {"success": False, "error": "Service temporarily unavailable"}

    except stripe.error.StripeError as e:
        # Other Stripe errors
        logger.error(
            "Stripe API error",
            user_id=user_id,
            amount=amount,
            request_id=request_id,
            error_type=type(e).__name__,
            error_message=str(e),
            exc_info=True,
        )
        return {"success": False, "error": "Payment processing failed"}

    except Exception as e:
        # Unexpected error (critical!)
        logger.critical(
            "Unexpected payment error",
            user_id=user_id,
            amount=amount,
            request_id=request_id,
            error_type=type(e).__name__,
            error_message=str(e),
            stack_trace=traceback.format_exc(),
            exc_info=True,
        )
        return {"success": False, "error": "An error occurred"}
```

---

## Exception Handling Best Practices

### Use Specific Exception Types

**Catch specific exceptions first, generic last:**

```python
# Bad - catches everything
try:
    process_payment(amount)
except Exception:
    logger.error("Payment failed")

# Good - handle specific cases
try:
    process_payment(amount)
except InsufficientFundsError as e:
    logger.warning(f"Insufficient funds: {e}")
    return {"error": "Insufficient funds"}
except PaymentGatewayError as e:
    logger.error(f"Gateway error: {e}", exc_info=True)
    return {"error": "Payment processing unavailable"}
except Exception as e:
    logger.critical(f"Unexpected error: {e}", exc_info=True)
    return {"error": "An error occurred"}
```

### Exception Hierarchy

**Order matters:**

```python
# Correct order (specific to generic)
try:
    operation()
except FileNotFoundError:      # Most specific
    pass
except IOError:                 # More general
    pass
except OSError:                 # Even more general
    pass
except Exception:               # Catch-all (last resort)
    pass
```

### Never Swallow Exceptions

**❌ Bad (silent failure):**

```python
try:
    critical_operation()
except Exception:
    pass  # DANGER: Silently swallows errors!
```

**✅ Good (log and handle):**

```python
try:
    critical_operation()
except Exception as e:
    logger.exception("Critical operation failed")
    raise  # Re-raise if you can't handle it
```

### Custom Exception Classes

**Create domain-specific exceptions:**

```python
class PaymentError(Exception):
    """Base class for payment errors"""
    pass

class InsufficientFundsError(PaymentError):
    """User has insufficient funds"""
    pass

class PaymentGatewayError(PaymentError):
    """Payment gateway unavailable"""
    pass

class InvalidCardError(PaymentError):
    """Invalid card details"""
    pass

# Usage
try:
    process_payment(amount, card)
except InvalidCardError as e:
    return {"error": "Invalid card details"}
except InsufficientFundsError as e:
    return {"error": "Insufficient funds"}
except PaymentGatewayError as e:
    logger.error(f"Gateway error: {e}", exc_info=True)
    return {"error": "Service unavailable"}
```

---

## Sensitive Data in Logs

### Never Log Sensitive Data

**❌ NEVER log:**

- Passwords, tokens, API keys
- Credit card numbers, CVV codes
- Social Security Numbers, passport numbers
- Private keys, certificates
- Session tokens, JWTs
- PII (personally identifiable information)

**✅ ALWAYS:**

- Log hashed/masked versions if needed
- Use sanitization filters (hyperi_pylib.logger)
- Audit logs for accidental leaks

### Examples

**❌ Bad (leaks credentials):**

```python
logger.info(f"User login: username={username}, password={password}")
# DANGER: Password in logs!
```

**✅ Good (safe logging):**

```python
logger.info(f"User login attempt: username={username}")
# Password not logged
```

**❌ Bad (leaks credit card):**

```python
logger.info(f"Payment: card={card_number}, cvv={cvv}")
# DANGER: PCI-DSS violation!
```

**✅ Good (masked data):**

```python
masked_card = f"****-****-****-{card_number[-4:]}"
logger.info(f"Payment: card={masked_card}")
# Only last 4 digits logged
```

### Automatic Sanitization

**Use hyperi_pylib.logger (automatic masking):**

```python
from hyperi_pylib import logger

# Automatically masks passwords, tokens, API keys
logger.info("User login", username="alice", password="secret123")
# Logs: "User login" username="alice" password="***MASKED***"
```

**Supported patterns:**

- Passwords (password=, pwd=, pass=)
- API keys (api_key=, apikey=, token=)
- Bearer tokens (Authorization: Bearer ...)
- Database URLs (postgresql://user:password@host)
- AWS keys (AKIA..., aws_secret_access_key=)
- Credit cards (card_number=, cvv=)

---

## Error Response Standards

### HTTP API Errors

**Standard error response format:**

```python
{
    "error": {
        "message": "Generic user-facing message",
        "code": "ERROR_CODE",
        "request_id": "req_abc123"
    }
}
```

**Example implementation:**

```python
from fastapi import HTTPException, Request

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    # Log full error server-side
    logger.exception(
        "Unhandled exception",
        path=request.url.path,
        method=request.method,
        request_id=request.headers.get("X-Request-ID"),
    )

    # Generic response to user
    return JSONResponse(
        status_code=500,
        content={
            "error": {
                "message": "An error occurred",
                "code": "INTERNAL_ERROR",
                "request_id": request.headers.get("X-Request-ID"),
            }
        }
    )
```

### Error Codes

**Use consistent error codes:**

```python
class ErrorCode:
    # Client errors (4xx)
    INVALID_REQUEST = "INVALID_REQUEST"
    UNAUTHORIZED = "UNAUTHORIZED"
    FORBIDDEN = "FORBIDDEN"
    NOT_FOUND = "NOT_FOUND"

    # Server errors (5xx)
    INTERNAL_ERROR = "INTERNAL_ERROR"
    SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
    GATEWAY_TIMEOUT = "GATEWAY_TIMEOUT"

# Usage
raise HTTPException(
    status_code=400,
    detail={
        "message": "Invalid request parameters",
        "code": ErrorCode.INVALID_REQUEST,
    }
)
```

---

## Monitoring and Alerting

### Error Rate Monitoring

**Track error rates:**

```python
from hyperi_pylib.metrics import create_metrics

metrics = create_metrics("myapp")

def process_request():
    try:
        # Process request
        metrics.counter("requests_total", labels={"status": "success"}).inc()
    except Exception as e:
        metrics.counter("requests_total", labels={"status": "error"}).inc()
        logger.exception("Request failed")
        raise
```

### Alert Thresholds

**Set up alerts for:**

- Error rate > 1% (warning)
- Error rate > 5% (critical)
- Specific error types spike
- Error rate change > 50% (anomaly detection)

---

## Multi-Language Error Handling

### Go

**Error handling is explicit in Go - errors are values, not exceptions:**

```go
package payment

import (
    "errors"
    "fmt"
    "log/slog"
)

// Custom error types
var (
    ErrInsufficientFunds = errors.New("insufficient funds")
    ErrInvalidCard       = errors.New("invalid card")
    ErrGatewayUnavailable = errors.New("payment gateway unavailable")
)

type PaymentError struct {
    Code    string
    Message string
    Err     error
}

func (e *PaymentError) Error() string {
    return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func (e *PaymentError) Unwrap() error {
    return e.Err
}

// Secure error handling
func ProcessPayment(userID string, amount float64, cardToken string) (*PaymentResult, error) {
    logger := slog.Default()

    charge, err := stripe.CreateCharge(amount, cardToken)
    if err != nil {
        // Log full details server-side
        logger.Error("Payment failed",
            slog.String("user_id", userID),
            slog.Float64("amount", amount),
            slog.String("error", err.Error()),
        )

        // Return generic error to caller (don't expose internal details)
        if errors.Is(err, stripe.ErrCardDeclined) {
            return nil, &PaymentError{
                Code:    "CARD_DECLINED",
                Message: "Card was declined",
                Err:     ErrInvalidCard,
            }
        }
        if errors.Is(err, stripe.ErrRateLimit) {
            return nil, &PaymentError{
                Code:    "SERVICE_UNAVAILABLE",
                Message: "Service temporarily unavailable",
                Err:     ErrGatewayUnavailable,
            }
        }
        // Generic error for unexpected cases
        return nil, &PaymentError{
            Code:    "PAYMENT_FAILED",
            Message: "Payment could not be processed",
            Err:     err,
        }
    }

    return &PaymentResult{Success: true, TransactionID: charge.ID}, nil
}

// Caller checks errors with errors.Is/errors.As
func HandlePayment(userID string, amount float64, card string) {
    result, err := ProcessPayment(userID, amount, card)
    if err != nil {
        var payErr *PaymentError
        if errors.As(err, &payErr) {
            // Handle known payment errors
            fmt.Printf("Payment error: %s\n", payErr.Message)
        }
        if errors.Is(err, ErrInsufficientFunds) {
            // Specific handling
        }
        return
    }
    fmt.Printf("Success: %s\n", result.TransactionID)
}
```

### TypeScript

**Use Result types or try/catch with custom errors:**

```typescript
// Custom error classes
class AppError extends Error {
  constructor(
    public code: string,
    message: string,
    public statusCode: number = 500
  ) {
    super(message);
    this.name = 'AppError';
  }
}

class ValidationError extends AppError {
  constructor(message: string) {
    super('VALIDATION_ERROR', message, 400);
    this.name = 'ValidationError';
  }
}

class PaymentError extends AppError {
  constructor(message: string, public details?: unknown) {
    super('PAYMENT_ERROR', message, 402);
    this.name = 'PaymentError';
  }
}

// Secure error handling
async function processPayment(
  userId: string,
  amount: number,
  cardToken: string
): Promise<PaymentResult> {
  try {
    const charge = await stripe.charges.create({
      amount: Math.round(amount * 100),
      currency: 'usd',
      source: cardToken,
    });

    return { success: true, transactionId: charge.id };
  } catch (error) {
    // Log full details server-side
    logger.error('Payment failed', {
      userId,
      amount,
      error: error instanceof Error ? error.message : 'Unknown error',
      stack: error instanceof Error ? error.stack : undefined,
    });

    // Return generic error (don't expose Stripe internals)
    if (error instanceof Stripe.errors.StripeCardError) {
      throw new PaymentError('Card was declined');
    }
    if (error instanceof Stripe.errors.StripeRateLimitError) {
      throw new AppError('SERVICE_UNAVAILABLE', 'Service temporarily unavailable', 503);
    }

    throw new AppError('PAYMENT_FAILED', 'Payment could not be processed');
  }
}

// Express error handler middleware
function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  // Log full error server-side
  logger.error('Request failed', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    requestId: req.headers['x-request-id'],
  });

  // Generic response to user
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        requestId: req.headers['x-request-id'],
      },
    });
  } else {
    // Unknown error - don't expose details
    res.status(500).json({
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred',
        requestId: req.headers['x-request-id'],
      },
    });
  }
}
```

### Rust

**Use Result<T, E> for recoverable errors:**

```rust
use thiserror::Error;
use tracing::{error, warn};

// Custom error types
#[derive(Error, Debug)]
pub enum PaymentError {
    #[error("Card was declined")]
    CardDeclined,

    #[error("Insufficient funds")]
    InsufficientFunds,

    #[error("Service temporarily unavailable")]
    ServiceUnavailable,

    #[error("Payment could not be processed")]
    ProcessingFailed(#[source] Box<dyn std::error::Error + Send + Sync>),
}

// API response error (doesn't expose internals)
#[derive(serde::Serialize)]
pub struct ApiError {
    pub code: String,
    pub message: String,
    pub request_id: Option<String>,
}

impl From<PaymentError> for ApiError {
    fn from(err: PaymentError) -> Self {
        match err {
            PaymentError::CardDeclined => ApiError {
                code: "CARD_DECLINED".to_string(),
                message: "Card was declined".to_string(),
                request_id: None,
            },
            PaymentError::InsufficientFunds => ApiError {
                code: "INSUFFICIENT_FUNDS".to_string(),
                message: "Insufficient funds".to_string(),
                request_id: None,
            },
            _ => ApiError {
                code: "PAYMENT_FAILED".to_string(),
                message: "Payment could not be processed".to_string(),
                request_id: None,
            },
        }
    }
}

// Secure error handling
pub async fn process_payment(
    user_id: &str,
    amount: f64,
    card_token: &str,
) -> Result<PaymentResult, PaymentError> {
    match stripe::create_charge(amount, card_token).await {
        Ok(charge) => Ok(PaymentResult {
            success: true,
            transaction_id: charge.id,
        }),
        Err(e) => {
            // Log full details server-side
            error!(
                user_id = %user_id,
                amount = %amount,
                error = %e,
                "Payment failed"
            );

            // Return generic error (don't expose Stripe internals)
            match e {
                StripeError::CardDeclined(_) => Err(PaymentError::CardDeclined),
                StripeError::RateLimit(_) => Err(PaymentError::ServiceUnavailable),
                other => Err(PaymentError::ProcessingFailed(Box::new(other))),
            }
        }
    }
}

// Using ? operator with proper error conversion
pub async fn checkout(order: Order) -> Result<Receipt, ApiError> {
    let payment = process_payment(&order.user_id, order.total, &order.card_token)
        .await
        .map_err(ApiError::from)?;

    Ok(Receipt { transaction_id: payment.transaction_id })
}
```

### Bash

**Exit codes and error messages:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Error codes
readonly E_SUCCESS=0
readonly E_INVALID_INPUT=1
readonly E_FILE_NOT_FOUND=2
readonly E_PERMISSION_DENIED=3
readonly E_NETWORK_ERROR=4
readonly E_UNKNOWN=99

# Error handler
error_handler() {
    local exit_code=$?
    local line_number=$1

    # Log full error details
    log_error "Script failed at line ${line_number} with exit code ${exit_code}"

    # Clean up
    cleanup

    exit "${exit_code}"
}

trap 'error_handler ${LINENO}' ERR

# Secure error function (logs full details, shows generic message)
die() {
    local code="${1}"
    local internal_message="${2}"
    local user_message="${3:-An error occurred}"

    # Log full details server-side
    log_error "${internal_message}"

    # Show generic message to user
    echo "Error: ${user_message}" >&2

    exit "${code}"
}

# Usage example
process_file() {
    local file="${1:-}"

    # Validate input
    if [[ -z "${file}" ]]; then
        die "${E_INVALID_INPUT}" "Empty file argument provided" "Invalid input"
    fi

    # Check file exists
    if [[ ! -f "${file}" ]]; then
        die "${E_FILE_NOT_FOUND}" "File not found: ${file}" "File not found"
    fi

    # Check permissions
    if [[ ! -r "${file}" ]]; then
        die "${E_PERMISSION_DENIED}" "Cannot read file: ${file}" "Permission denied"
    fi

    # Process file
    cat "${file}" || die "${E_UNKNOWN}" "Failed to read ${file}" "Processing failed"
}

# Main with error handling
main() {
    local input="${1:-}"

    if ! process_file "${input}"; then
        log_error "process_file failed for: ${input}"
        exit "${E_UNKNOWN}"
    fi

    log_info "Successfully processed: ${input}"
}

main "$@"
```
