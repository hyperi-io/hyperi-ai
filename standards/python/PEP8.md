# PEP 8 Comprehensive Guide

**Complete Python style guide for HyperSec projects**

**Official:** https://peps.python.org/pep-0008/ (current standard 2024-2025)
**Enforcement:** Automated via HS-CI (Ruff, Black, isort)

---

## Naming Conventions

### Variables and Functions

**Use `snake_case`:**

```python
# ✅ Good
user_count = 0
def calculate_total(items):
    pass

# ❌ Bad
userCount = 0  # camelCase
TotalPrice = 100.0  # PascalCase
def CalculateTotal(items):  # PascalCase
    pass
```

### Classes

**Use `PascalCase`:**

```python
# ✅ Good
class UserProfile:
    pass

class HTTPClient:  # Acronyms stay uppercase
    pass

# ❌ Bad
class user_profile:  # snake_case
    pass
```

### Constants

**Use `UPPER_SNAKE_CASE`:**

```python
# ✅ Good
MAX_RETRIES = 3
API_TIMEOUT = 30

# ❌ Bad
max_retries = 3  # Looks like variable
```

### Private Members

**Use `_` prefix for internal/private members:**

```python
class MyClass:
    def __init__(self):
        self._internal = 0  # Private variable

    def _helper(self):  # Private method
        pass

    def public(self):
        return self._helper()
```

**Use `__` prefix for name mangling (rare, special cases only):**

```python
self.__very_private = 0  # Becomes _MyClass__very_private
```

### Module and Package Names

**Use short, lowercase names (underscores if needed):**

```python
# ✅ Good
import mypackage, utils, data_processing

# ❌ Bad
import MyPackage  # PascalCase
```

---

## Indentation and Line Length

### Indentation

**Always 4 spaces (NEVER tabs):**

```python
# ✅ Good
def my_function():
    if condition:
        do_something()

# ❌ Bad - 2 spaces or tabs
def my_function():
  if condition:  # 2 spaces
	do_something()  # Tab
```

**Editor config:** 4-space tabs, show whitespace, auto-remove trailing

### Line Length

**PEP 8:** 79 chars | **Black:** 88 chars (HyperSec default, optimal for modern screens)

**Break at logical points:**

```python
# ✅ Good - function arguments
result = some_function(
    argument1,
    argument2,
    argument3,
)

# ✅ Good - list/dict
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

# ✅ Good - long strings
message = (
    "This is a very long message that needs to be "
    "split across multiple lines for readability."
)
```

```python
# ❌ Bad - exceeds line length or inconsistent breaking
result = some_function(argument1, argument2, argument3, argument4, argument5)
result = some_function(argument1, argument2,
    argument3)  # Inconsistent
```

---

## Imports

### Import Order

**Three groups (blank line between), alphabetical within:**

1. Standard library
2. Third-party packages
3. Local application

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
from hyperlib import logger
from myapp.models import User
```

```python
# ❌ Bad
import os
from myapp.models import User  # Mixed groups
import httpx
import sys
from hyperlib import logger
```

**HS-CI uses Ruff I rules to enforce this automatically.**

### Import Styles

**Prefer explicit imports:**

```python
# ✅ Good
from pathlib import Path
from typing import Optional, List

path = Path("file.txt")
users: List[User] = []
```

```python
# ❌ Bad
from pathlib import *  # Wildcard imports (unclear what's imported)
import pathlib
path = pathlib.Path("file.txt")  # Verbose
```

**Exception:** `import module` acceptable for stdlib (`import json, os`)

### Avoid Circular Imports

**Use TYPE_CHECKING for type hints only:**

```python
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from myapp.models import User  # Only imported for type checking

def get_user(user_id: int) -> "User":  # String annotation
    from myapp.models import User  # Import at runtime when needed
    return User.get(user_id)
```

---

## Whitespace

### Operators and Assignments

**Spaces around binary operators, not in kwargs:**

```python
# ✅ Good
x = 1
z = x + y
func(arg1=1, arg2=2)  # No spaces in kwargs

# ❌ Bad
x=1  # No spaces
func(arg1 = 1)  # Spaces in kwargs
```

### Brackets and Parentheses

**No spaces inside brackets, no space before colons:**

```python
# ✅ Good
my_list[0]
my_dict["key"]
{"key": "value"}

# ❌ Bad
my_list[ 0 ]
{"key" : "value"}  # Space before :
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

# ❌ Bad
items = ["item1", "item2", "item3"]  # No trailing comma
```

### Blank Lines

**Two blank lines between top-level, one between methods:**

```python
# ✅ Good
import os


def function1():
    pass


class MyClass:
    def method1(self):
        pass

    def method2(self):
        pass
```

**No trailing whitespace** (configure editor to auto-remove)

---

## Comments

### Inline Comments

**Use sparingly, explain WHY not WHAT. Two spaces before:**

```python
# ✅ Good
x = x + 1  # Compensate for border offset

# ❌ Bad
x = x + 1  # Increment x (obvious)
x = 1 # Only one space
```

### Block Comments

**Use for complex sections. NEVER number comments (hard to maintain):**

```python
# ✅ Good - explains algorithm
# Two-pass approach: identify candidates, then validate
for item in items:
    if is_candidate(item):
        candidates.append(item)

# ❌ Bad - numbered comments
# 1. Check user
# 2. Validate permissions
```

---

## PEP 257 Docstring Conventions

### Module, Function, and Class Docstrings

**All public modules, functions, and classes need docstrings:**

```python
"""User authentication utilities."""  # Module

