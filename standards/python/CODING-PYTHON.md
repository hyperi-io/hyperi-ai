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

---

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

---

## Security Standards

### Bandit Thresholds

**Severity:** Low (informational), Medium/High (enforced, fails CI)

**Config:** `bandit -r src/ -ll` (medium/high only)

### Dependency Scanning

**pip-audit:** Scans deps against CVE database, fails on vulnerabilities

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

**Official Python style guide (latest version)**

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
