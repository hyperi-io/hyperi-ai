---
name: python-standards
description: Python coding standards using uv, ruff, mypy, and pytest. Use when writing Python code, reviewing Python, or setting up Python projects. Covers project structure, typing, testing, and tooling.
rule_paths:
  - "**/*.py"
detect_markers:
  - "file:pyproject.toml"
  - "file:setup.py"
  - "file:requirements.txt"
  - "file:uv.lock"
  - "deep_file:pyproject.toml"
  - "deep_file:setup.py"
paths:
  - "**/*.py"
---

# Python Standards for HyperI Projects

**Comprehensive Python coding standards for DevOps, DataOps, and DevSecOps projects**

**Minimum Python Version: 3.12+** (other versions supported by exception only)

---

## Quick Reference

**Setup:** `./ci/bootstrap install`
**Dev:** `./ci/run check|test|build|dependency-update`
**Release:** `./ci/run release [--dry-run|--no-push]`

**Common issues:**

- Wrong venv: CI enforces `ci-local/.venv`
- Version: Pre-commit hook prevents corruption
- Coverage: 80% min (ci.yaml)
- Types: Use 3.12+ syntax

---

## Type Hints (Required)

### Modern Syntax (Python 3.12+)

```python
# ✅ Modern (REQUIRED for Python 3.12+)
def process(items: list[str]) -> dict[str, int]: ...
def optional(value: str | None = None) -> str | None: ...
def get_user(user_id: int) -> dict[str, str]:
    return {"id": str(user_id), "name": "Alice"}

# ✅ Python 3.12+ Generic Syntax (use this)
type Point = tuple[float, float]
type UserID = int
type Handler[T] = Callable[[T], None]

def first[T](items: list[T]) -> T | None:
    return items[0] if items else None

class Stack[T]:
    def __init__(self) -> None:
        self._items: list[T] = []

# ❌ Legacy (NEVER use in new code)
from typing import List, Dict, Optional, Union, TypeVar
T = TypeVar("T")
def process(items: List[str]) -> Dict[str, int]: ...
```

### Type Annotations

```python
# Variable annotations for non-obvious types
users: list[User] = []
config: dict[str, Any] = {}

# All public functions need type hints
def calculate_discount(price: float, percent: float) -> float:
    """Calculate discounted price."""
    if not 0 <= percent <= 100:
        raise ValueError(f"Invalid percent: {percent}")
    return price * (1 - percent / 100)
```

### Avoiding Circular Imports

```python
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from myapp.models import User  # Only for type checking

def get_user(user_id: int) -> "User":  # String annotation
    from myapp.models import User  # Runtime import
    return User.get(user_id)
```

---

## Code Quality Tools

**Tools:** ruff (lint + format), mypy/pyright (types), black (format)

```bash
ruff check . && ruff format .   # Lint + format
mypy src/                       # Type check
./ci/run test                   # Full CI suite
```

### HyperI CI Enforcement

| Tool | Checks | Blocking? |
|------|--------|-----------|
| **ruff** | PEP 8, import sorting (I rules), naming, unused code | ✅ Yes |
| **black** | Formatting (88 char, quotes) | ✅ Yes |
| **pyright** | Type checking | ⚠️ Warnings only |
| **bandit** | Security issues (medium/high) | ✅ Yes |
| **vulture** | Dead code | ✅ Yes |

---

## Package Structure

```text
myproject/
├── src/mypackage/
│   ├── __init__.py      # __version__ synced
│   └── module.py
├── tests/
│   ├── unit/            # Fast, isolated
│   ├── integration/     # Component integration
│   └── e2e/             # End-to-end
├── pyproject.toml       # version synced
├── VERSION              # Source of truth
└── uv.lock              # Commit this
```

**src/ layout:** Forces installation, prevents working directory imports

---

## Dependencies (uv)

**uv is REQUIRED for all Python work.** Both humans and AI assistants must use uv instead of native Python commands.

### uv-First Policy

