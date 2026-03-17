# CAG-Heavy Injection for 1M Context Window

**Date:** 2026-03-17
**Status:** Approved
**Trigger:** Claude Opus/Sonnet 1M context window announcement

---

## Summary

With the 1M context window, pre-load all relevant standards, skills, and
project context at session start. Eliminate dynamic loading indirection
(path-scoped RAG reliance, skill description-match, three-tier compaction
recovery) in favour of a single CAG payload that's cheap to inject and
re-inject.

**Token budget:** ~22K tokens (~2.2% of 1M window) for a typical project.
Worst case (all techs detected): ~38K tokens (~3.8%).

Token counts measured via Anthropic `count_tokens` API — not estimated.

---

## Changes

### 1. Unified CAG Payload (`inject_cag_payload()`)

New function in `hooks/common.py` that replaces the current `inject_rules()`
approach. Called by `inject_standards.py` (startup), `on_compact.py`
(compaction recovery), and `subagent_context.py`.

**Payload contents (in order):**

1. **Current date** — prevents model hallucination about dates
2. **UNIVERSAL.md** — always loaded
3. **Detected tech compact rules** — language + infrastructure rules matching
   project tech stack (same `detect_markers` frontmatter detection as today)
4. **All common compact rules** — rules in `standards/rules/` that have NO
   `detect_markers` frontmatter (currently delivered only via CC's native
   `.claude/rules/` symlinks, not via hook injection). These are: security,
   error-handling, design-principles, testing, mocks-policy, git, code-style,
   config-and-logging. Always loaded regardless of file being edited.
5. **All skill content** — verification, bleeding-edge, documentation SKILL.md
   bodies with YAML frontmatter stripped (always loaded, no description-match
   indirection)
6. **Project context** — STATE.md from the consumer project root (not the
   hyperi-ai submodule). Eliminates `/load` dependency for project state
   recovery.
7. **User standards override** — `~/.config/hyperi-ai/USER-CODING-STANDARDS.md`
   if it exists (loaded last so it takes priority, same as current behaviour)
8. **Bash efficiency rules** — same as today
9. **Tool survey** — available CLI tools, same as today

**Implementation note:** `inject_cag_payload()` returns `Tuple[str, List[str]]`
(payload text, list of loaded rule names) to maintain compatibility with
existing callers that check the loaded list.

### 2. Compaction Simplification (`on_compact.py`)

**Current:** Three-tier recovery — lean essentials injected, user prompted to
run `/load` for full recovery.

**New:** Calls `inject_cag_payload()` — same full payload as startup. Single
tier. No `/load` prompt. Emits short confirmation: "Context compacted. Full
standards re-injected."

**Note:** Tool survey runs on each re-injection. This adds a few seconds of
latency during compaction recovery — accepted trade-off for simplicity.

### 3. `/load` Command Simplification

**Current:** Recovers standards + STATE.md + TODO.md + git sync + submodule
updates.

**New:** Drops standards and STATE.md recovery (already in context via CAG).
Becomes:

1. Read TODO.md (tasks/progress)
2. Git sync (`git pull --rebase`, status, recent commits)
3. Submodule update check

### 4. Skill Pre-loading

**Current:** Skills loaded on-demand when CC matches user intent to skill
description.

**New:** `inject_cag_payload()` reads each `skills/*/SKILL.md`, strips YAML
frontmatter, injects body content directly. Skills are always in context.

SKILL.md files and frontmatter are unchanged — CC's native skill system still
works as a redundant path. Pre-loading ensures content is available regardless
of whether the skill is explicitly triggered.

### 5. Subagent Context (`subagent_context.py`)

Updated to use `inject_cag_payload()` for consistency. Subagents get the same
full context as the main session.

**Size risk:** The full payload (~22K tokens / ~74 KB text) is passed via
`additionalContext` in the SubagentStart hook response. If Claude Code imposes
an undocumented size limit on this field, the payload could be truncated. Test
full payload size during implementation. If constrained, fall back to detected
tech rules + UNIVERSAL only for subagents.

