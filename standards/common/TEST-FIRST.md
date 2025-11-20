# Test-First Development Strategy

**Develop success criteria tests before modifying existing code**

---

## Overview

**Test-first development** for existing code: define success criteria through tests BEFORE making changes.

**Not pure TDD:** Define what "done" looks like before refactoring, bug fixing, or adding features to existing code.

**Benefits:** Safety net, clear "done" definition, fast iteration, refactoring confidence, behavior documentation

---

## When to Use Test-First

### Perfect For:

**Refactoring existing code:**
```python
# Before refactoring, write tests that verify current behavior
def test_calculate_discount_current_behavior():
    """Test existing discount calculation before refactoring."""
    assert calculate_discount(100, 10) == 90.0
    assert calculate_discount(100, 0) == 100.0
    assert calculate_discount(50, 20) == 40.0

# Now refactor safely - tests will catch if you break anything
```

**Bug fixes:**
```python
# 1. Write test that reproduces the bug
def test_bug_negative_discount_crashes():
    """Bug: negative discount causes crash."""
    with pytest.raises(ValueError, match="Discount must be 0-100"):
        calculate_discount(100, -10)  # Currently crashes with TypeError

# 2. Fix the bug
def calculate_discount(price: float, percent: float) -> float:
    if not 0 <= percent <= 100:
        raise ValueError("Discount must be 0-100")  # Bug fixed
    return price * (1 - percent / 100)

# 3. Test passes - bug fixed and won't regress
```

**Adding features to existing code:**
```python
# 1. Write tests for new feature
def test_bulk_discount_tier():
    """New feature: bulk discount for orders > $1000."""
    assert calculate_discount(1500, 10, bulk=True) == 1200.0  # Extra 10% off
    assert calculate_discount(500, 10, bulk=True) == 450.0    # No bulk discount

# 2. Implement feature
def calculate_discount(price: float, percent: float, bulk: bool = False) -> float:
    discount = price * (1 - percent / 100)
    if bulk and price > 1000:
        discount *= 0.9  # Additional 10% for bulk orders
    return discount

# 3. Tests pass - feature complete
```

### Not Suitable For:

❌ **New greenfield code** - Use pure TDD
❌ **Exploratory prototypes** - Tests add overhead when requirements unclear
❌ **One-off scripts** - Overhead not worth it for throwaway code

---

## Test-First Workflow

### Step-by-Step Process

**1. Understand Current Behavior**

Understand what the code currently does:

```python
# Read existing code
def calculate_total(items: list[dict]) -> float:
    """Calculate order total."""
    total = 0
    for item in items:
        total += item["price"] * item["quantity"]
    return total

# Understand: Multiplies price * quantity, sums items, no tax/shipping
```

**2. Define Success Criteria**

What should the code do AFTER your changes?

```python
# Success criteria for adding tax calculation:
# 1. Calculate subtotal (existing behavior - MUST NOT BREAK)
# 2. Add tax based on tax_rate parameter
# 3. Handle zero tax rate (default)
# 4. Validate tax_rate is 0-1
```

**3. Write Tests for Success Criteria**

```python
def test_calculate_total_existing_behavior():
    """Test existing subtotal calculation (MUST NOT BREAK)."""
    items = [
        {"price": 10.0, "quantity": 2},
        {"price": 5.0, "quantity": 3},
    ]
    assert calculate_total(items) == 35.0  # 20 + 15

def test_calculate_total_with_tax():
    """Test new tax calculation."""
    items = [{"price": 100.0, "quantity": 1}]
    assert calculate_total(items, tax_rate=0.1) == 110.0  # 100 + 10% tax

def test_calculate_total_zero_tax():
    """Test zero tax (default)."""
    items = [{"price": 100.0, "quantity": 1}]
    assert calculate_total(items, tax_rate=0.0) == 100.0
    assert calculate_total(items) == 100.0  # Default tax_rate

def test_calculate_total_invalid_tax_rate():
    """Test tax rate validation."""
    items = [{"price": 100.0, "quantity": 1}]
    with pytest.raises(ValueError, match="Tax rate must be 0-1"):
        calculate_total(items, tax_rate=1.5)
    with pytest.raises(ValueError, match="Tax rate must be 0-1"):
        calculate_total(items, tax_rate=-0.1)
```

