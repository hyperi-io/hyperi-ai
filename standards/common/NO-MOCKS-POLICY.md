# No Mocks or Mock Code Policy

**Critical policy for AI code assistants and human developers**

---

## The Problem

AI code assistants routinely mistake placeholder/mock code as production-ready, causing: half-implemented features, missing error handling, incomplete logic with TODOs, example code treated as real, security vulnerabilities from simplified POC code.

### Real-World Impact

**Production incidents:** Auth bypass (always `true`), payment processing never charging, validation accepting any input, API endpoints returning hardcoded data, unimplemented DB queries.

**Cost:** Outages, breaches, lost revenue, trust damage, technical debt

---

## Policy: No Mocks, No Placeholders

**Production code MUST be complete and functional**

### Never Commit

❌ **NEVER** commit mock implementations
❌ **NEVER** use placeholder values in production code
❌ **NEVER** leave TODO comments in production code
❌ **NEVER** commit example/demonstration code as real features
❌ **NEVER** use simplified "proof of concept" code in production

### Always Implement

✅ **ALWAYS** implement complete functionality before committing
✅ **ALWAYS** handle all error cases and edge conditions
✅ **ALWAYS** validate inputs and outputs
✅ **ALWAYS** use real data structures, not simplified examples
✅ **ALWAYS** add tests that verify complete behavior

---

## Examples of Forbidden Mock Code

### Example 1: Mock Data

**❌ Bad (mock data):**
```javascript
function getUser(userId) {
    // TODO: Implement database lookup
    return {
        id: "123",
        name: "John Doe",
        email: "john@example.com"
    };
}
```

**Why bad:** Always returns same user (ignores userId), no database, no error handling, hardcoded test data

**✅ Good (real implementation):**
```javascript
async function getUser(userId) {
    // Validate input
    if (!userId) {
        throw new Error("userId is required");
    }

    // Query database
    const user = await db.query(
        "SELECT id, name, email FROM users WHERE id = $1",
        [userId]
    );

    // Handle not found
    if (!user) {
        throw new UserNotFoundError(`User ${userId} not found`);
    }

    // Return structured data
    return {
        id: user.id,
        name: user.name,
        email: user.email
    };
}
```

### Example 2: Placeholder Logic

**❌ Bad (placeholder logic):**
```go
func ProcessPayment(amount float64, card string) bool {
    // TODO: Integrate with payment gateway
    fmt.Printf("Processing $%.2f on card %s\n", amount, card)
    return true // Always succeeds for now
}
```

**Why it's bad:**
- Prints instead of processing payment
- Always returns true (no actual payment processing)
- No error handling
- No validation
- TODO comment in production code

**✅ Good (real implementation):**
```go
func ProcessPayment(amount float64, card string) (*PaymentResult, error) {
    // Validate amount
    if amount <= 0 {
        return nil, errors.New("amount must be positive")
    }

    // Validate card format
    if !validateCardFormat(card) {
        return nil, &InvalidCardError{Card: card}
    }

    // Process payment via Stripe
    charge, err := stripe.CreateCharge(&stripe.ChargeParams{
        Amount:   int64(amount * 100), // Convert to cents
        Currency: "usd",
        Source:   card,
    })

    if err != nil {
        // Handle card declined
        if stripeErr, ok := err.(*stripe.Error); ok {
            log.Printf("Card declined: %s", stripeErr.Message)
            return &PaymentResult{
                Success: false,
                Error:   stripeErr.Message,
            }, nil
        }
        // Handle other errors
        return nil, fmt.Errorf("payment processing failed: %w", err)
    }

    // Return success result
    return &PaymentResult{
        Success:       true,
        TransactionID: charge.ID,
        Amount:        amount,
        Timestamp:     time.Now(),
    }, nil
}
```

### Example 3: Example Code as Production

**❌ Bad (example code):**
```python
def analyze_data(data: list) -> dict:
    """Analyze data and return insights."""
    # Simple example - works for demo
    return {
        "count": len(data),
        "first": data[0] if data else None
    }
```

**Why it's bad:**
- Labeled as "simple example" (not production code)
- Minimal analysis (just count and first element)
- No real insights generated
- Comment admits it's for demo only

**✅ Good (complete analysis):**
```python
def analyze_data(data: list[dict]) -> DataAnalysis:
    """
    Analyze data and return comprehensive insights.

    Args:
        data: List of data points with 'value' field

    Returns:
        DataAnalysis with statistics and outliers

    Raises:
        ValueError: If data format is invalid
    """
    # Handle empty data
    if not data:
        return DataAnalysis(
            count=0,
            mean=None,
            median=None,
            std_dev=None,
            outliers=[]
        )

    # Validate data structure
    for i, item in enumerate(data):
        if not isinstance(item, dict) or "value" not in item:
            raise ValueError(f"Invalid data format at index {i}")

    # Extract values
    values = [item["value"] for item in data]

    # Calculate statistics
    mean_val = statistics.mean(values)
    median_val = statistics.median(values)
    std_dev = statistics.stdev(values) if len(values) > 1 else 0

    # Detect outliers (values > 2 std devs from mean)
    outliers = [
        item for item in data
        if abs(item["value"] - mean_val) > 2 * std_dev
    ]

    return DataAnalysis(
        count=len(data),
        mean=mean_val,
        median=median_val,
        std_dev=std_dev,
        outliers=outliers
    )
```

