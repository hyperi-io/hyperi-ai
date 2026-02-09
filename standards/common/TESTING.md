# Testing Standards

**Comprehensive testing guide with test-first development patterns**

---

## Quick Reference

**Structure:** `tests/unit/`, `tests/integration/`, `tests/e2e/`
**Coverage:** 80% minimum (enforced by CI)
**Frameworks:** pytest (Python), testing+testify (Go), Jest/Vitest (JS/TS), cargo test (Rust), BATS (Bash)

---

## Test Organisation

### Standard Directory Structure

```text
tests/
├── unit/          # Fast, isolated unit tests
├── integration/   # Component integration tests
└── e2e/           # End-to-end tests
```

### Test Requirements

**All projects MUST have:**

- Unit tests for core business logic
- Integration tests for external dependencies
- Minimum 80% code coverage
- Tests run before every build/release

### Test Naming

- Clear, descriptive test names
- Follow language conventions
- Explain WHAT is being tested

---

## Test-First Development

**Define success criteria through tests BEFORE making changes.**

### When to Use Test-First

**Perfect for:**

- Refactoring existing code
- Bug fixes
- Adding features to existing code

**Not suitable for:**

- New greenfield code (use pure TDD)
- Exploratory prototypes
- One-off scripts

### Test-First Workflow

**1. Understand Current Behaviour**

```python
# Read existing code
def calculate_total(items: list[dict]) -> float:
    """Calculate order total."""
    total = 0
    for item in items:
        total += item["price"] * item["quantity"]
    return total
```

**2. Write Tests for Success Criteria**

```python
def test_calculate_total_existing_behaviour():
    """Test existing subtotal calculation (MUST NOT BREAK)."""
    items = [
        {"price": 10.0, "quantity": 2},
        {"price": 5.0, "quantity": 3},
    ]
    assert calculate_total(items) == 35.0

def test_calculate_total_with_tax():
    """Test new tax calculation."""
    items = [{"price": 100.0, "quantity": 1}]
    assert calculate_total(items, tax_rate=0.1) == 110.0

def test_calculate_total_invalid_tax_rate():
    """Test tax rate validation."""
    items = [{"price": 100.0, "quantity": 1}]
    with pytest.raises(ValueError, match="Tax rate must be 0-1"):
        calculate_total(items, tax_rate=1.5)
```

**3. Run Tests (They Should Fail)**

```bash
pytest tests/test_calculate_total.py -v

test_calculate_total_existing_behaviour PASSED  # Existing behaviour works
test_calculate_total_with_tax FAILED           # New feature not implemented
test_calculate_total_invalid_tax_rate FAILED   # Validation not implemented
```

**4. Implement Changes**

```python
def calculate_total(items: list[dict], tax_rate: float = 0.0) -> float:
    if not 0.0 <= tax_rate <= 1.0:
        raise ValueError("Tax rate must be 0-1")

    subtotal = sum(item["price"] * item["quantity"] for item in items)
    return subtotal * (1 + tax_rate)
```

**5. Run Tests (They Should Pass)**

```bash
pytest tests/test_calculate_total.py -v
================================ 4 passed ================================
```

---

## Language-Specific Testing

### Python (pytest)

```python
# tests/unit/test_user.py
import pytest
from myapp.user import create_user, UserNotFoundError

class TestCreateUser:
    def test_creates_valid_user(self, db_session):
        """Test user creation with valid data."""
        user = create_user(email="test@example.com", name="Test User")
        assert user.id is not None
        assert user.email == "test@example.com"

    def test_rejects_invalid_email(self):
        """Test validation rejects invalid email."""
        with pytest.raises(ValueError, match="Invalid email"):
            create_user(email="invalid", name="Test")

    def test_handles_duplicate_email(self, db_session, existing_user):
        """Test duplicate email raises error."""
        with pytest.raises(DuplicateEmailError):
            create_user(email=existing_user.email, name="Another")
```

**Fixtures:**

```python
# tests/conftest.py
import pytest

@pytest.fixture
def db_session():
    """Provide test database session."""
    session = create_test_session()
    yield session
    session.rollback()

@pytest.fixture
def existing_user(db_session):
    """Create a user for tests that need existing data."""
    return create_user(email="existing@example.com", name="Existing")
```

### Go (testing + testify)

```go
// user_test.go
package user

import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestCreateUser(t *testing.T) {
    t.Run("creates valid user", func(t *testing.T) {
        user, err := CreateUser("test@example.com", "Test User")
        require.NoError(t, err)
        assert.NotEmpty(t, user.ID)
        assert.Equal(t, "test@example.com", user.Email)
    })

    t.Run("rejects invalid email", func(t *testing.T) {
        _, err := CreateUser("invalid", "Test")
        assert.ErrorContains(t, err, "invalid email")
    })

    t.Run("handles duplicate email", func(t *testing.T) {
        // Create first user
        _, err := CreateUser("duplicate@example.com", "First")
        require.NoError(t, err)

        // Try to create duplicate
        _, err = CreateUser("duplicate@example.com", "Second")
        assert.ErrorIs(t, err, ErrDuplicateEmail)
    })
}

// Table-driven tests
func TestValidateEmail(t *testing.T) {
    tests := []struct {
        name    string
        email   string
        wantErr bool
    }{
        {"valid email", "user@example.com", false},
        {"missing @", "userexample.com", true},
        {"empty", "", true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateEmail(tt.email)
            if tt.wantErr {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

### JavaScript/TypeScript (Jest/Vitest)

```typescript
// user.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { createUser, UserNotFoundError } from './user';

