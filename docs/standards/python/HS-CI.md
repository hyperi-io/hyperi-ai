# HS-CI Python Integration Guide

**Automated Python code quality enforcement for all HyperSec projects**

---

## Core Principles

**HS-CI implements three HyperSec principles:**

1. **Reduce cognitive load:** Simple commands (`./ci/run check`), consistent output, clear error messages
2. **Reduce context switching:** Same tools/config/commands across all projects
3. **Automated standards enforcement:** Pre-commit hooks + CI pipeline catch issues automatically

**Result:** Developers focus on solving problems, not remembering standards.

---

## Overview

**HS-CI provides automated enforcement of Python coding standards.**

**Benefits:**
- Zero configuration (opinionated defaults)
- Fast feedback (catches issues before commit)
- Consistent quality across projects
- Blocks common mistakes (PEP 8, security, dead code)

**Philosophy:** Automation over documentation.

---

## Quick Start

### Setup

```bash
# Bootstrap project (one-time)
./ci/bootstrap install

# Installs:
# - ci-local/.venv with CI tools (pytest, ruff, black, etc.)
# - Git hooks (commit-msg, optional pre-commit)
# - Configuration files
```

### Run Checks

```bash
./ci/run test                # Full test suite + all checks
./ci/run test --no-coverage  # Skip coverage
ruff check src/              # Linting only
black --check src/           # Formatting only
```

### Pre-commit Hooks (Optional)

```bash
./ci/bootstrap --install     # Installs hooks

# Hooks run automatically before each commit:
# - Black (formatting)
# - Ruff (linting + import sorting via I rules)
# - pyright (type checking, warnings only)
```

---

## Automated Checks

### Check Matrix

**All checks run via `./ci/run test`:**

| Tool | Checks | Blocking? | Auto-fix? |
|------|--------|-----------|-----------|
| **ruff** | PEP 8, import sorting (I rules), naming, unused code | ✅ Yes | ✅ `--fix` |
| **black** | Code formatting (88 char, quotes) | ✅ Yes | ✅ Auto |
| **pyright** | Type checking | ⚠️ Warnings | ❌ No |
| **bandit** | Security (medium/high) | ✅ Yes | ❌ No |
| **vulture** | Dead code | ✅ Yes | ❌ No |
| **pytest** | Test suite | ✅ Yes | ❌ No |
| **coverage** | Coverage (80% min) | ✅ Yes | ❌ No |

### Environment Variables

**Skip checks (NOT recommended):**

```bash
CI_SKIP_LINT=1 ./ci/run test       # Skip linting
CI_SKIP_COVERAGE=1 ./ci/run test   # Skip coverage
CI_SKIP_TESTS=1 ./ci/run build     # Skip tests
```

**Override settings:**

```bash
CI_COVERAGE_MIN=90 ./ci/run test          # Require 90% coverage
CI_COVERAGE_SOURCE=lib ./ci/run test      # Different source dir
```

---

## Tool Details

### Ruff - Fast Python Linter

Extremely fast Python linter (Rust) replacing Flake8, isort, pydocstyle, pyupgrade, and 50+ tools. **10-100x faster** than Flake8.

**Replaces isort:** Ruff's **I rules** handle import sorting (I001: unsorted imports, I002: missing import)

**Usage:**
```bash
ruff check src/              # Check (includes import sorting)
ruff check --fix src/        # Auto-fix (including imports)
ruff check --explain I001    # Explain import sorting rule
```

**Common Rules:**
- **E/W:** PEP 8 errors/warnings
- **F:** Logic errors (F401 unused import, F841 unused variable)
- **I:** Import sorting (I001 unsorted, I002 missing) - **replaces isort**
- **N:** Naming conventions
- **UP:** Modern syntax (UP006 use `list[X]`, UP007 use `X | Y`)

**Configuration:**
```toml
[tool.ruff]
line-length = 88
select = ["E", "F", "I", "N", "UP"]  # I rules = import sorting
ignore = ["E501"]  # Black handles line length

[tool.ruff.per-file-ignores]
"__init__.py" = ["F401"]
"tests/*" = ["F401", "F811"]
```

**HS-CI defaults:** 88 char, E/F/I/N/UP rules, E501 ignored