### Example 4: Simplified Validation

**❌ Bad (no validation):**
```python
def create_user(email, password):
    """Create user account."""
    # TODO: Add validation
    user_id = db.insert_user(email, password)
    return user_id
```

**Why it's bad:**
- No email validation
- No password strength check
- Stores plain text password (security vulnerability!)
- TODO comment admits missing validation

**✅ Good (complete validation):**
```python
def create_user(email: str, password: str) -> int:
    """
    Create user account with validation.

    Args:
        email: User email address
        password: Plain text password (will be hashed)

    Returns:
        New user ID

    Raises:
        ValueError: If email/password invalid
        DuplicateEmailError: If email already exists
    """
    # Validate email format
    if not validate_email_format(email):
        raise ValueError(f"Invalid email format: {email}")

    # Check email not already registered
    if db.email_exists(email):
        raise DuplicateEmailError(f"Email already registered: {email}")

    # Validate password strength
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters")
    if not has_uppercase(password):
        raise ValueError("Password must contain uppercase letter")
    if not has_number(password):
        raise ValueError("Password must contain number")

    # Hash password (NEVER store plain text!)
    password_hash = bcrypt.hashpw(
        password.encode('utf-8'),
        bcrypt.gensalt()
    )

    # Insert user
    try:
        user_id = db.insert_user(
            email=email.lower(),  # Normalize email
            password_hash=password_hash
        )
        logger.info(f"Created user: {user_id}")
        return user_id
    except DatabaseError as e:
        logger.error(f"Failed to create user: {e}")
        raise
```

---

## When Mocks ARE Allowed

### Test Code Only

**Mock code is ONLY acceptable in:**
- `tests/` directory (unit tests, integration tests)
- `examples/` directory (explicitly marked as examples)
- Documentation code blocks (clearly marked as examples)

**Example (acceptable mock in tests):**
```python
# tests/unit/test_payment.py
from unittest.mock import Mock, patch

def test_process_payment_success():
    """Test payment processing with mocked Stripe."""
    with patch('stripe.Charge.create') as mock_charge:
        mock_charge.return_value = Mock(id="ch_123")

        result = process_payment(100.0, "tok_visa")

        assert result.success is True
        assert result.transaction_id == "ch_123"
```

**Why this is OK:**
- File is in `tests/` directory (clearly test code)
- Mocking external service (Stripe) we don't control
- Testing our logic, not Stripe's
- Production code is still complete

---

## Code Review Checklist

**Before committing, verify:**

- [ ] No TODO comments in src/ directories
- [ ] No FIXME, HACK, XXX comments in src/
- [ ] No placeholder return values (e.g., `return true`, `return {}`, `return None`)
- [ ] No hardcoded example data
- [ ] All error cases handled (not just happy path)
- [ ] Input validation complete
- [ ] Output validation complete
- [ ] Edge cases tested (empty data, null values, max values)
- [ ] Security considerations addressed
- [ ] Performance considerations addressed
- [ ] Logging/monitoring added
- [ ] Documentation complete

---

## AI Assistant Warning Signs

### Red Flags in AI-Generated Code

**Watch for these patterns:**

🚨 **Phrases indicating incomplete code:**
- "Here's a simple example..."
- "This is a basic implementation..."
- "For demonstration purposes..."
- "This should work for most cases..."
- "Quick and dirty solution..."

🚨 **TODO comments:**
- "TODO: Add error handling"
- "TODO: Implement X"
- "TODO: Connect to database"
- "FIXME: This is temporary"

🚨 **Code patterns:**
- Hardcoded example data
- Always-successful operations (`return true`)
- Missing input validation
- Generic exception handling (`catch (Exception) {}` or `except Exception: pass`)
- Placeholder comments instead of implementation
- Functions that always return the same value

**When you see these, REJECT the code and request complete implementation.**

### How to Respond

**Don't accept:**
```
AI: "Here's a simple example of user authentication..."
You: [Accept and commit]  ❌
```

**Do this instead:**
```
AI: "Here's a simple example of user authentication..."
You: "This is a simplified example. Please provide complete implementation with:
     - Password hashing (bcrypt)
     - Input validation
     - Error handling (invalid credentials, account locked, etc.)
     - Rate limiting (prevent brute force)
     - Session management
     - Comprehensive tests"
```

