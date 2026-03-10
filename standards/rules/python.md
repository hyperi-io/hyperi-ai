---
paths:
  - "**/*.py"
detect_markers:
  - "file:pyproject.toml"
  - "file:setup.py"
  - "file:requirements.txt"
  - "file:uv.lock"
  - "deep_file:pyproject.toml"
  - "deep_file:setup.py"
source: languages/PYTHON.md
---

<!-- override: manual -->
## Python Standards

**Minimum Python: 3.12+**

**Commands:** `./ci/bootstrap install` | `./ci/run check|test|build|dependency-update` | `./ci/run release [--dry-run|--no-push]`

## Type Hints (Required)

- Use built-in generics: `list[str]`, `dict[str, int]`, `str | None` — NEVER `from typing import List, Dict, Optional, Union`
- Use 3.12+ `type` aliases and generic syntax: `type Point = tuple[float, float]`, `def first[T](items: list[T]) -> T | None:`
- All public functions must have full type annotations
- Use `TYPE_CHECKING` guard for circular imports with string annotations
- Annotate non-obvious variables: `users: list[User] = []`

❌ `from typing import List, Dict, Optional, TypeVar`
✅ `list[str]`, `dict[str, int]`, `str | None`, `type Handler[T] = Callable[[T], None]`

## Code Quality Tools

- **ruff**: Lint + format, import sorting — blocks CI
- **black**: 88-char formatting — blocks CI
- **pyright**: Type checking — warnings only
- **bandit**: Security (medium/high) — blocks CI
- **vulture**: Dead code — blocks CI

```bash
ruff check . && ruff format .
mypy src/
bandit -r src/ -ll
```

## Package Structure

- Use `src/` layout: `src/mypackage/` with `tests/unit/`, `tests/integration/`, `tests/e2e/`
- `VERSION` file is source of truth; `__init__.py` and `pyproject.toml` stay synced
- Commit `uv.lock`
- Coverage minimum: 80%

## Dependencies (uv Required)

**Always use uv for HyperI projects. Never use pip/venv directly.**

| Task | Use | NOT |
|------|-----|-----|
| Create venv | `uv venv` | `python -m venv` |
| Install deps | `uv sync --locked` | `pip install -r` |
| Add package | `uv add <pkg>` | `pip install` |
| Add dev dep | `uv add --dev <pkg>` | — |
| Run script | `uv run python script.py` | `python script.py` |
| Run module | `uv run -m pytest` | `python -m pytest` |
| Update lock | `uv lock` | `pip-compile` |
| Show deps | `uv tree` | `pip list` |

Native `python`/`pip` only for external projects that don't use uv.

## Naming (PEP 8)

- `snake_case`: variables, functions, methods
- `PascalCase`: classes (`HTTPClient` — acronyms uppercase)
- `UPPER_SNAKE_CASE`: module-level constants
- `_prefix`: private members/methods

## Formatting

- 4 spaces always, never tabs
- 88-char line length (Black default)
- Trailing commas in multi-line constructs
- Accept Black's formatting without modification
- Two blank lines between top-level definitions, one between methods

## Imports

- Three groups separated by blank lines: stdlib → third-party → local
- Alphabetical within groups
- Never use wildcard imports (`from x import *`)
- Ruff I rules enforce automatically

## Whitespace

- Spaces around `=` in assignments, around operators
- No spaces in keyword args: `func(arg1=1)`
- No spaces inside brackets: `my_list[0]`, `{"key": "value"}`

## Comments and Docstrings

- Inline comments explain WHY, not WHAT
- Never number comments (hard to maintain)
- PEP 257 docstrings with Args/Returns/Raises sections
- Imperative mood: "Save user" not "Saves user"
- Module-level docstring required

## Code Style

- Clarity over cleverness — no nested comprehensions, no dense lambda chains
- Use intermediate variables with descriptive names
- Simple single-level comprehensions are fine: `[x**2 for x in range(10)]`
- Break complex boolean expressions into named variables

❌ `result = list(map(lambda x: x[1], filter(lambda x: x[0] > 10, data)))`
✅ `filtered = [item for item in data if item[0] > 10]` then `result = [v for _, v in filtered]`

## Security

- Never use f-strings in SQL — use parameterized queries
- Never use `eval()`/`exec()` with external input; use `ast.literal_eval` for literals only
- Never use `pickle.loads()` on untrusted data — use JSON
- Specific exception handling only; never `except Exception: pass`
- pip-audit for CVE scanning

## Temporary Files

- Dev/CI: use `./.tmp/` directory
- Production: use `tempfile` module with context managers, never hardcode `/tmp`
- Always: random names, `0o700` permissions, auto-cleanup via context managers

## Ruff Configuration

```toml
[tool.ruff]
line-length = 88
select = ["E", "F", "I", "N", "UP"]
ignore = ["E501"]

[tool.ruff.lint.isort]
force-single-line = false
```

## hyperi-pylib

```python
from hyperi_pylib import logger                    # Logging
from hyperi_pylib.config import settings           # Config (Dynaconf cascade)
from hyperi_pylib import get_runtime_paths          # Runtime paths
from hyperi_pylib import build_database_url         # DB URLs
from hyperi_pylib import create_metrics             # Metrics
from hyperi_pylib import Application                # CLI
```

- Config: `settings.database.host` — cascade is automatic (ENV > .env > files > defaults)
- ENV keys: `database.host` → `MYAPP_DATABASE_HOST`
- Logging: `logger.info("Processing", user_id=123)` — auto-detects console vs container

## Modern Patterns

- Use `@dataclass` for data containers; `field(default_factory=list)` for mutable defaults
- Use Pydantic `BaseModel` for validation with `@field_validator`
- Use `httpx.AsyncClient` for async HTTP, never blocking `httpx.get` in async context
- Use `asyncio.gather` for concurrent async; `asyncio.run()` only from sync entrypoint

## Mocking Policy

- Never mock internal functions/classes
- Mock only external boundaries: APIs, databases, network, K8s

❌ `with patch('myapp.utils.calculate') as m: ...`
✅ `with patch('myapp.clients.stripe.charge') as m: ...`

## AI-Specific Rules

- Never generate `from typing import List, Dict, Optional` — use built-in generics
- Never use mutable default arguments (`def f(items=[])`); use `None` + reassign
- Never generate `except Exception: pass`
- Never use `asyncio.run()` inside already-async context — use `await` directly
- Verify packages exist before suggesting imports — common hallucinations: `pydantic_ai`, `fastapi_utils`
- When uncertain, prefer stdlib (`pathlib`, `json`, `dataclasses`, `asyncio`) or well-known packages (`pydantic`, `sqlalchemy`, `httpx`, `pytest`)
- Production code must be complete: no TODOs, no `return True` placeholders
