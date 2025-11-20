# HyperSec Coding Standards

**Comprehensive coding standards for all HyperSec projects**

**Path Convention:** All file references use `$AI_ROOT` to indicate the directory where this repository is attached (e.g., `ai/`, `standards/`, `.ai/`). This makes standards path-agnostic and works regardless of where the repository is located.

---

## Core Principles

**Everything in HyperSec standards, AI guides, and HS-CI automation is built around three key principles:**

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
- Standardized infrastructure (hs-lib, HS-CI, same tools everywhere)
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

**New to HyperSec?** Start here:
1. Read `$AI_ROOT/standards/common/QUICK-REFERENCE.md` - One-page cheat sheet
2. Read `$AI_ROOT/standards/common/CODING.md` - Core language-agnostic standards
3. **Python projects:** Read `$AI_ROOT/standards/python/CODING-PYTHON.md`
4. Read `$AI_ROOT/standards/common/GIT.md` - Git conventions

---

## Directory Structure

```
standards/
├── STANDARDS.md (this file - entry point)
│
├── Core Standards (root level)
├── CHARS-POLICY.md
├── CODE-HEADER.md
├── QUICK-REFERENCE.md
├── GIT.md
│
├── code-assistant/ (AI guidance - loaded on session start)
│   ├── COMMON.md (session mgmt, bash, commits)
│   ├── HS-CI.md (CI infrastructure guidance)
│   ├── PYTHON.md (Python-specific guidance)
│   └── AI-GUIDELINES.md (cognitive load research)
│
├── ai/ (AI workflow docs - NOT loaded on session start)
│   └── TOKEN-ENGINEERING.md (token optimization workflow)
│
├── common/ (language-agnostic standards)
│   ├── CODING.md (core coding standards)
│   ├── CONTAINERIZATION.md (k8s + HELM + ArgoCD)
│   ├── DESIGN-PRINCIPLES.md (SOLID, DRY, KISS)
│   ├── ERROR-HANDLING.md (security-first errors)
│   ├── NO-MOCKS-POLICY.md (production code policy)
│   └── TEST-FIRST.md (test-first development)
│
└── python/ (Python-specific standards)
    ├── CODING.md (Python coding standards)
    ├── PEP8.md (comprehensive PEP 8 guide)
    └── HS-CI.md (HS-CI Python integration)
```

---

## Standards by Topic

### Code Quality

**Core principles:**
- SOLID, DRY, KISS, YAGNI → `$AI_ROOT/standards/common/DESIGN-PRINCIPLES.md`
- Clarity over cleverness → `$AI_ROOT/standards/common/CODING.md`
- No mocks in production → `$AI_ROOT/standards/common/NO-MOCKS-POLICY.md`

**Language-specific:**
- Python PEP 8 → `$AI_ROOT/standards/python/PEP8.md`
- Python coding standards → `$AI_ROOT/standards/python/CODING-PYTHON.md`

### Error Handling

**Quick reference:** `$AI_ROOT/standards/common/QUICK-REFERENCE.md` (error handling section)
**Comprehensive guide:** `$AI_ROOT/standards/common/ERROR-HANDLING.md`

**Key rules:**
- Never expose stack traces to users
- Always log with context (user_id, request_id, timestamp)
- Use specific exception types
- Never log sensitive data (passwords, tokens, PII)

### Testing

**Quick reference:** `$AI_ROOT/standards/common/QUICK-REFERENCE.md` (testing section)
**Test-first development:** `$AI_ROOT/standards/common/TEST-FIRST.md`

**Key rules:**
- 80% minimum coverage
- Tests run before build/release
- Unit + integration + e2e tests
- No mocks in production code
- Write tests before modifying existing code

### Containerization & Deployment

**Full guide:** `$AI_ROOT/standards/common/CONTAINERIZATION.md`

**Quick tips:**
- Kubernetes + HELM + ArgoCD deployment
- Multi-stage Dockerfile (build vs runtime)
- Include debug utilities (curl, nc, ping)
- Health checks required (/health/live, /health/ready, /health/startup)
- Non-root user always