| Task | Use | NOT |
|------|-----|-----|
| Create venv | `uv venv` | `python -m venv` |
| Install deps | `uv sync` | `pip install -r` |
| Add package | `uv add <pkg>` | `pip install <pkg>` |
| Add dev dep | `uv add --dev <pkg>` | `pip install <pkg>` |
| Run script | `uv run python script.py` | `python script.py` |
| Run module | `uv run -m pytest` | `python -m pytest` |
| Update lock | `uv lock` | `pip-compile` |
| Show deps | `uv tree` | `pip list` |

### Common Commands

```bash
uv venv                        # Create virtual environment
uv sync --locked               # Install from lock file
uv add <pkg>                   # Add runtime dependency
uv add --dev <pkg>             # Add dev dependency
uv remove <pkg>                # Remove dependency
uv lock                        # Update lock file
uv run python script.py        # Run with project deps
uv run -m pytest               # Run module with deps
./ci/run dependency-update     # CI wrapper for lock update
```

### When Native Python is Acceptable

Only use native `python` or `pip` when:

- Working on external projects that don't use uv
- Modifying/extending third-party codebases
- System-level scripts outside project context
- No alternative exists (rare)

For HyperI projects, **always use uv**.

---

## PEP 8 Naming Conventions

### Variables and Functions

```python
# ✅ Good - snake_case
user_count = 0
def calculate_total(items):
    pass

# ❌ Bad
userCount = 0  # camelCase
TotalPrice = 100.0  # PascalCase
```

### Classes

```python
# ✅ Good - PascalCase
class UserProfile:
    pass

class HTTPClient:  # Acronyms stay uppercase
    pass

# ❌ Bad
class user_profile:  # snake_case
    pass
```

### Constants

```python
# ✅ Good - UPPER_SNAKE_CASE
MAX_RETRIES = 3
API_TIMEOUT = 30

# ❌ Bad
max_retries = 3  # Looks like variable
```

### Private Members

```python
class MyClass:
    def __init__(self):
        self._internal = 0  # Private (convention)

    def _helper(self):  # Private method
        pass

    def public(self):
        return self._helper()
```

---

## Formatting and Indentation

### Indentation

**Always 4 spaces (NEVER tabs):**

```python
# ✅ Good
def my_function():
    if condition:
        do_something()

# ❌ Bad
def my_function():
  if condition:  # 2 spaces
	do_something()  # Tab
```

### Line Length

**88 characters (Black default):**

```python
# ✅ Good - break at logical points
result = some_function(
    argument1,
    argument2,
    argument3,
)

config = {
    "database": "postgresql",
    "host": "localhost",
    "port": 5432,
}

# ✅ Good - chained methods
result = (
    dataframe
    .filter(col("age") > 18)
    .select("name", "email")
    .limit(100)
)

# ❌ Bad - too long
result = some_function(argument1, argument2, argument3, argument4, argument5)
```

### Trailing Commas

**Use in multi-line constructs (cleaner diffs):**

```python
# ✅ Good
items = [
    "item1",
    "item2",
    "item3",  # Trailing comma
]
```

---

## Imports

### Import Order

**Three groups (blank line between), alphabetical within:**

```python
# Standard library
import os
import sys
from pathlib import Path

# Third-party
import httpx
import typer
from fastapi import FastAPI

# Local
from hyperi_pylib import logger
from myapp.models import User
```

### Import Styles

```python
# ✅ Good - explicit imports
from pathlib import Path
from typing import Any

# ❌ Bad - wildcard imports
from pathlib import *  # Unclear what's imported
```

**HyperI CI uses Ruff I rules to enforce import order automatically.**

---

## Whitespace

### Operators and Assignments

```python
# ✅ Good
x = 1
z = x + y
func(arg1=1, arg2=2)  # No spaces in kwargs

# ❌ Bad
x=1  # No spaces
func(arg1 = 1)  # Spaces in kwargs
```

### Brackets

```python
# ✅ Good
my_list[0]
my_dict["key"]
{"key": "value"}

# ❌ Bad
my_list[ 0 ]
{"key" : "value"}  # Space before colon
```

