# Claude Code Settings Profiles

**Choose the right settings file for your model tier.**

## Available Profiles

### settings-pro.json (200k models)
**For:** Haiku, Sonnet (standard 200k context)

**Settings:**
- Context window: 190,000 tokens (95% of 200k)
- Aggressive context management: **ENABLED** (triggers at 80%)
- Output tokens: 12,288
- Parallel tools: 3
- **Removed:** MAX_THINKING_TOKENS (deprecated - use "think" commands)
- **Removed:** File summarization settings (redundant with Claude Code 2.0 auto-compact)

**Use when:** Using standard Claude models with 200k context windows

---

### settings-pro-max.json (1m models)
**For:** Sonnet [1m] variant (1 million token context)

**Settings:**
- Context window: 950,000 tokens (95% of 1m)
- Aggressive context management: **DISABLED** (critical!)
- Output tokens: 12,288
- Parallel tools: 3
- **Removed:** MAX_THINKING_TOKENS (deprecated - use "think" commands)
- **Removed:** File summarization settings (redundant with Claude Code 2.0 auto-compact)

**Use when:** Using `claude-sonnet-4-5-20250929[1m]` or future 1m+ models

**Key difference:** Disables aggressive context management to let you use the full 1m context naturally.

**Verified working:** Test suite confirmed aggressive context management DOES work in Claude Code 2.0.

---

## How to Apply

### For HyperCI Projects (Automated)

HyperCI will automatically deploy the appropriate settings file based on your `ci.yaml` configuration:

```yaml
# ci.yaml or ci-local/ci.yaml
ai:
  settings_profile: pro-max  # or "pro" for 200k models
```

Then run:
```bash
./ci/ai install
```

This copies the selected profile to `.claude/settings.json`.

### Manual Installation

1. **Choose your profile** based on model tier
2. **Copy to project:**
   ```bash
   cp ci/modules/common/templates/settings-pro-max.json .claude/settings.json
   ```
3. **Update model selection** in `.claude/settings.local.json`:
   ```json
   {
     "model": "claude-sonnet-4-5-20250929[1m]"
   }
   ```

**IMPORTANT:** The `[1m]` suffix is for Claude Code (Console/Pro/Max users only).
- **Enterprise/API users:** Model configuration varies by deployment
- **HyperCI does NOT auto-configure this** - Subject to frequent changes
- **Users must manually configure** based on their Claude Code tier

See [Claude Docs - Models](https://docs.claude.com/en/docs/about-claude/models/overview) for current model IDs.

---

## Why Two Profiles?

### Problem: Hard-coded limits cripple larger models

- A 200k optimized config with aggressive context management **breaks** 1m models
- Setting `CLAUDE_CODE_CONTEXT_WINDOW_TOKENS=160000` on a 1m model wastes 840k tokens
- Aggressive management at 70% (112k tokens) causes premature summarization

### Solution: Model-specific optimization

- **200k models:** Need aggressive management to avoid hitting limits
- **1m models:** Disable aggressive management, let context naturally grow to 950k

---

## Configuration Details

### Context Window Settings

| Setting | pro (200k) | pro-max (1m) | Purpose |
|---------|-----------|--------------|---------|
| `CLAUDE_CODE_CONTEXT_WINDOW_TOKENS` | 190000 | 950000 | Maximum context size |
| `CLAUDE_CODE_AGGRESSIVE_CONTEXT_MANAGEMENT` | 1 | 0 | Auto-compress when nearing limit |
| `CLAUDE_CODE_CONTEXT_MANAGEMENT_THRESHOLD` | 0.8 | 0.9 | When to trigger compression (%) |

### Why 95% not 100%?

**Safety margin:**
- Prevents hitting hard limits during active sessions
- Allows room for tool outputs, thinking tokens
- 190k on 200k model = safe buffer
- 950k on 1m model = safe buffer

### Why disable aggressive management on 1m?

**With 1m context:**
- You WANT to use the full capacity (reduce context switching)
- Aggressive management at 80% would compress at 760k (waste of 240k)
- Natural context growth aligns with "reduce context switching" principle
- Token engineering (PROMPT-MD-TOKEN-ENGINEERING.md) already reduces loaded docs

---

## Removed Settings (Claude Code 2.0)

### Deprecated Settings (removed from templates)

**MAX_THINKING_TOKENS** ❌
- **Reason:** Claude Code 2.0 uses command-based thinking budget
- **Replacement:** Use "think", "think hard", "think harder", "ultrathink" commands
- **Status:** Confirmed broken (test returned error code 1)

**CLAUDE_CODE_AUTO_SUMMARIZE_LARGE_FILES** ❌
**CLAUDE_CODE_LARGE_FILE_THRESHOLD** ❌
- **Reason:** Claude Code 2.0 has built-in auto-compact feature
- **Replacement:** Automatic microcompact clears outdated tool requests
- **Status:** Likely redundant (no documented purpose in 2.0)

## Troubleshooting

### "Context keeps getting compressed"
- Check: `CLAUDE_CODE_AGGRESSIVE_CONTEXT_MANAGEMENT` should be `"0"` for 1m models
- Check: `CLAUDE_CODE_CONTEXT_WINDOW_TOKENS` should be `"950000"` not `"160000"`
- **Verified:** Aggressive context management DOES work in Claude Code 2.0 (test suite confirmed)

### "Not seeing full 1m context"
- Verify model selection in `.claude/settings.local.json` shows `[1m]` suffix
- Restart Claude Code session after changing settings
- Check current session budget (should show 950k+ not 200k)

### "Which profile should I use?"
- Look at your model string in settings.local.json
- Has `[1m]` suffix? → Use `settings-pro-max.json`
- No `[1m]` suffix? → Use `settings-pro.json`

### "How do I control thinking tokens?"
- Don't use `MAX_THINKING_TOKENS` (deprecated)
- Use commands: "think" (low), "think hard" (medium), "ultrathink" (high)
- Each level allocates progressively more thinking budget

---

## Future: Auto-Detection

**Ideal future state (if Claude Code adds support):**

```json
{
  "env": {
    "CLAUDE_CODE_CONTEXT_WINDOW_PERCENT": "0.95",
    "CLAUDE_CODE_AGGRESSIVE_CONTEXT_MANAGEMENT": "auto"
  }
}
```

Currently not supported, so we use explicit tiered profiles.

---

**Last updated:** 2025-11-12
**Applies to:** HyperCI v2.6.2+
