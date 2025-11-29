# Coding Standards for HyperSec Projects

**Language-agnostic best practices for all software development**

---

## Core Principles

**HyperSec standards, AI guides and automation are built around three key principles:**

1. **Reduce cognitive load** - Simple, readable code for both humans and AI workflows
2. **Reduce context switching overhead** - Consistent patterns, standardized infrastructure, meaningful documentation
3. **Automated standards enforcement** - Make conforming to standards light work through automation

**See [README.md](README.md#core-principles) for detailed explanation.**

---

## Temporary Files and Directories

### Development Work

**Use `./.tmp/` for ALL project-scoped temporary operations:**

- Test projects and artifacts
- Build intermediates
- Code assistant scratch files
- CI work files

**Why:** Project-scoped, easy cleanup, gitignored, no system pollution

### Production/Runtime Code

**Language-specific guidance:**

- **Python:** Use `tempfile` module (see CODING-STANDARDS-PYTHON.md)
- **Go:** Use `os.MkdirTemp()` and `os.CreateTemp()`
- **Node.js:** Use `tmp` or `temp` packages
- **Rust:** Use `tempfile` crate

### Security Rules

❌ **NEVER** hardcode temporary paths (`/tmp`, `/var/tmp`, etc.)
❌ **NEVER** use predictable filenames
❌ **NEVER** create temp files without proper cleanup

✅ **ALWAYS** use language-standard temporary file libraries
✅ **ALWAYS** use auto-cleanup mechanisms (defer, RAII, context managers)
✅ **ALWAYS** set restrictive permissions (user-only when possible)

### Why

**Security:** Random names prevent TOCTOU. **Reliability:** Auto-cleanup prevents disk fill. **Portability:** Cross-platform. **Standards:** Best practices

---

## Code Style Standards

**For both human and AI code assistants**

### Clarity Over Cleverness

**Core Principles:**

- Break down compound operations into clear steps
- Use intermediate variables with descriptive names
- Prioritize readability over clever one-liners
- Add comments explaining WHY, not just WHAT
- Avoid dense operations that require mental parsing

### Why This Matters

**Maintainability:** Code read 10x more than written. **Debugging:** Clear code = obvious bugs. **Onboarding:** Faster understanding. **AI assistance:** Better parsing. **Code review:** Easier bug spotting

### Language-Agnostic Examples

**❌ Bad (dense, hard to follow):**

```javascript
const result = data.filter(n => n > 0).map(n => n * 2).reduce((a, b) => a + b, 0);
```

**✅ Good (clear, maintainable):**

```javascript
// Sum of doubled positive numbers
const positiveNumbers = data.filter(n => n > 0);
const doubledNumbers = positiveNumbers.map(n => n * 2);
const sum = doubledNumbers.reduce((a, b) => a + b, 0);
```

**❌ Bad (unexplained complex condition):**

```go
if (hasPermission && isActive) || (isAdmin && !isLocked) {
    process()
}
```

**✅ Good (explained logic):**

```go
// Allow if: (user has permission AND is active) OR (admin without lock)
normalUserAccess := hasPermission && isActive
adminOverride := isAdmin && !isLocked

if normalUserAccess || adminOverride {
    process()
}
```

### When Concise Code is OK

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

## No Mocks or Mock Code Policy

**Production code must be complete and functional before committing.**

❌ **NEVER commit:**

- Mock implementations or placeholder values
- TODO/FIXME/HACK comments in production code
- Example/demonstration code as real features
- Simplified "proof of concept" code

✅ **ALWAYS do:**

- Complete functionality before committing
- Handle all error cases and edge conditions
- Validate inputs and outputs
- Add tests verifying complete behavior

**Example:**

```javascript
// ❌ Bad (mock data)
function getUser(userId) {
    // TODO: Implement database lookup
    return { id: "123", name: "John Doe" };
}

// ✅ Good (real implementation)
async function getUser(userId) {
    if (!userId) throw new Error("userId is required");
    const user = await db.query("SELECT * FROM users WHERE id = $1", [userId]);
    if (!user) throw new UserNotFoundError(`User ${userId} not found`);
    return user;
}
```

**Mocks ONLY allowed in:**

- `tests/` directory (unit/integration tests)
- `examples/` directory (explicitly marked)
- Documentation code blocks

**AI warning signs (reject these):**

- "Here's a simple example..."
- "TODO: Add error handling"
- Hardcoded example data
- Always-successful operations (`return true`)
- Generic exception handling (`catch (Exception) {}`)

**See `$AI_ROOT/standards/common/NO-MOCKS-POLICY.md` for comprehensive policy guide with real-world examples.**

---

## Testing Standards

### Test Organization

**Standard directory structure:**

```
tests/
├── unit/          # Fast, isolated unit tests
├── integration/   # Component integration tests
└── e2e/           # End-to-end tests
```

### Test Requirements

**All projects MUST have:**

- Unit tests for core business logic
- Integration tests for external dependencies
- Minimum 80% code coverage
- Tests run before every build/release

**Test Naming:**

- Clear, descriptive test names
- Follow language conventions
- Explain WHAT is being tested

### Language-Specific Frameworks

**Python:** pytest
**Go:** testing package + testify
**Node.js:** Jest, Mocha, or Vitest
**Rust:** built-in `#[test]` + cargo test
**Java:** JUnit 5

**See language-specific standards for detailed testing guidance.**

---

## Security Standards

### Input Validation

**ALWAYS validate ALL external input:**

- User input (forms, CLI args, API requests)
- File uploads
- Environment variables
- Database query results
- External API responses

**Validation checklist:**

- [ ] Type checking
- [ ] Range/length limits
- [ ] Format validation (regex, parsing)
- [ ] Sanitization (SQL injection, XSS, etc.)
- [ ] Business logic constraints

### Secrets Management

❌ **NEVER** commit secrets to version control
❌ **NEVER** hardcode credentials in code
❌ **NEVER** log passwords, tokens, or API keys

✅ **ALWAYS** use environment variables
✅ **ALWAYS** use secret management tools (Vault, AWS Secrets Manager, etc.)
✅ **ALWAYS** rotate secrets regularly
✅ **ALWAYS** use different secrets per environment

### Dependency Security

**Requirements:**

- Security scanners for dependencies (language-specific)
- Automated vulnerability alerts
- Regular dependency updates
- Lock files for reproducible builds

**Language-specific tools:**

- **Python:** `bandit`, `pip-audit`
- **Go:** `govulncheck`
- **Node.js:** `npm audit`, `snyk`
- **Rust:** `cargo audit`

---

## Version Control Standards

### Commit Messages

**Format:** Conventional Commits

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**

- `feat:` New feature (minor version bump)
- `fix:` Bug fix (patch version bump)
- `docs:` Documentation only
- `refactor:` Code refactoring (no functional change)
- `test:` Test additions or updates
- `chore:` Maintenance, deps, config
- `perf:` Performance improvements

**Examples:**

```
feat(auth): add OAuth2 login support
fix(api): handle null response from database
docs: update README with installation steps
refactor: extract validation logic to utility
test: add integration tests for payment flow
chore: update dependencies to latest versions
```

### Branch Naming

**Format:** `<type>/<short-description>`

**Examples:**

```
feat/oauth-login
fix/null-pointer-exception
docs/update-readme
refactor/extract-validation
test/add-payment-tests
```

### Pull Request Standards

**PR Title:** Same format as commit message

**PR Description MUST include:**

- Summary of changes
- Related issue numbers
- Testing performed
- Screenshots (if UI changes)
- Breaking changes (if any)

---

## Code Organization Standards

### Function Ordering

**Helper-first approach (recommended for HyperSec projects):**

Place helper/child functions at the top, main/parent function at the bottom. This follows consumption order and makes code easier to refactor.

**✅ Good (helper-first):**

```
# Helper functions defined first
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

**Why helper-first:**

- Easy to cut/paste and reorder functions without breaking dependencies
- Reading top-to-bottom follows "zoom in" pattern (details → usage)
- Helper functions are defined before use (clearer dependencies)
- Refactoring is simpler (move helpers without updating order)

**Alternative (main-first):** Some teams prefer main function first (big picture → details). Both are acceptable - **pick one and stay consistent within each file**.

### Comment Numbering

**❌ NEVER number code comments or function steps:**

Bad (requires renumbering when reordering):

```
function processData(data) {
    // 1. Validate input
    validate(data);

    // 2. Transform data
    const transformed = transform(data);

    // 3. Save to database
    save(transformed);
}
```

**✅ ALWAYS use descriptive comments without numbers:**

Good (easy to reorder without refactoring):

```
function processData(data) {
    // Validate input
    validate(data);

    // Transform data
    const transformed = transform(data);

    // Save to database
    save(transformed);
}
```

**Why:** Numbered comments make code harder to refactor. When you cut/paste or reorder steps, you must also renumber all comments. This is tedious and error-prone.

---

## Design Principles

**Core principles for software design:**

**SOLID Principles:**

- **S**ingle Responsibility - one class, one reason to change
- **O**pen/Closed - open for extension, closed for modification
- **L**iskov Substitution - subtypes must substitute base types
- **I**nterface Segregation - no fat interfaces
- **D**ependency Inversion - depend on abstractions

**DRY (Don't Repeat Yourself):**

- Extract repeated logic to functions/classes
- Avoid code duplication
- Don't force abstraction (wait for 3+ duplicates)

**KISS (Keep It Simple, Stupid):**

- Favor simplicity over cleverness
- Avoid over-engineering
- Choose readable code over clever tricks

**YAGNI (You Aren't Gonna Need It):**

- Only implement what's needed NOW
- Don't add features "just in case"
- Refactor when requirements actually change

**See `$AI_ROOT/standards/common/DESIGN-PRINCIPLES.md` for comprehensive examples and explanations.**

---

## Error Handling Standards

**Security-first error handling:**

**Never expose to users:**

- ❌ Stack traces
- ❌ Database schemas or SQL
- ❌ File paths or system info
- ❌ Raw exception messages

**Always do:**

- ✅ Log full errors server-side (with context: user_id, request_id, timestamp, exc_info=True)
- ✅ Show generic messages to users ("Unable to process request")
- ✅ Use specific exception types (not bare `except Exception`)

**Never log sensitive data:**

- ❌ Passwords, tokens, API keys
- ❌ Credit cards, SSNs, PII
- ❌ Private keys, certificates

**Example (language-agnostic pattern):**

```
try {
    result = processPayment(amount, card);
} catch (InvalidCardError e) {
    logger.warning("Invalid card: " + e);
    return {"error": "Invalid card details"};
} catch (PaymentGatewayError e) {
    logger.error("Gateway error: " + e, e);
    return {"error": "Service unavailable"};
} catch (Exception e) {
    logger.critical("Unexpected: " + e, e);
    return {"error": "An error occurred"};
}
```

**See `$AI_ROOT/standards/common/ERROR-HANDLING.md` for comprehensive error handling guide.**

---

## Spelling and Language Guide

### Code: American English

**All source code uses American spelling** (programming language convention):

- ✅ `color`, `initialize`, `optimize`, `analyze`
- ✅ Variable names: `color_code`, `initializer`, `optimizer`
- ✅ Class names: `ColorPicker`, `DataAnalyzer`
- ✅ Function names: `initialize_app()`, `optimize_query()`
- ❌ NOT: `colour`, `initialise`, `optimise`, `analyse` in code

**Why:** Consistency with Python stdlib, frameworks, and global programming conventions.

### Documentation/Comments/Chat: Australian English

**Everything else uses Australian spelling:**

- ✅ Documentation: "colour", "realise", "organise", "favour"
- ✅ Comments: "Initialise the database connection"
- ✅ Chat responses: "This should help you organise the data"
- ✅ Commit messages: "fix: optimise query performance"
- ✅ README/docs: "Colour-coded output", "Realise the benefits"

**Examples:**

```python
# ✅ Correct - American in code, Australian in comments
def initialize_color_picker():
    """Initialise the colour picker component."""  # Australian
    color = "#FF0000"  # American variable name
    return ColorPicker(color)  # American class/param
```

```python
# ❌ Wrong - Mixed or backwards
def initialise_colour_picker():  # Australian in code (WRONG)
    """Initialize the color picker."""  # American in docs (WRONG)
```

---

## Documentation Standards

### Code Documentation

**ALWAYS document:**

- Public APIs (functions, classes, modules)
- Complex algorithms
- Non-obvious business logic
- Security considerations
- Performance considerations

**DON'T document:**

- Obvious code (`i++` doesn't need a comment)
- Implementation details that change frequently
- What the code does (code should be self-documenting)

**DO document:**

- WHY the code does what it does
- Edge cases and gotchas
- Assumptions and constraints
- External dependencies

### README Requirements

**Every project MUST have:**

- Project description
- Installation instructions
- Quick start guide
- Configuration options
- Testing instructions
- License information

---

## Performance Standards

### General Principles

- Profile before optimizing
- Optimize the hot path first
- Use appropriate data structures
- Cache expensive computations
- Batch operations when possible

### Common Anti-Patterns

❌ N+1 queries (database)
❌ Unnecessary loops over loops
❌ Memory leaks (unclosed resources)
❌ Blocking operations in hot paths
❌ Excessive logging in production

---

## AI Code Assistant Guidelines

**For developers using AI code completion tools (Copilot, Claude Code, Cursor, Gemini, etc.)**

### Quality Warning

⚠️ **Research shows AI code completion has significant issues:**

- **4x higher defect rates** vs human-written code
- **19% longer completion time** (despite autocomplete)
- **More security vulnerabilities** (doesn't understand security context)

### Context Window Capabilities

- **Claude Code:** 200k tokens - best for multi-file refactoring
- **GitHub Copilot:** 8k-128k tokens (model-dependent)
- **Google Gemini:** 1M-2M tokens - largest context window
- **Cursor:** Similar to Copilot (multi-model support)

### Best Practices

**Always:**

- ✅ Review all AI suggestions (don't blindly accept)
- ✅ Test thoroughly (90%+ coverage for AI code)
- ✅ Security scan all AI-generated code
- ✅ Simplify prompts (complex = worse code)
- ✅ Iterate and refine (don't use first suggestion)

**Don't use AI for:**

- ❌ Security-critical code (auth, encryption)
- ❌ Complex algorithms
- ❌ Performance-critical code
- ❌ Regulatory/compliance code

**AI is good for:**

- ✅ Boilerplate generation
- ✅ Test case generation
- ✅ Documentation writing
- ✅ Code formatting/style fixes
- ✅ Simple CRUD operations

**See `$AI_ROOT/standards/code-assistant/AI-GUIDELINES.md` for comprehensive AI code assistant guide.**

---

**This document defines language-agnostic coding standards for all HyperSec projects.**

**See also:**

- Language-specific coding standards in `python/`, `go/`, `rust/`, etc.
- `details/AI-GUIDELINES.md` - AI code assistant best practices
