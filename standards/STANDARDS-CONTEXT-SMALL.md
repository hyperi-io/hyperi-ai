# LLM-ONLY: HyperSec AI Code Assistant Standards (Self-Contained)

Target: Under 50K tokens. Self-contained for LLMs with under 500K context.

---

## Context Window Decision

**Your context window determines which standards to load:**

| Context Size | Action |
|--------------|--------|
| **Under 500K tokens** | Read ONLY `$AI_ROOT/standards/STANDARDS-CONTEXT-SMALL.md` (~8K tokens, self-contained) |
| **500K+ tokens** | Read `$AI_ROOT/standards/STANDARDS.md` then load ALL `$AI_ROOT/standards/**/*.md` files |

**If you're reading this file:** You should have <500K context. This file is self-contained - no additional files needed.

---

## 1. CRITICAL: AI Code of Conduct

### NEVER

- Self-promote or use marketing language
- AI attribution in git (Co-Authored-By, Generated-with trailers)
- Claim "finished" or "ready" without complete testing
- Placeholders (TODO, FIXME, PLACEHOLDER) in committed code
- Assume operations succeeded without verification
- Overclaim performance ("Production Ready", "Fully optimized")
- Use greetings or confirmations ("Great question!", "I'd be happy to help!")

### ALWAYS

- Subdued, factual language ("Just the facts, ma'am")
- Verify operations succeeded before reporting success
- Test code before claiming it works
- Complete, working implementations (no "...rest of code")
- Australian English in docs/comments, American English in code
- Be concise and direct
- Skip pleasantries - assume context, jump to work

---

## 2. CRITICAL: No Mocks Policy

**Production code MUST be complete and functional before committing.**

### Never Commit to src/

- Mock implementations or placeholder values
- TODO/FIXME/HACK/XXX comments
- Example/demo code as real features
- Simplified "proof of concept" code
- Always-true returns (`return true`, `return True`)
- Generic exception swallowing (`except Exception: pass`)

### Always Implement

- Complete functionality before committing
- All error cases and edge conditions
- Input/output validation
- Real data structures (not simplified examples)
- Tests verifying complete behavior (90%+ coverage for AI code)

### Red Flags in AI Code (REJECT)

- "Here's a simple example..."
- "This is a basic implementation..."
- "For demonstration purposes..."
- "TODO: Add error handling"
- "TODO: Connect to database"
- Hardcoded example data ("John Doe", "`test@example.com`")
- Functions that always return same value
- Missing input validation
- Generic exception catching

### Example: Incomplete vs Complete

❌ **Incomplete (REJECT):**

```python
def login(username, password):
    # TODO: Check database
    return True  # Always succeeds
```

✅ **Complete:**

```python
def login(username: str, password: str) -> LoginResult:
    """Authenticate user credentials."""
    # Validate inputs
    if not username or not password:
        return LoginResult(success=False, error="Credentials required")

    # Rate limiting (prevent brute force)
    if is_rate_limited(username):
        logger.warning(f"Rate limit: {username}")
        return LoginResult(success=False, error="Too many attempts")

    # Fetch user
    user = db.get_user_by_username(username)
    if not user:
        return LoginResult(success=False, error="Invalid credentials")

    # Check if account locked
    if user.is_locked:
        return LoginResult(success=False, error="Account locked")

    # Verify password
    if not bcrypt.checkpw(password.encode(), user.password_hash):
        db.record_failed_login(user.id)
        return LoginResult(success=False, error="Invalid credentials")

    # Create session
    session = create_session(user.id)
    return LoginResult(success=True, session_token=session.token, user_id=user.id)
```

### Where Mocks ARE Allowed

- `tests/` directory (unit/integration tests)
- `examples/` directory (explicitly marked)
- Documentation code blocks

---

## 3. CRITICAL: Error Handling

### Security Rules

❌ NEVER display to users: Stack traces, DB schemas, file paths, raw exceptions
✅ ALWAYS: Log full errors server-side, show generic messages to users

### Required Logging Context

```python
logger.error(
    "Operation failed",
    user_id=user_id,           # Who
    operation="update_profile", # What
    request_id=request_id,      # Tracking
    exc_info=True               # Stack trace
)
```

### Exception Handling Pattern