---

## Enforcement

### Pre-commit Checks

**Automated checks (enforced by git hooks):**
- Grep for TODO comments in src/ directories (fails commit)
- Grep for "TODO:", "FIXME:", "HACK:", "XXX:" in src/ (fails commit)
- Security scanners catch some placeholder patterns (bandit for Python)
- Code review requires human verification

**Example pre-commit hook:**
```bash
#!/bin/bash
# Check for TODO comments in src/
if git diff --cached --name-only | grep "^src/" | xargs grep -n "TODO:\|FIXME:\|HACK:\|XXX:"; then
    echo "ERROR: TODO/FIXME/HACK/XXX comments found in src/"
    echo "Remove placeholder comments before committing"
    exit 1
fi
```

### CI Enforcement

**Continuous integration checks:**
- Full test coverage required (80%+ line coverage)
- Integration tests must verify real behavior (not mocked)
- Static analysis scans for security issues
- Manual code review required before merge
- Extra scrutiny for AI-generated code

### Code Review Process

**Reviewers must verify:**
1. No placeholder code
2. All error paths handled
3. Edge cases tested
4. Security considerations addressed
5. Performance implications understood

---

## Migration Path

### If You Find Mock Code in Production

**DO NOT panic commit partial fixes!**

Follow this process:

1. **Identify:** Find all instances in src/ directories
   ```bash
   # Find TODO comments
   grep -r "TODO:" src/

   # Find hardcoded test data
   grep -r "John Doe\|test@example.com\|123-45-6789" src/

   # Find always-true returns
   grep -r "return true\|return True" src/
   ```

2. **Document:** Create GitHub issues for each incomplete feature
   - Tag as "technical-debt"
   - Assign severity (critical/high/medium/low)
   - Link to code location

3. **Prioritize:** Triage based on criticality
   - **Critical:** Security, payments, auth (fix immediately)
   - **High:** User-facing features (fix this sprint)
   - **Medium:** Internal tools (fix next sprint)
   - **Low:** Examples, dev tools (backlog)

4. **Implement:** Replace mocks with complete implementations
   - One feature at a time
   - Complete implementation (not another placeholder!)
   - Add comprehensive tests

5. **Test:** Verify complete behavior
   - Unit tests (90%+ coverage)
   - Integration tests
   - Manual testing
   - Security review

6. **Remove:** Delete mock code only after real code is tested
   - Don't remove until replacement is deployed
   - Keep examples in `examples/` directory if needed

**Do NOT commit partial fixes - complete the feature or revert.**

---

## Examples: Complete vs Incomplete

### Authentication

**❌ Incomplete:**
```python
def login(username, password):
    # TODO: Check database
    return True  # Always succeeds
```

**✅ Complete:**
```python
def login(username: str, password: str) -> LoginResult:
    """Authenticate user credentials."""
    # Validate inputs
    if not username or not password:
        return LoginResult(success=False, error="Credentials required")

    # Rate limiting (prevent brute force)
    if is_rate_limited(username):
        logger.warning(f"Rate limit exceeded: {username}")
        return LoginResult(success=False, error="Too many attempts")

    # Fetch user
    user = db.get_user_by_username(username)
    if not user:
        # Generic error (don't reveal if user exists)
        return LoginResult(success=False, error="Invalid credentials")

    # Check if account locked
    if user.is_locked:
        return LoginResult(success=False, error="Account locked")

    # Verify password
    if not bcrypt.checkpw(password.encode(), user.password_hash):
        # Log failed attempt
        db.record_failed_login(user.id)
        return LoginResult(success=False, error="Invalid credentials")

    # Create session
    session = create_session(user.id)

    return LoginResult(
        success=True,
        session_token=session.token,
        user_id=user.id
    )
```

### Data Validation

**❌ Incomplete:**
```python
def save_user(data):
    # TODO: Validate
    db.save(data)
```

**✅ Complete:**
```python
def save_user(data: dict) -> int:
    """Save user with validation."""
    # Required fields
    required = ["email", "name", "age"]
    for field in required:
        if field not in data:
            raise ValueError(f"Missing required field: {field}")

    # Email validation
    if not validate_email(data["email"]):
        raise ValueError(f"Invalid email: {data['email']}")

    # Age validation
    age = data["age"]
    if not isinstance(age, int) or age < 18 or age > 120:
        raise ValueError(f"Invalid age: {age}")

    # Sanitize inputs
    clean_data = {
        "email": data["email"].lower().strip(),
        "name": sanitize_string(data["name"]),
        "age": age
    }

    # Save to database
    user_id = db.save_user(clean_data)
    return user_id
```

---

**See also:**
- `CODING-STANDARDS.md` - Core coding standards
- `AI-GUIDELINES.md` - AI code assistant best practices
- `ERROR-HANDLING.md` - Comprehensive error handling