### Git Workflow

**Full guide:** `$AI_ROOT/standards/common/GIT.md`

**Quick tips:**
- Commit format: `<type>: <description>`
- Use `fix:` by default (not `feat:`)
- Branch format: `<type>/<description>`
- Conventional Commits standard

### AI Code Assistants

**Mandatory guidance:** `$AI_ROOT/standards/code-assistant/COMMON.md`
**Detailed research:** `$AI_ROOT/standards/code-assistant/AI-GUIDELINES.md`
**Token optimization:** `$AI_ROOT/docs/TOKEN-ENGINEERING.md` (workflow doc, not loaded on start)

**Key warnings:**
- AI code has 4x higher defect rates - always review
- Human-first design principle (no AI conventions)
- Cognitive load must be same or less than human-written code

---

## Standards by Role

### For Developers (Daily Use)

**Read once:**
1. `$AI_ROOT/standards/common/QUICK-REFERENCE.md` - Keep this handy!
2. `$AI_ROOT/standards/common/CODING.md` - Core standards
3. `$AI_ROOT/standards/common/GIT.md` - Commit conventions

**Python developers also read:**
4. `$AI_ROOT/standards/python/CODING-PYTHON.md`

**Bookmark for reference:**
- `$AI_ROOT/standards/common/ERROR-HANDLING.md` - When writing error handling
- `$AI_ROOT/standards/common/DESIGN-PRINCIPLES.md` - When designing architecture
- `$AI_ROOT/standards/python/PEP8.md` - When Python linter complains

### For Code Reviewers

**Check against:**
1. `$AI_ROOT/standards/common/CODING.md` - Core standards compliance
2. `$AI_ROOT/standards/common/NO-MOCKS-POLICY.md` - No placeholder code
3. `$AI_ROOT/standards/common/ERROR-HANDLING.md` - Security-first errors
4. `$AI_ROOT/standards/code-assistant/AI-GUIDELINES.md` - Extra scrutiny for AI code

**Python projects:**
5. `$AI_ROOT/standards/python/CODING-PYTHON.md` - PEP 8, type hints

### For Project Leads

**Architecture decisions:**
- `$AI_ROOT/standards/common/DESIGN-PRINCIPLES.md` - SOLID, DRY, KISS, YAGNI
- `$AI_ROOT/standards/common/CONTAINERIZATION.md` - Deployment architecture

**Process enforcement:**
- `$AI_ROOT/standards/common/GIT.md` - Git conventions

---

## Compliance Checklist

**Before committing code, verify:**

- [ ] Follows language-agnostic standards (`$AI_ROOT/standards/common/CODING.md`)
- [ ] Follows language-specific standards (Python: `$AI_ROOT/standards/python/CODING-PYTHON.md`)
- [ ] No TODO/FIXME comments in src/ (`$AI_ROOT/standards/common/NO-MOCKS-POLICY.md`)
- [ ] Error handling is security-first (`$AI_ROOT/standards/common/ERROR-HANDLING.md`)
- [ ] Tests pass (80%+ coverage)
- [ ] Commit message follows format (`$AI_ROOT/standards/common/GIT.md`)
- [ ] No sensitive data logged
- [ ] Files/dirs follow naming rules (`$AI_ROOT/standards/common/CHARS-POLICY.md`)

**Python projects also verify:**
- [ ] PEP 8 compliant (ruff, black, isort)
- [ ] Type hints present (pyright)
- [ ] Security scan passes (bandit)
- [ ] Uses hs-lib infrastructure (not custom)

---

## For Code Assistants (Context-Adaptive Loading)

### Loading Strategy: Context-Adaptive

**If your context window >= 500K tokens: FULL CAG (Load All)**

Load ALL standards files using glob patterns:

