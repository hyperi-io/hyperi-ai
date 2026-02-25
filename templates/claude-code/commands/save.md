# Save Session Progress

Checkpoint progress for session continuity.

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

Run `git status` and `git diff --stat`.

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

**Only if TODO.md and STATE.md are NOT in `.gitignore`:**

1. Check: `git check-ignore TODO.md STATE.md 2>/dev/null`
2. Stage whichever files are tracked (not ignored)
3. Commit with `chore: save session state`
4. `git pull --rebase` then `git push`

Skip this step entirely if both files are gitignored.

### 6. Summary for Developer

Provide concise summary:

- What was accomplished
- Current task state (if in progress)
- Next actions (reference TODO.md)
- Any blockers

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
