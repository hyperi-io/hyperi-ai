---
name: documentation
description: >-
  Documentation standards and code-reality auditing. Use when writing or
  updating docs, README, STATE.md, or ARCHITECTURE.md. Docs must match
  actual code — verify before writing.
---
<!-- Project: HyperI AI -->

# Documentation Standards

## The Iron Law

```
DOCUMENTATION MUST MATCH CODE REALITY
```

Stale documentation is actively harmful — it misleads developers and AI
agents into wrong assumptions. Every doc claim must be traceable to
actual source files.

## Keep Documentation Current

When making significant changes (new modules, architectural decisions,
API changes, new dependencies), update the relevant documentation in
the same commit or PR.

### What Triggers a Doc Update

| Change | Update Required |
|---|---|
| New module/package | README architecture section, STATE.md, `docs/ARCHITECTURE.md` |
| New external dependency | README prerequisites, dependency docs |
| API signature change | API docs, usage examples |
| Config/env var added | Configuration section, STATE.md |
| Infrastructure change (IaC) | Infrastructure docs, deployment diagrams |
| Entry point or CLI change | README usage section |
| Module deleted or renamed | Remove/update ALL references in docs |

### Documentation Drift Detection

Before writing or updating docs, verify existing docs against code:

1. File paths mentioned — do they still exist?
2. APIs described — do signatures match?
3. Config/env vars — are they still used?
4. Architecture described — does it match actual module structure?
5. Dependencies listed — current? Any added or removed?

If you find drift, fix it. Don't add new docs on top of stale docs.

## What Every Project Needs

### README.md (mandatory)

- What the project does (one paragraph)
- How to install/build/run (verified working commands)
- How to test
- Architecture overview (link to `docs/` if complex)
- Configuration/environment variables

### STATE.md (AI context — mandatory for AI-assisted projects)

- Project architecture and key decisions (with WHY)
- Tech stack and dependencies
- Key file paths and module boundaries
- NOT: version numbers, task lists, session history

### docs/ARCHITECTURE.md (recommended for 3+ modules)

- System diagram (mermaid)
- Component descriptions with file paths
- Data flow diagrams
- Infrastructure diagram (if IaC present)

## Mermaid Diagrams

Use mermaid diagrams in markdown for:

| Diagram Type | Use When |
|---|---|
| **Architecture** (`graph TD`) | 3+ components interacting |
| **Sequence** (`sequenceDiagram`) | Request/response flows, API interactions |
| **Entity-relationship** (`erDiagram`) | Data models, database schemas |
| **Flowchart** (`flowchart LR`) | Build pipelines, decision logic |
| **State** (`stateDiagram-v2`) | Lifecycle management, status transitions |

### Diagram Rules

- **Generate from code analysis, not imagination.** Every node and edge
  must correspond to actual components and relationships.
- Create diagrams when 3+ components interact or data flow isn't obvious
- Don't diagram trivial relationships (single-file scripts, simple CRUD)
- Keep diagrams focused — split large ones into multiple smaller diagrams
- Use descriptive node labels, not abbreviations

## Infrastructure Documentation (IaC Projects)

When Terraform, Ansible, K8s, or Docker files are present:

1. Document ALL deployed resources and their relationships
2. Cross-reference infra with application code — does the app USE what's deployed?
3. Flag orphaned resources (defined but unreferenced) or missing resources
   (referenced but not defined)
4. Include the actual resource names, not just types

## Documentation Location

| Type | Location |
|---|---|
| Project overview | `README.md` |
| AI/agent context | `STATE.md` |
| Architecture | `docs/ARCHITECTURE.md` |
| API documentation | `docs/API.md` or inline (rustdoc, pydoc, jsdoc) |
| Decision records | `docs/decisions/` or inline in STATE.md |
| Generated docs | `docs/` (via `/doco` command) |

## Avoid Hardcoded Counts

Never embed counts that will go stale when code changes:

- ❌ "132 BATS tests", "21 rule files", "7 hooks"
- ✅ "BATS test suite", "rule files covering languages and infrastructure"

Hardcoded counts create maintenance debt — every addition or removal
requires a doc update. Use prose descriptions instead.

## Anti-Patterns

- Writing docs without reading the code first
- Copying architecture descriptions from memory instead of code analysis
- Leaving TODO/placeholder sections in committed documentation
- Documenting aspirational architecture instead of actual architecture
- Bloating README with content that belongs in `docs/`
- Embedding counts (files, tests, rules) that go stale on every change