```bash
# 1. All code-assistant files (AI guidance - ALWAYS load)
Glob: ci/docs/standards/code-assistant/*.md
Read: ALL matches

# 2. All common files (language-agnostic standards)
Glob: ci/docs/standards/common/*.md
Read: ALL matches

# 3. All language-specific files (Python example)
Glob: ci/docs/standards/python/*.md
Read: ALL matches (for Python projects)

# 4. Project overrides (if exist)
Glob: ci-local/code-assistant/*.md
Read: ALL matches (if any)
```

### Benefits

- ✅ **Maintenance-free** - New files automatically loaded via glob
- ✅ **Most reliable** - All standards always available, zero guessing
- ✅ **Zero hallucination risk** - Complete context loaded upfront
- ✅ **Plenty of room for work** - 500K+ context has ample space

---

**If your context window < 500K tokens: CAG/RAG Hybrid (Two-Tier)**

### Tier 1 - MANDATORY LOAD (Session Start)

Load essential files:

**1. All code-assistant/ files (AI guidance - ALWAYS load):**
```
Glob: ci/docs/standards/code-assistant/*.md
Read: ALL matches
```
Includes: COMMON.md, AI-GUIDELINES.md, PYTHON.md, HS-CI.md

**2. Essential common/ files (ALWAYS load):**
- Read: `ci/docs/standards/common/QUICK-REFERENCE.md`
- Read: `ci/docs/standards/common/GIT.md`
- Read: `ci/docs/standards/common/CHARS-POLICY.md`
- Read: `ci/docs/standards/common/CODE-HEADER.md`

**3. Python essentials (ALWAYS load for Python projects):**
- Read: `ci/docs/standards/python/CODING-PYTHON.md`

**4. Project overrides (if exist - ALWAYS load):**
```
Glob: ci-local/code-assistant/*.md
Read: ALL matches (if any)
```

---

**Tier 2 - ON-DEMAND (Load When Topic Discussed):**

Load these files when specific topics arise:

### RAG Index: When to Load Which File

**Architecture & Design:**
- Discussing SOLID, DRY, KISS, YAGNI? → Load `$AI_ROOT/standards/common/DESIGN-PRINCIPLES.md`
- Designing container deployment? → Load `$AI_ROOT/standards/common/CONTAINERIZATION.md`

**Error Handling:**
- Implementing error handling? → Load `$AI_ROOT/standards/common/ERROR-HANDLING.md`
- Security concerns about errors? → Load `$AI_ROOT/standards/common/ERROR-HANDLING.md`

**Code Quality:**
- Reviewing code for mocks/TODOs/placeholders? → Load `$AI_ROOT/standards/common/NO-MOCKS-POLICY.md`
- General code review? → Load `$AI_ROOT/standards/common/CODING.md`

**Testing:**
- Writing tests for existing code? → Load `$AI_ROOT/standards/common/TEST-FIRST.md`
- Test-first methodology questions? → Load `$AI_ROOT/standards/common/TEST-FIRST.md`

**Python Deep Dives:**
- PEP 8 compliance questions? → Load `$AI_ROOT/standards/python/PEP8.md`
- Core Python standards? → Already loaded (`$AI_ROOT/standards/python/CODING-PYTHON.md`)

**CI/CD Infrastructure:**
- Git questions? → Already loaded (`$AI_ROOT/standards/common/GIT.md`)

### Why Context-Adaptive Loading?

**500K+ context (Full CAG):**
- ✅ **Most reliable** - No guessing when to load files
- ✅ **Zero hallucination risk** - All standards always available
- ✅ **Simpler for AI** - No RAG index maintenance
- ✅ **Plenty of room for work** - Ample context remaining

**<500K context (CAG/RAG Hybrid):**
- ✅ **Loads less upfront** - Essential standards only
- ✅ **More context available** for actual work
- ✅ **Essential standards always loaded** (git, naming, Python basics)
- ✅ **Faster session start**

**Trade-off for <500K:**
- Manual maintenance of RAG index (concept → file mapping)
- AI must recognize when to load on-demand files

---
