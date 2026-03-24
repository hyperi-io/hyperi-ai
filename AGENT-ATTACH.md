# Attach HyperI AI Standards

Read this file completely, then follow the steps. Do not skip detection.

## Step 1: Detect Project Type

Run these checks against the **target project** (the one you are attaching to,
NOT the hyperi-ai repo):

```bash
# Check 1: GitHub remote org
git remote -v 2>/dev/null | head -1

# Check 2: HyperI CI config
ls .hyperi-ci.yaml 2>/dev/null

# Check 3: LICENSE ownership
grep -l "HYPERI PTY LIMITED" LICENSE 2>/dev/null

# Check 4: Existing submodule
grep -l "hyperi-ai" .gitmodules 2>/dev/null
```

### Classification

**HyperI-controlled** — ANY of these are true:

- Remote URL contains `hyperi-io/` or `hypersec-io/`
- `.hyperi-ci.yaml` exists
- `LICENSE` mentions "HYPERI PTY LIMITED"
- `.gitmodules` already references `hyperi-ai`

**External** — NONE of the above match. This includes:

- Open-source projects we contribute to but do not own
- Third-party repos cloned for development
- Any project where we do not control the git history

## Step 2: Attach

### If HyperI-controlled: Submodule Mode

```bash
# Add submodule (skip if .gitmodules already has hyperi-ai)
git submodule add https://github.com/hyperi-io/hyperi-ai.git hyperi-ai

# Attach
./hyperi-ai/attach.sh

# Commit the attachment
git add .gitmodules hyperi-ai .claude STATE.md TODO.md
git commit -m "chore: attach hyperi-ai standards"
```

### If External: Stealth Mode

```bash
# Ensure system-wide clone exists
if [ ! -d ~/.local/share/hyperi-ai ]; then
    git clone https://github.com/hyperi-io/hyperi-ai.git ~/.local/share/hyperi-ai
fi

# Stealth attach (zero committed footprint)
~/.local/share/hyperi-ai/attach.sh --stealth --path "$(pwd)"
```

Do NOT commit anything. Stealth mode uses `.git/info/exclude` to hide all
artifacts. Verify with `git status` — you should see no hyperi-ai-related
changes.

## Step 3: Verify

After attaching (either mode), verify:

```bash
# .claude/ directory exists with symlinks
ls -la .claude/

# Rules are present
ls .claude/rules/

# Skills are present
ls .claude/skills/

# Settings exist
ls .claude/settings.json
```

If any are missing, re-run `attach.sh` with `--force`.

## Step 4: Agent Setup

```bash
# Auto-detect and configure the first available AI agent
./hyperi-ai/attach.sh --agent claude    # or: cursor, gemini, codex

# For stealth mode, the agent setup ran automatically during attach
```

## Decision Tree

```
Is remote URL hyperi-io/ or hypersec-io/?
  YES -> Submodule mode
  NO  -> Does .hyperi-ci.yaml exist?
    YES -> Submodule mode
    NO  -> Does LICENSE mention HYPERI PTY LIMITED?
      YES -> Submodule mode
      NO  -> Stealth mode
```

## Important

- **Never commit stealth artifacts.** If `git status` shows `.claude/`,
  `STATE.md`, or `TODO.md` as untracked in a stealth project, something
  went wrong with `.git/info/exclude`. Fix it before committing.
- **Stealth projects use absolute symlinks** pointing to
  `~/.local/share/hyperi-ai/`. If symlinks break, re-run the stealth attach.
- **Submodule projects use relative symlinks** pointing to `../../hyperi-ai/`.
  These survive clones and moves.
