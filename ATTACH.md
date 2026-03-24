# Attach HyperI AI Standards

Two modes depending on whether you control the project.

## Our Projects (Submodule)

For any project under `hyperi-io/` or `hypersec-io/` — where we own the repo
and control what gets committed.

```bash
git submodule add https://github.com/hyperi-io/hyperi-ai.git hyperi-ai
./hyperi-ai/attach.sh
git add .gitmodules hyperi-ai .claude STATE.md TODO.md
git commit -m "chore: attach hyperi-ai standards"
```

Skip the `submodule add` if `.gitmodules` already has `hyperi-ai`.

## External Projects (Stealth)

For projects we don't own — open-source repos, third-party code, anything
where hyperi-ai artifacts must never appear in the commit history.

```bash
# One-time: clone hyperi-ai to a shared location
git clone https://github.com/hyperi-io/hyperi-ai.git ~/.local/share/hyperi-ai

# From the project root
~/.local/share/hyperi-ai/attach.sh --stealth --path .
```

Nothing gets committed. `.git/info/exclude` hides everything locally.
Run `git status` to confirm — no hyperi-ai-related changes should appear.

## How to Tell Which Mode

| Signal | Means |
|---|---|
| Remote URL contains `hyperi-io/` or `hypersec-io/` | Our project |
| `.hyperi-ci.yaml` exists | Our project |
| `LICENSE` mentions "HYPERI PTY LIMITED" | Our project |
| `.gitmodules` already has `hyperi-ai` | Our project |
| None of the above | External -- use stealth |

## After Attaching

Check that it worked:

```bash
ls .claude/rules/       # Standards
ls .claude/skills/      # Methodology skills
ls .claude/settings.json  # Hook configuration
```

If anything is missing, re-run `attach.sh` with `--force`.

## Updating

```bash
# Submodule projects
git submodule update --remote hyperi-ai
./hyperi-ai/attach.sh --force

# Stealth projects
git -C ~/.local/share/hyperi-ai pull
~/.local/share/hyperi-ai/attach.sh --stealth --force --path .
```

The session-start hook also auto-updates silently in both modes.

## Notes

- Stealth symlinks are absolute (`~/.local/share/hyperi-ai/...`). If they
  break, re-run the stealth attach.
- Submodule symlinks are relative (`../../hyperi-ai/...`). These survive
  clones and moves.
- Never commit `.claude/`, `STATE.md`, or `TODO.md` in a stealth project.
  If they show in `git status`, check `.git/info/exclude`.

---

## AI Agent Instructions

If you are an AI coding assistant asked to "attach hyperi-ai", follow these
steps exactly. Do not skip detection.

### 1. Detect project type

Run each check in the target project:

```bash
git remote -v 2>/dev/null | head -1
ls .hyperi-ci.yaml 2>/dev/null
grep -l "HYPERI PTY LIMITED" LICENSE 2>/dev/null
grep -l "hyperi-ai" .gitmodules 2>/dev/null
```

If ANY check matches, this is a **HyperI-controlled project** -- use submodule
mode. If NONE match, this is **external** -- use stealth mode.

### 2. Submodule mode (HyperI-controlled)

```bash
# Skip if .gitmodules already has hyperi-ai
git submodule add https://github.com/hyperi-io/hyperi-ai.git hyperi-ai
./hyperi-ai/attach.sh
git add .gitmodules hyperi-ai .claude STATE.md TODO.md
git commit -m "chore: attach hyperi-ai standards"
```

### 3. Stealth mode (external)

```bash
if [ ! -d ~/.local/share/hyperi-ai ]; then
    git clone https://github.com/hyperi-io/hyperi-ai.git ~/.local/share/hyperi-ai
fi
~/.local/share/hyperi-ai/attach.sh --stealth --path "$(pwd)"
```

Do NOT stage or commit anything. Verify with `git status` -- no
hyperi-ai-related files should appear.

### 4. Verify

```bash
ls .claude/rules/
ls .claude/skills/
ls .claude/settings.json
```

All three must exist. If not, re-run `attach.sh` with `--force`.