```python
try:
    result = process_payment(amount, card)
except InvalidCardError as e:
    logger.warning("Invalid card", error=str(e), user_id=user_id)
    return {"error": "Invalid card details"}  # User-friendly
except PaymentGatewayError as e:
    logger.error("Gateway error", error=str(e), exc_info=True)
    return {"error": "Service unavailable"}  # Generic
except Exception as e:
    logger.critical("Unexpected", error=str(e), exc_info=True)
    return {"error": "An error occurred"}  # Very generic
```

### Never Log Sensitive Data

❌ Passwords, tokens, API keys
❌ Credit cards, CVV, SSNs, PII
❌ Private keys, certificates, JWTs

### Custom Exceptions

```python
class PaymentError(Exception):
    """Base for payment errors"""

class InsufficientFundsError(PaymentError):
    pass

class InvalidCardError(PaymentError):
    pass
```

### HTTP API Error Format

```json
{
    "error": {
        "message": "Generic user-facing message",
        "code": "ERROR_CODE",
        "request_id": "req_abc123"
    }
}
```

### Complete Payment Error Handling Example

```python
from hs_lib import logger
import traceback

def process_payment(user_id, amount, card_token, request_id):
    try:
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

## 4. CRITICAL: Git Standards

### Commit Format

```text
<type>: <description>

[optional body]

[optional footer]
```

### Commit Types (UNDERSTATE, NOT OVERSTATE)

AI assistants frequently overstate. **Default to `fix:` when uncertain.**

**Trigger version bumps:**

| Type | When to Use | Version Bump |
|------|-------------|--------------|
| `fix:` | Fixes, improvements, refactors (DEFAULT) | PATCH |
| `feat:` | NEW significant user-facing features (SPARINGLY) | MINOR |
| `perf:` | Performance improvements | PATCH |
| `sec:` | Security fixes | PATCH |
| `hotfix:` | Critical production fix | PATCH |

**No version bump:**

| Type | When to Use |
|------|-------------|
| `docs:` | Documentation only |
| `test:` | Tests only |
| `chore:` | Maintenance, dependencies |
| `ci:` | CI/CD configuration |
| `refactor:` | No functional change |
| `infra:` | Infrastructure changes |
| `ops:` | Platform, operational |
| `debt:` | Technical debt |
| `spike:` | Research, proof-of-concept |
| `cleanup:` | Remove deprecated code |
| `review:` | Internal review, audit |
| `ui:` | Frontend, layout, visual |
| `design:` | Architecture, UX design |
| `data:` | Data-model, ETL, schema |
| `meta:` | Process or workflow |

**Examples of CORRECT usage:**

```bash
fix: add selective test system          # NOT feat: (internal CI tool)
fix: improve GitHub Actions workflow    # NOT feat: (infrastructure)
fix: add version-exists check           # NOT feat: (safety improvement)
chore: update ci submodule              # NOT feat: or fix:
feat: add OAuth authentication          # OK - NEW user feature
```

**Breaking Changes:**
Add `BREAKING CHANGE:` footer ONLY if it breaks backward compatibility.

### Branch Naming

Format: `<type>/<issue-ref>/<description>`

```text
feat/AI-123/add-cursor-support
fix/no-ref/memory-leak
docs/no-ref/update-readme
chore/PROJ-456/update-deps
```

### AI Attribution

Git hooks auto-remove these. Don't add manually:

- `Co-Authored-By: Claude <noreply@anthropic.com>`
- `Generated with Claude Code`
- Similar from other AI tools

### Commit Message Rules

- Subject: 50 chars max, lowercase after type, no period, imperative mood
- Body: Explain WHY not WHAT, wrap at 72 chars
- Footer: `Fixes #123`, `BREAKING CHANGE:`

---

## 5. CRITICAL: Spelling Guide

### Code: American English

All source code uses American spelling (programming convention):
✅ `color`, `initialize`, `optimize`, `analyze`, `serialize`
✅ Variable: `color_code`, `initializer`, `optimizer`
✅ Class: `ColorPicker`, `DataAnalyzer`, `Serializer`
✅ Function: `initialize_app()`, `optimize_query()`
❌ NOT: `colour`, `initialise`, `optimise`, `analyse`, `serialiser`

**Why:** Consistency with Python stdlib, frameworks, global conventions.

### Documentation/Comments/Chat: Australian English

✅ Markdown docs: "colour", "realise", "organise", "favour"
✅ Docstrings: "Initialise the database connection"
✅ Chat: "This should help you organise the data"
✅ Commits: "fix: optimise query performance"

### Common Australian vs American Pairs

