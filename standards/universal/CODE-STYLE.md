---
name: code-style-standards
description: Language-agnostic code style for clarity, maintainability, and consistency across all HyperI projects.
rule_paths:
  - "**/*.py"
  - "**/*.rs"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.cpp"
  - "**/*.cc"
  - "**/*.sh"
  - "**/*.sql"
paths:
  - "**/*.py"
  - "**/*.rs"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.cpp"
  - "**/*.cc"
  - "**/*.sh"
  - "**/*.sql"
---

# Code Style Standards

**Language-agnostic code style for clarity, maintainability, and consistency**

---

## Clarity Over Cleverness

**Core Principles:**

- Break down compound operations into clear steps
- Use intermediate variables with descriptive names
- Prioritise readability over clever one-liners
- Add comments explaining WHY, not just WHAT
- Avoid dense operations that require mental parsing

**Why This Matters:**

- **Maintainability:** Code is read 10x more than written
- **Debugging:** Clear code = obvious bugs
- **Onboarding:** Faster understanding for new team members
- **AI assistance:** Better parsing by code assistants
- **Code review:** Easier bug spotting

---

## Multi-Language Examples

### Avoiding Dense One-Liners

**JavaScript/TypeScript:**

```javascript
// ❌ Bad (dense, hard to follow)
const result = data.filter(n => n > 0).map(n => n * 2).reduce((a, b) => a + b, 0);

// ✅ Good (clear, maintainable)
const positiveNumbers = data.filter(n => n > 0);
const doubledNumbers = positiveNumbers.map(n => n * 2);
const sum = doubledNumbers.reduce((a, b) => a + b, 0);
```

**Python:**

```python
# ❌ Bad (nested comprehension)
result = [[f(x) for x in row] for row in data if len(row) > 0]

# ✅ Good (clear steps)
non_empty_rows = [row for row in data if len(row) > 0]
result = [[f(x) for x in row] for row in non_empty_rows]
```

**Go:**

```go
// ❌ Bad (unexplained complex condition)
if (hasPermission && isActive) || (isAdmin && !isLocked) {
    process()
}

// ✅ Good (explained logic)
// Allow if: (user has permission AND is active) OR (admin without lock)
normalUserAccess := hasPermission && isActive
adminOverride := isAdmin && !isLocked

if normalUserAccess || adminOverride {
    process()
}
```

**Rust:**

```rust
// ❌ Bad (dense iterator chain)
let result: Vec<_> = items.iter()
    .filter(|x| x.is_valid())
    .map(|x| x.transform())
    .filter(|x| x.value > threshold)
    .collect();

// ✅ Good (clear pipeline with comments)
let valid_items = items.iter().filter(|x| x.is_valid());
let transformed = valid_items.map(|x| x.transform());
let above_threshold: Vec<_> = transformed.filter(|x| x.value > threshold).collect();
```

**Bash:**

```bash
# ❌ Bad (dense pipeline)
result=$(cat file.txt | grep -v "^#" | awk '{print $2}' | sort | uniq -c | sort -rn | head -5)

# ✅ Good (clear steps)
# Remove comments, extract second column, count unique values
without_comments=$(grep -v "^#" file.txt)
second_column=$(echo "${without_comments}" | awk '{print $2}')
sorted_unique=$(echo "${second_column}" | sort | uniq -c | sort -rn)
result=$(echo "${sorted_unique}" | head -5)
```

---

## When Concise Code is OK

**Simple, single operations are fine (language-dependent idioms are acceptable):**

- List comprehensions (Python), array methods (JavaScript), iterator chains (Rust)
- Simple transformations that are idiomatic to the language
- Well-understood patterns that improve readability

**Avoid:**

- Nested operations requiring mental parsing
- Multiple transformations in single expression
- Dense lambda/anonymous function chains
- Clever tricks that sacrifice readability

---

## Function Organisation

### Helper-First Approach (Recommended)

Place helper/child functions at the top, main/parent function at the bottom.

**JavaScript/TypeScript:**