### Blank Lines

**Two blank lines between top-level, one between methods:**

```python
import os


def function1():
    pass


class MyClass:
    def method1(self):
        pass

    def method2(self):
        pass
```

---

## Comments and Docstrings

### Inline Comments

**Use sparingly, explain WHY not WHAT:**

```python
# ✅ Good
x = x + 1  # Compensate for border offset

# ❌ Bad
x = x + 1  # Increment x (obvious)
```

### Block Comments

**NEVER number comments (hard to maintain when reordering):**

```python
# ✅ Good
# Two-pass approach: identify candidates, then validate
for item in items:
    if is_candidate(item):
        candidates.append(item)

# ❌ Bad - numbered comments
# 1. Check user
# 2. Validate permissions
```

### Docstrings (PEP 257)

```python
"""User authentication utilities."""  # Module docstring

def calculate_discount(price: float, percent: float) -> float:
    """
    Calculate discounted price.

    Args:
        price: Original price
        percent: Discount percentage (0-100)

    Returns:
        Discounted price

    Raises:
        ValueError: If percent is invalid
    """
    if not 0 <= percent <= 100:
        raise ValueError(f"Invalid percent: {percent}")
    return price * (1 - percent / 100)


class User:
    """
    User account representation.

    Attributes:
        user_id: Unique identifier
        email: Email address
    """
    pass
```

**Use imperative mood:** "Save user" not "Saves user"

---

## Code Style: Clarity Over Cleverness

### Principles

- Break down compound operations into clear steps
- Use intermediate variables with descriptive names
- Comments explain WHY, not WHAT
- Avoid dense lambdas and nested comprehensions

### Examples

**❌ Bad (dense, hard to follow):**

```python
result = [x for sublist in [[y**2 for y in range(n) if y % 2] for n in data] for x in sublist if x > 10]
```

**✅ Good (clear, maintainable):**

```python
# Filter data and square odd numbers above threshold
result = []
for n in data:
    odd_numbers = [y for y in range(n) if y % 2]
    squared = [y**2 for y in odd_numbers]
    result.extend([x for x in squared if x > 10])
```

**❌ Bad (unexplained logic):**

```python
if (a and b) or (c and not d):
    process()
```

**✅ Good (explained logic):**

```python
# Process if: (both conditions met) OR (special case without override)
both_conditions_met = a and b
special_case_without_override = c and not d
if both_conditions_met or special_case_without_override:
    process()
```

**❌ Bad (dense lambda chain):**

```python
result = list(map(lambda x: x[1], filter(lambda x: x[0] > 10, data)))
```

**✅ Good (clear steps):**

```python
# Extract values where threshold exceeded
filtered = [item for item in data if item[0] > 10]
result = [value for _, value in filtered]
```

### When Comprehensions Are OK

```python
# ✅ Simple single-level is fine
squares = [x**2 for x in range(10)]
names = [user.name for user in users]

# ❌ Avoid nested/complex - break into explicit loops
```

---

## Security Standards

### Bandit Thresholds

**Severity:** Medium/High enforced (fails CI)

```bash
bandit -r src/ -ll  # Medium/high only
```

### Dependency Scanning

**pip-audit:** Scans deps against CVE database, fails on vulnerabilities

### Common Security Issues

```python
# ❌ Bad - SQL injection
query = f"SELECT * FROM users WHERE id = {user_id}"

# ✅ Good - parameterized
query = "SELECT * FROM users WHERE id = %s"
cursor.execute(query, (user_id,))

# ❌ Bad - generic exception swallowing
try:
    do_something()
except Exception:
    pass

# ✅ Good - specific exception handling
try:
    do_something()
except ValueError as e:
    logger.warning(f"Invalid value: {e}")
    raise
```

---

## Temporary Files

### Development/CI Work

**Use `./.tmp/` for project-scoped temp operations:**

- Test projects, build artifacts, scratch files, CI work

### Production/Runtime Code

