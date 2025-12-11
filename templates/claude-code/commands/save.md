# Save Session Progress

Checkpoint progress to STATE.md for session continuity.

---

## Save Checklist

### 1. Update STATE.md - Current Session Section

**Add/update "Current Session" with:**

```markdown
## Current Session (YYYY-MM-DD)

### In Progress
- [What you were actively working on when /save was called]
- [Current task state - what's done, what remains]

### Accomplished
- [Completed items with brief description]

### Key Files Modified
- [List files changed this session with 1-line description]

### Decisions Made
- [Important choices and WHY - these persist across sessions]

### Next Steps
- [Immediate next actions for continuation]

### Blockers/Issues
- [Anything blocking progress]

### Dead Ends & Hypotheses
- [Approaches tried that FAILED - prevent next session re-trying]
- [What hypothesis was being tested when interrupted]
- [Why the failed approach didn't work]
```

**Critical for session continuation:**

- **In Progress** section must capture exactly where work stopped
- Include enough context that a fresh session can resume immediately
- Note any uncommitted changes

### 2. Rationalise STATE.md (Keep it Useful)

| Preserve | Safe to Remove |
|----------|----------------|
| Architecture decisions (why X over Y) | Sessions older than 2-3 |
| Current + previous 1-2 sessions | Deprecated implementation details |
| Long-term strategic goals | Duplicate information |
| Known blockers/issues | Temporary notes no longer relevant |
| Migration paths | Completed task details (move to CHANGELOG) |

**When in doubt:** Keep it. Lost context is worse than verbose docs.

### 3. Clean TODO.md

- **REMOVE completed tasks** (they're in STATE.md now)
- Add new tasks discovered during work
- Reprioritise remaining tasks
- TODO.md = active/pending work only

### 4. Capture Git Status Snapshot

Run `git status` and `git diff --stat` and add to STATE.md:

```markdown
### Git State
- **Branch:** [current branch name]
- **Upstream:** [ahead/behind status, or "no upstream"]
- **Uncommitted:** [list modified files or "clean"]
- **Staged:** [list staged files or "none"]
```

Also check:

- Staged but not committed? Commit or note why
- Any `.tmp/` files to clean up?

### 5. Conversation Summary (for next session)

Add to STATE.md if significant context would be lost:

```markdown
### Session Context Summary
[2-3 sentence summary of what this session was about, key context
that would take time to re-establish, and where things stand]
```

### 6. Fix Markdown Linting

Quick fixes in STATE.md, TODO.md:

- MD022: Blank lines around headings
- MD031: Blank lines around code blocks
- MD032: Blank lines around lists

### 7. Summary for Developer

Provide concise summary:

- What was accomplished
- What's in progress (if interrupted)
- Next actions
- Any blockers

---

## Proactive Save Triggers

**Save automatically when:**

- You complete a task from the todo list
- You make a significant decision
- You've been working for 30+ exchanges
- You're about to start a different type of work
- User mentions taking a break

**Signs you should save NOW:**

- Responses getting truncated
- Forgetting earlier context
- Repeating questions already answered
- Uncertainty about what was discussed earlier

---

## Save Complete

Confirm:

- [ ] STATE.md updated with current session
- [ ] TODO.md cleaned (completed removed, new added)
- [ ] Git status checked
- [ ] Summary provided to user
