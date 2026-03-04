# Load Session (ai repo — self-use)

You are loading project context for a new work session in the **ai repo itself**.

> This repo has no STATE.md or TODO.md — those belong in consumer projects.
> Project context is in Claude Code memory (auto-loaded by the session).

**IMPORTANT:** Run every bash command as its own individual Bash tool call.
Do NOT chain with `&&`, `||`, or `;`.

---

## Step 1: Establish Today's Date

Run `date '+%Y-%m-%d %A'` to get today's date.

**CRITICAL:** Use THIS date. Ignore training data dates.

---

## Step 2: Load Universal Standards (CAG Layer)

Read this compact file — it contains the critical cross-cutting rules:

- [UNIVERSAL.md](../../standards/rules/UNIVERSAL.md)

---

## Step 3: Sync and Ready

1. Check git status:

   ```bash
   git status --short
   ```

2. Recent commits:

   ```bash
   git log --oneline -5
   ```

3. Be ready — no greetings, wait for the user's first task.

---

## Proactive Saving

Run `/save` proactively throughout the session — context can compact without warning.

**Save when:**

- After completing any significant task
- Every 30-40 exchanges
- Before the user takes breaks
- When your responses get shorter (sign of context pressure)
