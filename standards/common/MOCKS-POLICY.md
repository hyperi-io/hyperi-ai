# Mock-Aware Testing Policy

**Mocks are scaffolding, not testing. A test suite with only mocked tests is untested.**

---

## The Core Problem

AI coding agents routinely run mock-heavy tests, see green, and declare code
"production ready." But mocking every external call proves only that code calls
mocks correctly — not that it works. Mock-only coverage creates a dangerous
illusion of quality.

**The rule:** Every mocked boundary must have a corresponding integration test
that exercises the real thing (or a realistic substitute).

---

## Mock Usage: Permitted, Not Sufficient

| Mock Target | In Unit Tests? | Integration Test Required? |
|-------------|---------------|---------------------------|
| Internal functions/classes | ❌ Never mock | N/A — test the real code |
| External APIs (Stripe, AWS, GCP) | ✅ Yes | ✅ Yes — against sandbox/staging |
| Databases (PostgreSQL, Redis) | ✅ Yes | ✅ Yes — use testcontainers |
| Kubernetes API | ✅ Yes | ✅ Yes — against test cluster or kind |
| File systems, network calls | ✅ Yes | ✅ Yes — against real FS/network in CI |
| Time/clock | ✅ Yes | Optional |

### The Key Distinction

```python
# ❌ BAD — mocking internal code (tests nothing real)
def test_process_order():
    with patch('myapp.services.calculate_total') as mock_calc:
        mock_calc.return_value = 100.0  # Imaginary contract
        result = process_order(order)
        assert result.total == 100.0  # Circular — tests the mock

# ✅ GOOD — mock external boundary, test real internal logic
def test_process_order():
    with patch('myapp.clients.stripe.charge') as mock_stripe:
        mock_stripe.return_value = ChargeResult(success=True)
        result = process_order(order)
        assert result.total == 85.0  # Real calculation tested
        mock_stripe.assert_called_with(amount=8500)
```

---

## The Two-Layer Testing Requirement

### Layer 1: Unit Tests (Mocks Allowed)

Fast, isolated, run on every commit. Mock external boundaries only.

- Test internal logic with real code paths
- Mock external APIs, databases, network at the client boundary
- 80% coverage minimum — but this alone is NOT "tested"

### Layer 2: Integration Tests (No Mocks)

Prove that boundaries actually work. Run in CI.

- Use testcontainers for databases (PostgreSQL, Redis, ClickHouse)
- Use sandbox/staging endpoints for external APIs
- Use kind/k3s for Kubernetes integration
- Use real filesystem and network in CI environment

**A feature is not tested until both layers exist.**

### Coverage Accounting

Mock-only unit tests contribute to coverage metrics but do NOT satisfy the
"tested" requirement for production readiness. When reporting test status:

- "Unit tests pass (mocked)" = fast feedback, not proof
- "Integration tests pass" = proof that boundaries work
- "Both pass" = actually tested

---

## For AI Code Assistants

### When You Write Tests

1. Write unit tests with mocks for fast feedback — this is fine
2. **You are NOT done.** Write at least one integration test per mocked boundary
3. If you cannot write integration tests (no testcontainers config, no sandbox),
   explicitly state: "Integration tests needed for: [list boundaries]"
4. Never report "all tests pass, production ready" when only mocked tests exist

### Completion Criteria

A feature is complete when:

- [ ] Unit tests pass with mocked external boundaries
- [ ] Integration tests pass against real (or realistic) dependencies
- [ ] No TODO/FIXME/HACK in production code
- [ ] No placeholder returns (`return True`, `return {}`, `return None`)
- [ ] No hardcoded example data ("John Doe", "test@example.com")
- [ ] Error handling covers failure paths, not just happy path
- [ ] Input validation is complete

### Red Flags — REJECT This Code

These phrases indicate incomplete work:

- "Here's a simple example..."
- "This is a basic implementation..."
- "For demonstration purposes..."
- "This should work for most cases..."
- "TODO: Add error handling"
- "TODO: Connect to database"

When you see these in your own output, stop and complete the implementation.

---

## Preferred Testing Patterns

### Database: Testcontainers

```python
@pytest.fixture
def db():
    with PostgresContainer() as postgres:
        yield create_connection(postgres.get_connection_url())

def test_save_user(db):
    user_id = save_user(db, {"name": "Alice", "email": "alice@example.com"})
    assert db.get_user(user_id).name == "Alice"  # Real DB, no mocks
```

### External API: Mock Unit + Sandbox Integration

```python
# Unit test (fast, mocked)
@patch('myapp.clients.stripe_client')
def test_payment_unit(mock_stripe):
    mock_stripe.create_charge.return_value = Charge(id="ch_123")
    result = process_payment(100.0, "tok_visa")
    assert result.transaction_id == "ch_123"

# Integration test (slow, real sandbox)
@pytest.mark.integration
def test_payment_integration():
    result = process_payment(100.0, "tok_visa")  # Hits Stripe test mode
    assert result.success is True
    assert result.transaction_id.startswith("ch_")
```

### Kubernetes: Mock Unit + Kind Integration

```python
# Unit test (mocked API)
@patch('kubernetes.client.CoreV1Api')
def test_create_secret_unit(mock_api):
    mock_api.return_value.create_namespaced_secret.return_value = V1Secret()
    result = create_app_secret("my-secret", {"key": "value"})
    assert result is not None

# Integration test (real kind cluster)
@pytest.mark.integration
def test_create_secret_integration(k8s_client):
    result = create_app_secret("test-secret", {"key": "value"})
    secret = k8s_client.read_namespaced_secret("test-secret", "default")
    assert secret.data["key"] is not None
```

---

## Production Code Requirements

Production code MUST be complete and functional:

- ❌ Never commit TODO/FIXME/HACK/XXX in `src/`
- ❌ Never commit placeholder returns or hardcoded example data
- ❌ Never commit "proof of concept" code as production features
- ✅ Always implement complete functionality with error handling
- ✅ Always validate inputs at system boundaries
- ✅ Always include both unit and integration tests

---

## Enforcement

### Pre-commit Hooks

```bash
# Fails commit if TODO/FIXME found in src/
if git diff --cached --name-only | grep "^src/" | \
   xargs grep -n "TODO:\|FIXME:\|HACK:\|XXX:"; then
    echo "ERROR: Placeholder comments found in src/"
    exit 1
fi
```

### CI Checks

- 80%+ line coverage (unit + integration combined)
- Integration test suite must exist and pass
- Static analysis (bandit, semgrep) for security
- Reviewer must verify both test layers exist for new features
