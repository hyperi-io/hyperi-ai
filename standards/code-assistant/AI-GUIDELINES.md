---
name: ai-guidelines
description: AI code assistant operational guidelines. Use when configuring AI assistants, reviewing AI-generated code, or ensuring AI output matches human quality standards. Covers spelling, communication style, and tool-specific settings.
---

# AI Code Assistant Guidelines

**Operational instructions for AI assistants - generate human-quality code**

⚠️ **CRITICAL:** AI-assisted projects must be indistinguishable from human-only projects.

---

## Core Requirements

1. ✅ Write code indistinguishable from human developers
2. ✅ Minimise cognitive load (simple > clever, explicit > implicit)
3. ✅ Follow HyperSec standards exactly
4. ✅ Never use placeholders/TODOs in production code
5. ✅ Use correct spelling (American in code, Australian in docs/comments)

---

## Spelling Guide

**Code:** American English (`color`, `initialize`, `serialize`)
**Docs/Comments:** Australian English (`colour`, `initialise`, `serialise`)

```python
def initialize_color_picker():
    """Initialise the colour picker component."""  # Australian
    color = "#FF0000"  # American variable name
```

---

## Communication Style

**Direct, professional, no LLM fluff:**

- ❌ "Great question! I'd be happy to help!"
- ❌ "This is an AMAZING feature!"
- ✅ "The issue is X. Fix it like this: [code]"

---

## When to Avoid AI

**Don't use AI for:** Security-critical code, complex algorithms, performance-critical code, regulatory/compliance code.

**AI is good for:** Boilerplate, test generation, documentation, simple CRUD.

---

## Anti-Rabbit-Holing

**Three-Iteration Rule:** Generate → Fix issues → Polish → STOP (commit or revert)

**Warning signs:** 5+ changes to same function, code getting more complex, 30+ minutes with no commit

---

## Claude Code

### Permission Patterns (2.0)

Claude Code uses **prefix matching** with `:*` wildcard:

| Pattern | Matches |
|---------|---------|
| `Bash(git:*)` | `git status`, `git commit -m "msg"` |
| `Bash(python:*)` | `python script.py`, `python -c "code"` |

**Key rules:**

- `:*` matches anything after the prefix
- Shell operators (`&&`, `||`, `;`, `|`) handled separately
- `Bash(safe-cmd:*)` does NOT match `safe-cmd && dangerous-cmd`

### Pipe Patterns

Pipes require explicit patterns:

```json
"Bash(fd * | grep:*)",
"Bash(git * | head:*)"
```

**Safe (allow):** `| grep`, `| head`, `| tail`, `| wc`, `| sort`
**Dangerous (ask):** `| sh`, `| bash`, `| sudo`, `| rm`

### Permission Order

Deny → Allow → Ask → Permission Mode → canUseTool

### Configuration Files

| File | Scope |
|------|-------|
| `~/.claude/settings.json` | User (all projects) |
| `.claude/settings.json` | Project (team) |
| `.claude/settings.local.json` | Project (personal) |

### Sleep Commands

⛔ **DENIED:** `sleep 10+` is blocked. Use polling loops instead.

```bash
# REQUIRED pattern - short sleeps with feedback
for i in {1..30}; do
  [ -f /tmp/ready ] && break
  echo "Waiting... ($i/30)"
  sleep 1
done
```

**Why:** Long sleeps block ALL user interaction - cannot cancel, provide input, or see progress.

**Settings.json rules:**

```json
"deny": ["Bash(sleep 1[0-9]:*)", "Bash(sleep [0-9][0-9][0-9]:*)"],
"allow": ["Bash(sleep [0-9])", "Bash(sleep 0.*)"]
```

### External Directory Search

Use `fd -H` (hidden directories) or `find` - never Glob/Grep on external paths.

```bash
# Find in hidden directories like .claude/
fd -H -t f "settings.json" -d 4 /path/ | grep '\.claude/'

# With find
find /path/ -maxdepth 4 -path '*/.claude/settings.json' -type f
```

### Recommended Deny Rules

```json
"deny": [
  "Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)",
  "Read(./**/*.pem)", "Read(./**/*.key)", "Read(~/.ssh/**)"
]
```

---

## GitHub Copilot

### Context Window

8k-200k tokens. Best for: inline completion, single-file edits, boilerplate.

### Good Context

Provide type hints, docstrings with business rules:

```python
def calculate_discount(
    price: float,
    discount_percent: float,
) -> float:
    """
    Calculate discounted price.
    Rules: discount 0-100, price must be positive
    """
    # Copilot has good context now
```

### Review Tab Completions

**NEVER blindly accept.** Check for: missing error handling, hardcoded values, TODO comments.

---

## Cursor

8k-200k tokens. Best for: multi-model switching, flexibility.

Same guidelines as Copilot. Cursor supports multiple models - choose based on task complexity.

---

## Google Gemini

1M-2M tokens. Best for: entire codebase analysis, 100k+ line projects.

Load full codebase context. Gemini excels at cross-file analysis and understanding large architectures.

---

## OpenAI Codex

8k-32k tokens. Best for: simple code generation, API integrations.

Keep prompts focused. Smaller context means more specific tasks work better.

---

## Common fd Exclusions

```bash
-E .git -E .venv -E node_modules -E __pycache__ -E vendor -E target -E dist -E build -E .terraform -E .mypy_cache -E .pytest_cache -E .next -E coverage
```

---

## Code Review Checklist (AI Code)

- [ ] Test coverage > 90%
- [ ] Security scan passes
- [ ] Edge cases handled
- [ ] No placeholder/mock code
- [ ] Type hints present

---