**Use Python tempfile module (NEVER hardcode /tmp):**

```python
import tempfile

# Temporary file (auto-cleanup)
with tempfile.NamedTemporaryFile(delete=True, suffix=".dat") as tmp:
    tmp.write(data)
    process(tmp.name)
# File auto-deleted, secure permissions, random name

# Temporary directory (auto-cleanup)
with tempfile.TemporaryDirectory(prefix="myapp-") as tmpdir:
    work_in(tmpdir)
# Directory + contents auto-deleted

# Persistent app temp directory
from pathlib import Path
app_temp = Path(tempfile.gettempdir()) / app_name
app_temp.mkdir(exist_ok=True, mode=0o700)  # User-only
```

### Security Rules

❌ **NEVER:** Hardcode "/tmp", use predictable names, skip cleanup
✅ **ALWAYS:** Use context managers, random names, 0o700 permissions

---

## Ruff Configuration

```toml
# pyproject.toml
[tool.ruff]
line-length = 88
select = ["E", "F", "I", "N", "UP"]
ignore = ["E501"]  # Black handles line length

[tool.ruff.lint.isort]
force-single-line = false
```

**Common rule series:**

- **E/W:** PEP 8 errors
- **F:** Logic errors (unused imports, undefined names)
- **I:** Import sorting (replaces isort)
- **N:** Naming conventions
- **UP:** Modern syntax upgrades

---

## Black Formatting

**Black** is opinionated, zero-config formatting.

**Settings:** 88 chars, double quotes, trailing commas, consistent spacing

```bash
black src/            # Format
black --check src/    # Check only
```

**Accept Black's formatting** - no bikeshedding, consistent team style

---

## Configuration and Logging (hyperi-pylib)

**Python uses hyperi-pylib for zero-config cascade and logging.**

### Configuration Cascade

```python
# Zero-config - cascade is AUTOMATIC via Dynaconf
from hyperi_pylib.config import settings

# Direct attribute access (Pythonic)
host = settings.database.host         # Cascade automatic!
port = settings.database.port         # ENV > .env > files > defaults

# Dict-style with fallback
host = settings.get("database.host", "localhost")
timeout = settings.get("api.timeout", 30)
```

**ENV Key Auto-Generation:**

```text
database.host         → MYAPP_DATABASE_HOST
api.timeout           → MYAPP_API_TIMEOUT
```

### Logging

```python
# Zero-config logging with RFC 3339, sensitive masking, auto-detect console
from hyperi_pylib import logger

logger.info("Processing", user_id=123)
logger.error("Failed", error=str(e), exc_info=True)
```

**Console (dev):** Solarized colours, emojis for levels
**Container/CI:** RFC 3339 JSON, ASCII-only

### hyperi-pylib Imports

| Need | Import |
|------|--------|
| Logging | `from hyperi_pylib import logger` |
| Config | `from hyperi_pylib.config import settings` |
| Runtime paths | `from hyperi_pylib import get_runtime_paths` |
| Database URLs | `from hyperi_pylib import build_database_url` |
| Metrics | `from hyperi_pylib import create_metrics` |
| CLI | `from hyperi_pylib import Application` |

**Why:** Zero-config, container-aware, production-ready, ENV-based

---

## Modern Patterns

### Dataclasses

```python
from dataclasses import dataclass, field

@dataclass
class User:
    id: int
    name: str
    email: str
    active: bool = True
    tags: list[str] = field(default_factory=list)
```

### Pydantic (Validation)

```python
from pydantic import BaseModel, EmailStr, field_validator

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    age: int

    @field_validator("age")
    @classmethod
    def validate_age(cls, v: int) -> int:
        if v < 18:
            raise ValueError("Must be 18+")
        return v
```

### Async/Await

```python
import asyncio
import httpx

async def fetch_user(user_id: int) -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.get(f"/users/{user_id}")
        response.raise_for_status()
        return response.json()

# Run multiple requests concurrently
async def fetch_all(ids: list[int]) -> list[dict]:
    return await asyncio.gather(*[fetch_user(id) for id in ids])
```

