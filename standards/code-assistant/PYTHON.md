# Python Development - AI Assistant Guidance

## Type Hints

**Python 3.12+ syntax (PEP 585, 604):**
```python
# ✅ Modern
def process(items: list[str]) -> dict[str, int]: ...
def optional() -> str | None: ...

# ❌ Legacy
from typing import List, Dict, Optional
```

---

## Code Quality

**Tools:** ruff (lint + format), mypy (types)

```bash
ruff check . && ruff format .   # Lint + format
mypy src/                       # Type check
```

---

## Package Structure

```
myproject/
├── src/mypackage/
│   ├── __init__.py      # __version__ synced
│   └── module.py
├── tests/unit/
├── tests/integration/
├── pyproject.toml       # version synced
├── VERSION              # Source of truth
└── uv.lock              # Commit
```

**src/ layout:** Forces installation, prevents WD imports

---

## Dependencies

**uv** (replaces pip, pip-tools, virtualenv)

```bash
uv sync --locked               # Install
uv add <pkg>                   # Add
uv add --dev <pkg>             # Add dev
./ci/run dependency-update     # Update lock
```


---

## Commit Types

**Standard conventional commits** (no Python-specific):
- `fix:` - Fixes, improvements, refactors (PATCH)
- `feat:` - New features (MINOR)
- `perf:` - Performance (PATCH)
- `docs:`, `test:`, `chore:` - No bump

---

## Quick Reference

**Setup:** `./ci/bootstrap install`

**Dev:** `./ci/run check|test|build|dependency-update`

**Release:** `./ci/run release [--dry-run|--no-push]`

**Issues:**
- Wrong venv: CI enforces `ci-local/.venv`
- Version: Pre-commit hook prevents corruption
- Coverage: 80% min (ci.yaml)
- Types: Use 3.10+ syntax

---