```javascript
// Helper functions defined first
function validateInput(data) {
    if (!data) throw new Error("Data required");
    return true;
}

function transformData(data) {
    return data.map(item => item.toUpperCase());
}

function saveToDb(data) {
    db.insert(data);
}

// Main function uses helpers (defined above)
function processUserData(data) {
    validateInput(data);
    const transformed = transformData(data);
    saveToDb(transformed);
}
```

**Python:**

```python
# Helper functions first
def validate_input(data: list) -> bool:
    if not data:
        raise ValueError("Data required")
    return True

def transform_data(data: list[str]) -> list[str]:
    return [item.upper() for item in data]

def save_to_db(data: list[str]) -> None:
    db.insert(data)

# Main function last
def process_user_data(data: list[str]) -> None:
    validate_input(data)
    transformed = transform_data(data)
    save_to_db(transformed)
```

**Go:**

```go
// Helper functions first
func validateInput(data []string) error {
    if len(data) == 0 {
        return errors.New("data required")
    }
    return nil
}

func transformData(data []string) []string {
    result := make([]string, len(data))
    for i, item := range data {
        result[i] = strings.ToUpper(item)
    }
    return result
}

// Main function last
func ProcessUserData(data []string) error {
    if err := validateInput(data); err != nil {
        return err
    }
    transformed := transformData(data)
    return saveToDb(transformed)
}
```

**Bash:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Helper functions first
validate_input() {
    [[ -n "${1:-}" ]] || return 1
}

process_file() {
    local file="${1}"
    echo "Processing: ${file}"
}

cleanup() {
    rm -rf "${TEMP_DIR:-}"
}

# Main function last
main() {
    local input="${1:-}"

    validate_input "${input}" || {
        echo "Error: Input required" >&2
        exit 1
    }

    trap cleanup EXIT
    process_file "${input}"
}

# Entry point at very end
main "$@"
```

**Why helper-first:**

- Easy to cut/paste and reorder functions without breaking dependencies
- Reading top-to-bottom follows "zoom in" pattern (details → usage)
- Helper functions are defined before use (clearer dependencies)
- Refactoring is simpler (move helpers without updating order)

**Alternative:** Some teams prefer main-first (big picture → details). Both are acceptable - **pick one and stay consistent within each file**.

---

## Comment Standards

### Never Number Comments

**❌ Bad (requires renumbering when reordering):**

```python
def process_data(data):
    # 1. Validate input
    validate(data)

    # 2. Transform data
    transformed = transform(data)

    # 3. Save to database
    save(transformed)
```

**✅ Good (easy to reorder without refactoring):**

```python
def process_data(data):
    # Validate input
    validate(data)

    # Transform data
    transformed = transform(data)

    # Save to database
    save(transformed)
```

**Why:** Numbered comments make code harder to refactor. When you cut/paste or reorder steps, you must also renumber all comments.

### Comment WHY, Not WHAT

**❌ Bad (comments describe obvious code):**

```python
# Increment counter
counter += 1

# Loop through users
for user in users:
    process(user)
```

**✅ Good (comments explain reasoning):**

```python
# Track retries for exponential backoff calculation
counter += 1

# Process users in registration order (oldest first) for fair queue handling
for user in users:
    process(user)
