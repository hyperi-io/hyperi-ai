# Token Engineering

**Purpose:** Optimise standards delivery for token efficiency in LLM context windows.

---

## CAG-Heavy Strategy (1M Context Window)

All relevant standards, skills, and project context are pre-loaded at session
start via `inject_cag_payload()` in `hooks/common.py`. The full payload is
re-injected on context compaction — no tiered recovery, no user action needed.

**Payload contents:**

1. UNIVERSAL.md (always)
2. Detected tech compact rules (language + infrastructure, via `detect_markers`)
3. All common compact rules (security, error-handling, design-principles, etc.)
4. All skill content (verification, bleeding-edge, documentation)
5. Project STATE.md
6. User standards override (if present)
7. Bash efficiency rules + tool survey

**Budget (approximate, measured via Anthropic `count_tokens` API):**

| Component | ~Tokens |
|-----------|---------|
| UNIVERSAL.md | ~2,300 |
| Detected tech rules (typical 5) | ~10,000 |
| All common rules (8 files) | ~5,000 |
| All skills (3) | ~3,400 |
| STATE.md | ~1,700 |
| Bash efficiency + tool survey | ~1,400 |
| **Typical total** | **~24,000** |
| **Worst case (all 13 tech rules)** | **~39,000** |

~24K tokens is ~2.4% of the 1M window. Even worst case is under 4%.

**Key insight:** Compact markdown tokenises at approximately 3 bytes per token
on Claude — not the commonly assumed 0.75-1.3 bytes per token. Always measure
with the API, never estimate from byte counts.

---

## Token Counting

**Use the Anthropic API (free, accurate):**

```python
from anthropic import Anthropic
client = Anthropic()  # reads ANTHROPIC_API_KEY from .env
result = client.messages.count_tokens(
    model="claude-sonnet-4-20250514",
    messages=[{"role": "user", "content": text}]
)
print(result.input_tokens)
```

**Do NOT use** tiktoken (OpenAI tokeniser) or byte-count heuristics — these
overestimate Claude token counts by 3-5x for compact markdown.

---

## Compact Rules Design

Compact rules in `standards/rules/` are the primary CAG payload. Generated
from full source standards by `tools/generate-rules.py` or hand-maintained
with `<!-- override: manual -->`.

**Constraints:**

| Rule | Maximum |
|------|---------|
| Compact rule (each) | 200 lines |
| Single rule tokens | ~2,500 tokens |

**Principles:**

- Token limits are LIMITS, not targets — don't pad
- Concise directives ("Use X", "Never Y")
- Tables over prose
- 1-2 examples max per concept
- No motivational language

---

## Document Profiles

| Profile | Location | Audience |
|---------|----------|----------|
| LLM-optimised | `standards/rules/` | AI assistants (CAG payload) |
| Human-AI balanced | `standards/common/`, `languages/`, `infrastructure/` | Developers + AI (full reference) |

The compact rules are what hit the context window. Full source standards are
reference material for humans and for the `generate-rules.py` pipeline.

---

## Anti-Patterns

- Don't pad files to reach token limits
- Don't estimate tokens from byte counts — measure with the API
- Don't use tiktoken for Claude token counts
- Don't remove essential context to save tokens (the budget is ~2.4% of 1M)
- Don't hardcode token counts in docs — label as approximate
