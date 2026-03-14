---
paths:
  - "**/*.py"
  - "**/*.rs"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.sh"
detect_markers:
  - "file:src"
  - "dir:src"
  - "dir:lib"
  - "dir:tests"
---
<!-- override: manual -->
<!-- inspired-by: obra/superpowers dispatching-parallel-agents (MIT) -->

# Dispatching Parallel Agents

## When to Use

When facing 2+ independent tasks that can be worked on without shared
state or sequential dependencies.

**Use when:**
- 3+ test files failing with different root causes
- Multiple subsystems broken independently
- Each problem can be understood without context from others
- No shared state between investigations

**Don't use when:**
- Failures are related (fixing one might fix others)
- Need to understand full system state first
- Agents would interfere (editing same files, using same resources)
- You don't know what's broken yet (investigate first)

## The Pattern

### 1. Identify Independent Domains

Group failures by what's broken. Each domain must be independent —
fixing one shouldn't affect another.

### 2. Create Focused Agent Tasks

Each agent gets:
- **Specific scope** — one test file or subsystem
- **Clear goal** — make these tests pass / fix this specific issue
- **Constraints** — don't change other code
- **Expected output** — summary of what was found and fixed

### 3. Dispatch in Parallel

Use the Agent tool with multiple parallel calls in a single response.
Use `isolation: "worktree"` when agents need to edit files to avoid
conflicts.

### 4. Review and Integrate

When agents return:
1. Read each summary — understand what changed
2. Check for conflicts — did agents edit the same code?
3. Run full test suite — verify all fixes work together
4. Spot check — agents can make systematic errors

## Agent Prompt Quality

**Good prompts are:**
- **Focused** — one clear problem domain
- **Self-contained** — all context needed to understand the problem
- **Specific about output** — what should the agent return?

**Common mistakes:**
- Too broad ("fix all the tests") — agent gets lost
- No context ("fix the race condition") — agent doesn't know where
- No constraints — agent might refactor everything
- Vague output ("fix it") — you don't know what changed

## When NOT to Parallelise

- **Related failures** — fix one, might fix others. Investigate together first.
- **Exploratory debugging** — you don't know what's broken yet.
- **Shared state** — agents editing same files = merge conflicts.
- **Sequential dependencies** — output of one feeds into another.

Parallel agents save time when problems are truly independent. Using
them on related problems wastes more time than sequential investigation.
