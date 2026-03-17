# Simplify Code

Review changed code for reuse, quality, and efficiency, then fix any issues found.

**IMPORTANT:** Run every shell command as a separate call — never chain commands
with `&&`, `||`, or `;`. Compound commands force unnecessary permission prompts.

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

- `hyperi-ai/standards/universal/CODE-STYLE.md`
- `hyperi-ai/standards/universal/DESIGN-PRINCIPLES.md`

### Conditional

Only load if relevant files exist:

| Condition | Load |
|-----------|------|
| `Dockerfile` or `docker-compose.yaml` | `hyperi-ai/standards/infrastructure/DOCKER.md` |
| `*.tf` files | `hyperi-ai/standards/infrastructure/TERRAFORM.md` |

---

## Step 3: Load Base Simplification Rules

Read the marketplace code-simplifier agent for its base rules:

`~/.claude/plugins/marketplaces/claude-plugins-official/plugins/code-simplifier/agents/code-simplifier.md`

If this file does not exist, use these fallback principles:

- Preserve functionality — never change what the code does
- Reduce unnecessary complexity and nesting
- Eliminate redundant code and abstractions
- Improve readability through clear variable and function names
- Avoid nested ternaries — prefer match/switch/if-else
- Choose clarity over brevity
- Focus on recently modified code unless instructed otherwise

---

## Step 4: Apply Both

Apply the **loaded language standards** (Step 2) AND the **base simplification rules**
(Step 3) together. Where they conflict, the language standards take precedence —
they encode project-specific idioms that override generic simplification heuristics.

**Process:**

1. Identify recently modified code (`git diff --name-only` against the session start
   or last commit)
2. For each changed file, apply the correct language standard
3. Apply base simplification rules on top
4. Ensure all functionality remains unchanged
5. Present changes for user review

**Scope options:**

- `/simplify` — recently modified files only
- `/simplify src/` — specific directory
- `/simplify src/auth.rs` — specific file
