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

> **HyperI Python Philosophy**
>
> Python is for everything that isn't the hot path. If performance matters,
> it's in Rust. Python can't be a pig or sluggish, but we're optimising for
> expressiveness, library ecosystem, and recruitability — not microseconds.
>
> The trade-off: Python's flexibility means decades of "kinda works" code in
> training data. Every AI model will produce outdated patterns. Every Google
> result leads to 2018-era code. The CI and these standards are the guardrails.
>
> **March 2026 update:** Major revision. Post Derek Dump of 5k lines, geez!
> Added hyperi-pylib section, deprecated packages table, production-at-scale
> controls, and bash minimalism rules.

**Minimum Python Version: 3.12+** (lockstep across all projects — update together)

## Table of Contents

1. [Design Philosophy](#hyperi-python-design-philosophy) — why Python, when Rust instead
2. [AI Anti-Patterns](#critical-ai-models-get-python-wrong) — deprecated packages, web-search-first
3. [Quick Reference](#quick-reference) — CI commands
4. [Python 3.12+ Features](#python-312-features-to-use) — generics, walrus, StrEnum, TaskGroup, tomllib
5. [Type Hints](#type-hints-required) — modern syntax, annotations
6. [Code Style](#code-style-clarity-over-cleverness) — naming, formatting, imports, clarity, Google rules
7. [Modern Patterns](#modern-patterns) — dataclasses, Pydantic, Protocols, DI, generators
8. [Async & Concurrency](#async--concurrency) — asyncio, TaskGroup, threading, decision matrix
9. [Container Deployment](#container-deployment-docker--k8s) — Docker, K8s, health checks, shutdown
10. [hyperi-pylib](#hyperi-pylib) — config, logging, metrics, HTTP, Kafka, secrets
11. [Dependencies (uv)](#dependencies-uv) — uv-first, version pinning, update policy
12. [Security](#security-standards) — bandit, SQL injection, secrets
13. [Testing](#testing--no-mocks-policy) — no mocks, testcontainers, fixtures
14. [Production Controls](#production-at-scale--controls) — CI enforcement, exceptions, Nuitka
15. [For AI Assistants](#for-ai-code-assistants) — package verification, slopsquatting, pitfalls
16. [Resources](#resources)

---

## HyperI Python Design Philosophy

> **"Python is for everything that isn't the hot path. It can't be a pig
> or sluggish though."** — Derek

1. **Expressiveness over performance** — leverage Python's huge library ecosystem
   and readable syntax. Hot paths belong in Rust.
2. **Recruitability** — Python is easier to hire for than Rust. Broader staff
   recruitment and outsourcing is a factor. Code must be easy to understand.
3. **Production at hyperscaler size** — but this is still production code running
   at scale. Flexibility without controls catches you in prod.
4. **Promote to hyperi-pylib** — patterns common across projects should be
   considered for promotion into the shared library.
5. **Single version lockstep** — all projects use the same Python version
   (currently 3.12). Update all together to avoid version conflict agony.
6. **uv and Astral tooling** — always use uv and Astral tools (ruff, ty) over
   alternatives unless there is a compelling reason not to.
7. **System utilities: Python 3 + stdlib** — scripts that run bare on an OS
   use only stdlib. Everything else uses uv and .venv.

### What Python Is Used For

- Orchestration and control planes (dfe-engine, dfe-discovery)
- Generalist APIs (FastAPI)
- AI/ML work
- Integration code (not hot path)
- Utilities and tooling (hyperi-ci, deploy scripts)
- System automation (where bash gets complex)

### What Python Is NOT Used For

- Hot path data processing (→ Rust)
- High-throughput ingest pipelines (→ Rust)
- Anything where microsecond latency matters (→ Rust)

### Rust-Python Bridge: PyO3 Bindings

If a Rust crate provides capability that would be useful in Python,
consider a Python binding of the Rust crate (via PyO3/maturin) over a
native Python implementation. You get Rust performance with Python
ergonomics.

Example: `hyperi-pylib` uses `common-expression-language` (CEL via
Rust/PyO3) for expression evaluation — orders of magnitude faster than
a pure Python CEL implementation.

```bash
# Build Rust Python bindings with maturin
uv add maturin --dev
maturin develop  # Build + install in current venv
```

---

## CRITICAL: AI Models Get Python Wrong

> **Web search for EVERY Python library before using it.** AI models are trained
> on decades of Python code. Most of it is outdated, deprecated, or just bad.
> This is WORSE than Rust because there's so much more old Python in training data.

### Deprecated Packages — Do NOT Use

| ❌ Dead / Old | ✅ Use Instead | Why |
|---|---|---|
| `psycopg2` / `psycopg2-binary` | `psycopg[binary]` (psycopg 3) | psycopg2 is legacy, build issues |
| `python-jose` | `joserfc` or `PyJWT` | python-jose is unmaintained |
| `requests` (new async code) | `httpx` | Async, HTTP/2, typed, modern API |
| `flask` (new APIs) | `fastapi` or `litestar` | Async-native, auto-docs, Pydantic |
| `datetime.utcnow()` | `datetime.now(UTC)` | Deprecated since 3.12 |
| `pkg_resources` | `importlib.metadata` | Deprecated, slow startup |
| `distutils` | `setuptools` or `hatchling` | Removed in 3.12 |
| `setup.py` / `setup.cfg` | `pyproject.toml` | PEP 517/518 standard |
| `cgi` / `cgitb` | FastAPI or any ASGI framework | Removed in 3.13 |
| `unittest.mock` (internal) | Real deps (testcontainers) | No mocks policy |
| `asyncio.ensure_future()` | `asyncio.create_task()` | Superseded |
| `typing.List/Dict/Optional` | `list[str]`, `str \| None` | Built-in generics since 3.9+ |
| `os.path` (new code) | `pathlib.Path` | Object-oriented, cleaner API |
| `json.loads(f.read())` | `json.load(f)` | Direct file loading |
| `print()` for logging | `logger.info()` | Structured, maskable, level-aware |
| `subprocess.run(shell=True)` | `subprocess.run([...])` (list args) | Injection risk |
| `pip install` | `uv add` | uv is the standard |
| `python -m venv` | `uv venv` | uv is the standard |
| `requirements.txt` (primary) | `pyproject.toml` + `uv.lock` | Modern packaging |

### Patterns AI Models Always Get Wrong

```python
# ❌ Old typing imports (EVERY model does this)
from typing import List, Dict, Optional, Union, Tuple
# ✅ Built-in generics (Python 3.12+)
list[str], dict[str, int], str | None, tuple[int, ...]

# ❌ Old generic syntax
from typing import TypeVar
T = TypeVar("T")
def first(items: list[T]) -> T | None: ...
# ✅ Python 3.12+ generic syntax
def first[T](items: list[T]) -> T | None: ...

# ❌ datetime.utcnow() (deprecated)
from datetime import datetime
now = datetime.utcnow()
# ✅ Timezone-aware
from datetime import datetime, UTC
now = datetime.now(UTC)

# ❌ requests (blocking, no async)
import requests
r = requests.get("https://api.example.com")
# ✅ httpx (async + sync, HTTP/2, typed)
import httpx
async with httpx.AsyncClient() as client:
    r = await client.get("https://api.example.com")

# ❌ os.path everywhere
import os
path = os.path.join(base_dir, "config", "settings.yaml")
if os.path.exists(path):
    with open(path) as f: ...
# ✅ pathlib
from pathlib import Path
path = Path(base_dir) / "config" / "settings.yaml"
if path.exists():
    data = path.read_text()

# ❌ Bare except / swallowed exceptions
try:
    do_something()
except Exception:
    pass  # NEVER
# ✅ Specific exceptions, always handle
try:
    do_something()
except ValueError as e:
    logger.error("Invalid input", error=str(e))
    raise

# ❌ Mutable default arguments (classic trap)
def process(items=[]):  # Shared mutable state!
# ✅ None default
def process(items: list[str] | None = None):
    items = items or []

# ❌ print() for operational output
print(f"Processing {len(records)} records")
# ✅ Structured logging
logger.info("Processing records", count=len(records))
```

---

## Quick Reference

**Setup:** `uv tool install hyperi-ci && hyperi-ci init`
**Dev:** `hyperi-ci check` (quality + test) or `make check`
**Quality only:** `hyperi-ci check --quick` or `make quality`
**Test:** `hyperi-ci run test` or `make test`
**Build:** `hyperi-ci run build` or `make build`

> See `standards/universal/CI.md` and the
> [hyperi-ci repo](https://github.com/hyperi-io/hyperi-ci) for full
> CLI reference. hyperi-ci evolves frequently — check its docs.

---

## Python 3.12+ Features to Use

### Generic Syntax (3.12+)

```python
# ✅ New syntax (use this)
type Point = tuple[float, float]
type UserID = int

def first[T](items: list[T]) -> T | None:
    return items[0] if items else None

class Stack[T]:
    def __init__(self) -> None:
        self._items: list[T] = []
```

### Match/Case (3.10+)

```python
match command:
    case {"action": "create", "name": str(name)}:
        create_resource(name)
    case {"action": "delete", "id": int(id)}:
        delete_resource(id)
    case _:
        raise ValueError(f"Unknown command: {command}")
```

### Walrus Operator `:=` (3.8+, but underused)

```python
# ❌ Compute twice or use temp variable
results = get_results()
if results:
    process(results)

# ✅ Assign and test in one expression
if results := get_results():
    process(results)

# ✅ In while loops
while chunk := f.read(8192):
    process(chunk)

# ✅ In comprehensions with filter
valid = [y for x in data if (y := transform(x)) is not None]
```

### StrEnum (3.11+)

```python
from enum import StrEnum

class Status(StrEnum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETE = "complete"
    FAILED = "failed"

# Works directly as string — no .value needed
status = Status.RUNNING
assert status == "running"  # True
assert f"Status: {status}" == "Status: running"
```

### ExceptionGroup and TaskGroup (3.11+)

```python
import asyncio

async def process_batch(items: list[str]) -> list[str]:
    """Process items concurrently — collect ALL errors, not just first."""
    results = []
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(process(item)) for item in items]
    # All tasks complete or ALL exceptions raised as ExceptionGroup
    return [t.result() for t in tasks]

# Handle exception groups
try:
    await process_batch(items)
except* ValueError as eg:
    for exc in eg.exceptions:
        logger.error("Validation failed", error=str(exc))
except* ConnectionError as eg:
    logger.error("Connection failures", count=len(eg.exceptions))
```

Use `TaskGroup` over raw `asyncio.gather()` — it cancels remaining tasks
on first failure and collects all exceptions via `ExceptionGroup`.

### tomllib (3.11+ stdlib)

```python
import tomllib

# ✅ Read TOML files without external deps
with open("pyproject.toml", "rb") as f:
    config = tomllib.load(f)

version = config["project"]["version"]
```

No need for `toml` or `tomli` packages for reading — `tomllib` is in stdlib.
For writing TOML, use `tomli-w`.

### Template Strings (3.14, when we adopt)

```python
# t-strings produce Template objects, not strings — safe for SQL/HTML
from string.templatelib import Template
query = t"SELECT * FROM users WHERE id = {user_id}"
# query is a Template, not a string — can be escaped before execution
```

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

Sourced from HyperI experience + [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html).

### Principles

- Break down compound operations into clear steps
- Use intermediate variables with descriptive names
- Comments explain WHY, not WHAT
- Avoid dense lambdas and nested comprehensions

### Google-Sourced Rules (adopted)

```python
# ✅ Use `is` for None, True, False comparisons
if value is None: ...       # ✅ Correct
if value == None: ...       # ❌ Wrong (can be overridden by __eq__)
if flag is True: ...        # ✅ Explicit bool check
if flag: ...                # ✅ Also fine for truthiness

# ✅ No mutable global state
CACHE = {}                  # ❌ Mutable global — breaks testability
_cache: dict[str, Any] = {} # ❌ Still mutable global

# ✅ Use module-level functions or dependency injection instead
def get_cache() -> dict[str, Any]:
    return {}  # Or inject via parameter

# ✅ Minimise try/except scope — catch only what you expect
try:                        # ❌ Too broad — hides bugs
    data = load_config()
    result = process(data)
    save(result)
except Exception:
    pass

try:                        # ✅ Minimal scope
    data = load_config()
except FileNotFoundError:
    data = default_config()
result = process(data)

# ✅ No semicolons — ever
x = 1; y = 2               # ❌ Never
x = 1                      # ✅ One statement per line
y = 2

# ✅ Properties over get/set methods
class User:
    @property
    def full_name(self) -> str:        # ✅ Pythonic
        return f"{self.first} {self.last}"

    def get_full_name(self) -> str:    # ❌ Java-style
        return f"{self.first} {self.last}"

# ✅ Threading warning — prefer async or multiprocessing
# Python threads do NOT provide parallelism for CPU work (GIL)
# Use threads ONLY for I/O-bound concurrency with external services
# For CPU parallelism: multiprocessing, concurrent.futures, or Rust

# ✅ No "power features" — avoid metaclasses, __getattr__ hacks,
# dynamic code generation, bytecode manipulation, sys._getframe.
# These make code impossible to understand, grep, and debug.
class MyMeta(type): ...     # ❌ Almost never justified
type("Dyn", (Base,), {})    # ❌ Dynamic class creation
exec(code_string)           # ❌ Never with external input

# ✅ Comprehensions: ONE clause max. No nesting.
[x**2 for x in range(10)]                    # ✅ Single clause
[name for user in users if user.active       # ❌ Two clauses —
      for name in user.aliases]              #    use explicit loop

# ✅ Default arguments must be IMMUTABLE
def bad(items: list = []):             # ❌ Mutable default
    items.append(1)                    #    shared across calls!

def good(items: list | None = None):   # ✅ None default
    items = items if items is not None else []

def also_good(count: int = 0):         # ✅ Immutable types are fine
    ...

def with_tuple(dims: tuple = (64, 64)):  # ✅ Tuples are immutable
    ...

# ✅ Import modules, not individual classes/functions
import os                              # ✅ Import module
from os import path                    # ❌ Avoid (Google rule)
path.exists("/tmp")                    # ❌ Unclear where path comes from
os.path.exists("/tmp")                 # ✅ Origin is obvious

# Exception: well-known short imports are fine
from pathlib import Path               # ✅ Widely understood
from typing import Protocol            # ✅ Standard pattern
from dataclasses import dataclass      # ✅ Standard pattern
from collections.abc import Iterator   # ✅ Standard pattern
```

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

## Modern Patterns

### Dataclasses (with slots and frozen)

```python
from dataclasses import dataclass, field

# ✅ Use slots=True for memory efficiency (no __dict__)
@dataclass(slots=True)
class User:
    id: int
    name: str
    email: str
    active: bool = True
    tags: list[str] = field(default_factory=list)

# ✅ Use frozen=True for immutable value objects
@dataclass(frozen=True, slots=True)
class EventKey:
    source: str
    event_type: str
    timestamp: float
    # Hashable — can be used as dict key or set member
```

### Generators for Lazy Processing

```python
# ✅ Process large files without loading into memory
def read_events(path: Path):
    with path.open() as f:
        for line in f:
            if line.strip():
                yield json.loads(line)

# ✅ Chain generators for pipelines
def pipeline(path: Path):
    events = read_events(path)
    valid = (e for e in events if e.get("type"))
    enriched = (enrich(e) for e in valid)
    for batch in itertools.batched(enriched, 1000):
        send_batch(batch)
```

### functools.singledispatch

```python
from functools import singledispatch

@singledispatch
def serialize(obj) -> str:
    raise TypeError(f"Cannot serialize {type(obj)}")

@serialize.register
def _(obj: dict) -> str:
    return json.dumps(obj)

@serialize.register
def _(obj: datetime) -> str:
    return obj.isoformat()

@serialize.register
def _(obj: Path) -> str:
    return str(obj)
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

### Pydantic Settings (Configuration)

```python
from pydantic_settings import BaseSettings

class AppSettings(BaseSettings):
    database_host: str = "localhost"
    database_port: int = 5432
    api_key: str  # Required — no default

    model_config = {"env_prefix": "MYAPP_"}

# Reads from MYAPP_DATABASE_HOST, MYAPP_API_KEY, etc.
settings = AppSettings()
```

Note: For HyperI projects, use `hyperi_pylib.config.settings` instead — it
provides a richer 8-layer cascade. Pydantic settings is for non-HyperI projects.

### Protocols (Structural Typing)

```python
from typing import Protocol

class Sendable(Protocol):
    def send(self, data: bytes) -> None: ...

class KafkaProducer:
    def send(self, data: bytes) -> None: ...

class HttpSender:
    def send(self, data: bytes) -> None: ...

# Both work — no inheritance needed, just matching interface
def dispatch(sender: Sendable, payload: bytes) -> None:
    sender.send(payload)
```

Use `Protocol` over `ABC` for interface definitions. It's structural (duck
typing with type checking) rather than nominal (requires inheritance).

### FastAPI Dependency Injection

```python
from fastapi import FastAPI, Depends
from typing import Annotated

app = FastAPI()

async def get_db():
    db = await connect_db()
    try:
        yield db
    finally:
        await db.close()

DB = Annotated[Database, Depends(get_db)]

@app.get("/users/{user_id}")
async def get_user(user_id: int, db: DB) -> User:
    return await db.fetch_user(user_id)
```

### Context Managers

```python
from contextlib import contextmanager, asynccontextmanager

@contextmanager
def managed_connection(url: str):
    conn = connect(url)
    try:
        yield conn
    finally:
        conn.close()

# Usage — cleanup guaranteed even on exception
with managed_connection("postgres://...") as conn:
    conn.execute(query)

# Async version
@asynccontextmanager
async def managed_session():
    session = await create_session()
    try:
        yield session
    finally:
        await session.close()
```

### Testing with Fixtures

```python
import pytest
from testcontainers.postgres import PostgresContainer

@pytest.fixture
def db():
    """Real PostgreSQL via testcontainers — no mocks."""
    with PostgresContainer() as postgres:
        yield create_connection(postgres.get_connection_url())

def test_save_user(db):
    user_id = save_user(db, {"name": "Alice"})
    assert db.get_user(user_id).name == "Alice"

@pytest.fixture
def client(db):
    """FastAPI test client with real DB."""
    app.dependency_overrides[get_db] = lambda: db
    with TestClient(app) as c:
        yield c
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

## Async & Concurrency

### The Decision Matrix

| Workload | Use | Why |
|---|---|---|
| **I/O-bound, async libs** | `asyncio` | Lightweight, scales to 100K+ connections |
| **I/O-bound, blocking libs** | `threading` / `ThreadPoolExecutor` | Sync libs need threads |
| **CPU-bound** | `multiprocessing` / `ProcessPoolExecutor` | Bypasses GIL |
| **Mixed blocking + async** | `asyncio` + `asyncio.to_thread()` | Bridge sync into async |
| **At HyperI: CPU-bound** | **Rust** (not Python) | Don't fight the language |

### TaskGroup — The Modern Standard (3.11+)

```python
import asyncio

async def process_batch(urls: list[str]) -> list[dict]:
    """Process URLs concurrently — collect ALL errors, not just first."""
    results = []
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(fetch(url), name=url) for url in urls]
    return [t.result() for t in tasks]
    # If ANY task fails, ALL others are cancelled and
    # exceptions are raised as ExceptionGroup
```

Use `TaskGroup` over `asyncio.gather()` — it cancels on failure and
propagates all exceptions. Name your tasks for debuggability.

### Concurrency Limiting

```python
import asyncio

async def fetch_all(urls: list[str], max_concurrent: int = 50):
    """Limit concurrent requests with semaphore."""
    sem = asyncio.Semaphore(max_concurrent)

    async def limited_fetch(url: str) -> dict:
        async with sem:
            return await fetch(url)

    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(limited_fetch(url)) for url in urls]
    return [t.result() for t in tasks]
```

❌ Never `asyncio.gather(*[fetch(url) for url in million_urls])` — OOM.
✅ Always limit concurrency with `Semaphore` or `asyncio.Queue` worker pool.

### Common Async Pitfalls

```python
# ❌ Forgetting to await — silently does nothing
async def bad():
    fetch_data()  # Returns coroutine, never executes!

# ✅ Always await or create_task
async def good():
    await fetch_data()
    # or
    task = asyncio.create_task(fetch_data())

# ❌ Sequential awaits — no concurrency
async def sequential():
    a = await fetch("url1")  # Waits for this...
    b = await fetch("url2")  # ...then this. Serial!

# ✅ Concurrent with TaskGroup
async def concurrent():
    async with asyncio.TaskGroup() as tg:
        t1 = tg.create_task(fetch("url1"))
        t2 = tg.create_task(fetch("url2"))
    a, b = t1.result(), t2.result()  # Ran in parallel

# ❌ Blocking call in async — freezes event loop
async def blocks():
    data = requests.get(url)  # BLOCKS entire loop!

# ✅ Use async library or to_thread
async def non_blocking():
    data = await asyncio.to_thread(requests.get, url)  # Bridge
    # Better: use httpx.AsyncClient
```

### Free-Threaded Python (3.14+, Optional GIL Removal)

Python 3.14 officially supports free-threaded builds (PEP 779). The GIL
can now be disabled, enabling true multi-core parallelism with threads.
Single-thread overhead is ~5-10%.

**At HyperI:** We don't use free-threaded Python yet. Our CPU-bound work
is in Rust. Monitor ecosystem readiness before adopting. When we do, the
decision matrix above changes — `threading` becomes viable for CPU work.

### Timeouts

```python
# ✅ Always set timeouts on I/O operations
async with asyncio.timeout(30):
    result = await fetch_data()

# ✅ httpx has built-in timeouts
async with httpx.AsyncClient(timeout=30.0) as client:
    response = await client.get(url)
```

---

## Container Deployment (Docker + K8s)

95% of HyperI Python services run inside containers on Kubernetes.
Use `hyperi-pylib` — it provides container detection, health endpoints,
structured logging, and graceful shutdown out of the box.

### Dockerfile Pattern

```dockerfile
# Multi-stage build — small, secure, reproducible
FROM python:3.12-slim AS builder
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --frozen --no-dev

FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY src/ ./src/
ENV PATH="/app/.venv/bin:$PATH"

# Non-root user (K8s policy enforcement)
RUN useradd -r -u 10001 appuser
USER appuser

# Exec form for proper SIGTERM forwarding
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Rules:**
- Multi-stage builds always (build deps stay out of runtime image)
- Non-root user always (`USER appuser`)
- Exec form for CMD always (signal forwarding for graceful shutdown)
- Pin Python version (no `python:latest`)
- Install deps first for layer caching

### Health Check Endpoints

```python
from fastapi import FastAPI
from hyperi_pylib.runtime import is_container

app = FastAPI()

@app.get("/health")
async def liveness():
    """Liveness probe — is the process alive?"""
    return {"status": "ok"}

@app.get("/ready")
async def readiness():
    """Readiness probe — are dependencies connected?"""
    checks = {
        "database": await check_db(),
        "redis": await check_redis(),
    }
    ok = all(checks.values())
    return {"status": "ready" if ok else "not_ready", "checks": checks}
```

Map to K8s probes:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 5
```

### Graceful Shutdown

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: init resources
    app.state.db = await connect_db()
    app.state.kafka = await connect_kafka()
    logger.info("Service started")

    yield  # App runs here

    # Shutdown: clean up in reverse order
    logger.info("Shutting down — draining connections")
    await app.state.kafka.close()
    await app.state.db.close()
    logger.info("Shutdown complete")

app = FastAPI(lifespan=lifespan)
```

K8s sends SIGTERM → uvicorn stops accepting new requests → lifespan
cleanup runs → pod terminates. Set `terminationGracePeriodSeconds: 30`
in your deployment spec.

### Structured Logging in Containers

```python
# hyperi-pylib auto-detects container vs terminal
from hyperi_pylib.logger import logger

# Container: JSON to stdout (machine-parseable)
# {"timestamp": "2026-03-17T12:00:00Z", "level": "info",
#  "message": "Request processed", "request_id": "abc123"}

# Terminal: human-readable with colours
# 12:00:00 INFO  Request processed (request_id=abc123)

logger.info("Request processed", request_id=req_id, duration_ms=42)
```

**Rules:**
- Log to stdout always (K8s collects via DaemonSet)
- JSON format in containers (parseable by Loki/Elasticsearch)
- Include correlation/request IDs for distributed tracing
- Never log secrets (hyperi-pylib auto-masks)
- Use `hyperi_pylib.logger` — it handles all of this

---

## hyperi-pylib

> **This section applies when `hyperi-pylib` is in `pyproject.toml`.**
> For non-HyperI projects, skip this section and use the generic patterns.

`hyperi-pylib` is the shared Python library for all HyperI Python projects.
It provides config, logging, metrics, HTTP, Kafka, secrets, CLI framework,
and more. Available on PyPI. **Use it — never roll bespoke versions of what
it provides.**

### Quick Start

```toml
# pyproject.toml
[project]
dependencies = [
    "hyperi-pylib",                    # Core (logging, config, runtime, cli)
    "hyperi-pylib[http,metrics]",      # With extras
]
```

```python
from hyperi_pylib.logger import logger
from hyperi_pylib.config import settings
from hyperi_pylib import build_database_url, get_runtime_paths

# Config: 8-layer cascade is AUTOMATIC (ENV > .env > YAML > defaults)
host = settings.database.host
port = settings.api.port

# Logging: auto-detects console vs container, masks sensitive fields
logger.info("Service starting", version="1.0.0", host=host)

# Database URLs from environment
postgres_url = build_database_url("postgresql")
```

### Use This, Not That

| ❌ Don't | ✅ Use hyperi-pylib | Module |
|---|---|---|
| Hand-rolled config loading | `settings.database.host` | `config` |
| Raw `logging` / `print()` | `logger.info("msg", key=val)` | `logger` |
| Build DB URLs manually | `build_database_url("postgresql")` | `database` |
| Raw `httpx` with retry | `hyperi_pylib.http` (stamina retries) | `http` |
| Raw prometheus-client | `create_metrics()` | `metrics` |
| Raw confluent-kafka | `hyperi_pylib.kafka` | `kafka` |
| Hand-rolled CLI with argparse | Subclass `DfeApp` | `cli` |
| Direct Vault/AWS/GCP calls | `SecretsManager` | `secrets` |
| Manual container detection | `get_runtime_paths()` | `runtime` |

### Feature Extras

```bash
uv add "hyperi-pylib"                              # Core only
uv add "hyperi-pylib[http,metrics]"                # Common
uv add "hyperi-pylib[http,metrics,kafka]"          # + Kafka
uv add "hyperi-pylib[http,metrics,kafka,opentelemetry]"  # + OTel
```

| Extra | Provides | Size |
|---|---|---|
| `http` | httpx + stamina retries | ~1 MB |
| `metrics` | Prometheus client + psutil | ~1 MB |
| `kafka` | confluent-kafka + schema inference | ~11 MB |
| `expression` | CEL expression evaluation (Rust/PyO3) | ~6 MB |
| `cache` | cashews + msgpack + psycopg pool | ~14 MB |
| `opentelemetry` | OTel SDK + OTLP + Prometheus exporters | ~4 MB |
| `secrets` | All backends (Vault + AWS + GCP + Azure) | varies |

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

### Version Pinning & Update Policy

**General rule: use `>=` version ranges, pin only when forced.**

```toml
# pyproject.toml
[project]
dependencies = [
    "httpx>=0.27",              # ✅ >= range (normal)
    "pydantic>=2.0,<3",         # ✅ >= with upper bound (major version)
    "hyperi-pylib>=2.24",       # ✅ >= range
    "cryptography==44.0.1",     # ⚠️ Pinned — only when you MUST
]
```

**Rules:**
- `>=X.Y` — default for all dependencies. Accept patches and minors.
- `>=X.Y,<Z` — when a known breaking major version exists
- `==X.Y.Z` — pin ONLY when a specific version has a known issue or
  you need reproducibility for a security-critical package. Document WHY.
- `uv.lock` — always committed. This IS your reproducible pin. The
  `pyproject.toml` ranges are for compatibility; the lock file is for builds.

**Update cadence:**
- Dependencies MUST be updated with every code review. Add `uv lock --upgrade`
  to the review checklist. Stale deps are a security and compatibility risk.
- `pip-audit` runs in CI — fails on known CVEs. Update or pin immediately.
- When updating, run the full test suite. If tests pass, update is safe.

```bash
# Update all deps to latest compatible versions
uv lock --upgrade

# Update a specific package
uv lock --upgrade-package httpx

# Check for security issues
uv run pip-audit
```

**Risk mitigation for `>=` ranges:**

The risk of `>=` is that a breaking upstream release can break your build.
We mitigate this with multiple layers:

| Risk | Mitigation |
|---|---|
| Breaking upstream release | `uv.lock` pins exact versions — builds are reproducible even with `>=` ranges |
| Security vulnerability | `pip-audit` in CI catches CVEs — blocks merge until resolved |
| Incompatible transitive deps | `uv.lock` resolves the full dependency tree — conflicts caught at lock time, not runtime |
| Stale deps accumulating risk | Mandatory `uv lock --upgrade` at every code review — deps never drift more than a few weeks |
| Major version break | Use `>=X.Y,<Z` upper bound for dependencies with known breaking major versions |

The key insight: `pyproject.toml` ranges express **compatibility intent**.
`uv.lock` provides **reproducible builds**. CI provides **safety gates**.
Together, these three layers make `>=` ranges safe and maintainable.

**When to pin `==`:** only when a specific version has a known regression
that the upstream hasn't fixed, OR for security-critical packages where
you need audit traceability. Always add a comment explaining WHY.

**Deprecation warnings MUST be fixed immediately.** If `pytest` or `ruff`
or runtime output shows a deprecation warning, address it in the current
PR — do not defer. Deprecations become removals and then your CI breaks
on a Python minor release with no warning.

**For AI assistants:** when adding a dependency, always use `>=` not `==`.
When reviewing code, check if `uv.lock` is stale and suggest
`uv lock --upgrade` if deps haven't been updated recently.
Flag any deprecation warnings in test output as must-fix.

### When Native Python is Acceptable

Only use native `python` or `pip` when:

- Working on external projects that don't use uv
- Modifying/extending third-party codebases
- System-level scripts outside project context
- No alternative exists (rare)

For HyperI projects, **always use uv**.

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

## Testing

### Project Layout for Testability

Use the `src/` layout. Tests import the installed package, not the working directory. Prevents import shadowing bugs that waste hours to debug.

```text
my_project/
├── pyproject.toml
├── src/
│   └── my_package/
│       ├── __init__.py
│       └── core.py
└── tests/
    ├── conftest.py
    ├── unit/
    ├── integration/
    ├── e2e/
    ├── fixtures/
    └── smoke/
```

If using `uv`, always `uv init --package` (creates src layout). The default `uv init` creates flat layout — don't use it for anything beyond throwaway scripts.

### Directory Structure

```text
tests/
├── conftest.py           # Shared fixtures (session-scoped DB, HTTP clients)
├── unit/
│   ├── conftest.py       # Unit-specific fixtures
│   ├── test_models.py
│   └── test_utils.py
├── integration/
│   ├── conftest.py       # Integration fixtures (testcontainers)
│   ├── test_api.py
│   └── test_database.py
├── e2e/
│   ├── conftest.py
│   └── test_workflows.py
├── fixtures/             # Static test data (JSON, YAML, SQL)
│   └── sample_data.json
└── smoke/
    └── test_startup.py   # MANDATORY — catches init crashes
```

- `conftest.py` at root for shared fixtures, per-directory for scoped fixtures
- Never import `conftest.py` directly — pytest auto-discovers it
- Static test data goes in `fixtures/`, not scattered through test files
- Smoke test is mandatory — boots the app with defaults, checks it doesn't crash

### Startup Smoke Test (MANDATORY)

Every project gets one. Catches init panics, missing config defaults, broken wiring. Single highest-value test.

```python
# tests/smoke/test_startup.py
def test_app_boots_with_default_config():
    """App should start without crashing on default config."""
    app = create_app()
    assert app is not None

import pytest

@pytest.mark.anyio
async def test_async_app_boots():
    """Async app should initialise without errors."""
    app = await create_async_app(Config())
    assert app.is_ready()
```

### No Mocks Policy

> **"Every time we have mocks and AI it always ends in tears."** — Derek

**Do not use mocks. Test against real dependencies.** See `standards/universal/MOCKS-POLICY.md` for the full policy.

```python
# ❌ NEVER — no mock libraries, no patch, no MagicMock
from unittest.mock import patch, MagicMock  # FORBIDDEN

with patch('myapp.db.session') as mock_db:
    mock_db.query.return_value = User(name="test")
    # Tests nothing real

# ✅ ALWAYS — real dependencies via testcontainers
from testcontainers.postgres import PostgresContainer

@pytest.fixture(scope="session")
def db():
    with PostgresContainer() as postgres:
        yield create_connection(postgres.get_connection_url())

def test_save_user(db):
    user_id = save_user(db, {"name": "Alice"})
    assert db.get_user(user_id).name == "Alice"  # Real DB

# ✅ External APIs — use sandbox/test mode, not mock
@pytest.mark.integration
def test_payment():
    result = process_payment(100.0, "tok_visa")  # Stripe test mode
    assert result.success is True

# ✅ If you can't test against real deps — skip, don't mock
@pytest.mark.skip(reason="Needs Stripe sandbox — not mocking")
def test_payment_integration():
    ...
```

**The one exception:** freezing time is acceptable (`time-machine` preferred over `freezegun`).

### Fixture Scoping

Wrong scope = slow tests or leaked state. Choose deliberately.

| Scope | Use for | Teardown |
|-------|---------|----------|
| `function` (default) | Isolated per-test state | After each test |
| `module` | Shared within file — expensive setup | After all tests in file |
| `session` | Shared across entire run — DB engine, HTTP pool | After full run |

Use `yield` for teardown (not `return`). Everything after `yield` runs even if the test fails.

```python
# tests/conftest.py
import pytest

@pytest.fixture(scope="session")
def db_engine():
    """Session-scoped — created once, shared across all tests."""
    engine = create_engine(test_database_url())
    yield engine
    engine.dispose()

@pytest.fixture
def db_session(db_engine):
    """Function-scoped — fresh transaction per test, rolled back."""
    session = Session(db_engine)
    yield session
    session.rollback()
    session.close()
```

### Async Testing

Use `anyio` marker (not `asyncio`) — works across backends and avoids plugin conflicts.

```python
import pytest

pytestmark = pytest.mark.anyio  # all async tests in this file

async def test_fetch_data(http_client):
    response = await http_client.get("/api/data")
    assert response.status_code == 200
```

For FastAPI, use `httpx.AsyncClient` with `ASGITransport`:

```python
from httpx import ASGITransport, AsyncClient

@pytest.mark.anyio
async def test_api_endpoint():
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test"
    ) as client:
        response = await client.get("/health")
        assert response.status_code == 200
```

Specify the backend explicitly in a session-scoped fixture:

```python
@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"
```

### Marks for CI Filtering

Tag tests so CI runs the right subset at the right time.

```python
# pyproject.toml
[tool.pytest.ini_options]
markers = [
    "integration: requires external services (DB, Kafka, APIs)",
    "e2e: end-to-end tests requiring full infrastructure",
    "slow: tests exceeding 30 seconds",
    "smoke: critical-path startup tests",
]
```

```python
@pytest.mark.integration
def test_kafka_produce(kafka_client):
    kafka_client.send("topic", b"data")

@pytest.mark.e2e
@pytest.mark.slow
def test_full_pipeline(running_app, kafka_client, db):
    ...
```

```bash
# CI stages
uv run pytest tests/unit/ tests/smoke/             # Every push (<3 min)
uv run pytest tests/integration/                   # Every push (<5 min)
uv run pytest tests/e2e/ -m "not slow"             # PR to release (<20 min)
uv run pytest -m smoke                             # Smoke subset (<1 min)
```

### CI Stage Mapping (hyperi-ci)

| Directory | CI stage | Trigger |
|-----------|----------|---------|
| `tests/unit/` + `tests/smoke/` | `quality` | Every push |
| `tests/integration/` | `test` | Every push |
| `tests/e2e/` | `test:e2e` | PR to `release` |
| `tests/smoke/` | `test:smoke` | Every push (fast subset) |

### Test Runner Config

```toml
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = [
    "-v",
    "--tb=short",
    "--strict-markers",
    "--import-mode=importlib",
]

[tool.coverage.run]
source = ["src"]
omit = ["tests/*"]

[tool.coverage.report]
fail_under = 80
```

Run tests with `uv run pytest` — no virtual env activation needed.

**Production code must be complete.** No TODOs, no `return True` placeholders, no `except: pass`.

---

## Production at Scale — Controls

Python's flexibility is a risk. These controls keep "kinda works" code out of production.

### Mandatory CI Enforcement

| Tool | Purpose | Blocking? |
|---|---|---|
| `ruff` | Lint + format (replaces flake8, isort, black) | ✅ Yes |
| `ty` / `pyright` | Type checking (catch runtime errors at dev time) | ⚠️ Warnings → ✅ Blocking |
| `bandit` | Security static analysis (medium/high) | ✅ Yes |
| `pip-audit` | CVE scanning of dependencies | ✅ Yes |
| `pytest` | Test suite with coverage | ✅ Yes (80% min) |
| `vulture` | Dead code detection | ✅ Yes |

### Exception Handling (Hyperscaler Grade)

```python
# ❌ Generic exception swallowing — THE most common production failure
try:
    result = process(data)
except Exception:
    pass  # Silent failure → data loss → customer impact

# ❌ Logging without raising — error is swallowed
try:
    result = process(data)
except Exception as e:
    logger.error(f"Failed: {e}")
    # Where does execution go? What state is the system in?

# ✅ Specific exception, log with context, re-raise or handle
try:
    result = process(data)
except ValidationError as e:
    logger.warning("Validation failed", input=data.id, error=str(e))
    raise  # Let caller decide
except ConnectionError as e:
    logger.error("DB unreachable", host=settings.database.host, error=str(e))
    raise ServiceUnavailableError("Database connection failed") from e
```

### Never Use print() in Production Code

```python
# ❌ print() — goes to stdout, no level, no structure, no masking
print(f"Processing {user.email}")  # PII leak!

# ✅ Structured logging — level-aware, JSON in containers, auto-masks secrets
logger.info("Processing user", user_id=user.id)  # No PII
```

### Nuitka Compilation (Nice to Have)

Nuitka can compile Python to native binaries. Benefits: faster startup,
single-file distribution, no Python runtime dependency. Not a hard
requirement, but consider for CLI tools and utilities.

```bash
nuitka --standalone --onefile my_tool.py
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

## Bash Minimalism — Call Python Instead

> **"If it's getting complex, over 20 lines, or pipes to jq — it should
> be Python."**

Bash at HyperI is a thin caller wrapper only. Reasons:
- Reliability: bash error handling is fragile
- Portability: macOS ships bash 3.2 (2007), zsh by default — the "mac bash
  problem"
- Logging: Python has structured logging, bash has echo
- Error handling: Python has exceptions, bash has `set -e` (which is unreliable)
- Testing: Python has pytest, bash has BATS (limited)

### What Bash Is For

```bash
#!/usr/bin/env bash
# Check Python, call Python. That's it.
set -euo pipefail
command -v python3 >/dev/null 2>&1 || { echo "Python 3 required"; exit 1; }
exec python3 "$(dirname "$0")/real_logic.py" "$@"
```

### What Bash Is NOT For

- Parsing JSON/YAML (→ Python `json`/`pyyaml`)
- Complex conditionals (→ Python)
- String manipulation (→ Python)
- Anything with `jq`, `sed`, `awk` pipelines (→ Python)
- Anything over ~20 lines (→ Python)
- Anything that needs to work reliably on macOS and Linux (→ Python)

See `standards/languages/BASH.md` for bash standards when bash IS appropriate.

---

## For AI Code Assistants

The following sections are specific guidance for AI code assistants working with Python.

### Package Verification — MANDATORY Before Every Suggestion

AI models hallucinate package names. Attackers register hallucinated names
with malicious code ("slopsquatting"). 25-38% of AI-suggested dependencies
point to deprecated or non-existent packages.

**Before suggesting ANY `import` or `uv add`:**

1. **Verify it exists** — web search `<package> pypi` or check `https://pypi.org/project/<package>/`
2. **Check it's actively maintained:**
   - Last release within 12 months
   - Open issues responded to (not 500+ ignored)
   - More than one maintainer (bus factor)
3. **Check it's widely used:**
   - PyPI download stats (`https://pypistats.org/packages/<package>`)
   - Minimum ~10K downloads/month for production dependencies
   - Known ecosystem presence (referenced in docs, tutorials, other projects)
4. **Check for superseding packages:**
   - Has it been replaced? (psycopg2 → psycopg, requests → httpx)
   - Is there a stdlib equivalent now? (tomli → tomllib, dateutil → zoneinfo)
5. **Check license compatibility** — no GPL/AGPL/SSPL

**Definition of "actively maintained":**
- Commit activity in the last 6 months
- Releases in the last 12 months
- Security issues addressed (not ignored)
- Python 3.12+ support confirmed

**Red flags — do NOT use:**
- Last release >18 months ago
- "Looking for new maintainer" in README
- Pinned to Python 3.8 or lower
- No type stubs or py.typed marker
- Single maintainer with no recent activity

### Silent Failure — The Worst AI Anti-Pattern

AI-generated code often fails silently instead of crashing. This is WORSE than
a crash — silent data loss, corrupted state, incorrect results that look right.

```python
# ❌ AI often generates this — silently returns None/empty on error
def get_user(user_id: int) -> User | None:
    try:
        return db.query(User).get(user_id)
    except Exception:
        return None  # Silent failure — caller has no idea

# ✅ Fail explicitly — let the caller decide
def get_user(user_id: int) -> User:
    try:
        return db.query(User).get(user_id)
    except DatabaseError as e:
        raise UserNotFoundError(user_id) from e
```

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

---

## AI Test Generation Traps

> **Derek's hard lessons learned from trusting AI-generated test suites.**
> The tests looked great. CI was green. Production broke anyway.

### The Core Problem

AI generates tests that confirm happy paths. That's the least valuable thing a test can do. The bugs live in edge cases, error states, race conditions, and boundary values — exactly where AI produces the least useful output.

Up to 30% of AI-generated tests contain patterns that look correct but verify nothing meaningful. Coverage reports 85% but effective coverage (meaningful behaviours verified) can be as low as 40%.

### Traps to Watch For

| Trap | What AI does | What you need |
|------|-------------|---------------|
| **Happy-path only** | Tests valid input, checks it works | Tests INVALID input, checks it fails correctly |
| **Mirror tests** | Assertions that duplicate implementation logic | Assertions that check observable behaviour |
| **Assertion-free tests** | Calls functions but never asserts | Every test MUST assert something meaningful |
| **Missing error paths** | No tests for exceptions, None, timeout | Explicit tests for every exception your code can raise |
| **No boundary tests** | Values like 5 and 10 but not 0, MAX, -1, empty | Boundary values: zero, one, max, overflow, empty, None |
| **Missing async tests** | Sequential-only tests for async code | Tests with timeout, cancellation, concurrent access |
| **No startup smoke test** | Tests for individual functions, nothing for "does the app boot?" | Mandatory smoke test with default config |

### The Shared Blind Spot

When AI generates BOTH the code AND the tests, the same blind spots appear in both. The tests confirm the code's biases rather than challenging them.

### Test Quality Checklist (Apply After AI Generation)

- [ ] Every exception/error type has at least one test that triggers it
- [ ] Zero, one, empty, and max-value inputs are tested
- [ ] Invalid/malformed input is tested (not just valid input)
- [ ] Async code has timeout and cancellation tests
- [ ] The test actually fails when you break the implementation
- [ ] Test names describe the scenario, not the function
- [ ] No `assert True` or assertion-free tests
- [ ] Startup smoke test exists

**Treat AI-generated tests as drafts.** Add the edge cases, failure paths, and adversarial inputs yourself.

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


