# Project Documentation Generator

Analyse this project thoroughly and produce comprehensive, accurate documentation
with mermaid diagrams. Documentation must reflect the **actual code and
infrastructure reality** — not aspirational or outdated descriptions.

> **This is an analysis-first skill.** Read the code before writing docs.
> Every claim in the output must be traceable to actual source files.

---

## Step 1: Deep Project Analysis

### 1a. Identify Project Type

Determine what this project is by reading actual source files:

| Check | How |
|---|---|
| Language | `Cargo.toml`, `pyproject.toml`, `go.mod`, `package.json`, `CMakeLists.txt` |
| Type | Binary/library/service/CLI/infrastructure |
| Entry points | `main.rs`, `main.py`, `main.go`, `index.ts`, `main()` |
| Build system | `Makefile`, CI config, `justfile` |

### 1b. Map the Architecture

Use parallel subagents to explore the codebase simultaneously:

**Agent 1 — Module/Package Structure:**
- List all top-level modules, packages, or directories with source code
- For each: read the module entry point and identify its responsibility
- Map dependencies between modules (imports, use statements)

**Agent 2 — External Dependencies & Interfaces:**
- Read dependency manifests (`Cargo.toml`, `pyproject.toml`, `package.json`, etc.)
- Identify external services (databases, APIs, message queues, cloud services)
- Find configuration files and environment variable usage
- Check for IaC files (`*.tf`, `ansible/`, `k8s/`, `helm/`, `docker-compose.yml`)

**Agent 3 — Data Flow & State:**
- Trace the primary data path from input to output
- Identify data models, schemas, database migrations
- Find state management patterns (caches, sessions, queues)
- Map error handling and logging patterns

### 1c. Infrastructure Reality Check (if IaC present)

If the project contains infrastructure-as-code:

1. Read ALL Terraform/Ansible/K8s/Docker files
2. Map deployed resources and their relationships
3. Cross-reference with application code — does the app actually USE what's deployed?
4. Flag any infrastructure defined but not referenced by code (or vice versa)

---

## Step 2: Documentation vs Reality Audit

**BEFORE writing new docs, audit existing ones.**

1. Read ALL existing documentation: `README.md`, `STATE.md`, `docs/`, `ARCHITECTURE.md`
2. For each claim in existing docs, verify against actual code:
   - File paths mentioned — do they exist?
   - APIs described — do they match the actual signatures?
   - Architecture described — does it match the actual module structure?
   - Dependencies listed — are they current? Any missing or removed?
   - Configuration described — do the env vars/config files actually exist?
3. If IaC is present: verify infrastructure docs match actual resource definitions

### Audit Output

Produce a drift report before generating new documentation:

```markdown
## Documentation Drift Report

### Accurate (verified against code)
- [claim] — confirmed in [file:line]

### Stale (no longer matches code)
- [claim from docs] — actual state: [what the code shows]
- File: [doc file:line] → should reference [correct file:line]

### Missing (undocumented)
- [module/feature] exists in code but not in any documentation
```

Present this report to the user before proceeding to Step 3.

---

## Step 3: Generate Documentation

Based on the analysis, produce documentation in `docs/`. If `docs/` doesn't
exist, create it.

### 3a. Architecture Overview (`docs/ARCHITECTURE.md`)

```markdown
# Architecture

## Overview
[1-2 paragraphs: what this project does, how it's structured]

## System Diagram
```mermaid
graph TD
    %% Generate from actual module analysis, not imagination
```

## Components
### [Module Name]
- **Location:** `src/module/`
- **Purpose:** [from actual code analysis]
- **Key files:** [list actual files with one-line descriptions]
- **Dependencies:** [what it imports/uses]

## Data Flow
```mermaid
sequenceDiagram
    %% Trace actual request/data path from code
```

## Configuration
| Variable | Source | Used By |
|---|---|---|
| [actual env var] | [.env / config file] | [module that reads it] |
```

### 3b. Infrastructure Diagram (if IaC present)

```markdown
## Infrastructure

```mermaid
graph TD
    %% Generated from actual Terraform/K8s/Docker resources
```

| Resource | Type | Defined In | Used By |
|---|---|---|---|
| [resource name] | [type] | [file:line] | [app module] |
```

### 3c. Data Model Diagram (if applicable)

```markdown
## Data Model

```mermaid
erDiagram
    %% Generated from actual schema/model definitions
```
```

### 3d. API Surface (if applicable)

Document all public APIs, CLI commands, or service endpoints found in
the actual code. Include request/response shapes from type definitions.

### 3e. Build & Deploy Pipeline

```markdown
## Build Pipeline

```mermaid
flowchart LR
    %% Generated from Makefile/CI config/hyperi-ci.yaml
```
```

---

## Step 4: Update README.md

After generating `docs/`, review `README.md`:

1. Ensure it links to `docs/ARCHITECTURE.md` for detailed architecture
2. Verify install/build/test instructions actually work
3. Update any stale sections identified in the drift report
4. Keep README concise — link to `docs/` for depth

**Do NOT bloat the README.** It should be a landing page, not a book.

---

## Step 5: Update STATE.md

If `STATE.md` exists, verify it reflects the current architecture:

1. Cross-reference architecture section against `docs/ARCHITECTURE.md`
2. Update key file paths if they've changed
3. Update tech stack if dependencies changed
4. Do NOT add dates, version numbers, or task lists (per UNIVERSAL.md rules)

---

## Step 6: Summary

Present to the user:

1. **Drift report** — what was stale, what was missing
2. **Files created/updated** — list with brief descriptions
3. **Diagrams generated** — list diagram types and what they show
4. **Recommendations** — any architectural concerns discovered during analysis

---

## Scope Options

The user may specify a scope:

- `/doco` — Full project documentation
- `/doco src/auth/` — Document specific module
- `/doco --infra` — Infrastructure documentation only
- `/doco --api` — API surface documentation only
- `/doco --audit` — Drift report only (no new docs)
- `/doco --diagrams` — Mermaid diagrams only

---

## Rules

### Analysis Rules

1. **Code is truth.** Every diagram and description must come from actual
   source analysis. Never invent components or flows.
2. **Verify before claiming.** Don't say "the API handles authentication"
   unless you've read the auth code and traced the flow.
3. **Use parallel agents.** The analysis phase should dispatch 3+ agents
   to explore the codebase concurrently for speed.
4. **Mermaid over prose.** Prefer diagrams for relationships, flows, and
   architecture. Use prose for decisions and rationale.
5. **Minimise noise.** Don't document trivial code. Focus on boundaries,
   interfaces, and non-obvious behaviour.

### Writing Rules (from UNIVERSAL.md — enforce strictly)

6. **Australian English for prose.** Use `colour`, `initialise`, `optimise`,
   `serialise` in all documentation text, comments, and descriptions.
   American English only for code identifiers (`color`, `initialize`).
7. **No emojis.** Never use emojis in generated documentation. Use markdown
   formatting (bold, headers, tables) for emphasis instead.
8. **No LLM cheerleading.** No "Great!", "Amazing!", "World-class!" language.
   Write direct, technically accurate, understated prose.
9. **No decorative separators.** No `# ====`, `# ────`, or similar.
10. **File headers.** All generated markdown files must include the standard
    HyperI file header (Project, File, Purpose, License, Copyright).
11. **No TODOs/FIXMEs in output.** Generated documentation must be complete.
    If something is unknown, say "undocumented" — don't leave placeholders.
12. **Commit message for doc changes:** Use `docs:` prefix (no version bump).
13. **Concise.** Keep descriptions short. One paragraph per component.
    Link to source files instead of inlining large code blocks.