```

---

## Naming Conventions

### Universal Patterns

| Element | Convention | Examples |
|---------|------------|----------|
| **Variables** | Descriptive, context-clear | `user_count`, `isValid`, `total_price` |
| **Functions** | Verb-noun or action | `get_user()`, `validateInput()`, `process_payment()` |
| **Constants** | UPPER_SNAKE_CASE | `MAX_RETRIES`, `DEFAULT_TIMEOUT` |
| **Boolean** | is/has/can/should prefix | `is_active`, `hasPermission`, `canDelete` |

### Language-Specific

| Language | Variables/Functions | Classes | Constants |
|----------|-------------------|---------|-----------|
| **Python** | `snake_case` | `PascalCase` | `UPPER_SNAKE_CASE` |
| **Go** | `camelCase` / `PascalCase` (exported) | `PascalCase` | `PascalCase` or `UPPER_SNAKE_CASE` |
| **JavaScript/TypeScript** | `camelCase` | `PascalCase` | `UPPER_SNAKE_CASE` |
| **Rust** | `snake_case` | `PascalCase` | `UPPER_SNAKE_CASE` |
| **Bash** | `snake_case` (local), `UPPER_SNAKE_CASE` (export) | N/A | `UPPER_SNAKE_CASE` |

---

## Spelling and Language

### Code: American English

**All source code uses American spelling** (programming language convention):

- ✅ `color`, `initialize`, `optimize`, `analyze`
- ✅ Variable names: `color_code`, `initializer`, `optimizer`
- ✅ Class names: `ColorPicker`, `DataAnalyzer`
- ❌ NOT: `colour`, `initialise`, `optimise`, `analyse` in code

**Why:** Consistency with standard libraries, frameworks, and global conventions.

### Documentation/Comments: Australian English

**HyperI documentation uses Australian spelling:**

- ✅ Documentation: "colour", "realise", "organise", "favour"
- ✅ Comments: "Initialise the database connection"
- ✅ Commit messages: "fix: optimise query performance"

**Example:**

```python
# ✅ Correct - American in code, Australian in comments
def initialize_color_picker():
    """Initialise the colour picker component."""
    color = "#FF0000"  # American variable name
    return ColorPicker(color)
```

---

## Temporary Files

### Development Work

**Use `./.tmp/` for ALL project-scoped temporary operations:**

- Test projects and artifacts
- Build intermediates
- Code assistant scratch files
- CI work files

**Why:** Project-scoped, easy cleanup, gitignored, no system pollution

### Production Code

**Use language-standard libraries:**

| Language | Library/Function |
|----------|-----------------|
| **Python** | `tempfile` module |
| **Go** | `os.MkdirTemp()`, `os.CreateTemp()` |
| **Node.js** | `tmp` or `temp` packages |
| **Rust** | `tempfile` crate |
| **Bash** | `mktemp` command |

**Security Rules:**

- ❌ NEVER hardcode `/tmp` paths
- ❌ NEVER use predictable filenames
- ❌ NEVER create temp files without cleanup
- ✅ ALWAYS use auto-cleanup (context managers, defer, RAII)
- ✅ ALWAYS set restrictive permissions

---

## Documentation Standards

### ALWAYS Document

- Public APIs (functions, classes, modules)
- Complex algorithms
- Non-obvious business logic
- Security considerations
- Performance considerations

### DON'T Document

- Obvious code (`i++` doesn't need a comment)
- Implementation details that change frequently
- WHAT code does (code should be self-documenting)

### DO Document

- WHY code does what it does
- Edge cases and gotchas
- Assumptions and constraints
- External dependencies

---

## Performance Guidelines

### General Principles

- Profile before optimising
- Optimise the hot path first
- Use appropriate data structures
- Cache expensive computations
- Batch operations when possible

### Common Anti-Patterns

- ❌ N+1 queries (database)
- ❌ Unnecessary nested loops
- ❌ Memory leaks (unclosed resources)
- ❌ Blocking operations in hot paths
- ❌ Excessive logging in production

---

## CLI Utility Preferences

Use modern CLI tools when available. Fall back to standard tools if not installed
(`command -v tool_name`).

| Task | Use | Instead of |
|------|-----|------------|
| Recursive text search | `rg` (ripgrep) | `grep -R` |
| Find files | `fd` / `fdfind` | `find` |
| File loops | `fd`, `parallel`, `xargs -0` | bash for loops |
| Search/replace | `sd` | `sed -i` |
| JSON | `jq` | grep/awk |
| YAML/JSON/XML/CSV/TOML | `yq` | grep/awk |
| CSV/TSV | `mlr` (Miller) | awk/cut |
| Directory trees | `rsync` | complex cp/mv |
| File preview | `bat` / `batcat` | `cat` |
| Interactive pickers | `fzf` | custom shell menus |

---

## Temporary Files

- Dev/CI: `./.tmp/` (project-scoped, gitignored)
- Production: use language tempfile libraries with auto-cleanup
- Never hardcode `/tmp`, never use predictable names
