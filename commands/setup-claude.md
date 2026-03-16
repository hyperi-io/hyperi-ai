# Setup Claude Code Environment

One-time setup wizard to configure this project for efficient Claude Code use.
Creates the `.tmp/` workspace, surveys available tools, and updates
`settings.local.json` with permission patterns that eliminate unnecessary
OK prompts.

> **Note:** The bash efficiency rules themselves are always active — injected
> automatically at session start and after every context compact via hooks.
> This command just ensures the environment is properly configured.

---

## Step 0: Verify Superpowers Plugin

Check if the superpowers plugin is installed:

```bash
claude plugin list 2>/dev/null | grep -q superpowers && echo "INSTALLED" || echo "NOT INSTALLED"
```

If **NOT INSTALLED**, tell the user:

```
The superpowers plugin provides methodology skills (debugging, TDD, planning,
worktrees, code review). It complements our corporate coding standards.

Install with:
  claude plugin marketplace add obra/superpowers-marketplace
  claude plugin install superpowers@superpowers-marketplace

Restart Claude Code after installing.
```

**Ask the user before installing.** Do NOT install without confirmation.

If **INSTALLED**, check for updates:

```bash
claude plugin list 2>/dev/null | grep superpowers
```

Report the installed version and move on.

---

## Step 1: Create the `.tmp/` Workspace

The `.tmp/` directory is a gitignored scratch area INSIDE THE PROJECT for
intermediate files between commands.

1. Run `mkdir -p .tmp`
2. Read `.gitignore` (create if missing)
3. If `.tmp/` is not listed, append `.tmp/` to `.gitignore`

---

## Step 1b: Configure GitHub MCP Authentication

The GitHub MCP server is deployed as a remote HTTP server
(`https://api.githubcopilot.com/mcp/`) in `.mcp.json`. It needs authentication
to work. Check if auth is already configured:

```bash
claude mcp list 2>/dev/null | grep -A2 github || echo "NOT CONFIGURED"
```

If the github server shows up with auth, move on.

If NOT CONFIGURED or missing auth, discover a PAT:

```bash
python3 "$CLAUDE_PROJECT_DIR/hyperi-ai/tools/discover_github_pat.py" --source 2>&1 | tail -1
```

If a token was found, configure it at user scope:

```bash
TOKEN=$(python3 "$CLAUDE_PROJECT_DIR/hyperi-ai/tools/discover_github_pat.py")
claude mcp add -s user --transport http github https://api.githubcopilot.com/mcp/ -H "Authorization: Bearer $TOKEN"
```

If no token was found, tell the user:

```
The GitHub MCP server needs authentication. Two options:

Option 1 — OAuth (easiest, requires browser):
  Claude Code will prompt for OAuth when the MCP server is first used.
  Just approve the GitHub OAuth flow when prompted.

Option 2 — Personal Access Token:
  The PAT discovery script checks these locations (in order):
    1. $GITHUB_TOKEN or $GH_TOKEN environment variable
    2. Project .env file (GITHUB_TOKEN=...)
    3. ~/.env file (GITHUB_TOKEN=...)
    4. gh auth token (gh CLI keyring -- run: gh auth login)
    5. ~/.config/gh/hosts.yml
    6. ~/.netrc

  Easiest: run `gh auth login` to authenticate the gh CLI, then re-run /setup-claude.
  Or create a PAT at: https://github.com/settings/tokens
  Required scopes: repo, read:org
```

**Ask the user which approach they prefer.** Do NOT create tokens for them.

---

## Step 2: Survey Available Tools

**IMPORTANT: You MUST use the Python survey script below. Do NOT run individual
`which` checks or guess about package availability. The script checks both PATH
and package repos (apt-cache/dnf/brew) automatically and produces an accurate
report.**

Run this single command:

```bash
python3 "$CLAUDE_PROJECT_DIR/hyperi-ai/hooks/survey_tools_cli.py"
```

Read the output. It shows three sections:
- **Installed** — tools found on PATH (with binary path)
- **Not Installed (available in package repos)** — not installed but the package
  exists in apt/dnf/brew (with exact package name)
- **Not Available in Repos** — needs manual install (e.g. macbash from GitHub)

### Install missing tools

For tools listed as "available in package repos", suggest the install command
using the **exact package name from the survey output**.
**Ask the user before installing.** Do NOT install without confirmation.

**Debian/Ubuntu:** `sudo apt install <package-names>`
**Fedora/RHEL:** `sudo dnf install <package-names>`
**macOS (Homebrew):** `brew install <formula-names>`

Example: if the survey says `gron (apt: gron)` → `sudo apt install gron`

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

## Step 2b: Check hyperi-ci (Conditional)

**Only if `.hyperi-ci.yaml` exists in the project root.** Skip this step entirely
for projects without it.

Check if `hyperi-ci` is installed:

```bash
which hyperi-ci
```

If NOT installed, tell the user:

```
This project uses hyperi-ci (.hyperi-ci.yaml detected).
The hyperi-ci CLI is not installed. Install with:

  uv tool install hyperi-ci

Or if uv is unavailable:

  pip install --user hyperi-ci
```

**Ask the user before installing.** Do NOT install without confirmation.

If installed, verify it works:

```bash
hyperi-ci detect
```

Report the detected language and confirm CI tool is operational.

Also verify the project has a `Makefile` with standard targets. If present,
mention available targets: `make quality`, `make test`, `make build`, `make ci`.

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
