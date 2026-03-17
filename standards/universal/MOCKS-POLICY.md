---
name: mocks-policy-standards
description: No mocks policy. Test against real dependencies always. Mocks are forbidden — use testcontainers, sandboxes, and real infrastructure.
rule_paths:
  - "**/*.py"
  - "**/*.rs"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/tests/**"
  - "**/*_test.*"
  - "**/*.test.*"
  - "**/*.spec.*"
---

# No Mocks Policy

> **"Every time we have mocks and AI it always ends in tears."** — Derek

**Do not use mocks. Test against real dependencies. Period.**

A mocked test proves nothing — it tests your assumptions about the dependency,
not the dependency itself. Mocked test suites pass while production burns.

---

## The Rule

- **No `unittest.mock`**, `patch()`, `MagicMock`, `Mock()`
- **No `jest.mock()`**, `jest.fn()`, `jest.spyOn()` with fake returns
- **No `gomock`**, `testify/mock`, `mockgen`
- **No `mockall`**, `mockito`, or any mock framework in any language
- **No hand-rolled fakes** that simulate dependency behaviour

If a test cannot run against the real dependency, it is not a test —
it is a wish. Skip it or fix the test infrastructure.

---

## What To Use Instead

| Dependency | Use Instead of Mocks |
|---|---|
| **Databases** | Testcontainers (real PostgreSQL/Redis/ClickHouse in Docker) |
| **External APIs** | Sandbox/staging endpoints (Stripe test mode, AWS LocalStack) |
| **Kubernetes** | kind or k3s in CI |
| **File system** | Real files in `tempfile.TemporaryDirectory` |
| **Network** | Real HTTP calls to local test server or actual endpoint |
| **Time/clock** | The ONE exception — freezing time is acceptable (`freezegun`, `tokio::time::pause`, `jest.useFakeTimers`) |

```python
# ❌ NEVER — mocking internal code
def test_process_order():
    with patch('myapp.services.calculate_total') as mock_calc:
        mock_calc.return_value = 100.0  # Tests nothing
        result = process_order(order)

# ❌ NEVER — mocking the database
def test_save_user():
    with patch('myapp.db.session') as mock_db:
        mock_db.query.return_value = User(name="test")
        # Proves nothing about real SQL

# ✅ ALWAYS — real database via testcontainers
@pytest.fixture
def db():
    with PostgresContainer() as postgres:
        yield create_connection(postgres.get_connection_url())

def test_save_user(db):
    user_id = save_user(db, {"name": "Alice", "email": "a@b.com"})
    assert db.get_user(user_id).name == "Alice"  # Real SQL, real DB

# ✅ ALWAYS — real external API sandbox
@pytest.mark.integration
def test_payment():
    result = process_payment(100.0, "tok_visa")  # Stripe test mode
    assert result.success is True
```

---

## If You Cannot Test Against Real Dependencies

Say so explicitly. Do NOT mock to make a test pass.

```python
@pytest.mark.skip(reason="Needs Stripe sandbox — not mocking")
def test_payment_integration():
    ...
```

This is honest. A skipped test is better than a mocked test that lies
about coverage.

---

## Coverage Accounting

Tests using mocks do NOT count toward the "tested" requirement for
production readiness. Only tests against real dependencies count.

---

## For AI Code Assistants

### When Writing Tests

1. Write tests that exercise real code against real dependencies
2. Use testcontainers or Docker for databases and message queues
3. Use sandbox endpoints for external APIs
4. If you cannot test against real dependencies, say so explicitly:
   "Cannot test [boundary] — needs [setup]. Skipping, not mocking."
5. **Never** create a mock to make a test pass — that is not testing

### NEVER Do

- Import any mock library
- Patch or monkey-patch any function, method, or module
- Create fake objects that simulate real dependency behaviour
- Write `mock_*.py` or `*_mock.py` files
- Claim "tests pass" when tests use mocks — they do not pass,
  they pretend to pass

### If You See Existing Mocks

Do not add more. If modifying a test file that uses mocks, flag it:
"This test uses mocks — results are unreliable. Needs migration to
real dependencies." Do not extend mock-based tests.

### Completion Criteria

- [ ] Tests pass against real dependencies (not mocks)
- [ ] No TODO/FIXME/HACK in production code
- [ ] No placeholder returns (`return True`, `return {}`, `return None`)
- [ ] Error handling covers failure paths, not just happy path
- [ ] Input validation is complete

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
