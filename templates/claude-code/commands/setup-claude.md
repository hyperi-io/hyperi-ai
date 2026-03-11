# Setup Claude Code Environment

One-time setup wizard to configure this project for efficient Claude Code use.
Creates the `.tmp/` workspace, surveys available tools, and updates
`settings.local.json` with permission patterns that eliminate unnecessary
OK prompts.

> **Note:** The bash efficiency rules themselves are always active — injected
> automatically at session start and after every context compact via hooks.
> This command just ensures the environment is properly configured.

---

## Step 1: Create the `.tmp/` Workspace

The `.tmp/` directory is a gitignored scratch area INSIDE THE PROJECT for
intermediate files between commands.

1. Run `mkdir -p .tmp`
2. Read `.gitignore` (create if missing)
3. If `.tmp/` is not listed, append `.tmp/` to `.gitignore`

---

## Step 2: Survey Available Tools

Run each check as a **separate** Bash call (never chain):

### Core (should be installed)

1. `which sponge` — in-place filter (moreutils)
2. `which fdfind fd` — fast find replacement
3. `which rg` — ripgrep (fast recursive grep)
4. `which jq` — JSON processor
5. `which sd` — sed replacement (simpler regex)
6. `which mlr` — miller (CSV/JSON/tabular processor)
7. `which yq` — YAML processor

### Productivity (recommended)

8. `which parallel` — GNU parallel (replace for loops)
9. `which batcat bat` — syntax-highlighted cat
10. `which macbash` — multi-line to single-line converter
11. `which ifne` — run only if stdin non-empty (moreutils)
12. `which chronic` — silence unless failure (moreutils)
13. `which gron` — flatten JSON for grep
14. `which entr` — file watcher (replace polling loops)

### Package install suggestions

Detect the package manager and suggest installing missing tools:

**Debian/Ubuntu:**
```
sudo apt install moreutils fd-find bat ripgrep sd miller jq
```

**Fedora:**
```
sudo dnf install moreutils fd-find bat ripgrep sd miller jq
```

**Ask the user before installing.** Do NOT install without confirmation.

---

## Step 3: Review Current Permissions

Read these files (each as a separate Read call):

1. `$CLAUDE_PROJECT_DIR/.claude/settings.local.json` (project-level)
2. `~/.claude/settings.local.json` (user-level)
3. `~/.claude/settings.json` (user base settings)

Report the current permission landscape to the user.

---

## Step 4: Update Project `settings.local.json`

Read or create `$CLAUDE_PROJECT_DIR/.claude/settings.local.json`.

Merge these permission patterns into the existing `permissions.allow` array.
**Do NOT remove existing entries.** Only ADD entries not already present.

### Patterns to add

These cover `.tmp/` operations and common single-command patterns:

```json
{
  "permissions": {
    "allow": [
      "Bash(test:*)",
      "Bash([ :*)",
      "Bash([[ :*)",
      "Bash(printf:*)",
      "Bash(sponge:*)",
      "Bash(chronic:*)",
      "Bash(ifne:*)",
      "Bash(timeout :*)",
      "Bash(time :*)",
      "Bash(nice :*)",
      "Bash(nohup :*)",
      "Bash(tee .tmp/*)",
      "Bash(mktemp .tmp/*)",
      "Bash(wc .tmp/*)",
      "Bash(cat .tmp/*)",
      "Bash(head .tmp/*)",
      "Bash(tail .tmp/*)",
      "Bash(sort .tmp/*)",
      "Bash(uniq .tmp/*)",
      "Bash(diff .tmp/*)",
      "Bash(comm .tmp/*)",
      "Bash(paste .tmp/*)",
      "Bash(column .tmp/*)",
      "Bash(nl .tmp/*)",
      "Bash(rm .tmp/*)",
      "Bash(rm -f .tmp/*)",
      "Bash(rm -rf .tmp)",
      "Bash(cp .tmp/*)",
      "Bash(mv .tmp/*)",
      "Bash(chmod +x .tmp/*)",
      "Bash(bash .tmp/*)",
      "Bash(sh .tmp/*)",
      "Bash(python3 .tmp/*)",
      "Bash(python .tmp/*)",
      "Bash(node .tmp/*)",
      "Bash(./.tmp/*)",
      "Bash(source .tmp/*)",
      "Bash(. .tmp/*)"
    ]
  }
}
```

**Important:** Use the Edit tool or write a small Python script to
`.tmp/merge-settings.py` and run it — do NOT try to do JSON manipulation
via pipes or compound bash.

---

## Step 5: Summary

Print a summary of what was configured:

```
SETUP COMPLETE

  Workspace:     .tmp/ (gitignored)
  Tools found:   sponge, fdfind, rg, jq, sd, mlr, parallel, ...
  Tools missing: gron, entr (optional — suggest install)
  Permissions:   N new entries added to settings.local.json

  Bash efficiency rules are active automatically.
  They persist across context compacts via hooks.
```
