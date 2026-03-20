# Project Context

**Project:** hyperi-ai
**Purpose:** Corporate coding standards, AI assistant configuration, and developer tooling — delivered as a git submodule and Claude Code plugin

> **Note:** This is the submodule itself, not a consumer project. It self-deploys
> its own standards via `./agents/claude.sh --self`.

---

## DO NOT ADD TO THIS FILE

**The following belong elsewhere:**

| Data | Correct Location |
|------|------------------|
| Version numbers | `VERSION` file, `git describe --tags` |
| Tasks/Progress | `TODO.md` |
| Session history | Git log (`git log --oneline -10`) |
| Changelog | `CHANGELOG.md` (semantic-release) |
| Dates | Git commit timestamps |

**This file is for static project context only.**

---

## Project Overview

### Purpose

hyperi-ai is a git submodule that consumer projects add to get:

- **Coding standards** — rules covering languages, infrastructure, security, and conventions
- **AI assistant setup** — automated configuration for Claude Code, Cursor, Copilot, and Gemini
- **Skills** — verification, documentation, bleeding-edge dependency protection, and CI/CD workflow automation (release, ci-check, ci-watch, ci-logs)
- **Hooks** — auto-format, lint-on-stop, safety guards, standards injection
- **MCP servers** — Context7 (live library docs)
- **Slash commands** — `/load`, `/save`, `/review`, `/simplify`, `/standards`, `/doco`, `/setup-claude`

### Architecture

```
Consumer Project/
  hyperi-ai/          <- git submodule (this repo)
  .claude/
    settings.json     -> hyperi-ai/templates/claude-code/settings.json
    commands/*.md     -> hyperi-ai/commands/*.md
    rules/*.md        -> hyperi-ai/standards/rules/*.md
    skills/*/SKILL.md -> hyperi-ai/standards/**/*.md + hyperi-ai/skills/*/SKILL.md
  .mcp.json           <- merged from hyperi-ai/.mcp.json
  CLAUDE.md           -> STATE.md
```

### Dual Mode

1. **Submodule mode** — `git submodule add`, then `./hyperi-ai/attach.sh` + `./hyperi-ai/agents/claude.sh`
2. **Plugin mode** — `.claude-plugin/plugin.json` manifest for Claude Code plugin system

### Key Components