**4. Run Tests (They Should Fail)**

```bash
$ pytest tests/test_calculate_total.py -v

test_calculate_total_existing_behavior PASSED  # Existing behavior works
test_calculate_total_with_tax FAILED           # New feature not implemented
test_calculate_total_zero_tax FAILED           # New feature not implemented
test_calculate_total_invalid_tax_rate FAILED   # Validation not implemented
```

**5. Implement Changes**

```python
def calculate_total(items: list[dict], tax_rate: float = 0.0) -> float:
    """
    Calculate order total with optional tax.

    Args:
        items: List of items with 'price' and 'quantity'
        tax_rate: Tax rate (0.0-1.0), default 0.0

    Returns:
        Total including tax

    Raises:
        ValueError: If tax_rate < 0 or > 1
    """
    # Validate tax rate
    if not 0.0 <= tax_rate <= 1.0:
        raise ValueError("Tax rate must be 0-1")

    # Calculate subtotal (existing behavior - preserved)
    subtotal = 0.0
    for item in items:
        subtotal += item["price"] * item["quantity"]

    # Add tax (new feature)
    total = subtotal * (1 + tax_rate)

    return total
```

**6. Run Tests (They Should Pass)**

```bash
$ pytest tests/test_calculate_total.py -v

test_calculate_total_existing_behavior PASSED  # ✅ Didn't break existing code
test_calculate_total_with_tax PASSED           # ✅ New feature works
test_calculate_total_zero_tax PASSED           # ✅ Default works
test_calculate_total_invalid_tax_rate PASSED   # ✅ Validation works

================================ 4 passed ================================
```

**7. Refactor (If Needed)**

Now that tests pass, refactor for clarity:

```python
def calculate_total(items: list[dict], tax_rate: float = 0.0) -> float:
    """Calculate order total with optional tax."""
    if not 0.0 <= tax_rate <= 1.0:
        raise ValueError("Tax rate must be 0-1")

    # More readable refactor
    subtotal = sum(item["price"] * item["quantity"] for item in items)
    total = subtotal * (1 + tax_rate)

    return total
```

**8. Re-run Tests (Still Pass)**

```bash
$ pytest tests/test_calculate_total.py -v
================================ 4 passed ================================
```

**Done! Commit with confidence.**

---

## Test-First Patterns

### Pattern 1: Regression Prevention

**Prevent bugs from coming back:**

```python
# Bug report: "calculate_discount crashes with float quantities"
def test_bug_123_float_quantities():
    """Regression test for bug #123: float quantities crash."""
    items = [{"price": 10.0, "quantity": 2.5}]  # 2.5 quantity
    assert calculate_total(items) == 25.0  # Should work

# This test will ALWAYS run, preventing regression
```

### Pattern 2: Edge Case Coverage

**Define edge cases first:**

```python
# Edge cases to handle:
def test_empty_items():
    """Empty cart should return 0."""
    assert calculate_total([]) == 0.0

def test_zero_price():
    """Free items should work."""
    items = [{"price": 0.0, "quantity": 10}]
    assert calculate_total(items) == 0.0

def test_zero_quantity():
    """Zero quantity should work."""
    items = [{"price": 100.0, "quantity": 0}]
    assert calculate_total(items) == 0.0

def test_large_numbers():
    """Handle large orders."""
    items = [{"price": 999999.99, "quantity": 1000}]
    assert calculate_total(items) == 999999990.0
```

### Pattern 3: Behavior Documentation

**Tests document expected behavior:**

```python
def test_discount_rounding():
    """Discounts round to 2 decimal places (business rule)."""
    assert calculate_discount(10.00, 33.33) == 6.67  # Not 6.6670
    assert calculate_discount(100.00, 7.5) == 92.50  # Not 92.5
```

### Pattern 4: Integration Test First

**Test integration points first:**

