# HyperSec Coding Standards (Quick Reference)

## About These Standards

This standards library represents the collation of years of HyperSec (and Derek's prior) experience building at-scale, high-automation DevOps, DataOps, and DevSecOps projects. It is designed as an AI-friendly knowledge base that can be attached to any project as a git submodule.

---

Core coding standards for all HyperSec projects. For detailed guidance, see:

- **Languages:** `$AI_ROOT/standards/languages/` (Python, Go, TypeScript, Rust, Bash)
- **Infrastructure:** `$AI_ROOT/standards/infrastructure/` (K8s/HELM, Terraform, Ansible)

---

## 1. Code Style

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

## 2. Git Standards

### Default Branch

**Always `main`, never `master`.**

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

Format: `<type>/<issue-ref>/<description>` OR `<type>/<description>`

```text
feat/AI-123/add-cursor-support    # With issue tracking
fix/memory-leak                   # Without issue (simpler)
docs/update-readme                # Without issue (simpler)
chore/PROJ-456/update-deps        # With issue tracking
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

## 3. Error Handling

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

### Configuration Cascade (7 Layers)

All configuration follows this priority (highest to lowest):

1. **CLI args** → `--host=X` (runtime override)
2. **ENV vars** → `MYAPP_DATABASE_HOST` (deployment)
3. **.env file** → Local secrets (gitignored)
4. **settings.{env}.yaml** → Environment-specific
5. **settings.yaml** → Project base config
6. **defaults.yaml** → Safe fallback
7. **Hard-coded** → Last resort in code

**Python:** Use `hs-lib` (zero-config cascade via Dynaconf)
**Other languages:** See `$AI_ROOT/standards/common/CONFIG-AND-LOGGING.md`

### Logging Format

| Context | Format | Colours |
|---------|--------|---------|
| Console (dev) | Human-friendly | Solarized |
| Container/CI | RFC 3339 JSON | None |
| File | RFC 3339 plain | None |

**RFC 3339 timestamp (with timezone):** `2025-01-20T14:30:00.123+11:00` or `2025-01-20T03:30:00.123Z`

⚠️ Always include timezone offset - never use timestamps without timezone.

**ENV overrides:** `LOG_LEVEL`, `LOG_FORMAT`, `LOG_OUTPUT`, `NO_COLOR`

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

---

## 4. Security

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

## 5. Testing

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

## 6. Design Principles

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

## 7. Spelling Guide

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

## 8. Communication Style

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

## 9. Semantic Release (All Projects)

All HyperSec projects use semantic-release for automated versioning.

### Commit Type → Version Bump

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `fix:` | PATCH (0.0.X) | `1.2.3` → `1.2.4` |
| `feat:` | MINOR (0.X.0) | `1.2.3` → `1.3.0` |
| `BREAKING CHANGE:` footer | MAJOR (X.0.0) | `1.2.3` → `2.0.0` |

### No Version Bump

`docs:`, `test:`, `chore:`, `ci:`, `refactor:` - No release triggered.

### Required Files

```text
.releaserc.json     # Semantic-release config
package.json        # Even for non-Node projects (version field)
CHANGELOG.md        # Auto-generated
```

### Release Process

1. Push to main branch
2. CI runs semantic-release
3. Version determined from commits since last tag
4. CHANGELOG.md updated automatically
5. Git tag created
6. Release published

---

## 10. Containerization

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

## 11. GitHub Defaults

### Repository Visibility

✅ ALWAYS `gh repo create --private` unless explicitly requested public
❌ NEVER create public by default

### Licensing

- **Default:** HyperSec EULA (`LicenseRef-HyperSec-EULA`) - no approval needed
- **Open source:** Apache-2.0 (requires management approval)
- ❌ MIT is NOT permitted

**Full guide:** `$AI_ROOT/standards/common/LICENSING.md`

---

## 12. File Headers (All Languages)

### Required Fields

```python
# Project:   <NAME>
# File:      <FILENAME>
# Purpose:   <One sentence>
# Language:  Python
#
# License:   LicenseRef-HyperSec-EULA
# Copyright: (c) <YEAR> HyperSec
```

### Never Include

❌ Version numbers (use CHANGELOG.md, git)
❌ Change dates (use git history)
❌ Author names (always organisation)
❌ File modification history

---

## 13. Temporary Files and Directories

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
- **Rust:** Use `tempfile` crate
- **Node.js:** Use `tmp` or `temp` packages

### Temp File Security Rules

❌ NEVER hardcode temporary paths (`/tmp`, `/var/tmp`, etc.)
❌ NEVER use predictable filenames
❌ NEVER create temp files without proper cleanup

✅ ALWAYS use language-standard temporary file libraries
✅ ALWAYS use auto-cleanup mechanisms (defer, RAII, context managers)
✅ ALWAYS set restrictive permissions (user-only when possible)

---

## 14. No Mocks Policy

**"No mocks" = no mocking internal code. External dependencies are legitimate mock targets.**

| Mock Target | Allowed? |
|-------------|----------|
| Internal functions/classes | ❌ NO |
| External APIs, DBs, K8s, network | ✅ YES |

```python
# ❌ BAD - mocking internal code
with patch('myapp.utils.calculate') as m: ...

# ✅ GOOD - mocking external boundary
with patch('myapp.clients.stripe.charge') as m: ...
```

**Production code:** No TODOs, no placeholders, no `return True`, no `except: pass`.

**Full policy:** See `$AI_ROOT/standards/common/NO-MOCKS-POLICY.md`

---

## 15. CLI Utility Preferences

**Use modern tools when available:**

| Task | Use | Not |
|------|-----|-----|
| Search | `rg` (ripgrep) | `grep -R` |
| Find files | `fd` / `fdfind` | `find` |
| File loops | `fd`, `parallel`, `xargs -0` | bash for loops |
| Replace | `sd` | `sed -i` |
| JSON | `jq` | grep/awk |
| YAML/JSON/XML/CSV/TOML | `yq` | grep/awk |
| CSV/TSV | `mlr` (Miller) | awk/cut |
| Dir trees | `rsync` | cp/mv |
| Preview | `bat` / `batcat` | `cat` |
| Pickers | `fzf` | shell menus |

**Full guide:** See `$AI_ROOT/standards/code-assistant/COMMON.md`

---

## 16. Python: uv Required

**Use uv, not pip/python directly.** Exception: external non-uv projects.

| Use | Not |
|-----|-----|
| `uv venv` | `python -m venv` |
| `uv sync` | `pip install -r` |
| `uv add <pkg>` | `pip install` |
| `uv run python` | `python` |
| `uv run -m pytest` | `python -m pytest` |

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

---

## For AI Code Assistants

The following sections are specific guidance for AI code assistants (Claude Code, GitHub Copilot, Cursor, etc.).

---

## Loading Standards

**All AI code assistants load:**

1. `$AI_ROOT/standards/STANDARDS-QUICKSTART.md` (this file)
2. Language files from `$AI_ROOT/standards/languages/` - detect by project config files
3. Infrastructure files from `$AI_ROOT/standards/infrastructure/` - detect by IaC files present

**Auto-detection:** Match project files (e.g., `pyproject.toml`, `go.mod`, `Chart.yaml`, `*.tf`) to the corresponding standards file in the appropriate directory. File names are self-documenting (e.g., `PYTHON.md`, `GOLANG.md`, `K8S.md`, `TERRAFORM.md`).

---

## AI Code of Conduct

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

## AI Pitfalls to Avoid (2024-2025 Research)

**Sources:** Apiiro, GitClear, METR, CrowdStrike (Sep 2025)

### Security Issues (Critical)

| Issue | Impact |
|-------|--------|
| Privilege escalation paths | +322% in AI code vs human |
| Architectural design flaws | +153% in AI code vs human |
| Secrets exposure (API keys) | +40% in AI-assisted projects |
| Code with vulnerabilities | 48-62% of AI output |
| AI code merged to prod | 4x faster (bypasses review) |

### Code Quality Issues

| Issue | Impact |
|-------|--------|
| Code duplication | 8x increase in 2024 |
| Refactoring decline | <10% (down from 25% in 2021) |
| Context misses | 65% for refactoring tasks |

### Productivity Illusion (METR Study Jul 2025)

Developers using AI (Cursor Pro + Claude 3.5/3.7):

- Were **19% slower** on average
- Yet believed they were **20% faster**

### Common Hallucinations

❌ Non-existent packages (npm: "ts-migrate-parser", pip: "pydantic-ai")
❌ Incorrect API signatures (outdated or hallucinated)
❌ Wrong dependency versions
❌ Missing edge case handling

### Best Practices

✅ **Always run linters** before accepting AI code
✅ **Verify package names** in official registries
✅ **Review security patterns** (privilege, secrets, validation)
✅ **Test AI code** like untrusted code
✅ **Check for duplication** - refactor instead of copy

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

---

## AI Red Flags (REJECT)

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

---

## Avoiding AI Rabbit-Holing

### Warning Signs

- AI refactoring code from 2 iterations ago
- 5+ changes to same function
- AI suggests "improvements" that don't solve original problem
- Code getting more complex, not simpler
- >30 minutes with no commit
- AI adding abstractions "for future use" (YAGNI violation)

### Three-Iteration Rule

```text
Iteration 1: Generate initial implementation
Iteration 2: Fix obvious issues (tests, validation)
Iteration 3: Polish (formatting, docs)

STOP - Commit or revert
```

### Revert If

- 3+ iterations with no progress
- Code more complex than when started
- Lost track of what you're solving
- Tests failing and unclear why
- AI suggesting contradictory changes

```bash
git reset --hard HEAD~3  # Revert last 3 commits
```

---

## Avoid Sleep Commands for Debugging

**AI assistants should avoid using `sleep` commands for debugging purposes.**

❌ **DON'T:** Use sleep to wait for processes or debug timing issues

```bash
# BAD - blocks all interaction
sleep 30  # Wait for service to start
curl http://localhost:8080/health
```

✅ **DO:** Use polling loops, health checks, or timeouts

```bash
# GOOD - allows interruption, provides feedback
for i in {1..30}; do
    curl -s http://localhost:8080/health && break
    echo "Waiting for service... ($i/30)"
    sleep 1
done
```

**Why:** Sleep commands block all interaction with the AI assistant during execution. The user cannot cancel, provide input, or see progress. Use short polling intervals with feedback instead.

**Applies to:** AI assistant debugging/testing workflows only (NOT coding advice for user projects).

---

## Session Management

### /load (Every Session)

1. Read STATE.md (project state, history)
2. Read TODO.md (current tasks)
3. Read STANDARDS-QUICKSTART.md (this file)
4. Read relevant language files from `standards/languages/`
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

### CI Infrastructure Token Efficiency

❌ NEVER read ci/ directory - wastes context
✅ CI docs already in STATE.md

---

## AI Code Review Checklist

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

End of standards. Full details in `standards/*.md` files.
