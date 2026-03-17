---
name: hyperi-standards
description: HyperI coding standards and best practices. Use when writing code, reviewing code, making commits, or when quality and consistency matter.
---

# HyperI Coding Standards

Standards for all HyperI projects. Delivered as a git submodule (`hyperi-ai/`)
and automatically injected into AI assistant context at session start.

---

## Directory Structure

```
standards/
├── universal/           Cross-cutting standards (all code, all projects)
├── languages/           Language-specific (Python, Rust, Go, TypeScript, C++, Bash, SQL)
├── infrastructure/      Infrastructure (Docker, K8S, Terraform, Ansible)
└── rules/               Compact rules (LLM-generated from above, auto-injected)
```

---

## How Standards Are Delivered

Standards are injected automatically via hooks — no manual loading needed.

**Compact tier** (200K context, default): LLM-compressed rules from `standards/rules/`.
**Full tier** (1M+ context, auto-detected): Complete source standards from `standards/{universal,languages,infrastructure}/`.

Detection is automatic (VS Code model selection or `HYPERI_CONTEXT_TIER` env var).

---

## For AI Code Assistants (Claude Code, Cursor, Copilot, Gemini, Codex)

### What Gets Loaded Automatically

1. **Universal rules** — collation of all `standards/universal/*.md` (always)
2. **Detected tech rules** — matched by project files (Cargo.toml → Rust, pyproject.toml → Python, etc.)
3. **Skills** — verification, bleeding-edge protection, documentation

### When You Need Full Detail

Read the complete standard from `standards/languages/` or `standards/infrastructure/`.
Use for: code review, simplification, complex implementation decisions.

### Session Start

1. Standards are auto-injected — no action needed
2. Read `TODO.md` and `STATE.md` for project context
3. Language/infrastructure rules match automatically by file type

---

## Quick Reference — What's Where

### Universal (apply to all code)

| Standard | Covers |
|----------|--------|
| AI-CONDUCT.md | Communication style, AI code of conduct, three-iteration rule |
| CHARS-POLICY.md | Spelling split (American code / Australian docs), character restrictions |
| CI.md | hyperi-ci, semantic-release, GitHub Actions |
| CODE-HEADER.md | File header format (all languages) |
| CODE-STYLE.md | Clarity, naming, CLI tools, temporary files |
| CONFIG-AND-LOGGING.md | 7-layer config cascade, RFC 3339 logging |
| DESIGN-PRINCIPLES.md | SOLID, DRY, KISS, YAGNI |
| ERROR-HANDLING.md | Security-first error handling |
| GIT.md | Commit types, branch naming, semantic-release alignment |
| LICENSING.md | FSL-1.1-ALv2 default, no GPL/AGPL/SSPL |
| LINEAR-TICKETS.md | Issue tracking (GH Issues + Linear) |
| MOCKS-POLICY.md | No mocks — test against real dependencies |
| PKI.md | TLS, SSH, certificates, CNSA 2.0 |
| REPO-NAMING.md | Repository naming by product scope |
| SECURITY.md | Input validation, secrets management |
| TESTING.md | Test-first development, 80% coverage |

### Languages (auto-detected by marker files)

| Marker | Language | File |
|--------|----------|------|
| `Cargo.toml` | Rust | `languages/RUST.md` |
| `pyproject.toml`, `setup.py` | Python | `languages/PYTHON.md` |
| `go.mod` | Go | `languages/GOLANG.md` |
| `tsconfig.json`, `package.json` | TypeScript/JS | `languages/TYPESCRIPT.md` |
| `CMakeLists.txt`, `*.cpp` | C++ | `languages/CPP.md` |
| `*.sh` | Bash | `languages/BASH.md` |
| `*.sql` | ClickHouse SQL | `languages/SQL-CLICKHOUSE.md` |

### Infrastructure (auto-detected by marker files)

| Marker | Technology | File |
|--------|-----------|------|
| `Dockerfile` | Docker | `infrastructure/DOCKER.md` |
| `Chart.yaml` | Kubernetes/Helm | `infrastructure/K8S.md` |
| `*.tf` | Terraform | `infrastructure/TERRAFORM.md` |
| `ansible.cfg` | Ansible | `infrastructure/ANSIBLE.md` |

---

## Source of Truth

| Data | Source | NOT From |
|------|--------|----------|
| Version | `git describe --tags` or `VERSION` | STATE.md, agent memory |
| Tasks | `TODO.md` | STATE.md, agent memory |
| History | `git log` | STATE.md, agent memory |
| Changelog | `CHANGELOG.md` (semantic-release) | STATE.md, agent memory |
| Project context | `STATE.md` (symlinked as CLAUDE.md, etc.) | agent memory |

---

## Tool-Specific Notes

### Claude Code

Standards injected via `hooks/inject_standards.py` at session start and on
context compaction. Auto-memory at `~/.claude/projects/<hash>/memory/` —
do not duplicate STATE.md content there.

### Cursor IDE

Rules deployed to `.cursor/rules/*.mdc`. Notepads are ephemeral — do not
rely on them for shared context.

### Gemini Code

Settings in `.gemini/`. Same principle: do not duplicate STATE.md into
agent-local storage.

### Copilot / Codex / Others

Read this quickstart file, then the relevant standards for your project's
languages and infrastructure. Standards are plain markdown — any tool that
reads markdown files can use them.