```python
def test_payment_gateway_integration():
    """Test Stripe integration works end-to-end."""
    # This test defines how we'll use Stripe
    result = process_payment(
        amount=100.0,
        card="tok_visa",  # Stripe test token
        idempotency_key="test_123"
    )

    assert result.success is True
    assert result.transaction_id.startswith("ch_")
    assert result.amount == 100.0

# Now implement process_payment() to pass this test
```

---

## Test-First with AI Code Assistants

### Workflow with AI

**1. Write tests yourself (don't let AI write them):**

```python
# You write the tests - AI doesn't understand business logic
def test_apply_seasonal_discount():
    """Summer sale: 20% off items with 'summer' tag."""
    items = [
        {"price": 100, "tags": ["summer"]},      # Gets discount
        {"price": 50, "tags": ["winter"]},       # No discount
    ]
    assert calculate_seasonal_discount(items) == 170.0  # 80 + 50 + 40
```

**2. Let AI implement to pass tests:**

```
Prompt: "Implement calculate_seasonal_discount() to pass these tests"
```

**3. AI generates code:**

```python
def calculate_seasonal_discount(items: list[dict]) -> float:
    total = 0
    for item in items:
        price = item["price"]
        if "summer" in item.get("tags", []):
            price *= 0.8  # 20% discount
        total += price
    return total
```

**4. Run tests:**

```bash
$ pytest tests/test_seasonal_discount.py -v
test_apply_seasonal_discount PASSED
```

**5. Done - AI implemented correctly because tests were clear.**

### Why This Works

**Tests are your specification:** AI knows what to implement, no ambiguity, catches mistakes immediately

**Example of AI failing without tests:**

```
Prompt: "Add seasonal discount feature"

AI generates:
def calculate_seasonal_discount(items):
    # TODO: Implement seasonal discount logic
    return sum(item["price"] for item in items)  # Wrong! No discount applied
```

**With tests, AI iterates until passing.**

---

## Common Pitfalls

### Pitfall 1: Writing Tests After Code

❌ **Wrong order:**
```
1. Modify code
2. Code breaks
3. Write tests to debug
4. Fix code
5. Tests pass
```

✅ **Correct order:**
```
1. Write tests defining success
2. Tests fail (feature not implemented)
3. Implement feature
4. Tests pass
5. Done
```

### Pitfall 2: Testing Implementation Instead of Behavior

❌ **Bad test (tests HOW not WHAT):**
```python
def test_calculate_total_uses_loop():
    """Test that calculate_total uses a for loop."""
    source = inspect.getsource(calculate_total)
    assert "for" in source  # Brittle! Breaks if we refactor to sum()
```

✅ **Good test (tests WHAT not HOW):**
```python
def test_calculate_total_sums_items():
    """Test that calculate_total returns correct sum."""
    items = [{"price": 10, "quantity": 2}, {"price": 5, "quantity": 3}]
    assert calculate_total(items) == 35.0  # Don't care how, just that it works
```

### Pitfall 3: Too Many Tests

❌ **Over-testing:**
```python
# 50 tests for one simple function
def test_add_1_plus_1(): assert add(1, 1) == 2
def test_add_1_plus_2(): assert add(1, 2) == 3
def test_add_1_plus_3(): assert add(1, 3) == 4
# ... 47 more tests
```

✅ **Right amount of testing:**
```python
# Test edge cases and representative examples
def test_add_positive_numbers(): assert add(5, 3) == 8
def test_add_zero(): assert add(5, 0) == 5
def test_add_negative_numbers(): assert add(-5, -3) == -8
```

**Rule of thumb:** 3-7 tests per function covers most cases.

### Pitfall 4: Not Running Tests Frequently

❌ **Write 10 tests, implement, run once:**
```
Write test1, test2, ... test10 → Implement → Run all tests
(Many failures, hard to debug)
```

✅ **Write one test, implement, run, repeat:**
```
Write test1 → Implement → Run → Pass → Commit
Write test2 → Implement → Run → Pass → Commit
...
```

---

## Test-First Checklist

**Before modifying existing code:**

- [ ] Read and understand current behavior
- [ ] Write tests that verify current behavior (regression tests)
- [ ] Write tests for new behavior (success criteria)
- [ ] Run tests - existing behavior passes, new behavior fails
- [ ] Implement changes to make all tests pass
- [ ] Refactor if needed (tests still pass)
- [ ] Commit with confidence

**For bug fixes:**

- [ ] Write test that reproduces the bug
- [ ] Verify test fails (confirms bug exists)
- [ ] Fix the bug
- [ ] Verify test passes (confirms bug fixed)
- [ ] Test will prevent regression forever

**For new features on existing code:**

- [ ] Write tests defining feature behavior
- [ ] Write tests for edge cases
- [ ] Tests fail (feature not implemented)
- [ ] Implement feature
- [ ] Tests pass
- [ ] Refactor if needed

---

## Examples

### Example 1: Refactoring Spaghetti Code

**Existing code (works but messy):**

```python
def process_order(order):
    total = 0
    for item in order["items"]:
        total = total + item["price"] * item["qty"]
    if order["customer"]["type"] == "premium":
        total = total * 0.9
    if order["shipping"] == "express":
        total = total + 25
    else:
        total = total + 10
    return total
```

**Step 1: Write tests for current behavior:**

```python
def test_process_order_regular_customer():
    order = {
        "items": [{"price": 100, "qty": 1}],
        "customer": {"type": "regular"},
        "shipping": "standard"
    }
    assert process_order(order) == 110.0  # 100 + 10 shipping

def test_process_order_premium_customer():
    order = {
        "items": [{"price": 100, "qty": 1}],
        "customer": {"type": "premium"},
        "shipping": "standard"
    }
    assert process_order(order) == 100.0  # (100 * 0.9) + 10

def test_process_order_express_shipping():
    order = {
        "items": [{"price": 100, "qty": 1}],
        "customer": {"type": "regular"},
        "shipping": "express"
    }
    assert process_order(order) == 125.0  # 100 + 25 express
```

**Step 2: Refactor with confidence (tests prevent breaking):**

```python
def process_order(order: dict) -> float:
    """Calculate order total with discounts and shipping."""
    subtotal = calculate_subtotal(order["items"])
    discount = calculate_discount(subtotal, order["customer"]["type"])
    shipping = calculate_shipping(order["shipping"])
    return subtotal - discount + shipping

def calculate_subtotal(items: list[dict]) -> float:
    return sum(item["price"] * item["qty"] for item in items)

def calculate_discount(subtotal: float, customer_type: str) -> float:
    if customer_type == "premium":
        return subtotal * 0.1  # 10% discount
    return 0.0

def calculate_shipping(shipping_type: str) -> float:
    return 25.0 if shipping_type == "express" else 10.0
```

**Step 3: Run tests - all pass! Refactoring successful.**

### Example 2: Bug Fix with Test-First

**Bug report:** "Division by zero crash when calculating average"

**Step 1: Write test that reproduces bug:**

```python
def test_bug_456_empty_list_crashes():
    """Bug #456: calculate_average([]) crashes with ZeroDivisionError."""
    # Currently crashes - test will fail with ZeroDivisionError
    assert calculate_average([]) == 0.0  # Should return 0, not crash
```

**Step 2: Run test - confirms bug:**

```bash
$ pytest tests/test_average.py::test_bug_456_empty_list_crashes -v
FAILED - ZeroDivisionError: division by zero
```

**Step 3: Fix bug:**

```python
def calculate_average(numbers: list[float]) -> float:
    """Calculate average of numbers."""
    if not numbers:  # Fix: handle empty list
        return 0.0
    return sum(numbers) / len(numbers)
```

**Step 4: Run test - passes! Bug fixed:**

```bash
$ pytest tests/test_average.py::test_bug_456_empty_list_crashes -v
PASSED
```

**Test runs forever, preventing regression.**

---

## Integration with HS-CI

**HS-CI enforces test-first workflow:**

```bash
# Tests must pass before build
./ci/run build

# If tests fail, build fails
ERROR: Tests failed - cannot build
Run: ./ci/run test

# Fix code until tests pass
./ci/run test
PASSED - All tests passed

# Now build succeeds
./ci/run build
SUCCESS - Build complete
```

**80% coverage minimum ensures tests exist.**
