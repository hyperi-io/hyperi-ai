# Mock-Aware Testing Policy

**Mocks are scaffolding, not testing. A test suite with only mocked tests is untested.**

## Core Rule

Every mocked boundary must have a corresponding integration test that exercises the real thing (or a realistic substitute).

## Mock Usage: Permitted, Not Sufficient

- **Internal functions/classes** — NEVER mock; test the real code
- **External APIs (Stripe, AWS, GCP)** — mock in unit tests; integration test against sandbox/staging REQUIRED
- **Databases (PostgreSQL, Redis)** — mock in unit tests; integration test with testcontainers REQUIRED
- **Kubernetes API** — mock in unit tests; integration test against kind/k3s REQUIRED
- **File systems, network calls** — mock in unit tests; integration test against real FS/network in CI REQUIRED
- **Time/clock** — mock allowed; integration test optional

```python
# ❌ Mocking internal code (tests nothing real)
with patch('myapp.services.calculate_total') as mock_calc:
    mock_calc.return_value = 100.0  # Circular — tests the mock

# ✅ Mock external boundary, test real internal logic
with patch('myapp.clients.stripe.charge') as mock_stripe:
    mock_stripe.return_value = ChargeResult(success=True)
    result = process_order(order)
    assert result.total == 85.0  # Real calculation tested
```

## Two-Layer Testing Requirement

**A feature is not tested until both layers exist.**

### Layer 1: Unit Tests (Mocks Allowed)

- Fast, isolated, run on every commit
- Mock external boundaries ONLY — never internal code
- 80% coverage minimum — but this alone is NOT "tested"

### Layer 2: Integration Tests (No Mocks)

- Use testcontainers for databases
- Use sandbox/staging endpoints for external APIs
- Use kind/k3s for Kubernetes
- Use real filesystem and network in CI
- Mark with `@pytest.mark.integration` or equivalent

### Coverage Accounting

- "Unit tests pass (mocked)" = fast feedback, not proof
- "Integration tests pass" = proof that boundaries work
- "Both pass" = actually tested

## For AI Code Assistants

### When You Write Tests

1. Write unit tests with mocks for fast feedback
2. **You are NOT done.** Write at least one integration test per mocked boundary
3. If you cannot write integration tests (no testcontainers config, no sandbox), explicitly state: "Integration tests needed for: [list boundaries]"
4. Never report "all tests pass, production ready" when only mocked tests exist

### Completion Criteria

A feature is complete when:

- Unit tests pass with mocked external boundaries
- Integration tests pass against real (or realistic) dependencies
- No TODO/FIXME/HACK in production code
- No placeholder returns (`return True`, `return {}`, `return None`)
- No hardcoded example data ("John Doe", "test@example.com")
- Error handling covers failure paths, not just happy path
- Input validation is complete

### Red Flags — REJECT and Redo

Stop and complete the implementation if you catch yourself writing:

- "Here's a simple example..." / "This is a basic implementation..."
- "For demonstration purposes..." / "This should work for most cases..."
- "TODO: Add error handling" / "TODO: Connect to database"

## Production Code Requirements

- Never commit TODO/FIXME/HACK/XXX in `src/`
- Never commit placeholder returns or hardcoded example data
- Never commit "proof of concept" code as production features
- Always implement complete functionality with error handling
- Always validate inputs at system boundaries
- Always include both unit and integration tests

## CI Enforcement

- 80%+ line coverage (unit + integration combined)
- Integration test suite must exist and pass
- Pre-commit hooks must block TODO/FIXME/HACK/XXX in `src/`
- Reviewer must verify both test layers exist for new features
