---
name: hyperi-standards
description: HyperI coding standards and best practices. Use when writing code, reviewing code, making commits, or when quality and consistency matter. Covers git conventions, error handling, security, testing, and design principles.
---

# HyperI Coding Standards

Comprehensive coding standards for all HyperI projects.

**Path Convention:** All file references use `$AI_ROOT` to indicate the directory where this repository is attached (e.g., `ai/`, `standards/`, `.ai/`). This makes standards path-agnostic and works regardless of where the repository is located.

---

## About These Standards

This standards library represents the collation of years of HyperI (and Derek's prior) experience building at-scale, high-automation DevOps, DataOps, and DevSecOps projects. It is designed as an AI-friendly knowledge base that can be attached to any project as a git submodule.

---

## Core Principles

**Everything in HyperI standards, AI guides, and CI automation is built around three key principles:**

### 1. Reduce Cognitive Load

**For developers AND AI-assisted workflows:**

- Simple, readable code (minimize extraneous cognitive load)
- Self-documenting patterns (clear names, early returns, explicit logic)
- Consistent patterns across all projects (mental model transfers)
- Human-first design (no AI conventions to learn)

**Research:** 23-45 minute recovery time after context switches, working memory limited to 4-7 concepts

### 2. Reduce Context Switching Overhead

**For developers AND AI-assisted workflows:**

- Project-specific context files (STATE.md, TODO.md, ARCHITECTURE.md)
- Standardised infrastructure (hyperi-pylib, hyperi-rustlib, [HyperI CI](https://github.com/hyperi-io/ci), same tools everywhere)
- Meaningful commits and documentation (faster "resume" time)
- Time-boxed work (minimum 2-hour chunks per project)

**Cost:** $50k/year per developer in lost productivity from context switching

### 3. Automated Standards Enforcement

**Make conforming to standards light work:**

- Automated checks (ruff, black, isort, mypy, bandit)
- Pre-commit hooks (validation before commit, not after)
- CI pipeline enforcement (tests, lint, security scans)
- Simple commands abstract complex tasks (`./ci/run check`, `./ci/run build`)

**Result:** Standards are enforced automatically, not manually remembered

**These three principles work together:**

- Standards reduce cognitive load → easier to follow
- Automation enforces standards → no manual effort
- Reduced context switching → standards become muscle memory

---

## Quick Start

**New to HyperI?** Start here:

1. Read `$AI_ROOT/standards/common/CODE-STYLE.md` - Core language-agnostic code style
2. Read `$AI_ROOT/standards/common/GIT.md` - Git conventions
3. Read language-specific file from `$AI_ROOT/standards/languages/` based on your project
4. For infrastructure, also read relevant files from `$AI_ROOT/standards/infrastructure/`

---

## Directory Structure

```text
standards/
├── STANDARDS.md (this file - entry point for 500K+ context)
├── STANDARDS-QUICKSTART.md (quick reference index to rules)
│
├── code-assistant/ (AI guidance - language agnostic)
│   ├── COMMON.md (session mgmt, bash, commits)
│   └── AI-GUIDELINES.md (cognitive load research)
│
├── common/ (language-agnostic standards)
│   ├── CHARS-POLICY.md (character/emoji policy)
│   ├── CODE-HEADER.md (file header standards)
│   ├── CODE-STYLE.md (clarity, naming, organisation)
│   ├── CONFIG-AND-LOGGING.md (7-layer cascade, RFC 3339)
│   ├── DESIGN-PRINCIPLES.md (SOLID, DRY, KISS, YAGNI)
│   ├── ERROR-HANDLING.md (security-first errors)
│   ├── GIT.md (git conventions)
│   ├── LICENSING.md (FSL-1.1-ALv2)
│   ├── MOCKS-POLICY.md (mock-aware testing policy)
│   ├── PKI.md (TLS, SSH, certificates, CNSA 2.0)
│   ├── SECURITY.md (input validation, secrets)
│   └── TESTING.md (test-first development)
│
├── languages/ (language-specific standards)
│   ├── PYTHON.md
│   ├── GOLANG.md
│   ├── TYPESCRIPT.md
│   ├── RUST.md
│   ├── BASH.md
│   └── SQL-CLICKHOUSE.md
│
└── infrastructure/ (infrastructure standards)
    ├── DOCKER.md (Dockerfile, multi-stage, health checks)
    ├── K8S.md (HELM, pods, ArgoCD, KEDA)
    ├── TERRAFORM.md (HCL, EKS, state mgmt)
    └── ANSIBLE.md (playbooks, roles)
```

---

## Standards by Topic

### Code Style & Quality (Daily Use)

**Code style:** `$AI_ROOT/standards/common/CODE-STYLE.md` (clarity, naming, organisation)
**Design principles:** `$AI_ROOT/standards/common/DESIGN-PRINCIPLES.md` (SOLID, DRY, KISS, YAGNI)
**Configuration & logging:** `$AI_ROOT/standards/common/CONFIG-AND-LOGGING.md` (7-layer cascade, RFC 3339)

**Language-specific:** See `$AI_ROOT/standards/languages/` directory for your language.

### Git Workflow (Every Commit)

**Full guide:** `$AI_ROOT/standards/common/GIT.md`

**Quick tips:**

- Commit format: `<type>: <description>`
- Use `fix:` by default (not `feat:`)
- Branch format: `<type>/<description>`
- Conventional Commits standard

### Error Handling & Security

**Error handling:** `$AI_ROOT/standards/common/ERROR-HANDLING.md`
**Security:** `$AI_ROOT/standards/common/SECURITY.md`
**PKI/TLS:** `$AI_ROOT/standards/common/PKI.md`

**Key rules:**

- Never expose stack traces to users
- Always log with context (user_id, request_id, timestamp)
- Use specific exception types
- Never log sensitive data (passwords, tokens, PII)
- Validate ALL external input
- Use parameterised queries (prevent SQL injection)
- TLS 1.2+ required, Ed25519 for SSH, ECDSA P-384 for prod TLS certs

### Testing

**Testing standards:** `$AI_ROOT/standards/common/TESTING.md`

**Key rules:**

- 80% minimum coverage
- Tests run before build/release
- Unit + integration + e2e tests
- Write tests before modifying existing code

### Containerization & Deployment (When Needed)

**Full guide:** `$AI_ROOT/standards/infrastructure/DOCKER.md`

**Infrastructure:** See `$AI_ROOT/standards/infrastructure/` directory for K8s, Terraform, Ansible.

**Quick tips:**

- Kubernetes + HELM + ArgoCD deployment
- Multi-stage Dockerfile (build vs runtime)
- Include debug utilities (curl, nc, ping)
- Health checks required (/health/live, /health/ready, /health/startup)
- Non-root user always

### Code Completeness (Review/AI Code)

**Mock-aware testing:** `$AI_ROOT/standards/common/MOCKS-POLICY.md`

### AI Code Assistants

**Mandatory guidance:** `$AI_ROOT/standards/code-assistant/COMMON.md`
**Detailed research:** `$AI_ROOT/standards/code-assistant/AI-GUIDELINES.md`

**Key warnings:**

- AI code has 4x higher defect rates - always review
- Human-first design principle (no AI conventions)
- Cognitive load must be same or less than human-written code

---

## Standards by Role

### For Developers (Daily Use)

**Read once:**

1. `$AI_ROOT/standards/common/CODE-STYLE.md` - Core code style
2. `$AI_ROOT/standards/common/GIT.md` - Commit conventions
3. Your language file from `$AI_ROOT/standards/languages/`

**Bookmark for reference:**

- `$AI_ROOT/standards/common/ERROR-HANDLING.md` - When writing error handling
- `$AI_ROOT/standards/common/CONFIG-AND-LOGGING.md` - When setting up config/logging
- `$AI_ROOT/standards/common/DESIGN-PRINCIPLES.md` - When designing architecture
- `$AI_ROOT/standards/infrastructure/` - When working with K8s or Terraform

### For Code Reviewers

**Check against:**

1. `$AI_ROOT/standards/common/CODE-STYLE.md` - Core standards compliance
2. `$AI_ROOT/standards/common/MOCKS-POLICY.md` - Mock-aware testing, no placeholder code
3. `$AI_ROOT/standards/common/ERROR-HANDLING.md` - Security-first errors
4. `$AI_ROOT/standards/common/SECURITY.md` - Input validation, secrets
5. `$AI_ROOT/standards/code-assistant/AI-GUIDELINES.md` - Extra scrutiny for AI code
6. Language-specific file from `$AI_ROOT/standards/languages/`

### For Project Leads

**Architecture decisions:**

- `$AI_ROOT/standards/common/DESIGN-PRINCIPLES.md` - SOLID, DRY, KISS, YAGNI
- `$AI_ROOT/standards/infrastructure/DOCKER.md` - Container architecture

**Process enforcement:**

- `$AI_ROOT/standards/common/GIT.md` - Git conventions

---

## Compliance Checklist

**Before committing code, verify:**

- [ ] Follows code style standards (`$AI_ROOT/standards/common/CODE-STYLE.md`)
- [ ] Follows language-specific standards (`$AI_ROOT/standards/languages/`)
- [ ] No TODO/FIXME comments in src/ (`$AI_ROOT/standards/common/MOCKS-POLICY.md`)
- [ ] Error handling is security-first (`$AI_ROOT/standards/common/ERROR-HANDLING.md`)
- [ ] Input validation present (`$AI_ROOT/standards/common/SECURITY.md`)
- [ ] Tests pass (80%+ coverage) (`$AI_ROOT/standards/common/TESTING.md`)
- [ ] Commit message follows format (`$AI_ROOT/standards/common/GIT.md`)
- [ ] No sensitive data logged

**Language-specific checks:** See your language file in `$AI_ROOT/standards/languages/`

---

## For Code Assistants

### Loading Standards

**All AI code assistants load:**

1. `$AI_ROOT/standards/rules/UNIVERSAL.md` (cross-cutting rules — always load first)
2. Path-scoped rules from `$AI_ROOT/standards/rules/` (auto-injected by agent when editing matching files)
3. Full standards from `$AI_ROOT/standards/languages/` and `$AI_ROOT/standards/infrastructure/` for deep reference

**Auto-detection:** Match project files (e.g., `pyproject.toml`, `go.mod`, `Chart.yaml`, `*.tf`) to the corresponding compact rule in `$AI_ROOT/standards/rules/`. Full standards are available for code review and complex decisions.

---
