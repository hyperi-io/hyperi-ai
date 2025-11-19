# Token Engineering for Documentation

**Purpose:** Optimize markdown for token efficiency while preserving human readability.

**Scope:** All markdown files loaded as AI prompts (standards, guidelines, etc.)

---

## Three Document Profiles

### Profile: AI (LLM-First)

**Target audience:** AI code assistants only
**Human readability:** Secondary (SME-level)
**Token efficiency:** Maximum
**Context dilution:** Minimum

**Characteristics:**

- Concise directives ("Use X", "Never Y")
- Minimal explanatory prose
- Examples only when clarifying ambiguous concepts
- Tables over prose for structured data
- Bullet points over paragraphs
- Technical precision over narrative flow

**Token savings:** 40-60% reduction from Human profile

**Optimization techniques:**

1. Remove transitional phrases ("In order to", "It is important to note that")
2. Use imperative mood ("Do X" not "You should do X")
3. Eliminate redundant examples (keep 1-2 max)
4. Replace verbose explanations with concise rules
5. Remove motivational language
6. Use symbolic notation (✅ ❌ vs "Correct:" "Incorrect:")

---

### Profile: Human-AI (Symbiotic, Balanced)

**Target audience:** Both humans and AI
**Human readability:** Good (intermediate developer)
**Token efficiency:** High
**Context dilution:** Low

**Characteristics:**

- Clear, direct language with moderate flow
- Sufficient context for non-SMEs
- Examples aiding both human learning and AI clarity
- Brief rationale for non-obvious rules
- Balance between tables and readable prose
- Professional but concise tone

**Token savings:** 20-35% reduction from Human profile

**Optimization techniques:**

1. One example per concept (remove redundant variations)
2. Subsections with clear headers
3. Combine related rules into single statements
4. Rationale in 1-2 sentences (not paragraphs)
5. Code blocks for examples
6. "Why this matters" sections brief (3-5 bullets max)

---

### Profile: Human (Learning-Focused)

**Target audience:** Human developers (new to topic)
**Human readability:** Excellent (beginner-friendly)
**Token efficiency:** Moderate
**Context dilution:** Acceptable

**Characteristics:**

- Comprehensive explanations with narrative flow
- Multiple examples showing variations
- Detailed rationale explaining "why"
- Gradual progression simple→complex
- Analogies and metaphors
- Extensive "Why this matters" sections

**Token savings:** 10-20% reduction (eliminate redundancy only)

**Optimization techniques:**

1. Group related examples together
2. Clear section hierarchy for optional deep-dives
3. Consolidate verbose explanations without losing meaning
4. Remove filler words while maintaining readability
5. Tables for comparison examples

---

## Profile Selection Guide

**Choose AI profile when:**

- Document ONLY read by LLMs during session initialization
- Target audience: SMEs
- Contains directives, not educational content
- Token budget critical (pre-loaded every session)
- Examples: code-assistant/ files, automation scripts

**Choose Human-AI profile when:**

- Read by both LLMs and developers regularly
- Target audience: intermediate developers
- Mix of rules and explanatory content
- Moderate token budget (loaded frequently)
- Examples: common/, {language}/ standards

**Choose Human profile when:**

- Primarily for human learning/reference
- Target audience: beginners
- Educational content with comprehensive examples
- Token budget flexible (read on-demand)
- Examples: detailed guides, tutorials

---

## Optimization Process

### Step 1: Determine Current Profile

Assess:

1. Primary audience (AI, Human, or Both)
2. Current verbosity level
3. Example density
4. Rationale depth
5. Target location

### Step 2: Identify Target Profile

Based on:

- File location (ai/, code-assistant/, common/, {language}/)
- Usage pattern (session-loaded vs on-demand)
- Audience needs

### Step 3: Create Backup Commit

**CRITICAL: Always backup before optimization**

```bash
# Stage ONLY the file being optimized
git add path/to/file.md

# Create timestamped backup commit
git commit -m "backup: FILENAME.md before token optimization

Profile: [Current] → [Target]
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Token estimate: ~[X] tokens (current)
Target: ~[Y] tokens ([Z]% reduction)"
```

**Recovery:**

```bash
# List backups
git log --oneline --grep="backup.*before token optimization"

# Restore
git show <commit-hash>:path/to/file.md > path/to/file.md
```

### Step 4: Apply Profile Transformations

**For AI profile:**

1. Remove transitional phrases
2. Convert explanatory→directive
3. Compress examples (5→1 canonical)
4. Eliminate motivational language
5. Replace verbose with symbolic (✅/❌)
6. Consolidate related rules

**For Human-AI profile:**

