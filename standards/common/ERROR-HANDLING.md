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
from hs_lib import logger
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
- Use sanitization filters (hs_lib.logger)
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

**Use hs_lib.logger (automatic masking):**

```python
from hs_lib import logger

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
from hs_lib.metrics import create_metrics

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