describe('createUser', () => {
  beforeEach(() => {
    // Reset database or mocks
  });

  it('creates valid user', async () => {
    const user = await createUser({
      email: 'test@example.com',
      name: 'Test User',
    });

    expect(user.id).toBeDefined();
    expect(user.email).toBe('test@example.com');
  });

  it('rejects invalid email', async () => {
    await expect(
      createUser({ email: 'invalid', name: 'Test' })
    ).rejects.toThrow('Invalid email');
  });

  it('handles duplicate email', async () => {
    await createUser({ email: 'dup@example.com', name: 'First' });

    await expect(
      createUser({ email: 'dup@example.com', name: 'Second' })
    ).rejects.toThrow('Email already exists');
  });
});
```

### Rust (cargo test)

```rust
// src/user.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_user_valid() {
        let user = create_user("test@example.com", "Test User").unwrap();
        assert!(!user.id.is_empty());
        assert_eq!(user.email, "test@example.com");
    }

    #[test]
    fn test_create_user_invalid_email() {
        let result = create_user("invalid", "Test");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("invalid email"));
    }

    #[test]
    #[should_panic(expected = "duplicate email")]
    fn test_create_user_duplicate_panics() {
        create_user("dup@example.com", "First").unwrap();
        create_user("dup@example.com", "Second").unwrap(); // Should panic
    }
}
```

### Bash (BATS)

```bash
# tests/script.bats
#!/usr/bin/env bats

setup() {
    # Source the script to test
    source "${BATS_TEST_DIRNAME}/../script.sh"
    # Create temp directory
    TEMP_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "${TEMP_DIR}"
}

@test "validate_input accepts valid input" {
    run validate_input "valid_input"
    [ "$status" -eq 0 ]
}

@test "validate_input rejects empty input" {
    run validate_input ""
    [ "$status" -eq 1 ]
}

@test "process_file creates output" {
    echo "test content" > "${TEMP_DIR}/input.txt"

    run process_file "${TEMP_DIR}/input.txt"

    [ "$status" -eq 0 ]
    [ -f "${TEMP_DIR}/input.txt.processed" ]
}

@test "main exits with error on missing argument" {
    run main
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"* ]]
}
```

**Source Guard Pattern (enable BATS testing):**

```bash
#!/usr/bin/env bash
set -euo pipefail

validate_input() {
    [[ -n "${1:-}" ]] || return 1
}

main() {
    validate_input "${1:-}" || exit 1
    echo "Processing..."
}

# Only run main if not sourced (enables BATS testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

---

## Test Patterns

### Regression Prevention

```python
def test_bug_123_float_quantities():
    """Regression test for bug #123: float quantities crash."""
    items = [{"price": 10.0, "quantity": 2.5}]
    assert calculate_total(items) == 25.0  # Should work
```

### Edge Case Coverage

```python
def test_empty_items():
    """Empty cart should return 0."""
    assert calculate_total([]) == 0.0

def test_zero_price():
    """Free items should work."""
    items = [{"price": 0.0, "quantity": 10}]
    assert calculate_total(items) == 0.0

def test_large_numbers():
    """Handle large orders."""
    items = [{"price": 999999.99, "quantity": 1000}]
    assert calculate_total(items) == 999999990.0
```

### Behaviour Documentation

```python
def test_discount_rounding():
    """Discounts round to 2 decimal places (business rule)."""
    assert calculate_discount(10.00, 33.33) == 6.67
    assert calculate_discount(100.00, 7.5) == 92.50
```

---

## Test-First with AI Code Assistants

### Workflow

**1. Write tests yourself (don't let AI write them):**

```python
def test_apply_seasonal_discount():
    """Summer sale: 20% off items with 'summer' tag."""
    items = [
        {"price": 100, "tags": ["summer"]},
        {"price": 50, "tags": ["winter"]},
    ]
    assert calculate_seasonal_discount(items) == 130.0  # 80 + 50
```

**2. Let AI implement to pass tests:**

```text
Prompt: "Implement calculate_seasonal_discount() to pass these tests"
```

**3. Run tests - iterate until passing**

**Why This Works:** Tests are your specification. AI knows what to implement, no ambiguity, catches mistakes immediately.

---

## Common Pitfalls

### Testing Implementation Instead of Behaviour

**❌ Bad (tests HOW not WHAT):**

```python
def test_calculate_total_uses_loop():
    source = inspect.getsource(calculate_total)
    assert "for" in source  # Brittle!
```

**✅ Good (tests WHAT not HOW):**

```python
def test_calculate_total_sums_items():
    items = [{"price": 10, "quantity": 2}]
    assert calculate_total(items) == 20.0  # Don't care how
```

### Too Many Tests

**Rule of thumb:** 3-7 tests per function covers most cases. Focus on:

- Happy path
- Error conditions
- Edge cases (empty, zero, max values)
- Business rule verification

### Not Running Tests Frequently

**❌ Wrong:** Write 10 tests → Implement → Run all tests (many failures)

**✅ Correct:** Write 1 test → Implement → Run → Pass → Commit → Repeat

---

## CI Integration

**Tests must pass before build:**

```bash
./ci/run build
# If tests fail, build fails
```

**Coverage enforcement (80% minimum):**

```yaml
# ci.yaml
test:
  coverage_threshold: 80
```
