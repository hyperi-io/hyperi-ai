# HyperSec Coding Standards - GitHub Copilot / OpenAI Codex Instructions

**Recommended model:** GPT-5.1-Codex (Nov 2025) - optimized for agentic coding with advanced reasoning

## VS Code 1.108+ Agent Skills

If using VS Code 1.108 or later, enable Agent Skills for enhanced context:

```json
{
    "chat.useAgentSkills": true
}
```

Skills are located in `.github/skills/` and are automatically loaded based on project context.

## Standards Location

Standards are located in: `$AI_ROOT/standards/`

Where `$AI_ROOT` is the directory where this repository is attached (e.g., `ai/`, `standards/`, `.ai/`).

## Session Start - Read These Files

**Step 1: Read critical documentation** (in this order):

1. `STATE.md` or `CODEX.md` - Current project state and session history
2. `TODO.md` - Current tasks and priorities
3. `$AI_ROOT/standards/STANDARDS.md` - Contains complete loading strategy

**Step 2: Follow STANDARDS.md loading instructions**

STANDARDS.md contains the complete "For Code Assistants" section with CAG/RAG loading strategy, Tier 1 files (mandatory load), and Tier 2 files (on-demand RAG index).

## Essential Files (Tier 1 - Always Load)

1. **AI Guidance:**
   - `$AI_ROOT/standards/code-assistant/COMMON.md` - Session management, bash, commits
   - `$AI_ROOT/standards/code-assistant/AI-GUIDELINES.md` - Cognitive load research
   - `$AI_ROOT/standards/code-assistant/PYTHON.md` - Python-specific guidance (for Python projects)

2. **Essential Standards:**
   - `$AI_ROOT/standards/common/QUICK-REFERENCE.md` - One-page cheat sheet
   - `$AI_ROOT/standards/common/GIT.md` - Git conventions
   - `$AI_ROOT/standards/common/CHARS-POLICY.md` - File/directory naming rules

3. **Python Projects:**
   - `$AI_ROOT/standards/python/CODING-PYTHON.md` - Python coding standards

## Key Principles

1. **Reduce Cognitive Load** - Simple, readable code with consistent patterns
2. **Reduce Context Switching** - Project-specific context files (STATE.md, TODO.md)
3. **Automated Standards Enforcement** - Make conforming to standards light work

## Important Warnings

- **AI code has 4x higher defect rates** - Always review AI-generated code carefully
- **Human-first design** - No AI conventions to learn, same cognitive load as human code
- **No mocks in production** - See `$AI_ROOT/standards/common/NO-MOCKS-POLICY.md`

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

## Reference

For complete standards documentation, see: `$AI_ROOT/standards/STANDARDS.md`
