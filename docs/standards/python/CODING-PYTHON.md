# Python Standards for HyperSec Projects

**Best practices for DevOps, DataOps, and DevSecOps Python projects**

---

## Temporary Files and Directories

### Development/CI Work
**Use `./.tmp/` for ALL project-scoped temp operations:**
- Test projects, build artifacts, scratch files, CI work

**Why:** Project-scoped, easy cleanup, gitignored, no system pollution

### Production/Runtime Code
**Use Python tempfile module (NEVER hardcode /tmp):**

**Temporary files (auto-cleanup):**
```python
import tempfile

with tempfile.NamedTemporaryFile(delete=True, suffix=".dat") as tmp:
    tmp.write(data)
    process(tmp.name)
# File auto-deleted, secure permissions, random name
```

**Temporary directories (auto-cleanup):**
```python
import tempfile

with tempfile.TemporaryDirectory(prefix="myapp-") as tmpdir:
    work_in(tmpdir)
# Directory + contents auto-deleted
```

**Application temp directories (persistent):**
```python
import tempfile
from pathlib import Path

app_temp = Path(tempfile.gettempdir()) / app_name
app_temp.mkdir(exist_ok=True, mode=0o700)  # User-only
# Respects TMPDIR env var, cross-platform
```

### Security Rules
❌ **NEVER** hardcode "/tmp", use `mktemp()`, create predictable names
✅ **ALWAYS** use context managers, `TemporaryFile()`/`TemporaryDirectory()`, random names, 0o700 permissions

**Why:** Security (TOCTOU prevention), reliability (auto-cleanup), portability (cross-platform), standards (OpenStack, AWS, Python)

---

## Project Layout Standards

### Source Root Detection (v1.0.25+)

**CI tools use `get_source_root('python')` for consistent detection:**

