# Python Development - AI Assistant Guidance

---

## Virtual Environments

**Two venvs - NEVER mix:**
- `ci-local/.venv` - CI tools
- `.venv` - Runtime deps

**CI enforcement:** Check `"ci-local/.venv" in sys.prefix` else error

**Setup:** `uv sync --locked` (both venvs)

---

## Testing

**Stack:** pytest + coverage (80% min) + mypy + ruff

```bash
./ci/run test          # Tests + coverage
./ci/run check         # All checks
```

---

## Version Sync

**Auto-synced:** `VERSION` → `pyproject.toml` → `__init__.py`

**NEVER edit VERSION manually** - semantic-release updates atomically

**Verify:** `./ci/run check-version-sync`

---

## Type Hints

**Python 3.10+ syntax (PEP 585, 604):**
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
./ci/run check                  # All
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

## Release

```bash
./ci/run release              # Create + push
./ci/run release --dry-run    # Preview
./ci/run release --no-push    # Local only
```

**Process:** Analyze commits → determine version → update VERSION/pyproject/init → CHANGELOG → tag → push → GitHub Actions → JFrog

---

## Build

**Standard:** `./ci/run build`

**Nuitka:** `./ci/run build --nuitka`

**ci.yaml:**
```yaml
nuitka:
  enabled: true
  build_type: package  # or app
  protection_level: recommended
```

**Modes:** Package (`.whl` + `.so`, no `.py`), App (binary + tarball)

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

**Refs:** [CODE-ASSISTANT-COMMON.md](CODE-ASSISTANT-COMMON.md), [CODE-ASSISTANT-HS-CI.md](CODE-ASSISTANT-HS-CI.md), [CODING-STANDARDS-PYTHON.md](../CODING-STANDARDS-PYTHON.md), [GIT-WORKFLOW.md](../GIT-WORKFLOW.md)
