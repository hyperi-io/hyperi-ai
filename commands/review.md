# Code Review

You are performing a code review of this project. Load the appropriate standards and analyse the codebase.

---

## Step 1: Detect Project Languages

Check for config files in project root to determine which language standards to load:

| Config File | Language |
|-------------|----------|
| `Cargo.toml` | Rust |
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python |
| `go.mod` | Go |
| `package.json`, `tsconfig.json` | TypeScript |
| `CMakeLists.txt`, `*.cpp`, `*.hpp` | C++ |
| `clickhouse-server.xml`, `.sql` with `ENGINE = *MergeTree` | ClickHouse SQL |

**Important:** A project may use multiple languages. Load ALL that apply.

Also check for shell scripts:

- If `scripts/` directory exists with `.sh` files → also load Bash
- If project is primarily shell scripts → load Bash

---

## Step 2: Load Standards

Load in this order:

### Load Per Detected Language

| Language | Standard File |
|----------|---------------|
| Rust | `hyperi-ai/standards/languages/RUST.md` |
| Python | `hyperi-ai/standards/languages/PYTHON.md` |
| Go | `hyperi-ai/standards/languages/GOLANG.md` |
| TypeScript | `hyperi-ai/standards/languages/TYPESCRIPT.md` |
| C++ | `hyperi-ai/standards/languages/CPP.md` |
| Bash | `hyperi-ai/standards/languages/BASH.md` |
| ClickHouse SQL | `hyperi-ai/standards/languages/SQL-CLICKHOUSE.md` |

### Always Load (universal standards)

These apply to all code — load for every review:
- `hyperi-ai/standards/universal/ERROR-HANDLING.md`
- `hyperi-ai/standards/universal/SECURITY.md`
- `hyperi-ai/standards/universal/TESTING.md`
- `hyperi-ai/standards/universal/MOCKS-POLICY.md`
- `hyperi-ai/standards/universal/DESIGN-PRINCIPLES.md`
- `hyperi-ai/standards/universal/CODE-STYLE.md`
- `hyperi-ai/standards/universal/AI-CONDUCT.md`

### Conditional

Only load if relevant files exist:

| Condition | Load |
|-----------|------|
| `Dockerfile` or `docker-compose.yaml` | `hyperi-ai/standards/infrastructure/DOCKER.md` |
| `certs/`, `ssl/`, `tls/`, `pki/` directories | `hyperi-ai/standards/universal/PKI.md` |
| `*.tf` files | `hyperi-ai/standards/infrastructure/TERRAFORM.md` |

---

## Step 3: Understand the Project

Before reviewing, understand what you're looking at:

1. **Read key files:**
   - `README.md` - what does this project do?
   - `STATE.md` or `CLAUDE.md` - project context (if exists)
   - Main entry point (`main.rs`, `main.py`, `main.go`, `index.ts`, etc.)

2. **Identify architecture:**
   - Is this a library or application?
   - What are the main modules/packages?
   - Where is the core business logic?

3. **Check existing patterns:**
   - How are errors handled currently?
   - What testing patterns are used?
   - Is there a consistent code style?

---

## Step 4: Perform the Review

Focus your review on:

### Priority 1 - Critical Issues (blockers)

- Security vulnerabilities (hardcoded secrets, injection, path traversal)
- Error handling that swallows/ignores errors
- Panics/crashes in library code
- Missing error context
- **License violations** (see License Compliance below)

### Priority 2 - Code Quality

- Functions that are too long or do too much
- Excessive nesting / complexity
- Copy-paste code that should be abstracted
- Missing tests for core functionality

### Priority 3 - Language-Specific

- Apply the patterns from the loaded language standard
- Check for language idioms being violated
- Look for anti-patterns specific to that language

---

## Step 5: Output Format

Structure your review as:

```markdown
# Code Review: [Project Name]

## Summary
[1-2 sentence overview of code quality and main findings]

## 🔴 Critical Issues (must fix)
- [file:line] **Issue title**
  - Problem: What's wrong
  - Fix: How to fix it
  - Example: (if helpful)

## 🟡 Improvements (should fix)
- [file:line] **Issue title**
  - Problem: What's wrong
  - Fix: How to fix it

## 🟢 Suggestions (nice to have)
- [file:line] Minor improvement suggestion

## ✅ What's Good
- Positive observations about the codebase
- Good patterns being followed
- Strong test coverage areas

## Recommendations
[Top 3-5 actionable next steps, prioritised]
```

---

## License Compliance (ALWAYS CHECK)

Every review must verify license compliance:

### LICENSE File

**Source of truth:** <https://github.com/hyperi-io/hyperi-licensing/tree/main/github-template>

- [ ] `LICENSE` file exists in project root
- [ ] Contains FSL-1.1-ALv2 (check for "Functional Source License")
- [ ] Copyright line references "HYPERI PTY LIMITED"

**If missing or wrong:** Flag as 🔴 Critical. Run `ci/attach.sh --init licensing` to fix.

### File Headers

Spot-check 3-5 source files for correct headers:

```text
License:      FSL-1.1-ALv2
Copyright:    (c) <YEAR> HYPERI PTY LIMITED
```

**If using old format:** Flag as 🟡 Improvement. Headers should use FSL-1.1-ALv2, not EULA.

### Dependency Licenses

Check for prohibited licenses in dependencies:

| License | Status |
|---------|--------|
| GPL, AGPL, LGPL | ❌ PROHIBITED (copyleft) |
| SSPL | ❌ PROHIBITED |
| CC-BY-NC | ❌ PROHIBITED (non-commercial) |
| MIT, Apache-2.0, BSD | ✅ Allowed |
| ISC, Zlib, Unlicense | ✅ Allowed |

**How to check:**

- Python: `pip-licenses` or check pyproject.toml
- Rust: `cargo deny check licenses` or check Cargo.toml
- Node: `license-checker` or check package.json
- Go: `go-licenses` or check go.mod

**If prohibited license found:** Flag as 🔴 Critical with specific dependency name.

---

## Review Scope Options

The user may specify a scope:

- `/review` - Full project review
- `/review src/` - Review specific directory
- `/review src/auth.rs` - Review specific file
- `/review --security` - Security-focused review only
- `/review --tests` - Test coverage/quality review only

Adjust your focus accordingly.