1. Reduce example variations (keep 1-2)
2. Condense rationale (3-4 paragraphs → 2-3 sentences)
3. Streamline structure (combine subsections)
4. Balance clarity and brevity

**For Human profile:**

1. Eliminate redundancy only
2. Consolidate repetitive examples
3. Tighten prose (remove filler)
4. Optimize without sacrificing learning

### Step 5: Measure Results

**Precise token count (recommended):**

```bash
# Use tiktoken if available
.venv/bin/python -c "import sys, tiktoken; enc=tiktoken.encoding_for_model('gpt-4'); print(len(enc.encode(open(sys.argv[1]).read())))" path/to/file.md
```

**Fallback (approximate):**

```bash
# 1 token ≈ 4 characters for English
wc -c path/to/file.md | awk '{print int($1/4)}'
```

**Compare before/after:**

```bash
BEFORE=$(git show <backup-commit>:path/to/file.md | wc -c | awk '{print int($1/4)}')
AFTER=$(wc -c < path/to/file.md | awk '{print int($1/4)}')
REDUCTION=$(echo "scale=1; 100 * ($BEFORE - $AFTER) / $BEFORE" | bc)
echo "~Token reduction: $REDUCTION% (~$BEFORE → ~$AFTER tokens)"
```

**Validate:**

- AI: 40-60% reduction?
- Human-AI: 20-35% reduction?
- Human: 10-20% reduction?
- Document still serves purpose?
- Readability appropriate?

### Step 6: Commit Optimized Version

```bash
git add path/to/file.md
git commit -m "refactor: optimize FILENAME.md for [Target Profile] profile

Applied token engineering [Current → Target] transformation.

Changes:
- [Specific changes]

Results (approx):
- Before: ~X tokens
- After: ~Y tokens
- Reduction: Z%

Profile: [Target Profile]
Readability: [Audience level]"
```

---

## File Hierarchy and Profiles

```text
standards/
├── ai/                          # AI profile (not session-loaded)
│   └── Workflow documentation
├── code-assistant/              # AI profile (session-loaded)
│   └── Guidance files
├── common/                      # Human-AI profile
│   └── Language-agnostic standards
└── {language}/                  # Human-AI profile
    └── Language-specific standards
```

**Profile assignment:**

- `ai/` → AI profile (maximum optimization, not session-loaded)
- `code-assistant/` → AI profile (maximum optimization, session-loaded)
- `common/` → Human-AI profile (balanced)
- `{language}/` → Human-AI profile (balanced)

---

## Optimization Metrics

### Token Budget Guidelines

**Session-loaded files:**

- Target: <25,000 tokens total
- Maximum: 35,000 tokens

**Context dilution goals:**

- AI: <5% dilution
- Human-AI: <15% dilution
- Human: <30% dilution

---

## Anti-Patterns

❌ Don't create .backup files
❌ Don't optimize without backup
❌ Don't over-optimize Human profiles
❌ Don't remove essential context
❌ Don't change meaning
❌ Don't mix profiles in same document
❌ Don't remove all examples

---

## Quick Reference

| Profile | Audience | Token Target | Optimization | Location |
|---------|----------|--------------|-------------|----------|
| AI | LLM only | 40-60% reduction | Maximum | ai/, code-assistant/ |
| Human-AI | Both | 20-35% reduction | High | common/, {language}/ |
| Human | Human-first | 10-20% reduction | Moderate | Detailed guides |

**Backup:** Single-file git commits with timestamp
**Recovery:** `git show <commit>:path/to/file.md > path/to/file.md`

---

## For LLM Code Assistants

**When instructed to optimize documentation:**

1. **Create backup commit** (timestamp, current token count)
2. **Analyze current state** (identify profile, measure tokens)
3. **Apply transformations** based on target profile
4. **Measure results** (use tiktoken if available, else wc -c)
5. **Validate** (reduction target met, purpose preserved)
6. **Commit** with metrics

**Instruction format:**

```text
Apply TOKEN-ENGINEERING.md [AI|Human-AI|Human] profile to [file-path]

Target: [percentage] reduction
Preserve: [specific sections]
```

**Example:**

```text
Apply TOKEN-ENGINEERING.md Human-AI profile to common/CODING.md

Target: 20-35% reduction
Preserve: Code examples (remove redundant variations)
Preserve: Security rules (make concise)
```

**Profile detection:**

- `ai/` directory → AI profile
- `code-assistant/` directory → AI profile
- `common/` directory → Human-AI profile
- `python/`, `go/`, etc. → Human-AI profile
- Detailed guides → Human profile

**Use tiktoken for precise counts when available. Fall back to wc -c approximation (÷4) if needed.**

---

**Status:** Ready for use
**Version:** 2.0
**Last updated:** 2025-11-12
