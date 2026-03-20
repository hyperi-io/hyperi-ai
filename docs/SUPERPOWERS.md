# Superpowers Integration

## Strategy: Superpowers + Ours (Lean)

[obra/superpowers](https://github.com/obra/superpowers) (MIT, 40k+ stars) handles
**development methodology** -- how to debug, test, plan, and review. hyperi-ai handles
**corporate standards** -- what rules apply, how they're detected per tech stack, and
how they integrate with CI.

We previously cherry-picked superpowers ideas into our own rules. With the v2.8
architecture, we delegate methodology entirely to superpowers and focus on what's
unique to us.

## Division of Responsibility

| What | Source | Why |
|---|---|---|
| Systematic debugging | superpowers | Their 4-phase methodology is mature, maintained |
| TDD enforcement | superpowers | RED-GREEN-REFACTOR workflow |
| Brainstorming/design | superpowers | Design thinking workflow |
| Git worktrees | superpowers | Parallel development |
| Plan writing/execution | superpowers | Structured planning pipeline |
| Code review methodology | superpowers | Review workflow |
| Subagent-driven development | superpowers | Parallel agent coordination |
| **Corporate coding standards** | **hyperi-ai** | Rules covering languages, infrastructure, and cross-cutting concerns |
| **Verification before completion** | **hyperi-ai** | Unique -- evidence-before-claims gate |
| **Documentation/code-reality audit** | **hyperi-ai** | Unique -- docs must match code |
| **Bleeding-edge dependency protection** | **hyperi-ai** | Unique -- stale training data protection |

## What We Removed (superpowers covers it)

These rules were deleted from `standards/rules/` in v2.8:

| Former hyperi-ai Rule | Superpowers Equivalent |
|---|---|
| `debugging.md` | `systematic-debugging` |
| `testing.md` | `test-driven-development` |
| `parallel-agents.md` | `dispatching-parallel-agents` / `subagent-driven-development` |

## What We Kept as Skills (unique to us)

These became Agent Skills in `skills/` -- superpowers has no equivalent:

| Skill | Purpose |
|---|---|
| `verification` | Verify before claiming completion -- requires fresh command output as evidence |
| `documentation` | Documentation standards and code-reality auditing |
| `bleeding-edge` | Stale training data protection + Context7 MCP for live library docs |
| `release` | Full release workflow for hyperi-ci projects (commit to GH Releases + R2) |
| `ci-check` | Local pre-push validation via hyperi-ci |
| `ci-watch` | Trigger and monitor GitHub Actions CI runs |
| `ci-logs` | Fetch and debug CI failure logs |

## Installation

```bash
# From within a Claude Code session
claude plugin install superpowers@superpowers-marketplace

# Or via /setup-claude command
/setup-claude
```

The `/setup-claude` command checks for superpowers and prompts to install if missing.

## Conflict Resolution

| Potential Conflict | Resolution |
|---|---|
| Superpowers uses American English | Our `universal.md` rule (project-level) overrides -- Australian English wins |
| Both define verification | Superpowers `verification-before-completion` and our `verification` skill complement -- ours is stricter (requires command output evidence) |
| Both define code review | Superpowers provides methodology, our `/review` command adds corporate standards on top |

## Air-Gapped Environments

If superpowers can't be installed (no internet, restricted environments):
- All corporate coding standards still work (rules are submodule-deployed)
- Our unique skills still work (verification, documentation, bleeding-edge, CI/CD skills)
- Methodology (debugging, TDD, planning) is unavailable -- accepted gap
- No fallback methodology skills are maintained -- lean approach

## Attribution

superpowers is MIT licensed. See https://github.com/obra/superpowers for the full
project. Our earlier cherry-picked rules (now removed) credited the source with
`<!-- inspired-by: obra/superpowers ... (MIT) -->` comments.
