# Save Session Progress

Checkpoint progress for session continuity.

**IMPORTANT:** Run every shell command as a separate call — never chain commands
with `&&`, `||`, or `;`. Compound commands force unnecessary permission prompts.

---

## Source of Truth Reminder

| Data | Correct Location |
|------|------------------|
| Tasks/Progress | `TODO.md` only |
| Static context | `STATE.md` (architecture, decisions) |
| Version | `git describe --tags` or `VERSION` |
| History | `git log` |

**NEVER add to STATE.md:**

- Session dates or "Current Session" sections
- Progress updates or status
- Version numbers
- Task lists

---

## Save Checklist

### 1. Update TODO.md

**Mark completed tasks:**

```markdown
- [x] Completed task (move to "Completed This Session" section)
```

**Update in-progress task:**

```markdown
- [ ] Task description `[IN PROGRESS]`
  - Current state: [what's done]
  - Next: [immediate next step]
  - Blockers: [if any]
```

**Add new tasks discovered during work.**

### 2. Update STATE.md (Static Context Only)

Only add if you learned something that will be true next week:

- Architecture decisions made (and WHY)
- Key component explanations
- External dependency notes
- "How things work" documentation

**DO NOT add:** dates, versions, progress, session history.

### 3. Check Git Status

Run each command separately (never chain with `&&`):

1. `git status`
2. `git diff --stat`

- Uncommitted changes? Note in TODO.md or commit
- Staged but not committed? Commit or unstage

### 4. Validate STATE.md

**Warn the user if STATE.md contains forbidden content:**

- Version numbers → should use `git describe --tags`
- "Current Session" or "Last Session" sections → remove
- Task lists or progress → move to TODO.md
- Dates (other than in decision rationale) → remove

If found, offer to clean it up.

### 5. Commit and Push Session State

**Only if TODO.md and STATE.md are NOT in `.gitignore`.**

Run each command separately (never chain with `&&`):

1. `git check-ignore TODO.md STATE.md`
2. Stage whichever files are tracked (not ignored)
3. Commit with `chore: save session state [skip ci]`
4. `git pull --rebase`
5. `git push`

Skip this step entirely if both files are gitignored.

### 6. Summary for Developer

Provide concise summary:

- What was accomplished
- Current task state (if in progress)
- Next actions (reference TODO.md)
- Any blockers

---

## End-of-Day Operations (User-Prompted)

After the core save checklist, **ask the user** which of these optional operations
they'd like to run. Present as a multi-select list — never run any automatically.

> "Would you like me to run any end-of-day housekeeping?"

### A. Align Documentation with Code

Check project docs against actual code and recent commit history.

1. Read each doc: `README.md`, `CLAUDE.md`, `STATE.md`, and any `docs/*.md`
2. `git log --oneline -20` — review recent changes
3. Compare docs against the real file tree and recent commits
4. Flag: stale file paths, removed/renamed APIs, outdated examples,
   references to deleted features, wrong directory structures
5. Propose edits for user approval — never auto-fix

### B. Audit Inline TODOs and FIXMEs

Surface code markers that may need tracking.

1. Grep for `TODO`, `FIXME`, `HACK`, `XXX` across the codebase
2. Compare against TODO.md — find markers not tracked there
3. Check for markers added during this session (`git diff` against session start)
4. Present untracked markers and offer to add them to TODO.md

### C. Review Uncommitted Work

Catch forgotten work-in-progress beyond `git status`.

1. `git stash list`
2. `git branch --no-merged`
3. `git status`
4. Summarise: uncommitted changes, stashed work, unmerged branches
5. Ask user what to do with each (commit, stash, discard, note in TODO.md)

### D. Clean Stale Branches

Find local branches that have been merged and can be pruned.

1. `git branch --merged main`
2. Exclude `main`, `master`, and current branch
3. List candidates and ask user which to delete
4. Delete only user-approved branches one at a time

---

## Proactive Save Triggers

**Save when:**

- You complete a task
- You make a significant decision
- 30+ exchanges have passed
- User mentions taking a break

**Signs you should save NOW:**

- Responses getting truncated
- Forgetting earlier context
- Repeating questions already answered

---

## Save Complete Checklist

- [ ] TODO.md updated (completed marked, in-progress noted)
- [ ] STATE.md validated (no forbidden content)
- [ ] Git status checked
- [ ] Summary provided to user
