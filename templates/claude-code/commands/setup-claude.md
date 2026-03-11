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

Run the tool survey via the Python helper (this checks both PATH and package
repos in one call):

```bash
python3 "$CLAUDE_PROJECT_DIR/hyperi-ai/hooks/survey_tools_cli.py"
```

This outputs a structured report showing:
- **Installed** tools (with binary path)
- **Not installed but available** in apt/dnf repos (with package name)
- **Not available** in repos (may need manual install)

### Install missing tools

For any tools listed as "available in repos", suggest the install command.
**Ask the user before installing.** Do NOT install without confirmation.

**Debian/Ubuntu:**
```
sudo apt install <package-names>
```

**Fedora/RHEL:**
```
sudo dnf install <package-names>
```

**macOS (Homebrew):**
```
brew install <formula-names>
```

Use the package names shown in the survey output (e.g. `apt: moreutils` → `sudo apt install moreutils`).

### macbash

**macbash** (https://github.com/hyperi-io/macbash) checks bash scripts for
macOS (BSD) compatibility and converts multi-line scripts to single-line.
Essential for projects targeting both Linux and macOS.

Not in default OS repos — install from GitHub releases:

**Debian/Ubuntu (amd64):**
```
curl -LO https://github.com/hyperi-io/macbash/releases/latest/download/macbash_1.2.0_amd64.deb
sudo dpkg -i macbash_1.2.0_amd64.deb
```

**Debian/Ubuntu (arm64):**
```
curl -LO https://github.com/hyperi-io/macbash/releases/latest/download/macbash_1.2.0_arm64.deb
sudo dpkg -i macbash_1.2.0_arm64.deb
```

**Fedora/RHEL (x86_64):**
```
curl -LO https://github.com/hyperi-io/macbash/releases/latest/download/macbash-1.2.0-1.x86_64.rpm
sudo rpm -i macbash-1.2.0-1.x86_64.rpm
```

**Fedora/RHEL (aarch64):**
```
curl -LO https://github.com/hyperi-io/macbash/releases/latest/download/macbash-1.2.0-1.aarch64.rpm
sudo rpm -i macbash-1.2.0-1.aarch64.rpm
```

**macOS (Homebrew):**
```
brew install hyperi-io/macbash/macbash
```

**Any platform (tarball):**
```
# Download the appropriate tarball for your OS/arch from:
# https://github.com/hyperi-io/macbash/releases/latest
tar xzf macbash-1.2.0-*.tar.gz
sudo install macbash /usr/local/bin/
```

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