- organise/organize, realise/realize, optimise/optimize, analyse/analyze
- colour/color, favour/favor, behaviour/behavior
- serialise/serialize, initialise/initialize, finalise/finalize

### Example

```python
def initialize_color_picker():
    """Initialise the colour picker component."""  # Australian docstring
    color = "#FF0000"  # American variable
    return ColorPicker(color)  # American class

class DataSerializer:  # American class name
    """Serialise data to JSON format."""  # Australian docstring

    def serialize(self, data):  # American method name
        """Serialise the provided data."""  # Australian docstring
        pass
```

---

## 6. Communication Style

### DO

- Direct and concise - get to the point
- Technical accuracy over politeness
- Show code examples over lengthy descriptions
- Relaxed but professional tone
- Understated (don't oversell)
- Factual without being dry

### DON'T (LLM Cheerleading)

❌ "Great question! I'd be happy to help you with that!"
❌ "Absolutely! Let me walk you through this step by step..."
❌ "I hope this helps! Let me know if you have questions!"
❌ "I'm excited to share...", "I'd be delighted to..."
❌ Over-explaining obvious concepts

### DON'T (American Marketing Hype)

❌ "This is an AMAZING feature that will revolutionize your workflow!"
❌ "Incredible performance boost!", "Game-changing architecture!"
❌ "World-class implementation!", "Cutting-edge solution!"
❌ "Best-in-class!", "Transformative results!"

### DO (Australian Understated)

✅ "This feature should help with your workflow"
✅ "Performance is improved", "Architecture is reorganised"
✅ "Implementation is working", "Standard approach"
✅ "Results as expected"

### Example Responses

**❌ Bad (LLM fluff):**
> "Great question! I'd be absolutely delighted to help you understand this fascinating aspect of Python! Let's explore this together step by step."

**✅ Good (direct, professional):**
> "The issue is the async context manager isn't being awaited properly. Fix it like this: [code]"

---

## 7. Code Style

### Clarity Over Cleverness

- Break down compound operations into clear steps
- Use intermediate variables with descriptive names
- Comments explain WHY, not WHAT
- Helper functions FIRST, main function LAST
- NEVER number comments (hard to refactor when reordering)

### Bad (Dense)

```python
result = [x for x in [y**2 for y in data if y > 0] for _ in range(3) if x > 10]
```

### Good (Clear)

```python
# Filter and transform positive numbers above threshold
positive = [y for y in data if y > 0]
squared = [y**2 for y in positive]
result = [x for x in squared if x > 10]
```

### Bad (Unexplained)

```python
if (a and b) or (c and not d):
    process()
```

### Good (Explained)

```python
# Process if: (both conditions met) OR (special case without override)
both_conditions = a and b
special_case = c and not d
if both_conditions or special_case:
    process()
```

### When Comprehensions OK

Simple single-level: `squares = [x**2 for x in range(10)]`
Avoid nested/complex: Break into explicit loops

### Function Ordering (Helper-First)

Place helper/child functions at the top, main/parent function at the bottom:

```python
# Helper functions defined first
def validate_input(data):
    if not data:
        raise ValueError("Data required")
    return True

def transform_data(data):
    return [item.upper() for item in data]

def save_to_db(data):
    db.insert(data)

# Main function uses helpers (defined above)
def process_user_data(data):
    validate_input(data)
    transformed = transform_data(data)
    save_to_db(transformed)
```

**Why helper-first:**

- Easy to cut/paste and reorder functions without breaking dependencies
- Reading top-to-bottom follows "zoom in" pattern (details → usage)
- Refactoring is simpler (move helpers without updating order)

### Comment Numbering - NEVER

❌ Bad (requires renumbering when reordering):

```python
def process_data(data):
    # 1. Validate input
    validate(data)
    # 2. Transform data
    transformed = transform(data)
    # 3. Save to database
    save(transformed)
```

✅ Good (easy to reorder):

```python
def process_data(data):
    # Validate input
    validate(data)
    # Transform data
    transformed = transform(data)
    # Save to database
    save(transformed)
```

---

## 8. Design Principles

### SOLID

**S - Single Responsibility:** One class, one reason to change

```python
# Bad: UserManager does DB, email, reporting
class UserManager:
    def save_user(self, user): ...
    def send_welcome_email(self, user): ...
    def generate_report(self, user): ...

# Good: Single responsibilities
class UserRepository:
    def save(self, user): ...

class EmailService:
    def send_welcome(self, user): ...

class UserReportGenerator:
    def generate(self, user): ...
```

**O - Open/Closed:** Open for extension, closed for modification

```python
# Bad: Must modify class for new payment types
class PaymentProcessor:
    def process(self, payment_type, amount):
        if payment_type == "credit_card":
            pass
        elif payment_type == "paypal":
            pass

# Good: Extend via inheritance
class PaymentProcessor:
    def process(self, amount):
        raise NotImplementedError

class CreditCardProcessor(PaymentProcessor):
    def process(self, amount):
        pass

class PayPalProcessor(PaymentProcessor):
    def process(self, amount):
        pass
```

**L - Liskov Substitution:** Subtypes must substitute base types

```python
# Bad: Penguin(Bird) raises on fly()
class Bird:
    def fly(self):
        return "Flying"

class Penguin(Bird):
    def fly(self):
        raise Exception("Penguins can't fly!")  # Violates LSP!

# Good: Correct hierarchy
class Bird:
    def move(self):
        raise NotImplementedError

class FlyingBird(Bird):
    def move(self):
        return "Flying"

class Penguin(Bird):
    def move(self):
        return "Swimming"
```

**I - Interface Segregation:** No fat interfaces

```python
# Bad: Robot must implement eat(), sleep() it can't do
class Worker:
    def work(self): pass
    def eat(self): pass
    def sleep(self): pass

class Robot(Worker):
    def work(self):
        return "Working"
    def eat(self):
        raise NotImplementedError  # Robots don't eat!
    def sleep(self):
        raise NotImplementedError  # Robots don't sleep!

# Good: Segregated interfaces
class Workable:
    def work(self): pass

class Eatable:
    def eat(self): pass

class Robot(Workable):
    def work(self):
        return "Working"

class Human(Workable, Eatable):
    def work(self):
        return "Working"
    def eat(self):
        return "Eating"
```

**D - Dependency Inversion:** Depend on abstractions

```python
# Bad: Depends on concrete implementation
class UserService:
    def __init__(self):
        self.db = MySQLDatabase()  # Tight coupling!

# Good: Depends on abstraction
class Database:
    def query(self, sql):
        raise NotImplementedError

class MySQLDatabase(Database):
    def query(self, sql):
        pass

class UserService:
    def __init__(self, db: Database):
        self.db = db  # Depends on abstraction!

# Easy to swap implementations
service = UserService(MySQLDatabase())  # or PostgreSQLDatabase()
```

### DRY (Don't Repeat Yourself)

- Wait for 3+ duplicates before extracting (Rule of Three)
- Duplication is better than wrong abstraction
- Don't force DRY if logic will diverge

```python
# Don't force DRY if logic diverges
def process_user(user):
    validate_user(user)
    sanitize_user_email(user)
    encrypt_user_password(user)
    save_user(user)

def process_product(product):
    validate_product(product)
    sanitize_product_name(product)
    calculate_product_price(product)
    save_product(product)

# These are similar but serve different purposes
# Forcing DRY would create artificial coupling
```

### KISS (Keep It Simple)

- Simple > clever
- Avoid over-engineering
- Choose readable over clever tricks

❌ Bad (over-engineered):

```python
class ConfigFactoryFactory:
    def create_factory(self, type):
        return ConfigFactory(type)

class ConfigFactory:
    def create_config(self):
        pass

factory_factory = ConfigFactoryFactory()
factory = factory_factory.create_factory("yaml")
config = factory.create_config()
```

✅ Good (simple):

```python
config = load_config("config.yaml")
```

### YAGNI (You Aren't Gonna Need It)

- Build only what's needed NOW
- Don't add features "just in case"
- Refactor when requirements actually change

❌ Don't build database abstraction if you only use PostgreSQL
❌ Don't build plugin system with only one plugin
❌ Don't make everything configurable

---

## 9. Testing

### Requirements

- 80% minimum coverage (90%+ for AI code)
- Unit tests for core logic
- Integration tests for dependencies
- Tests run before build/release

### Structure

```text
tests/
├── unit/          # Fast, isolated
├── integration/   # Component integration
└── e2e/           # End-to-end
```

### Test-First for Existing Code

1. Understand current behavior
2. Write tests for current behavior (regression)
3. Write tests for new behavior (they fail)
4. Implement changes
5. Tests pass
6. Refactor if needed
7. Commit

### Test-First with AI

```python
# YOU write the tests - AI doesn't understand business logic
def test_apply_seasonal_discount():
    """Summer sale: 20% off items with 'summer' tag."""
    items = [
        {"price": 100, "tags": ["summer"]},      # Gets discount
        {"price": 50, "tags": ["winter"]},       # No discount
    ]
    assert calculate_seasonal_discount(items) == 130.0  # 80 + 50

# Prompt AI: "Implement calculate_seasonal_discount() to pass this test"
```

### Regression Prevention

```python
def test_bug_123_float_quantities():
    """Regression test for bug #123: float quantities crash."""
    items = [{"price": 10.0, "quantity": 2.5}]
    assert calculate_total(items) == 25.0  # This test runs forever
```

### Test Naming

- Clear, descriptive test names
- Explain WHAT is being tested
- Follow language conventions

---

## 10. Security

### Input Validation

ALWAYS validate ALL external input:

- User input (forms, CLI, API)
- File uploads
- Environment variables
- External API responses

Validate: Type, range/length, format, sanitize, business constraints

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

### Secrets Management

❌ NEVER: Commit secrets, hardcode credentials, log passwords/tokens/keys
✅ ALWAYS: Env vars, secret managers (Vault, AWS Secrets), rotate regularly

### Dependency Security

- Python: `bandit`, `pip-audit`
- Go: `govulncheck`
- Node: `npm audit`, `snyk`
- Lock files for reproducible builds

---

## 11. Python Specific

### Type Hints (Required)

```python
def get_user(user_id: int) -> dict[str, str]:  # ✅
def get_user(user_id):  # ❌ No type hints
```

### Modern Syntax (3.10+)

```python
def process(value: int | str) -> list[User]:  # ✅ Modern
from typing import Union, List  # ❌ Legacy
```

### PEP 8 Naming

- `snake_case`: functions, variables, methods
- `PascalCase`: classes
- `UPPER_SNAKE_CASE`: constants
- `_private`: internal members

### Formatting

- 4 spaces (never tabs)
- 88 chars line length (Black)
- Import order: stdlib → third-party → local

### Import Order

```python
# ✅ Good
# Standard library
import os
import sys
from pathlib import Path

# Third-party
import httpx
import typer
from fastapi import FastAPI

# Local
from hs_lib import logger
from myapp.models import User
```

### HS-CI Enforcement

```bash
./ci/run test  # Runs: ruff, black, pyright, bandit, vulture
```

| Tool | Checks | Blocking? |
|------|--------|-----------|
| ruff | PEP 8, imports (I rules), naming | ✅ Yes |
| black | Formatting | ✅ Yes |
| pyright | Type checking | ⚠️ Warnings |
| bandit | Security | ✅ Yes |
| vulture | Dead code | ✅ Yes |

### Temp Files

```python
import tempfile
with tempfile.NamedTemporaryFile(delete=True, suffix=".dat") as tmp:
    tmp.write(data)
    process(tmp.name)
# Auto-deleted, secure permissions, random name
```

❌ NEVER hardcode `/tmp` or use predictable names

### HS-Lib Infrastructure

Always use hs-lib (not custom implementations):

| Need | Use |
|------|-----|
| Logging | `from hs_lib import logger` |
| Config | `from hs_lib.config import settings` |
| Runtime paths | `from hs_lib import get_runtime_paths` |
| Database URLs | `from hs_lib import build_database_url` |
| Metrics | `from hs_lib import create_metrics` |
| CLI | `from hs_lib import Application` |

**Why:** Zero-config, container-aware, production-ready, ENV-based

---

## 12. Containerization

### Multi-Stage Required

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /build
COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --frozen --no-dev
COPY src/ ./src/
RUN uv build

FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /build/dist/*.whl ./
RUN pip install *.whl && rm *.whl
USER nobody
CMD ["python", "-m", "myapp", "serve"]
```

### Debug Utilities (Include)

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl netcat-openbsd iputils-ping && rm -rf /var/lib/apt/lists/*
```

~5MB cost, worth it for debugging.

### Health Endpoints (Required)

- `/health/live` - Process alive? (K8s kills if failing)
- `/health/ready` - Can handle traffic? (removes from endpoints)
- `/health/startup` - Initialized? (prevents premature checks)

```python
@app.get("/health/live")
async def liveness():
    """Liveness probe - is process alive?"""
    return {"status": "alive"}

@app.get("/health/ready")
async def readiness():
    """Readiness probe - can handle traffic?"""
    if not await check_database():
        return Response(status_code=503)
    return {"status": "ready"}

@app.get("/health/startup")
async def startup():
    """Startup probe - initialization complete?"""
    if not app_initialized:
        return Response(status_code=503)
    return {"status": "started"}
```

### Kubernetes Probes

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2

startupProbe:
  httpGet:
    path: /health/startup
    port: http
  failureThreshold: 30  # 150 seconds max startup
```

### Container Secrets

**Docker Standalone:**

```yaml
services:
  myapp:
    env_file:
      - .env  # Never commit this file
```

**Kubernetes:**

```yaml
env:
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-service-secrets
        key: db-password
```

---

## 13. AI Code Quality Warnings

### Research Findings

⚠️ AI-generated code has:

- 4x higher defect rates vs human code
- 19% longer completion time
- More security vulnerabilities

### Best Practices

✅ Review ALL suggestions (never blindly accept Tab)
✅ Test thoroughly (90%+ coverage for AI code)
✅ Security scan all AI code
✅ Simplify prompts (complex = worse code)
✅ Iterate and refine (don't use first suggestion)

### Don't Use AI For

❌ Security-critical (auth, encryption, sessions, passwords)
❌ Complex algorithms (sorting, graph, DP)
❌ Performance-critical (DB optimization, caching, concurrency)
❌ Regulatory/compliance (HIPAA, GDPR, PCI-DSS, SOC 2)

### AI Good For

✅ Boilerplate generation
✅ Test case generation
✅ Documentation writing
✅ Simple CRUD operations
✅ Code formatting/style fixes

### Red Flags in AI Suggestions

- Missing error handling
- Hardcoded values
- TODO comments
- Simplified logic
- Generic exception catching
- Missing input validation

### Context Window Capabilities

| Tool | Context | Best For |
|------|---------|----------|
| Claude Code | 200k-1M | Multi-file refactoring, architecture |
| GitHub Copilot | 8k-200k | Inline completion, single-file edits |
| Cursor | 8k-200k | Multi-model switching |
| Google Gemini | 1M-2M | Entire codebase analysis |

---

## 14. Avoiding AI Rabbit-Holing

### Warning Signs

- AI refactoring code from 2 iterations ago
- 5+ changes to same function
- AI suggests "improvements" that don't solve original problem
- Code getting more complex, not simpler
- >30 minutes with no commit
- AI adding abstractions "for future use" (YAGNI violation)

### Strategy: Define "Done" Upfront

```text
DONE = Function returns correct total with 2 decimal rounding
DONE ≠ Generic interface for future payment types

## Task: Add discount calculation

**Done when:**
- [ ] Function accepts price and discount_percent
- [ ] Returns discounted price
- [ ] Validates percent is 0-100
- [ ] Has 3 tests (valid, zero, invalid)
- [ ] Passes all tests

**NOT in scope:** Bulk discounts, seasonal discounts, caching
```

### Three-Iteration Rule

```text
Iteration 1: Generate initial implementation
Iteration 2: Fix obvious issues (tests, validation)
Iteration 3: Polish (formatting, docs)

STOP - Commit or revert
```

### Commit When

✅ Tests pass
✅ Meets definition of "done"
✅ No obvious bugs
✅ Reasonably simple

### You Do NOT Need

❌ Perfect abstraction
❌ Every edge case handled
❌ Future-proofing
❌ 100% coverage
❌ AI's approval

### Revert If

- 3+ iterations with no progress
- Code more complex than when started
- Lost track of what you're solving
- Tests failing and unclear why
- AI suggesting contradictory changes

```bash
git reset --hard HEAD~3  # Revert last 3 commits
```

### Recovery Process

1. Stop immediately
2. Close AI chat
3. Take 5-minute break
4. Re-read original task
5. Check git diff - better or just different?
6. Keep if objectively better, revert if not sure

---

## 15. Session Management

### /start (Every Session)

1. Read STATE.md (project state, history)
2. Read TODO.md (current tasks)
3. If under 500K context: Read STANDARDS-CONTEXT-SMALL.md (this file)
4. If 500K+ context: Read STANDARDS.md + standards/ subtree
5. Check git status and recent commits
6. Be ready - no greetings, wait for first task

### /save (Checkpoint Progress)

1. Update STATE.md with session progress
2. Update TODO.md (mark completed, add new)
3. Run markdownlint fixes

### When to /save

- After major task/milestone
- Before breaks (lunch, end of day)
- After 30-40 exchanges (prevent context compression)
- When responses get truncated

### TODO.md Policy

1. Add tasks as work begins
2. Update status as you progress
3. **DELETE completed tasks once in CHANGELOG.md**
❌ NEVER keep completed tasks (that's what CHANGELOG is for)

### Time Estimates

- Format: **1h**, **2h**, **4h** (powers of 2)
- Sub-hour: **0.25h** (15min), **0.5h** (30min)
- Range: **4-8h** when uncertainty exists
- AI productivity: Traditional 1 day ≈ 1h AI-assisted

---

## 16. Knowledge Cutoff Validation

### Process

1. Read <env> for today's date
2. Note your model training cutoff
3. Calculate: days_since_cutoff = today - cutoff
4. If >30 days: Use WebSearch for important decisions

### What to Validate via WebSearch

- Latest library versions
- API changes, deprecations
- Framework updates
- Security vulnerabilities
- Pricing/availability changes

### Cutoff Example

```text
Today: 2025-03-15 (from env section)
Cutoff: 2025-01-15
Difference: 60 days (>30 threshold)
User asks: "Use GitHub Actions ARM64 runners"
Action: WebSearch "GitHub Actions ARM64 availability 2025"
```

---

## 17. GitHub Defaults

### Repository Visibility

✅ ALWAYS `gh repo create --private` unless explicitly requested public
❌ NEVER create public by default

### Licensing

- Proprietary: HyperSec EULA (`LicenseRef-HyperSec-EULA`)
- Open source: Apache-2.0 (NOT MIT - lacks patent protection)

---

## 18. File Headers

### Required Fields

```python
# Project:   <NAME>
# File:      <FILENAME>
# Purpose:   <One sentence>
# Language:  Python
#
# License:   LicenseRef-HyperSec-EULA
# Copyright: (c) <YEAR> HyperSec Pty Ltd
```

### Never Include

❌ Version numbers (use CHANGELOG.md, git)
❌ Change dates (use git history)
❌ Author names (always organisation)
❌ File modification history

---

## 19. CI Infrastructure

### Token Efficiency

❌ NEVER read ci/ directory - wastes context
✅ CI docs already in STATE.md

### Project Commits

```bash
git add src/ tests/ docs/
git commit -m "fix: description"
# Do NOT include ci/ unless explicitly requested
```

---

## 20. Temporary Files and Directories

### Development Work

Use `./.tmp/` for ALL project-scoped temporary operations:

- Test projects and artifacts
- Build intermediates
- Code assistant scratch files
- CI work files

**Why:** Project-scoped, easy cleanup, gitignored, no system pollution

### Production/Runtime Code

- **Python:** Use `tempfile` module
- **Go:** Use `os.MkdirTemp()` and `os.CreateTemp()`
- **Node.js:** Use `tmp` or `temp` packages

### Temp File Security Rules

❌ NEVER hardcode temporary paths (`/tmp`, `/var/tmp`, etc.)
❌ NEVER use predictable filenames
❌ NEVER create temp files without proper cleanup

✅ ALWAYS use language-standard temporary file libraries
✅ ALWAYS use auto-cleanup mechanisms (defer, RAII, context managers)
✅ ALWAYS set restrictive permissions (user-only when possible)

---

## Quick Reference Checklist

### Before Committing

- [ ] No TODO/FIXME in src/
- [ ] Error handling security-first (no stack traces to users)
- [ ] Tests pass (80%+ coverage)
- [ ] Commit message: `<type>: <description>` format
- [ ] No sensitive data logged
- [ ] Type hints on public functions (Python)
- [ ] American spelling in code, Australian in docs/comments
- [ ] Complete implementation (no placeholders)

### Before Session End

- [ ] Run /save
- [ ] Update STATE.md with progress
- [ ] Update TODO.md status

### AI Code Review Checklist

- [ ] Test coverage > 90%
- [ ] Security scan passes (bandit, semgrep)
- [ ] Performance profiling (no N+1 queries, memory leaks)
- [ ] Edge cases handled
- [ ] Error handling complete
- [ ] No placeholder/mock code
- [ ] Input validation
- [ ] Output validation
- [ ] Logging added
- [ ] Type hints present
- [ ] Docstrings complete
- [ ] No hardcoded values

---

End of compact standards. Full details in standards/*.md files.
