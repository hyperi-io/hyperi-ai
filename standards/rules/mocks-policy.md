# No Mocks Policy

**Do not use mocks, patches, fakes, stubs, or test doubles. Period.**

A mocked test proves nothing — it tests your assumptions about the
dependency, not the dependency itself. Mocked test suites pass while
production burns.

## The Rule

- **No `unittest.mock`**, `patch()`, `MagicMock`, `Mock()`
- **No `jest.mock()`**, `jest.fn()`, `jest.spyOn()` with fake returns
- **No `gomock`**, `testify/mock`, `mockgen`
- **No `mockall`**, `mockito`, or any mock framework in any language
- **No hand-rolled fakes** that simulate dependency behaviour

If a test cannot run against the real dependency, it is not a test —
it is a wish. Delete it or fix it.

## What To Use Instead

### Databases
Use real instances — testcontainers, Docker Compose, or an in-process
equivalent (SQLite for simple cases, actual PostgreSQL/Redis for real
ones). Tests must hit real SQL, real connections, real transactions.

### External APIs
Use sandbox/staging endpoints provided by the service (Stripe test
mode, AWS LocalStack, GCP emulators). If no sandbox exists, write a
thin adapter and test the adapter against the real API in CI with
rate limiting. Skip in local dev if needed (`@pytest.mark.integration`).

### Kubernetes
Use kind or k3s in CI. Real cluster, real API, real manifests.

### File System and Network
Use real files in a temp directory. Use real HTTP calls to a local
test server or the actual endpoint.

### Time
The one exception — freezing/controlling time is acceptable
(`freezegun`, `tokio::time::pause`, `jest.useFakeTimers`). This is
not mocking a dependency, it is controlling the environment.

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
- Claim "tests pass" when tests use mocks — they do not pass, they
  pretend to pass

### If You See Existing Mocks

Do not add more. If modifying a test file that uses mocks, flag it:
"This test uses mocks — results are unreliable. Needs migration to
real dependencies." Do not extend mock-based tests.