---

## What Doesn't Change

- `generate-rules.py` pipeline — compact rules still generated from source
- Frontmatter-driven tech detection (`detect_markers` in rule files)
- Path-scoped rule frontmatter (`paths:`) — stays in files, CC's native
  system still works as redundant layer
- Commands — still user-triggered, not pre-loaded
- Safety guard, auto-format, lint hooks — unrelated to context injection
- `hooks/hooks.json` — same hook wiring, same events
- `templates/claude-code/settings.json` — same hooks referenced, no changes
- `.claude/rules/` symlinks — still deployed by `deploy_claude.py`, serve as
  redundant delivery path via CC's native rule system

---

## Complexity Removed

| Before | After |
|--------|-------|
| Two-layer CAG + RAG injection | Single CAG payload |
| Three-tier compaction recovery | Single-tier re-inject |
| Skill description-match loading | Skill content pre-loaded |
| `/load` recovers standards + state | `/load` is git sync + TODO only |
| Common rules via CC native system only | Common rules in CAG payload |

---

## Post-Implementation: Compact Rules Audit

Separate review pass after implementation. Diff each compact rule against its
full source standard and flag:

- Rules/guidance present in source but missing from compact
- Nuance lost in compression
- Code examples encoding important patterns not captured by bullets

Output: list of gaps to fix in compact rules via `generate-rules.py` updates
or manual overrides.

---

## Token Budget (Measured)

Counted via Anthropic `count_tokens` API — not estimated. Compact markdown
tokenises at ~3.3 bytes per token on Claude, not the commonly assumed ~0.75-1.3.

| Component | Bytes | Tokens |
|-----------|-------|--------|
| UNIVERSAL.md | 7.9 KB | 2,274 |
| Detected tech rules (typical 5) | 30 KB | 9,643 |
| All common rules (8 files) | 17 KB | 4,817 |
| All skills (3, full content) | 13 KB | 3,367 |
| STATE.md | 6 KB | 1,713 |
| User standards (if present) | 0-4 KB | ~0-1,200 |
| Bash efficiency rules | 2.7 KB | 816 |
| Tool survey | ~2 KB | ~600 |
| **Typical total** | **~79 KB** | **~23,230** |

**23K tokens = 2.3% of 1M window. Leaves ~977K for conversation and code.**

**Worst case** (all 13 tech rules + 8 common + universal + skills + state +
bash): ~80 KB / ~38,816 tokens = **3.9% of 1M window.**

| All 13 tech rules detail | Tokens |
|--------------------------|--------|
| python.md | 1,965 |
| rust.md | 2,422 |
| golang.md | 1,544 |
| typescript.md | 1,912 |
| bash.md | 2,070 |
| cpp.md | 2,037 |
| clickhouse-sql.md | 2,647 |
| docker.md | 1,832 |
| k8s.md | 1,726 |
| terraform.md | 1,037 |
| ansible.md | 1,751 |
| ci.md | 2,050 |
| pki.md | 2,336 |
| **All tech total** | **25,329** |

---

## Files to Modify

| File | Change |
|------|--------|
| `hooks/common.py` | Add `inject_cag_payload()`, refactor `inject_rules()` |
| `hooks/inject_standards.py` | Call `inject_cag_payload()` instead of piecemeal injection |
| `hooks/on_compact.py` | Replace three-tier recovery with `inject_cag_payload()` call |
| `hooks/subagent_context.py` | Use `inject_cag_payload()` for subagent context |
| `commands/load.md` | Remove standards/STATE.md recovery sections |
| `docs/TOKEN-ENGINEERING.md` | Update strategy to reflect CAG-heavy approach |
| `tools/deploy_claude.py` | Update help text/architecture description (rules now primarily CAG-delivered) |

---

## Rollback

Set environment variable `HYPERI_CAG_LEAN=1` to fall back to current lean
injection behaviour. `inject_cag_payload()` checks this and delegates to the
original `inject_rules()` path if set.