1. **agents/** — thin bash wrappers per AI tool (claude.sh, cursor.sh, codex.sh, gemini.sh)
2. **tools/** — Python3+stdlib deploy logic (deploy_claude.py, merge_mcp.py)
3. **standards/** — SSOT for all coding standards (rules/ for compact, languages/ and infrastructure/ for full)
4. **skills/** — Agent Skills (SKILL.md with YAML frontmatter) for methodology
5. **commands/** — slash command markdown files
6. **hooks/** — Python hooks wired via settings.json (SessionStart, PostToolUse, PreToolUse, Stop, SubagentStart)
7. **templates/** — settings.json, managed-settings.json, STATE.md template

### Tech Stack

- **Languages:** Bash (thin wrappers only), Python 3.12+ (all logic, stdlib only)
- **Testing:** BATS
- **CI:** hyperi-ci
- **Standards:** Superpowers plugin (methodology) + our skills (corporate standards)
- **MCP:** Context7 (live docs)

---

## Key Decisions

### Bash as Wrapper Only

**Decision:** All bash scripts are thin wrappers (~50 lines) that forward to Python3+stdlib
**Rationale:** Bash is hard to test, debug, and maintain at scale. Python has pathlib, json, argparse built in.
**Alternatives considered:** Pure bash (rejected — was 877 lines, unmaintainable)

### Superpowers + Lean Approach

**Decision:** Install superpowers plugin for methodology (debugging, TDD, planning). Our plugin carries ONLY corporate-specific standards and skills.
**Rationale:** Superpowers is well-maintained (40K+ stars) and covers methodology. We focus on what's unique to us: coding standards, verification, bleeding-edge protection.
**Alternatives considered:** Full methodology in our plugin (rejected — duplicates superpowers, more to maintain)

### Skills Over Rules for Methodology

**Decision:** Verification, documentation, and bleeding-edge are skills (SKILL.md), not rules
**Rationale:** Skill descriptions survive context compaction. Rules are path-scoped (wrong trigger). Skills activate by description match (right trigger).
**Alternatives considered:** Rules with broad globs (rejected — always-on wastes context budget)

### GitHub via gh CLI (not MCP)

**Decision:** Use `gh` CLI directly instead of GitHub MCP Server
**Rationale:** MCP server was unreliable across subrepo deployments. `gh` CLI is already authenticated, universally available, and Claude Code can call it directly via Bash.
**Alternatives considered:** Go binary MCP (fragile install/auth across consumer projects), deprecated npm package (EOL), Copilot remote HTTP (needs browser OAuth)

### Git Branch Flow

**Decision:** All work flows through main -> PR -> release. Never commit directly to release.
**Rationale:** Release branch triggers deployment/publishing. Direct commits bypass review and CI.

### Tiered Context Injection (compact vs full)

**Decision:** Standards injection auto-detects context window size and selects the appropriate tier.
**Rationale:** 1M context is Pro Max only. Most users have 200K. Full source standards consume ~48% of 200K but only ~8% of 1M.

| Tier | Window | Source | Budget |
|------|--------|--------|--------|
| `compact` | 200K (default) | `standards/rules/` | ~12K tokens (~6%) |
| `full` | 1M+ (auto-detected) | `standards/{languages,universal,infrastructure}/` | ~83K tokens (~8%) |

**Detection:** `HYPERI_CONTEXT_TIER` env var > VS Code `claudeCode.selectedModel` `[1m]` suffix > default `compact`.

### Compact Rules: Generated Output, NOT Hand-Edited

**Decision:** Compact rules in `standards/rules/` are OUTPUT of `tools/generate-rules.py`. Never hand-edit them.
**Rationale:** Hand edits get overwritten on regeneration. To improve compact rules, fix the generator or the source document structure. Currently all files have `<!-- override: manual -->` because the generator only extracts bullets — it needs to be improved to preserve code blocks, tables, and ❌/✅ pairs.
**Status:** Generator improvement is a pending task. See `docs/TOKEN-ENGINEERING.md`.

---

## API Keys and Token Counting

**Keys:** Stored in project `.env` (gitignored). Currently holds:

- `ANTHROPIC_API_KEY` — for token counting via the Anthropic SDK
- `CONTEXT7_API_KEY` — for Context7 MCP live docs

**Token counting:** Use the Anthropic `count_tokens` API (free, no cost) for
accurate Claude token measurements. Available via `anthropic` SDK in `~/.venv`.
See `docs/TOKEN-ENGINEERING.md` for measured budgets per tier.

---

## External Dependencies

- **Superpowers plugin** — methodology skills (debugging, TDD, planning, worktrees, code review)
- **Context7 MCP** — live library documentation via Upstash
- **gh CLI** — GitHub operations (PRs, issues, releases, Actions) via direct CLI calls
- **hyperi-ci** — CI runner for consumer projects

---

## Resources

**Documentation:**

- [README.md](README.md) — installation, usage, architecture overview
- [docs/SUPERPOWERS.md](docs/SUPERPOWERS.md) — superpowers integration strategy

**External Resources:**

- [Agent Skills Open Standard](https://agentskills.io/home)
- [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)
- [Context7 MCP](https://github.com/upstash/context7) — live library docs
- [obra/superpowers](https://github.com/obra/superpowers) — methodology plugin

---

## Notes for AI Assistants

This file is **STATE.md**, symlinked as **CLAUDE.md** in consumer projects.
In the hyperi-ai repo itself, it exists as STATE.md (no symlink — self-deploy
skips the CLAUDE.md symlink).

**DO NOT add:**

- Version numbers (use `git describe --tags`)
- Progress/tasks (use `TODO.md`)
- Dates or session history (use `git log`)
- "Current Session" or "Last Session" sections
- Personal preferences (use auto-memory)

**DO add:**

- Architecture decisions and rationale
- Key component descriptions
- External dependencies
- How things work (not what's happening)

When in doubt, ask: "Will this be true next week?" If no, it doesn't belong here.
