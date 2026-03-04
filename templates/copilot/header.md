# HyperI Coding Standards - GitHub Copilot / OpenAI Codex Instructions

**Recommended model:** GPT-5.1-Codex (Nov 2025) - optimized for agentic coding with advanced reasoning

## VS Code 1.108+ Agent Skills

If using VS Code 1.108 or later, enable Agent Skills for enhanced context:

```json
{
    "chat.useAgentSkills": true
}
```

Skills are located in `.github/skills/` and are automatically loaded based on project context.

## Session Start - Read These Files

**Read these files** (in this order):

1. `STATE.md` or `CODEX.md` - Current project state and session history
2. `TODO.md` - Current tasks and priorities

## Key Principles

1. **Reduce Cognitive Load** - Simple, readable code with consistent patterns
2. **Reduce Context Switching** - Project-specific context files (STATE.md, TODO.md)
3. **Automated Standards Enforcement** - Make conforming to standards light work

## Important Warnings

- **AI code has 4x higher defect rates** - Always review AI-generated code carefully
- **Human-first design** - No AI conventions to learn, same cognitive load as human code
- **Mock-aware testing** - Mocks are scaffolding, not testing. Both unit and integration tests required.

## Session Save Instructions

At the end of a session or when checkpointing progress:

1. **Update STATE.md:**
   - Document what was accomplished
   - Add any important decisions or changes
   - Note any blockers for next session
   - Remove completed sessions older than 2-3 sessions

2. **Clean up TODO.md:**
   - REMOVE all completed tasks (they belong in STATE.md)
   - Add new tasks discovered during work
   - TODO.md should only contain active/pending work

3. **Check git status** - Any uncommitted changes to review?

4. **Review test status** - Did all tests pass?
