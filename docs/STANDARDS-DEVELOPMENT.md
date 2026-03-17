# Standards Development Process

**Purpose:** Document how HyperI coding standards are developed and maintained using human-AI collaboration.

---

## Human-AI Collaboration Model

| Role | Responsibilities |
|------|------------------|
| **Human** | Strategic direction, architectural decisions, quality gates, final approval |
| **AI Assistant** | Research, drafting, consistency checking, cross-referencing, token optimisation |

**Key Principle:** AI generates, human validates. Never commit AI output without human review.

---

## Standards Loading Strategy

**Single path - always load:**

1. `rules/UNIVERSAL.md` - Cross-cutting coding rules (~137 lines)
2. Relevant `rules/<lang>.md` file(s) - Auto-injected when editing matching files
3. Full `languages/*.md` and `infrastructure/*.md` for deep reference

See [TOKEN-ENGINEERING.md](TOKEN-ENGINEERING.md) for auto-detection rules.

---

## File Structure

```text
standards/
├── STANDARDS.md              # Full reference (not session-loaded)
├── STANDARDS-QUICKSTART.md   # Quick reference index
├── rules/                   # Compact rules (<200 lines each)
│
│   ├── COMMON.md             # Session management, commits
│   └── AI-GUIDELINES.md      # Cognitive load, pitfalls
│
├── universal/                   # Language-agnostic
│   ├── CODE-STYLE.md
│   ├── GIT.md
│   ├── TESTING.md
│   ├── SECURITY.md
│   ├── ERROR-HANDLING.md
│   └── ...
│
├── languages/                # One file per language
│   ├── PYTHON.md
│   ├── GOLANG.md
│   ├── TYPESCRIPT.md
│   ├── RUST.md
│   └── BASH.md
│
└── infrastructure/           # One file per tool
    ├── DOCKER.md
    ├── K8S.md
    ├── TERRAFORM.md
    └── ANSIBLE.md
```

---

## Development Workflow

### Phase 1: Research

1. Human identifies gap in standards
2. AI researches existing HyperI projects for patterns
3. AI summarises findings with code examples
4. Human reviews and confirms patterns to standardise

### Phase 2: Drafting

1. AI drafts initial standards file
2. Human reviews structure and content
3. AI iterates based on feedback (3-5 rounds typical)
4. Human approves for commit

### Phase 3: Maintenance

1. AI monitors for inconsistencies during sessions
2. AI proposes updates when new patterns emerge
3. Human reviews and commits

---

## Quality Gates

### Before Committing

- [ ] Token count under budget (see [TOKEN-ENGINEERING.md](TOKEN-ENGINEERING.md))
- [ ] Examples compile/run mentally
- [ ] No contradictions with other standards
- [ ] Cross-references valid (`$AI_ROOT/standards/...` paths exist)
- [ ] Section ordering follows workflow relevance
- [ ] AI-specific content at end of file

---

## AI Code of Conduct

### What AI Does

✅ Research projects for patterns
✅ Draft standards content
✅ Check consistency across files
✅ Count tokens and optimise
✅ Update cross-references
✅ Propose improvements

### What AI Does NOT Do

❌ Commit without human approval
❌ Make architectural decisions
❌ Override human direction
❌ Add content without research backing
❌ Use marketing/promotional language
❌ Add AI attribution to commits

---

## Commit Standards

| Type | Use For |
|------|---------|
| `fix:` | Most changes (default) |
| `docs:` | Documentation updates |
| `refactor:` | Reorganisation without content change |
| `chore:` | Maintenance, cleanup |

**Never use `feat:` for standards** - Standards are infrastructure, not features.

**No AI attribution** - No Co-Authored-By, no "Generated with" trailers.

---

## Communication Style

- **Direct and concise** - No LLM cheerleading
- **Australian English** - In docs/comments (American in code)
- **Understated** - No hype, just facts
- **Technical accuracy** - Over politeness
