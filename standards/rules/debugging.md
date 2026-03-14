---
paths:
  - "**/*.py"
  - "**/*.rs"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.sh"
  - "**/*.bash"
  - "**/*.c"
  - "**/*.cpp"
detect_markers:
  - "file:src"
  - "dir:src"
  - "dir:lib"
  - "dir:tests"
---
<!-- override: manual -->
<!-- inspired-by: obra/superpowers systematic-debugging (MIT) -->

# Systematic Debugging

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## When to Use

Use for ANY technical issue: test failures, bugs, unexpected behaviour,
performance problems, build failures, integration issues.

Use ESPECIALLY when:
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes
- Previous fix didn't work

## The Four Phases

Complete each phase before proceeding to the next.

### Phase 1: Root Cause Investigation

BEFORE attempting ANY fix:

1. **Read error messages carefully** — don't skip past errors or warnings.
   Read stack traces completely. Note line numbers, file paths, error codes.

2. **Reproduce consistently** — can you trigger it reliably? What are the
   exact steps? If not reproducible, gather more data — don't guess.

3. **Check recent changes** — `git diff`, recent commits, new dependencies,
   config changes, environmental differences.

4. **Gather evidence in multi-component systems** — before proposing fixes,
   add diagnostic instrumentation at each component boundary. Log what
   enters and exits each layer. Run once to gather evidence showing WHERE
   it breaks, THEN investigate that specific component.

5. **Trace data flow** — where does the bad value originate? What called
   this with a bad value? Keep tracing up until you find the source. Fix
   at source, not at symptom.

### Phase 2: Pattern Analysis

1. **Find working examples** — locate similar working code in the same codebase.
2. **Compare against references** — read reference implementations COMPLETELY.
3. **Identify differences** — list every difference, however small.
4. **Understand dependencies** — what other components, settings, config does this need?

### Phase 3: Hypothesis and Testing

1. **Form single hypothesis** — "I think X is the root cause because Y."
2. **Test minimally** — make the SMALLEST possible change. One variable at a time.
3. **Verify before continuing** — didn't work? Form NEW hypothesis.
   DON'T add more fixes on top.
4. **When you don't know** — say "I don't understand X." Don't pretend.

### Phase 4: Implementation

1. **Create failing test** — simplest possible reproduction. Automated test
   if possible. MUST have before fixing.
2. **Implement single fix** — address the root cause. ONE change at a time.
   No "while I'm here" improvements. No bundled refactoring.
3. **Verify fix** — test passes? No other tests broken? Issue actually resolved?
4. **If fix doesn't work** — STOP. Count: how many fixes have you tried?
   If < 3: return to Phase 1 with new information.
   **If >= 3: STOP and question the architecture.**

### When 3+ Fixes Have Failed

Pattern indicating architectural problem:
- Each fix reveals new shared state/coupling in a different place
- Fixes require "massive refactoring" to implement
- Each fix creates new symptoms elsewhere

STOP and question fundamentals:
- Is this pattern fundamentally sound?
- Should we refactor architecture vs. continue fixing symptoms?

**Discuss with the user before attempting more fixes.** This is NOT a
failed hypothesis — this is a wrong architecture.

## Red Flags — STOP and Return to Phase 1

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes, run tests"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Here are the main problems:" (listing fixes without investigation)
- Proposing solutions before tracing data flow
- "One more fix attempt" (when already tried 2+)

## Common Rationalisations

| Excuse | Reality |
|---|---|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "I see the problem, let me fix it" | Seeing symptoms != understanding root cause. |

## Quick Reference

| Phase | Key Activities | Gate |
|---|---|---|
| 1. Root Cause | Read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
| 2. Pattern | Find working examples, compare, identify differences | Know what's different |
| 3. Hypothesis | Form theory, test minimally, verify | Confirmed or new hypothesis |
| 4. Implementation | Create test, fix, verify | Bug resolved, all tests pass |