**Supported layouts:**
1. **src/** (recommended) - `src/packagename/__init__.py`
2. **Flat** - `PackageName/__init__.py` at root
3. **App** - `app/`, `lib/`, `core/` directories
4. **Empty** - Auto-creates `src/packagename/` skeleton

**Auto-detection:** Runs during `./ci/bootstrap install`, stores in `ci-local/ci.yaml: python.source_root`

**Override:** Set `CI_PYTHON_SOURCE_ROOT` env var or edit `ci-local/ci.yaml`

---

## Testing Standards

### Test Enforcement (v1.0.26+)

**Tests REQUIRED before build/release:**

```bash
./ci/run test    # Run tests first
./ci/run build   # Enforces tests passed
./ci/run release # Enforces tests passed
```

**Emergency override (build only):** `./ci/run build`

**Release has NO override** - tests must pass!

### Test Frameworks

**Primary:** pytest (REQUIRED), pytest-cov (OPTIONAL, auto-detected)

**Quality:** ruff, black, isort (REQUIRED), pyright (non-blocking)

**Security:** bandit (medium/high), pip-audit (REQUIRED)

**Package:** interrogate (docstrings, package only), vulture (dead code), twine (metadata)

### Test Organization

```
tests/
├── unit/          # Fast, isolated
├── integration/   # Component integration
└── e2e/           # End-to-end
```

**Selective execution:** `CI_TEST_LEVELS="unit" ./ci/run test`

**Config:** `ci.yaml: tests.levels, tests.pytest_args`

---

## Build and Release Standards

### Build Patterns

**Standard:** `./ci/run test && ./ci/run build` (wheel + sdist)

**Nuitka:** `./ci/run build --nuitka` (compiled binary)

**Version sync:** VERSION file = source of truth, auto-synced to pyproject.toml and `__init__.py`, pre-commit hook prevents corruption

### Release Workflow

**Automated:** `./ci/run test && ./ci/run release` (creates tag, pushes to remote)

**Local/dry-run:** `./ci/run release --no-push` or `--dry-run`

---

## Configuration Standards

### Configuration Cascade

**Precedence (highest to lowest):**
1. ENV vars (CI_* prefix)
2. `.env` (secrets)
3. `ci-local/ci.yaml` (overrides)
4. `ci/ci.yaml` (module defaults)
5. `ci/modules/common/defaults.yaml` (global)

**Example config and overrides:** See `ci-local/ci.yaml` for YAML format, use `CI_*` env vars to override

---

## Virtual Environment Patterns

### ONE .venv Strategy

**Unified `.venv` at project root** - contains project code AND CI tools, managed by `uv`

**Setup:** `./ci/bootstrap install` (creates .venv, installs deps)

**Dependencies:** Define in `pyproject.toml [project.optional-dependencies] dev = [...]`

---

## Security Standards

### Bandit Thresholds

**Severity:** Low (informational), Medium/High (enforced, fails CI)

**Config:** `bandit -r src/ -ll` (medium/high only)

### Dependency Scanning

**pip-audit:** Scans deps against CVE database, fails on vulnerabilities

---

## Hyperlib Infrastructure Standards

**Mandatory for all HyperSec Python projects** - enterprise infrastructure

| Need | Use | Import |
|------|-----|--------|
| **Logging** | hyperlib logger | `from hyperlib import logger` |
| **Config** | hyperlib (7-layer cascade) | `from hyperlib.config import settings` |
| **Paths** | hyperlib runtime (K8s/Docker/local) | `from hyperlib import get_runtime_paths` |
| **Database** | hyperlib database | `from hyperlib import build_database_url` |
| **Metrics** | hyperlib Prometheus | `from hyperlib import create_metrics` |
| **CLI** | hyperlib (Typer wrapper) | `from hyperlib.cli import Typer` |
| **Lifecycle** | hyperlib Application | `from hyperlib import Application` |

### Quick Start

**Option 1: Application framework (recommended)**
```python
from hyperlib import Application

app = Application()
app.logger.info("Started")
app.config.database.host
app.runtime.data_dir
app.metrics.http_requests.inc()
```

**Option 2: Individual components**
```python
from hyperlib import logger, get_runtime_paths, create_metrics
from hyperlib.config import settings
from hyperlib import build_database_url

logger.info("Service starting")
runtime = get_runtime_paths()
metrics = create_metrics(namespace="myapp")
db_url = build_database_url("postgresql")
```

### Installation

```bash
pip install hyperlib  # Basic
pip install hyperlib[api,cli,database,metrics,all]  # With features
```

**JFrog config:** Set `JF_USER` and `JF_PASSWORD` in `.env`

### Why Hyperlib?

✅ Zero config, container-aware (K8s/Docker/bare metal), production-ready (RFC 3339, structured logs), ENV-based (12-factor), consistent patterns

❌ DON'T roll your own logging/config/metrics, use multiple libs, or hardcode paths/config

**Docs:** `hyperlib.__doc__`, `help(Application)`, project README

---

## Code Style Standards

### Clarity Over Cleverness

**Principles:** Break down operations, use descriptive names, prioritize readability, explain WHY not WHAT, avoid dense lambdas and nested comprehensions

**Why:** Code read 10x more than written, clear code = obvious bugs, faster onboarding, better AI parsing

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

**❌ Bad (nested comprehension):**
```python
matrix = [[cell.strip().upper() for cell in row.split(',')] for row in data if row]
```

**✅ Good (clear transformation):**
```python
# Parse CSV rows into normalized matrix
matrix = []
for row in data:
    if not row:
        continue
    cells = row.split(',')
    normalized = [cell.strip().upper() for cell in cells]
    matrix.append(normalized)
```

### When Comprehensions Are OK

**Simple single-level OK:** `squares = [x**2 for x in range(10)]`, `names = [user.name for user in users]`

**Avoid nested/complex:** Break down `[f(g(x)) for x in items if h(x) and j(x)]` into explicit loops with intermediate variables

---

## PEP 8 Compliance

**Official Python style guide (current 2024-2025)**

**Naming:** `snake_case` (vars/functions), `PascalCase` (classes), `UPPER_SNAKE_CASE` (constants), `_private` (internal)

**Formatting:** 4 spaces, 88 chars (Black), import order: stdlib → third-party → local

**Type hints required:** `def get_user(user_id: int) -> dict[str, str]:`

**HS-CI enforcement via `./ci/run test`:** ruff (including I rules for import sorting), black (blocking), pyright (warnings), bandit, vulture

**See [python/PEP8.md](python/PEP8.md) for comprehensive guide**

---

## No Mocks or Mock Code Policy

**Production code must be complete before committing**

❌ **NEVER:** Mock implementations, TODO/FIXME in src/, example code as real features, POC code

✅ **ALWAYS:** Complete functionality, handle errors/edge cases, validate I/O, add tests

**Mocks allowed ONLY in:** `tests/`, `examples/`, documentation

**See [details/NO-MOCKS-POLICY.md](details/NO-MOCKS-POLICY.md) for comprehensive guide**

---

## AI Code Assistant Guidelines (Python-Specific)

**Type hints and docstrings help AI generate better code**

### AI Pitfalls

❌ **Watch for:** Deprecated APIs (`from typing import List`), overly complex comprehensions, generic exception handling (`except Exception: pass`)

### HS-CI + AI Workflow

1. Write type hints/docstrings
2. AI suggests implementation (review carefully)
3. Run `./ci/run test` (catches mistakes)
4. Iterate on failures
5. Human review

**HS-CI catches:** Missing type hints, PEP 8 violations, security issues, unused imports, dead code

**See [details/AI-GUIDELINES.md](details/AI-GUIDELINES.md) for comprehensive guide**

---

**Last Updated:** 2025-11-10
**Version:** v1.1.0 (PEP 8 compliance + HS-CI integration + AI guidelines)
**Status:** Active

**This document defines comprehensive Python standards for all HyperSec projects.**

**See also:**
- `CODING-STANDARDS.md` - Language-agnostic standards
- `ci/docs/standards/AI-GITHUB-COPILOT.md` - GitHub Copilot detailed guide (platform-specific)
- `ci/docs/standards/AI-CLAUDE-CODE.md` - Claude Code detailed guide (platform-specific)
- `ci/docs/standards/AI-CURSOR.md` - Cursor detailed guide (platform-specific)