### Black - Code Formatter

Opinionated Python formatter with zero configuration. "Any color you like, as long as it's Black."

**Usage:**
```bash
black src/                   # Format
black --check src/           # Check only
black --diff src/            # Show changes
```

**Opinions:** 88 char lines, double quotes `"`, trailing commas in multi-line, consistent spacing

**Example:**
```python
# Before: def my_function(arg1,arg2): return {'key':'value'}
# After:  def my_function(arg1, arg2): return {"key": "value"}
```

**Configuration:**
```toml
[tool.black]
line-length = 88
target-version = ['py39', 'py310', 'py312']
```

**Benefits:** No bikeshedding, consistent formatting, diffs focus on logic

### pyright - Type Checker

Fast Python type checker from Microsoft. **10-100x faster** than mypy.

**Usage:**
```bash
pyright src/                 # Check types
```

**HS-CI behavior:** Warnings only (gradual adoption, not blocking)

**Configuration:**
```toml
[tool.pyright]
pythonVersion = "3.9"
typeCheckingMode = "basic"  # HS-CI default

# Optional strict mode:
# typeCheckingMode = "strict"
# reportMissingTypeStubs = false
```

### Bandit - Security Scanner

Scans for SQL injection, hardcoded secrets, insecure crypto, `eval()`, shell injection, weak hashing.

**Usage:**
```bash
bandit -r src/               # Scan
bandit -r src/ -ll           # Medium/high only
```

**Common Issues:**
```python
# B101: assert user.is_admin  # ❌ Use if/raise instead
# B303: hashlib.md5(password)  # ❌ Use bcrypt
# B602: subprocess.run(cmd, shell=True)  # ❌ Command injection
```

**Configuration:**
```toml
[tool.bandit]
skips = ["B101"]  # Skip assert warnings
```

**HS-CI defaults:** Medium/high severity, blocking

### Vulture - Dead Code Detector

Finds unused imports, variables, functions, classes, and unreachable code.

**Usage:**
```bash
vulture src/                      # Find dead code
```

**Configuration:**
```toml
[tool.vulture]
min_confidence = 80
paths = ["src"]
```

**False positives:** Flask/FastAPI routes, pytest fixtures, abstract methods. Whitelist via `vulture_whitelist.py`:
```python
app.route
pytest_plugins
```

### Pytest - Test Framework

De facto standard Python testing. Simple assertions, fixtures, parametrized tests, detailed failure reports.

**Usage:**
```bash
pytest                                 # All tests
pytest --cov=src --cov-report=term-missing  # With coverage
pytest -v                              # Verbose
pytest -x                              # Stop on first failure
```

**Configuration:**
```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-v --strict-markers"
```

**HS-CI defaults:** 80% coverage, blocking

### Coverage - Test Coverage

Measures line coverage, branch coverage, and missing lines.

**Usage:**
```bash
pytest --cov=src --cov-report=term-missing  # With missing lines
pytest --cov=src --cov-report=html          # HTML report
```

**Configuration:**
```toml
[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*"]

[tool.coverage.report]
fail_under = 80
show_missing = true
```

**Override:** `CI_COVERAGE_MIN=90 ./ci/run test`

---

## HS-CI Workflow

### Development Workflow

**Recommended:**

1. Write code (with type hints and docstrings)
2. Run `./ci/run test` (catches issues early)
3. Fix failures (linting, typing, tests)
4. Commit (pre-commit hooks run if enabled)
5. Push (CI/CD runs full checks)

### Pre-commit Hooks

**Optional but recommended:**

```bash
./ci/bootstrap --install     # Install hooks

# Hooks run before each commit:
# 1. Black - Auto-format
# 2. Ruff - Lint + import sorting (I rules)
# 3. pyright - Type check (warnings only)

# Skip hooks (emergency)
git commit --no-verify
```

**Benefits:** Immediate feedback, cleaner history, faster iteration

**Drawbacks:** Slightly slower commits (~2-5 seconds), bypassable

**Recommendation:** Use for active development, skip for trivial changes.

### CI/CD Pipeline

**GitHub Actions integration:**

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Bootstrap
        run: ./ci/bootstrap --install
      - name: Run tests
        run: ./ci/run test