---

## Commit Types

**Standard conventional commits (no Python-specific):**

- `fix:` - Fixes, improvements, refactors (PATCH)
- `feat:` - New features (MINOR)
- `perf:` - Performance improvements (PATCH)
- `docs:`, `test:`, `chore:` - No version bump

---

## Resources

**Official PEPs:**

- PEP 8 - Style Guide: <https://peps.python.org/pep-0008/>
- PEP 257 - Docstrings: <https://peps.python.org/pep-0257/>
- PEP 484 - Type Hints: <https://peps.python.org/pep-0484/>

**Tools:**

- Black: <https://black.readthedocs.io/>
- Ruff: <https://docs.astral.sh/ruff/>
- pyright: <https://microsoft.github.io/pyright/>

---

## For AI Code Assistants

The following sections are specific guidance for AI code assistants working with Python.

---

## Mock-Aware Testing Policy

**Mocks are scaffolding, not testing. Mock-only tests ≠ production tested.**

| Mock Target | In Unit Tests? | Integration Test Required? |
|-------------|---------------|---------------------------|
| Internal functions/classes | ❌ Never mock | N/A — test real code |
| External APIs, DBs, K8s, network | ✅ Yes | ✅ Yes — against sandbox/testcontainers |

```python
# ❌ BAD - mocking internal code (tests nothing real)
with patch('myapp.utils.calculate') as m: ...

# ✅ GOOD - mock external boundary, test real internal logic
with patch('myapp.clients.stripe.charge') as m: ...
```

**Two-layer requirement:** Unit tests (mocks OK for external boundaries) + integration tests (no mocks).

**Production code must be complete:** No TODOs, no `return True` placeholders, no `except: pass`.

---

## AI Pitfalls to Avoid

**Before generating Python code, check these patterns:**

### DO NOT Generate

```python
# ❌ Old typing imports (Python 3.12+ - NEVER use)
from typing import List, Dict, Optional  # WRONG - deprecated
# ✅ Use built-in types (Python 3.12+)
list[str], dict[str, int], str | None    # CORRECT

# ❌ Generic exception swallowing
except Exception:
    pass  # WRONG - hides bugs
# ✅ Specific exception handling
except ValueError as e:
    logger.error("Invalid input", error=str(e))
    raise

# ❌ Mutable default arguments
def process(items=[]):  # WRONG - shared mutable state
# ✅ Use None default
def process(items: list[str] | None = None):
    items = items or []

# ❌ f-string SQL (injection risk)
query = f"SELECT * FROM users WHERE id = {user_id}"  # WRONG
# ✅ Parameterised queries
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))

# ❌ eval/exec with any external input
result = eval(user_expression)  # NEVER
# ✅ Use ast.literal_eval for data, or don't
result = ast.literal_eval(user_data)  # Only for literals

# ❌ Pickle for untrusted data
data = pickle.loads(user_bytes)  # NEVER - RCE risk
# ✅ Use JSON
data = json.loads(user_string)
```

### Package Verification Required

Before suggesting any import, verify the package exists:

```python
# ❌ These are common AI hallucinations:
from pydantic_ai import ...       # DOES NOT EXIST
from fastapi_utils import ...     # Often wrong
from sqlalchemy_utils import ...  # Check version

# ✅ When uncertain, use standard library or well-known packages:
# stdlib: pathlib, json, dataclasses, typing, asyncio
# well-known: pydantic, sqlalchemy, httpx, pytest
```

### Async Patterns

```python
# ❌ Missing await
async def fetch():
    response = httpx.get(url)  # WRONG - blocking call
# ✅ Async client with await
async def fetch():
    async with httpx.AsyncClient() as client:
        response = await client.get(url)

# ❌ Running async in sync context
result = asyncio.run(coro())  # In already async context - WRONG
# ✅ Check context first
result = await coro()  # If already in async
# or
result = asyncio.run(coro())  # Only from sync entrypoint
```
