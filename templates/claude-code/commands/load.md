# Load Session

You are loading project context for a new work session or refreshing my memory.

## Session Initialization

**Step 1: Check current date:**

Run `date '+%Y-%m-%d %A'` to get today's date. Remember this date for the session - do not rely on your training data for the current date or year.

**Step 2: Read project state** (in this order):

- [STATE.md](../../STATE.md) - Current project state and session history
- [TODO.md](../../TODO.md) - Current tasks and priorities

**Step 3: Load standards (COMPLETE FILE - do not truncate):**

- [STANDARDS-QUICKSTART.md](../../ai/standards/STANDARDS-QUICKSTART.md) - Core coding standards

⚠️ **Read the ENTIRE file** - do not use `limit` parameter or truncate. Critical instructions are throughout.

**Step 4: Detect project language and load standards:**

Follow the "MANDATORY: Detect Project Language" section in STANDARDS-QUICKSTART.md:

1. **Glob** for config files in project root (not subdirs, not `.venv/`, not `node_modules/`, not git submodules)
2. **Read** the config file to confirm language
3. **Read the ENTIRE language standards file** (do not truncate):

| Config File Found | Load (COMPLETE FILE) |
|-------------------|----------------------|
| `pyproject.toml`, `setup.py` | `ai/standards/languages/PYTHON.md` |
| `go.mod` | `ai/standards/languages/GOLANG.md` |
| `package.json`, `tsconfig.json` | `ai/standards/languages/TYPESCRIPT.md` |
| `Cargo.toml` | `ai/standards/languages/RUST.md` |
| `CMakeLists.txt`, `*.cpp`, `*.hpp` | `ai/standards/languages/CPP.md` |
| `*.sh` only (no other lang) | `ai/standards/languages/BASH.md` |

**Step 5: Check for infrastructure:**

| IaC Files Found | Load (COMPLETE FILE) |
|-----------------|----------------------|
| `Dockerfile`, `docker-compose.yaml` | `ai/standards/infrastructure/DOCKER.md` |
| `Chart.yaml`, `values.yaml` | `ai/standards/infrastructure/K8S.md` |
| `*.tf` | `ai/standards/infrastructure/TERRAFORM.md` |
| `ansible.cfg`, `playbook.yml` | `ai/standards/infrastructure/ANSIBLE.md` |

**Step 6: Check for PKI/TLS:**

| Files/Dirs Found                           | Load (COMPLETE FILE)          |
|--------------------------------------------|-------------------------------|
| `certs/`, `ssl/`, `pki/`, `tls/` dirs      | `ai/standards/common/PKI.md`  |
| `*.crt`, `*.pem`, `ssl*.xml`, `*-tls.yaml` | `ai/standards/common/PKI.md`  |

---

## Ready to Work

After loading all documentation:

1. Check git status and recent commits
2. Be ready - no greetings, wait for the user's first task

---

## IMPORTANT: Proactive Saving

⚠️ **Run `/save` proactively throughout the session** - context can compact without warning.

**Save when:**

- After completing any significant task
- Every 30-40 exchanges
- Before the user takes breaks
- When your responses get shorter (sign of context pressure)
- After making important decisions

**Signs you need to save NOW:**

- Responses getting truncated
- Forgetting earlier context
- Repeating questions already answered
- Uncertainty about what was discussed earlier
