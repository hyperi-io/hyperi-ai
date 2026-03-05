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
It does NOT contain versions, progress, dates, or session history.

---

## Step 3: Read Project Files

Read in this order:

1. [TODO.md](../../TODO.md) - Tasks and progress (SSoT for work)
2. [STATE.md](../../STATE.md) - Project context (static info only)

---

## Step 4: Verify Standards Are Loaded

Coding standards are injected automatically by the `SessionStart` hook
(`inject_standards.py`). This runs before your first message and detects
project technologies from marker files (Cargo.toml, pyproject.toml, etc.),
injecting UNIVERSAL.md plus all matching language/infra rule files.

**You do not need to load standards manually.** They are already in your
context from the hook. To verify, briefly note which standards the hook
injected (visible in the session preamble).

If standards appear to be missing — for example, the hook did not detect a
technology — use `/standards <domain>` to force-load a specific rule file
(e.g. `/standards rust`, `/standards docker`).

For deep reference during `/review` or `/simplify`, full standards are
available as skills — invoke them explicitly when needed.

---

## Step 5: Update Submodules

Update `ai` and `ci` submodules if they are attached and auto-update is enabled.

The update mode is stored in `.gitmodules`:

- `update = rebase` → auto-update from upstream (default)
- `update = none` → pinned, skip update

### For each submodule (`ai`, then `ci`)

1. Check if `<name>/.git` exists — use `ls -d <name>/.git` (one call per submodule,
   do NOT chain commands)
2. If the submodule is not attached (file not found), skip it
3. Read the update mode:

   ```bash
   git config -f .gitmodules submodule.<name>.update
   ```

4. **If `rebase` (or unset):** Update from upstream:

   ```bash
   git submodule update --remote <name>
   ```

5. **If `none`:** Skip — the project has pinned this submodule. Note it silently.

Report what happened for each (e.g. "ai: updated", "ci: pinned, skipped").

### After updating the `ai` submodule

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

## Step 6: Sync and Ready

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
