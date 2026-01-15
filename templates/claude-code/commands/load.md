# Load Session

You are loading project context for a new work session or refreshing my memory.

## Step 1: Establish Today's Date

Run `date '+%Y-%m-%d %A'` to get today's date.

**CRITICAL:** Use THIS date for all date-related work. Your training data may have
an outdated date - ignore it. The output of this command is the actual current date.

---

## Step 2: Source of Truth (SSoT)

**Before reading any files, understand this hierarchy:**

| Data | Source of Truth | NOT From |
|------|-----------------|----------|
| Today's date | `date` command output above | Training data |
| Version | `git describe --tags` or `VERSION` file | STATE.md |
| Tasks/Progress | `TODO.md` only | STATE.md |
| History | `git log --oneline -10` | STATE.md |
| Changelog | `CHANGELOG.md` (semantic-release) | STATE.md |

**If STATE.md contradicts git or TODO.md, ignore STATE.md.**

STATE.md contains static project context only (architecture, decisions, how things work).
It does NOT contain versions, progress, dates, or session history.

---

## Step 3: Read Project Files

Read in this order:

1. [TODO.md](../../TODO.md) - Tasks and progress (SSoT for work)
2. [STATE.md](../../STATE.md) - Project context (static info only)

---

## Step 4: Load Standards

Read the ENTIRE file (do not truncate):

- [STANDARDS-QUICKSTART.md](../../ai/standards/STANDARDS-QUICKSTART.md)

---

## Step 5: Detect Project Language

Glob for config files in project root (not subdirs, not `.venv/`, not `node_modules/`):

| Config File Found | Load (COMPLETE FILE) |
|-------------------|----------------------|
| `pyproject.toml`, `setup.py` | `ai/standards/languages/PYTHON.md` |
| `go.mod` | `ai/standards/languages/GOLANG.md` |
| `package.json`, `tsconfig.json` | `ai/standards/languages/TYPESCRIPT.md` |
| `Cargo.toml` | `ai/standards/languages/RUST.md` |
| `CMakeLists.txt`, `*.cpp`, `*.hpp` | `ai/standards/languages/CPP.md` |
| `*.sh` only (no other lang) | `ai/standards/languages/BASH.md` |

---

## Step 6: Check for Infrastructure

| IaC Files Found | Load (COMPLETE FILE) |
|-----------------|----------------------|
| `Dockerfile`, `docker-compose.yaml` | `ai/standards/infrastructure/DOCKER.md` |
| `Chart.yaml`, `values.yaml` | `ai/standards/infrastructure/K8S.md` |
| `*.tf` | `ai/standards/infrastructure/TERRAFORM.md` |
| `ansible.cfg`, `playbook.yml` | `ai/standards/infrastructure/ANSIBLE.md` |

---

## Step 7: Check for PKI/TLS

| Files/Dirs Found | Load (COMPLETE FILE) |
|------------------|----------------------|
| `certs/`, `ssl/`, `pki/`, `tls/` dirs | `ai/standards/common/PKI.md` |
| `*.crt`, `*.pem`, `ssl*.xml`, `*-tls.yaml` | `ai/standards/common/PKI.md` |

---

## Step 8: Sync and Ready

1. **Update `ai` submodule** (only if `ai/.git` exists):

   ```bash
   git submodule update --remote ai 2>/dev/null || true
   ```

   Skip silently if no submodule or not a git repo.

2. Sync with remote:

   ```bash
   git pull --rebase 2>/dev/null || true
   ```

3. Check git status: `git status --short` and `git log --oneline -5`

4. Be ready - no greetings, wait for the user's first task

---

## Proactive Saving

Run `/save` proactively throughout the session - context can compact without warning.

**Save when:**

- After completing any significant task
- Every 30-40 exchanges
- Before the user takes breaks
- When your responses get shorter (sign of context pressure)

**Signs you need to save NOW:**

- Responses getting truncated
- Forgetting earlier context
- Repeating questions already answered