def calculate_discount(price: float, percent: float) -> float:
    """
    Calculate discounted price.

    Args:
        price: Original price
        percent: Discount (0-100)

    Returns:
        Discounted price

    Raises:
        ValueError: If percent invalid
    """
    if not 0 <= percent <= 100:
        raise ValueError(f"Invalid: {percent}")
    return price * (1 - percent / 100)

def get_count() -> int:
    """Return total count."""  # One-liner for simple functions
    return len(items)

class User:
    """
    User account.

    Attributes:
        user_id: Unique ID
        email: Email address
    """
    pass
```

**Use imperative mood:** "Save user" not "Saves user"

**HS-CI:** `interrogate` enforces docstrings on package projects

---

## Type Hints (PEP 484, 526, 604)

### Function and Variable Annotations

**All public functions need type hints:**

```python
# ✅ Good
def get_user(user_id: int) -> dict[str, str]:
    return {"id": str(user_id), "name": "Alice"}

users: list[User] = []  # Variable annotations for non-obvious types

# ❌ Bad
def get_user(user_id):  # No type hints
    return {}
```

### Modern Syntax (Python 3.10+)

**Use `|` union syntax and built-in generics:**

```python
# ✅ Good (3.10+)
def process(value: int | str) -> list[User]:
    pass

# ✅ Acceptable (3.7-3.9)
from typing import Union, List
def process(value: Union[int, str]) -> List[User]:
    pass
```

**HS-CI:** `pyright` runs type checking (warnings only via `./ci/run test`)

**Benefits:** IDE autocomplete, self-documenting code, catches bugs early

---

## Black Formatting

**Black** is an opinionated zero-config Python formatter.

**Philosophy:** "Any color you like, as long as it's Black"

**Settings:** 88 chars, double quotes, trailing commas, consistent spacing

**Usage:**
```bash
black src/            # Format
black --check src/    # Check only
```

**HS-CI:** Runs automatically in `./ci/run test` and pre-commit hooks

**Accept Black's formatting** - no bikeshedding, consistent team style, logic-focused diffs

---

## Ruff Linting

**Ruff** is an extremely fast Rust-based Python linter.

**Replaces:** Flake8, isort, pydocstyle, pyupgrade, and 50+ other tools

**Common rule series:**
- **E/W:** PEP 8 errors (E101 mixed spaces/tabs, E501 line length, W291 trailing whitespace)
- **F:** Logic errors (F401 unused import, F841 unused variable, F821 undefined name)
- **I:** Import sorting (I001 unsorted imports, I002 missing import) - **replaces isort**
- **N:** Naming (N802 function naming, N806 variable naming)
- **UP:** Modern syntax (UP006 use `list[X]`, UP007 use `X | Y`)

**Usage:**
```bash
ruff check src/           # Check
ruff check --fix src/     # Auto-fix
ruff check --explain F401 # Explain rule
```

**HS-CI:** Runs in `./ci/run test` (blocking)

**Configure in `pyproject.toml`:**
```toml
[tool.ruff]
line-length = 88
select = ["E", "F", "I", "N", "UP"]
ignore = ["E501"]  # Black handles line length
```

---

## HS-CI Enforcement

**All HS-CI Python projects enforce:**

| Tool | Checks | Blocking? |
|------|--------|-----------|
| **ruff** | PEP 8, import sorting (I rules), naming, unused code | ✅ Yes |
| **black** | Formatting (88 char, quotes) | ✅ Yes |
| **pyright** | Type checking | ⚠️ Warnings only |
| **bandit** | Security issues | ✅ Yes |
| **vulture** | Dead code | ✅ Yes |

**Run checks:** `./ci/run test` (full suite) or `ruff check src/` (lint only)

**Pre-commit hooks:** `./ci/bootstrap install` (auto-format, lint, type-check)

**Bypass (emergencies only):** `git commit --no-verify`

---

## Common PEP 8 Violations

**Line too long:** Break at logical points (88 chars)
**Trailing whitespace:** Configure editor to auto-remove
**Incorrect indentation:** Always 4 spaces (never tabs or 2 spaces)
**Missing blank lines:** 2 between top-level, 1 between methods
**Import order:** stdlib → third-party → local (blank lines between)
**Naming:** `snake_case` functions/vars, `PascalCase` classes, `UPPER_SNAKE_CASE` constants

---

## Best Practices Summary

**DO:**
- ✅ 4 spaces indentation, 88 char lines
- ✅ `snake_case` vars/functions, `PascalCase` classes, `UPPER_SNAKE_CASE` constants
- ✅ Type hints on public functions
- ✅ Docstrings for public APIs
- ✅ Group imports (stdlib → third-party → local)
- ✅ Trailing commas in multi-line
- ✅ Run `./ci/run test` before commit

**DON'T:**
- ❌ Tabs or mixed spaces/tabs
- ❌ Wildcard imports (`from x import *`)
- ❌ Numbered code comments
- ❌ Fight Black's formatting
- ❌ Ignore Ruff/pyright warnings

---

## Resources

**Official PEPs:**
- PEP 8 - Style Guide: https://peps.python.org/pep-0008/
- PEP 257 - Docstrings: https://peps.python.org/pep-0257/
- PEP 484 - Type Hints: https://peps.python.org/pep-0484/

**Tools:**
- Black: https://black.readthedocs.io/
- Ruff: https://docs.astral.sh/ruff/ (includes I rules for import sorting)
- pyright: https://microsoft.github.io/pyright/

**HyperSec docs:**
- [CODING-STANDARDS-PYTHON.md](../../CODING-STANDARDS-PYTHON.md) - Python standards overview
- [HYPERCI-INTEGRATION.md](HYPERCI-INTEGRATION.md) - HS-CI tool details

---

**Last Updated:** 2025-11-10
**Version:** v1.0.0
**Status:** Active
