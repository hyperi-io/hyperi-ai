# Token Engineering

**Purpose:** Optimise standards delivery for token efficiency in LLM context windows.

---

## Tiered Context Strategy

Not all users have the same context window. Claude Code offers 200K (default)
and 1M+ (Pro Max / extended models). The injection system auto-detects the
available context and selects the appropriate tier.

| Tier | Context Window | Standards Source | Typical Budget |
|------|---------------|-----------------|----------------|
| `compact` | 200K (default) | `standards/rules/` (condensed) | ~12K tokens (~6% of 200K) |
| `full` | 1M+ (auto-detected) | `standards/{languages,universal,infrastructure}/` | ~83K tokens (~8% of 1M) |

### Tier Detection (priority order)

1. **`HYPERI_CONTEXT_TIER` env var** — explicit override (`compact` or `full`)
2. **VS Code `claudeCode.selectedModel` setting** — auto-detects `[1m]`/`[2m]` suffix
3. **Default: `compact`** — safe for 200K, the common case

The VS Code setting is read from `~/.config/Code/User/settings.json`. Models
with extended context suffixes (e.g. `opus[1m]`, `sonnet[2m]`) trigger `full`.

```bash
# Force full tier (e.g. in project .env)
HYPERI_CONTEXT_TIER=full

# Force compact (override auto-detection)
HYPERI_CONTEXT_TIER=compact

# Check what VS Code has:
jq '."claudeCode.selectedModel"' ~/.config/Code/User/settings.json
```

### How It Works

`inject_cag_payload()` in `hooks/common.py` calls `get_context_tier()` at
session start and on every compaction re-injection. The tier selects which
loader runs:

- **Compact:** loads from `standards/rules/*.md` (hand-maintained summaries)
- **Full:** reads the `source:` frontmatter in each compact rule to find its
  full source counterpart in `standards/{languages,universal,infrastructure}/`

Both tiers load the same supplementary content (skills, STATE.md, user
overrides, bash rules, tool survey). Only the standards content differs.

---

## Token Budgets (measured via Anthropic `count_tokens` API)

### Compact Tier (200K users)

| Component | ~Tokens |
|-----------|---------|
| UNIVERSAL.md | ~2,300 |
| Detected tech rules (typical: 1 language + docker) | ~5,500 |
| All common rules | ~5,000 |
| Skills, STATE.md, bash rules, tool survey | ~6,500 |
| **Typical total** | **~12,000** |

~12K tokens is ~6% of 200K. Leaves 94% for conversation + code.

### Full Tier (1M users)

| Component | ~Tokens |
|-----------|---------|
| UNIVERSAL.md | ~2,300 |
| Detected tech full source (Rust + Docker example) | ~58,000 |
| All common full source | ~32,000 |
| Skills, STATE.md, bash rules, tool survey | ~6,500 |
| **Typical total (Rust project)** | **~83,000** |
| **Worst case (all languages)** | **~220,000** |

~83K tokens is ~8% of 1M. Even worst case is ~22%.

### Per-Language Full Source Sizes

| Language | Full Source | Compact Rule | Ratio |
|----------|-----------|--------------|-------|
| RUST.md | ~51,000 | ~3,600 | 14x |
| SQL-CLICKHOUSE.md | ~35,000 | ~2,600 | 13x |
| CPP.md | ~17,600 | ~2,000 | 9x |
| GOLANG.md | ~12,900 | ~1,500 | 9x |
| TYPESCRIPT.md | ~11,100 | ~1,900 | 6x |
| BASH.md | ~8,100 | ~2,100 | 4x |
| PYTHON.md | ~6,100 | ~2,000 | 3x |

RUST.md and SQL-CLICKHOUSE.md are the largest — these have extensive code
examples and production patterns. Python will grow when it gets the same
treatment.

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

**Key insight:** Compact markdown tokenises at approximately 3 bytes per token
on Claude — not the commonly assumed 0.75-1.3 bytes per token. Always measure
with the API, never estimate from byte counts.

---

## Compact Rules Design

Compact rules in `standards/rules/` serve the 200K tier. Generated from full
source standards by `tools/generate-rules.py` or hand-maintained with
`<!-- override: manual -->`.

Each compact rule has a `source:` frontmatter field pointing to its full source
counterpart. This is used by the `full` tier loader to resolve the complete
document.

**Constraints:**

| Rule | Maximum |
|------|---------|
| Compact rule (each) | 200 lines |
| Single rule tokens | ~3,600 tokens |

**Principles:**

- Token limits are LIMITS, not targets — don't pad
- Concise directives ("Use X", "Never Y")
- Tables over prose
- 1-2 examples max per concept
- No motivational language

---

## Document Profiles

| Profile | Location | Audience | Tier |
|---------|----------|----------|------|
| LLM-optimised (compact) | `standards/rules/` | AI assistants on 200K | `compact` |
| Full source | `standards/{languages,universal,infrastructure}/` | AI on 1M + humans | `full` |

---

## Anti-Patterns

- Don't pad files to reach token limits
- Don't estimate tokens from byte counts — measure with the API
- Don't use tiktoken for Claude token counts
- Don't remove essential context to save tokens when on `full` tier
- Don't hardcode token counts in docs — label as approximate
- Don't assume all users have 1M context — default to `compact`
