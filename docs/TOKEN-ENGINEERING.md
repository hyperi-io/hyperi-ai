# Token Engineering for Documentation

**Purpose:** Optimise markdown for token efficiency while preserving human readability.

---

## Loading Strategy

**Single path - always load:**

1. `STANDARDS-QUICKSTART.md` - Core coding standards
2. Relevant `languages/*.md` file(s) - Based on project config files detected
3. Relevant `infrastructure/*.md` file(s) - Based on IaC files detected

**Auto-detection:**

| If you find... | Load from `languages/` |
|----------------|------------------------|
| `pyproject.toml`, `*.py` | `PYTHON.md` |
| `go.mod` | `GOLANG.md` |
| `package.json`, `tsconfig.json` | `TYPESCRIPT.md` |
| `Cargo.toml` | `RUST.md` |
| `*.sh`, `ci/` directory | `BASH.md` |

| If you find... | Load from `infrastructure/` |
|----------------|----------------------------|
| `Dockerfile`, `docker-compose.yaml` | `DOCKER.md` |
| `Chart.yaml`, `helmfile.yaml` | `K8S.md` |
| `*.tf` | `TERRAFORM.md` |
| `ansible.cfg`, `playbooks/` | `ANSIBLE.md` |

---

## Token Budgets

**Philosophy:** Token limits are LIMITS, not targets.

- Only add content that provides HIGH VALUE
- Don't pad to reach a number - quality over quantity
- If a file is 3K tokens and complete, that's GOOD

| File Type | Maximum |
|-----------|---------|
| STANDARDS-QUICKSTART.md | 12K |
| Language file (each) | 10K |
| Infrastructure file (each) | 10K |

**Current Sizes:**

| File | Tokens | Status |
|------|--------|--------|
| STANDARDS-QUICKSTART.md | ~7.5K | ✅ Under budget |
| PYTHON.md | ~3.7K | ✅ Under budget |
| GOLANG.md | ~8.7K | ✅ Under budget |
| TYPESCRIPT.md | ~7.7K | ✅ Under budget |
| RUST.md | ~3.3K | ✅ Under budget |
| BASH.md | ~5K | ✅ Under budget |
| DOCKER.md | ~5.3K | ✅ Under budget |
| K8S.md | ~3K | ✅ Under budget |
| TERRAFORM.md | ~2.5K | ✅ Under budget |
| ANSIBLE.md | ~6K | ✅ Under budget |

---

## Document Profiles

### AI Profile (LLM-First)

**Use for:** `code-assistant/` files
**Audience:** AI assistants (SME-level understanding)

**Characteristics:**

- Concise directives ("Use X", "Never Y")
- Tables over prose
- Symbolic notation (✅ ❌)
- 1-2 examples max per concept
- No motivational language

### Human-AI Profile (Balanced)

**Use for:** `common/`, `languages/`, `infrastructure/` files
**Audience:** Developers + AI assistants

**Characteristics:**

- Clear, direct language
- Sufficient context for intermediate developers
- Brief rationale (1-2 sentences)
- Balance tables and readable prose

---

## File Structure

```text
standards/
├── STANDARDS.md              # Full entry point (reference)
├── STANDARDS-QUICKSTART.md   # Core standards (always loaded)
│
├── code-assistant/           # AI profile
│   ├── COMMON.md
│   └── AI-GUIDELINES.md
│
├── common/                   # Human-AI profile
│   └── (language-agnostic standards)
│
├── languages/                # Human-AI profile
│   └── (per-language standards)
│
└── infrastructure/           # Human-AI profile
    └── (per-tool standards)
```

---

## Section Ordering

Order sections by developer workflow relevance:

1. **Immediate needs** - Code style, git commits (used daily)
2. **Writing code** - Error handling, security, testing
3. **Architecture** - Design principles, reference material
4. **Workflow** - Semantic release, CI/CD
5. **Rare operations** - Repo setup, file headers
6. **AI-specific** - No mocks policy, AI code of conduct (LAST)

---

## Token Counting

**Precise:**

```bash
python3 -c "import tiktoken; enc=tiktoken.encoding_for_model('gpt-4'); print(len(enc.encode(open('FILE.md').read())))"
```

**Approximate:**

```bash
# 1 token ≈ 4 characters for English
wc -c FILE.md | awk '{print int($1/4)}'
```

---

## Anti-Patterns

❌ Don't create .backup files (use git commits)
❌ Don't pad files to reach token limits
❌ Don't remove essential context
❌ Don't change meaning
❌ Don't remove all examples

---

## Quick Reference

| Profile | Location | Audience |
|---------|----------|----------|
| AI | code-assistant/ | LLM only |
| Human-AI | common/, languages/, infrastructure/ | Both |
