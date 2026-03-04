# HyperI Coding Standards — Quick Reference Index

This file is a router/index to the HyperI coding standards library.
Standards content is in the files referenced below — not in this file.

## Standards Architecture

Standards are delivered in three layers:

1. **Universal Rules** — `ai/standards/rules/UNIVERSAL.md` (~137 lines)
   Cross-cutting rules for ALL code: git, style, errors, security, testing, licensing.
   Always load this first.

2. **Path-Scoped Rules** — `ai/standards/rules/<topic>.md`
   Auto-injected when editing matching file types.

3. **Full Standards** — `ai/standards/languages/`, `ai/standards/infrastructure/`,
   `ai/standards/common/`
   Complete unabridged standards for deep reference, code review, and simplification.

## Available Rules

### Universal (always relevant, no path scope)

| File | Topic |
|------|-------|
| `rules/UNIVERSAL.md` | Git, style, errors, security, testing, licensing |
| `rules/testing.md` | Test structure, frameworks, test-first development |
| `rules/error-handling.md` | Security-first error handling |
| `rules/security.md` | Input validation, secrets, OWASP |
| `rules/design-principles.md` | SOLID, DRY, KISS, YAGNI |
| `rules/mocks-policy.md` | Mock-aware testing policy |

### Language-Specific (auto-injected by file type)

| Marker Files | Language | Rule File |
|--------------|----------|-----------|
| pyproject.toml, setup.py, requirements.txt, uv.lock | Python | `rules/python.md` |
| go.mod | Go | `rules/golang.md` |
| tsconfig.json, package.json | TypeScript/JS | `rules/typescript.md` |
| Cargo.toml | Rust | `rules/rust.md` |
| CMakeLists.txt, *.cpp, *.hpp | C++ | `rules/cpp.md` |
| *.sh | Bash | `rules/bash.md` |
| *.sql + MergeTree | ClickHouse SQL | `rules/clickhouse-sql.md` |

### Infrastructure (auto-injected by file type)

| Marker Files | Technology | Rule File |
|--------------|-----------|-----------|
| Dockerfile, docker-compose*.yml | Docker | `rules/docker.md` |
| Chart.yaml, values.yaml | Kubernetes | `rules/k8s.md` |
| *.tf, *.tfvars | Terraform | `rules/terraform.md` |
| ansible.cfg, playbook.yml | Ansible | `rules/ansible.md` |
| certs/, ssl/, pki/, tls/ | PKI/TLS | `rules/pki.md` |

## For AI Code Assistants

### Session Start

1. Read `TODO.md` and `STATE.md`
2. Read `ai/standards/rules/UNIVERSAL.md`
3. Language/infra rules are auto-injected by your agent when editing matching files

### When You Need Full Detail

Read the full standard from `ai/standards/languages/` or `ai/standards/infrastructure/`.
Appropriate for code review, simplification, or complex implementation decisions.
