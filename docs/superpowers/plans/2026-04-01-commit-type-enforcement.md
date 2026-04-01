# Commit Type Enforcement — AI Guardrails

**Date:** 2026-04-01
**Problem:** AI agents repeatedly misuse `feat:` and `BREAKING CHANGE:` despite
standards explicitly prohibiting it without user approval.

---

## The Problem

The CI standards (`standards/infrastructure/CI.md`) contain these rules:

1. `feat:` should be used RARELY — AI exaggerates importance
2. `fix:` is the DEFAULT for most changes
3. `BREAKING CHANGE:` in footer — NEVER write automatically, always ask user

These rules exist in the loaded context but are consistently violated because:

- **Passive knowledge vs active enforcement.** The rules are text in a large
  context window. By the time the AI writes a `git commit -m` command, it's
  thinking about "what changed" not "what are the commit rules."
- **No interruption at point of action.** Nothing blocks the AI between
  deciding to commit and executing the command.
- **`feat:` feels correct for "new" things.** The AI sees a new struct, new
  module, new function → defaults to `feat:`. The standard says most of these
  should be `fix:` (internal improvements) but the AI's instinct overrides
  the standard.

## Observed Failure Modes

### 1. `BREAKING CHANGE:` without asking

The AI added `BREAKING CHANGE:` to a commit footer to force a major version
bump. The standard says "NEVER write automatically. Always ask user." The AI
knew the rule (it's in its context) but didn't follow it because the commit
message was composed inline during implementation flow, not during a
"check the rules" step.

**Occurred:** 3 times in one session (2026-03-31 to 2026-04-01)

### 2. `feat:` overuse

The AI used `feat:` for internal refactors, test additions, and library
improvements that are not user-facing features. Examples:

- `feat: add BatchProcessor trait` — internal API, should be `fix:` or `refactor:`
- `feat: add RuntimeContext` — internal detection, should be `fix:`
- `feat!: add ServiceRuntime` — internal trait change, should be `feat:` at most

**Occurred:** 6+ times across two sessions

### 3. `feat!:` (bang suffix) used without understanding

The AI used `feat!:` thinking it would trigger a major bump. This is a
conventional commits convention but its behaviour depends on the
semantic-release configuration. In some configs it's equivalent to
`BREAKING CHANGE:` in the footer; in others it's ignored.

## Proposed Solutions

### Solution A: Claude Code pre-commit hook (recommended)

Add a hook in `.claude/settings.json` that fires before any `git commit`
bash command. The hook inspects the commit message and:

1. **BLOCKS** if `BREAKING CHANGE:` is present → "BREAKING CHANGE requires
   explicit user approval. Ask the user before committing."
2. **WARNS** if `feat:` is used → "You used feat: — is this genuinely a new
   user-facing feature? Most changes should use fix:. Proceed? (y/n)"
3. **BLOCKS** if `feat!:` is used → same as BREAKING CHANGE

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "scripts/check-commit-type.sh"
          }
        ]
      }
    ]
  }
}
```

The hook script parses the `git commit -m` argument and checks for prohibited
patterns. This is enforcement at the point of action, not passive guidance.

### Solution B: Superpowers skill for committing

Create a `commit` skill that wraps `git commit`. The skill:

1. Analyses the staged diff
2. Proposes a commit type based on the changes (not the AI's judgement)
3. Shows the user the proposed message and type
4. Only proceeds after user confirmation
5. Never uses `feat:` without showing the user the alternative (`fix:`)
6. Never allows `BREAKING CHANGE:` without explicit user "yes"

This is more heavyweight but gives the user full control.

### Solution C: Strengthen the standard wording

Make the rules more prominent and actionable in the standards doc.
Add a decision tree:

```
Before every commit:
  1. Default to fix:
  2. Is this a genuinely new USER-FACING feature?
     No  → use fix:
     Yes → use feat: (and ask yourself: would a user see this in release
           notes and say "that's new"?)
  3. Does this break existing API contracts?
     No  → do NOT add BREAKING CHANGE
     Yes → STOP. Ask the user. Do not commit.
```

This is the weakest solution (still passive) but costs nothing to implement.

## Recommendation

**All three.** C is free (update the standard). A prevents the most common
failure mode (BREAKING CHANGE without approval). B is the gold standard but
takes longer to build.

Priority: C now → A this week → B when superpowers has a commit skill.

## Impact

Every `feat:` commit creates a MINOR version bump. Every `BREAKING CHANGE:`
creates a MAJOR bump. Incorrect bumps waste version numbers, create misleading
changelogs, and confuse downstream consumers about the significance of updates.

In the current session alone, incorrect commit types caused:
- v2.0.0 (should have been v1.x — BREAKING CHANGE used to force major)
- v2.1.0, v2.2.0, v2.3.0 (rapid minor bumps from feat: overuse)
- 4 wasted version numbers that could have been v1.22.x patches
