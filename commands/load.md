# Load Session

You are loading project context for a new work session or refreshing my memory.

## Step 1: Establish Today's Date

Run `date '+%Y-%m-%d %A'` to get today's date.

**CRITICAL:** Use THIS date for all date-related work. Your training data may have
an outdated date - ignore it. The output of this command is the actual current date.

---

## Step 2: Source of Truth (SSoT)

**Before reading any files, understand this hierarchy:**

| Data | Source of Truth | NOT From |
|------|-----------------|----------|
| Today's date | `date` command output above | Training data |
| Version | `git describe --tags` or `VERSION` file | STATE.md |
| Tasks/Progress | `TODO.md` only | STATE.md |
| History | `git log --oneline -10` | STATE.md |
| Changelog | `CHANGELOG.md` (semantic-release) | STATE.md |

**If STATE.md contradicts git or TODO.md, ignore STATE.md.**

STATE.md contains static project context only (architecture, decisions, how things work).
It does NOT contain versions, progress, dates, or session history. STATE.md is auto-loaded
at session start via CAG injection — you already have it in context.

---

## Step 3: Read TODO.md

Read [TODO.md](../../TODO.md) — tasks and progress (SSoT for work).

---

## Step 4: Update Submodules

Update the `hyperi-ai` submodule if it is attached and auto-update is enabled.

**Note:** Coding standards are pre-loaded via CAG injection at session start
(UNIVERSAL + all detected tech rules). You do not need to load them manually.
If a technology was not detected, use `/standards <domain>` to force-load it.

The update mode is stored in `.gitmodules`:

- `update = rebase` → auto-update from upstream (default)
- `update = none` → pinned, skip update

1. Check if `hyperi-ai/.git` exists — if not, skip
2. Read the update mode:

   ```bash
   git config -f .gitmodules submodule.hyperi-ai.update
   ```

3. **If `rebase` (or unset):** Update from upstream:

   ```bash
   git submodule update --remote hyperi-ai
   ```

4. **If `none`:** Skip — the project has pinned this submodule. Note it silently.

### After updating the `hyperi-ai` submodule

If the `ai` submodule was updated (not skipped/pinned), check if deployment-relevant
files changed. Run this from the **project root**:

```bash
git -C ai diff HEAD@{1}..HEAD --name-only
```

If the output includes ANY of these paths, the user needs to re-run attach:

- `agents/claude.sh` (agent deployment logic changed)
- `templates/claude-code/` (commands, settings, or config changed)
- `standards/rules/` (compact rule files changed or added)

**If matches found**, tell the user:

> The hyperi-ai submodule update includes changes to deployment files (commands, rules,
> or agent config). Run `./hyperi-ai/agents/claude.sh` to re-deploy, then restart this
> session for the changes to take effect.

**If no matches** or the diff is empty, continue silently.

---

## Step 5: Sync and Ready

1. Sync with remote:

   ```bash
   git pull --rebase
   ```

2. Check git status and recent commits — run as **separate** Bash calls:

   ```bash
   git status --short
   ```

   ```bash
   git log --oneline -5
   ```

3. Be ready - no greetings, wait for the user's first task

---

**IMPORTANT — Bash permissions:** Run every bash command as its own individual
Bash tool call. Do NOT chain commands with `&&`, `||`, or `;` — these trigger
permission prompts. Single commands like `git status --short` match allowed
patterns and run without approval.

---

## Proactive Saving

Run `/save` proactively throughout the session - context can compact without warning.

**Save when:**

- After completing any significant task
- Every 30-40 exchanges
- Before the user takes breaks
- When your responses get shorter (sign of context pressure)

**Signs you need to save NOW:**

- Responses getting truncated
- Forgetting earlier context
- Repeating questions already answered
