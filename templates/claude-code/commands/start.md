# Start Session

You are starting a new work session.

## Session Initialization

**Step 1: Read critical documentation** (in this order):

- [STATE.md](../../STATE.md) - Current project state and session history
- [TODO.md](../../TODO.md) - Current tasks and priorities
- [ci/docs/standards/STANDARDS.md](../../ci/docs/standards/STANDARDS.md) - Contains loading strategy

## Step 2: Follow STANDARDS.md loading instructions

STANDARDS.md contains the complete "For Code Assistants" section with:

- CAG/RAG Hybrid Strategy explanation
- Tier 1 files (mandatory load)
- Tier 2 files (on-demand RAG index)
- Loading instructions for your context window size

Simply follow the loading strategy documented there.

---

## Ready to Work

After loading documentation:

1. **Report session configuration:**
   - Context window size: [your total token budget]
   - Loading strategy used: [CAG/RAG Hybrid - Tier 1 loaded, Tier 2 on-demand]
   - Standards files loaded: [count] files (~[estimated tokens]k tokens)

2. Confirm you're ready with a greeting

3. Ask what they want to work on

**Example session configuration report:**

```text
📊 Session Configuration:
- Context window: 200,000 tokens
- Strategy: CAG/RAG Hybrid (Tier 1 mandatory, Tier 2 on-demand)
- Standards loaded: 8 files (~17k tokens)
- Reasoning: Essential standards loaded upfront, detailed guides available on-demand via RAG index
```
