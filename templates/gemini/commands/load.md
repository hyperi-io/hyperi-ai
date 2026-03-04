# Load Session

You are loading project context for a new work session or refreshing my memory.

## Session Initialization

**Step 1: Read project state** (in this order):

- [STATE.md](../../STATE.md) - Current project state and session history
- [TODO.md](../../TODO.md) - Current tasks and priorities

**Step 2: Load universal standards:**

- [UNIVERSAL.md](../../ai/standards/rules/UNIVERSAL.md) - Cross-cutting coding rules

**Step 3: Load language and infrastructure rules:**

Check which languages/infra are in use based on project files, then read the
matching compact rule from [ai/standards/rules/](../../ai/standards/rules/):

| Marker Files | Rule File |
|--------------|-----------|
| pyproject.toml, setup.py, requirements.txt | rules/python.md |
| go.mod | rules/golang.md |
| tsconfig.json, package.json | rules/typescript.md |
| Cargo.toml | rules/rust.md |
| CMakeLists.txt, *.cpp | rules/cpp.md |
| *.sh | rules/bash.md |
| Dockerfile, docker-compose*.yml | rules/docker.md |
| Chart.yaml, values.yaml | rules/k8s.md |
| *.tf | rules/terraform.md |
| ansible.cfg, playbook.yml | rules/ansible.md |
| certs/, ssl/, pki/ | rules/pki.md |

Also read these universal rules: testing.md, error-handling.md, security.md,
design-principles.md, mocks-policy.md

For full detail during review or complex decisions, see
[ai/standards/languages/](../../ai/standards/languages/) and
[ai/standards/infrastructure/](../../ai/standards/infrastructure/).

---

## Ready to Work

After loading documentation:

1. Check git status and recent commits
2. Be ready - no greetings, wait for the user's first task
