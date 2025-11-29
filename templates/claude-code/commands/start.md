# Start Session

You are starting a new work session.

## Session Initialization

**Step 1: Read critical documentation** (in this order):

- [STATE.md](../../STATE.md) - Current project state and session history
- [TODO.md](../../TODO.md) - Current tasks and priorities

### Step 2: Load standards based on your context window size

| Your Context Window | Action |
|---------------------|--------|
| **Under 500K tokens** | Read ONLY `$AI_ROOT/standards/STANDARDS-CONTEXT-SMALL.md` (~8K tokens, self-contained) |
| **500K+ tokens** | Read `$AI_ROOT/standards/STANDARDS.md` then load ALL `standards/**/*.md` files |

**This is the ONLY place context window selection happens.** STANDARDS.md assumes you have 500K+ context if you're reading it.

---

## Ready to Work

After loading documentation:

1. **Report session configuration:**
   - Context window size: [your total token budget]
   - Standards loaded: [STANDARDS-CONTEXT-SMALL.md or full subtree]
   - Estimated tokens used: [count]

2. Confirm you're ready (no greetings or pleasantries)

3. Wait for the user's first task

**Example session configuration report:**

```text
📊 Session Configuration:
- Context window: 200,000 tokens
- Standards: STANDARDS-CONTEXT-SMALL.md (~8K tokens)
- Ready for work
```

```text
📊 Session Configuration:
- Context window: 1,000,000 tokens
- Standards: Full subtree via STANDARDS.md (~40K tokens)
- Ready for work
```