```

**CI checks:** All linting, type checking, security, dead code, tests + coverage

**Blocking:** CI must pass before merge to main.

---

## HS-CI + AI Code Assistants

**HS-CI catches AI mistakes:** Missing type hints, PEP 8 violations, security issues, unused code, incomplete coverage.

**Workflow:**
1. Write type hints/docstrings
2. AI suggests implementation
3. Run `./ci/run test`
4. Fix failures
5. Human review

**Example:**
```python
# 1. Write signature
def calculate_discount(price: float, percent: float) -> float:
    """Calculate discounted price."""
    pass

# 2. AI completes
def calculate_discount(price: float, percent: float) -> float:
    if not 0 <= percent <= 100:
        raise ValueError(f"Invalid percent: {percent}")
    return price * (1 - percent / 100)

# 3-5. Test, fix, review
```

**Common AI defects (4x higher than human):** Missing error handling, unused imports, missing type hints, insecure crypto.

---

## Troubleshooting

**Line too long:** `black src/`

**Import sorting issues:** `ruff check --fix src/` (Ruff I rules handle import sorting)

**False positives:** Skip via config (`[tool.bandit] skips = ["B101"]`) or inline (`# nosec B101`)

**Low coverage:** Exclude files via `omit = ["*/deprecated/*"]` in `[tool.coverage.run]`

**Disable checks (NOT recommended):**
- Inline: `# noqa: F403`, `# nosec B303`
- File: `# ruff: noqa`
- Project: `CI_SKIP_LINT=1 ./ci/run test`

---

## Configuration Files

### pyproject.toml

**All tool configuration:**

```toml
[tool.ruff]
line-length = 88
select = ["E", "F", "I", "N", "UP"]
ignore = ["E501"]

[tool.black]
line-length = 88
target-version = ['py39', 'py310', 'py312']

# Ruff handles import sorting via I rules

[tool.pyright]
pythonVersion = "3.9"
typeCheckingMode = "basic"

[tool.bandit]
skips = ["B101"]

[tool.vulture]
min_confidence = 80
paths = ["src"]

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-v --strict-markers"

[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*"]

[tool.coverage.report]
fail_under = 80
show_missing = true
```

### ci-local/ci.yaml

**HS-CI project configuration:**

```yaml
python:
  source_root: "src/mypackage"  # Auto-detected

coverage:
  minimum: 80  # Override default

lint:
  enabled: true  # Disable with false
```

---

## Best Practices

### DO:
- ✅ Run `./ci/run test` before committing
- ✅ Fix linting issues immediately
- ✅ Add type hints to public functions
- ✅ Write tests for new code (80%+ coverage)
- ✅ Accept Black's formatting
- ✅ Use pre-commit hooks for active development
- ✅ Review AI-generated code carefully

### DON'T:
- ❌ Skip checks with CI_SKIP_* (emergency only)
- ❌ Use `# noqa` or `# nosec` without good reason
- ❌ Commit untested code
- ❌ Ignore pyright warnings
- ❌ Fight Black's formatting
- ❌ Disable bandit security checks
- ❌ Trust AI code without running checks

---

## Resources

**HS-CI Documentation:**
- HS-CI GitHub: https://github.com/hypersec-io/hyperci
- Bootstrap guide: `ci/docs/BOOTSTRAP.md`
- Testing guide: `ci/docs/TESTING.md`

**Tool Documentation:**
- Ruff: https://docs.astral.sh/ruff/ (includes I rules for import sorting)
- Black: https://black.readthedocs.io/
- pyright: https://microsoft.github.io/pyright/
- Bandit: https://bandit.readthedocs.io/
- Vulture: https://github.com/jendrikseipp/vulture
- Pytest: https://docs.pytest.org/
- Coverage: https://coverage.readthedocs.io/

**HyperSec Standards:**
- [CODING-STANDARDS-PYTHON.md](../../CODING-STANDARDS-PYTHON.md) - Python standards
- [PEP8-GUIDE.md](PEP8-GUIDE.md) - PEP 8 guide
- [TYPE-HINTS.md](TYPE-HINTS.md) - Type hints best practices

---

**Last Updated:** 2025-11-12
**Version:** v1.1.0
**Status:** Active
