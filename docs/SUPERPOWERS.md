# Superpowers Integration

## Relationship

[obra/superpowers](https://github.com/obra/superpowers) (MIT, 83k+ stars) and
hyperi-ai are **complementary, not competing**:

- **Superpowers** provides **workflow methodology** — how to think about
  debugging, testing, planning, and verification
- **hyperi-ai** provides **standards enforcement** — what rules apply, how
  they're auto-detected per project tech stack, and how they integrate with CI

## What We Cherry-Picked (Option B)

We evaluated all 14 superpowers skills and cherry-picked the four highest-value
ideas into our own `standards/rules/` format:

| Superpowers Skill | Our Rule | What We Took |
|---|---|---|
| `systematic-debugging` | `debugging.md` | 4-phase root cause methodology |
| `verification-before-completion` | `verification.md` | Evidence-before-claims gate |
| `test-driven-development` | `testing.md` (enhanced) | RED-GREEN-REFACTOR enforcement |
| `dispatching-parallel-agents` | `parallel-agents.md` | When/how to parallelise subagents |

### Why Not the Others

| Skill | Decision | Reason |
|---|---|---|
| `brainstorming` | Skip | Too heavyweight for most tasks |
| `writing-plans` | Skip | Good for huge features, overkill for normal work |
| `executing-plans` | Skip | Coupled to their planning pipeline |
| `using-git-worktrees` | Skip | CC has native worktree support already |
| `finishing-a-development-branch` | Skip | Covered by our git + CI rules |
| `subagent-driven-development` | Skip | Coupled to their plan/execution pipeline |
| `receiving-code-review` | Skip | We have `/review` command |
| `requesting-code-review` | Skip | We have `/review` command |
| `writing-skills` | Skip | Meta — only useful for their framework |
| `using-superpowers` | Skip | Intro — not applicable |

## Why Option B Over Other Options

**Option A (submodule)** was rejected because:
- Their SKILL.md format doesn't match our YAML frontmatter detection system
- Nested submodule (hyperi-ai is already a submodule) gets messy
- Their skills cross-reference each other — we'd inherit the whole workflow graph
- They're opinionated about file locations (`docs/superpowers/plans/`)

**Option C (companion recommendation)** is still valid — users who want the full
structured methodology can install superpowers via the Claude plugin marketplace
alongside hyperi-ai without conflict.

**Option D (hybrid submodule + cherry-pick)** was rejected as unnecessary
complexity — the methodology ideas are stable and don't need upstream tracking.

## Our Advantages Over Plugin Approach

| Feature | hyperi-ai (submodule) | superpowers (plugin) |
|---|---|---|
| Team enforcement | Committed to repo | Per-user install |
| Tech detection | YAML frontmatter auto-detect | Manual skill selection |
| Multi-agent | Claude, Cursor, Copilot, Gemini | Claude-only |
| CI integration | hyperi-ci check, hooks, guards | None |
| Customisation | Override per-project, per-user | Fork or skip skills |
| Human-readable | Markdown rules in `standards/` | SKILL.md files |

## Attribution

Cherry-picked rules include `<!-- inspired-by: obra/superpowers ... (MIT) -->`
comments crediting the source. The superpowers project is MIT licensed.
