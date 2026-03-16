---
name: verification
description: >-
  Verification-before-completion protocol. Use before any success claim,
  commit, PR, or expression of satisfaction. Requires fresh command output
  as evidence — no claims without running the verification command.
---
<!-- Project: HyperI AI -->
<!-- inspired-by: obra/superpowers verification-before-completion (MIT) -->

# Verification Before Completion

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this response, you cannot
claim it passes.

## The Gate

Before claiming any status or expressing satisfaction:

1. **IDENTIFY** — what command proves this claim?
2. **RUN** — execute the FULL command (fresh, complete)
3. **READ** — full output, check exit code, count failures
4. **VERIFY** — does output confirm the claim?
   - If NO: state actual status with evidence
   - If YES: state claim WITH evidence
5. **ONLY THEN** — make the claim

Skip any step = unverified claim.

## What Counts as Evidence

| Claim | Requires | NOT Sufficient |
|---|---|---|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, "looks good" |
| Bug fixed | Test original symptom: passes | "Code changed, assumed fixed" |
| Requirements met | Line-by-line checklist verified | "Tests passing" alone |
| Agent completed task | VCS diff shows changes | Agent reports "success" |

## Red Flags — STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Done!")
- About to commit/push/PR without running tests
- Trusting subagent success reports without checking
- Relying on partial verification
- Thinking "just this once"

## Rationalisation Prevention

| Excuse | Reality |
|---|---|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence != evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter != compiler != tests |
| "Agent said success" | Verify independently |
| "Partial check is enough" | Partial proves nothing |

## Key Patterns

**Tests:**
```
CORRECT: [Run test command] [See: 34/34 pass] "All tests pass"
WRONG:   "Should pass now" / "Looks correct"
```

**Build:**
```
CORRECT: [Run build] [See: exit 0] "Build succeeds"
WRONG:   "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
CORRECT: Re-read spec -> Create checklist -> Verify each -> Report gaps or completion
WRONG:   "Tests pass, task complete"
```

## When to Apply

ALWAYS before:
- Any success/completion claim
- Any expression of satisfaction about work state
- Committing, PR creation, task completion
- Moving to next task
- Reporting subagent results

**No shortcuts. Run the command. Read the output. THEN claim the result.**
