# Load Standards

You are loading coding standards into context on demand.

## Usage

`/standards [domain]` — load a specific domain, or all domains if no argument given.

The argument (if any) is in `$ARGUMENTS`.

---

## Step 1: Determine what to load

Check `$ARGUMENTS`:

- **No argument (empty):** Load all rule files — read every `.md` file in
  `../../ai/standards/rules/` and output its content.

- **Argument given (e.g. `python`, `bash`, `docker`):** Map to the corresponding
  rule file:

  | Argument | File |
  |---|---|
  | `python` | `../../ai/standards/rules/python.md` |
  | `bash` / `shell` / `sh` | `../../ai/standards/rules/bash.md` |
  | `typescript` / `ts` / `js` | `../../ai/standards/rules/typescript.md` |
  | `rust` / `rs` | `../../ai/standards/rules/rust.md` |
  | `golang` / `go` | `../../ai/standards/rules/golang.md` |
  | `docker` | `../../ai/standards/rules/docker.md` |
  | `ansible` | `../../ai/standards/rules/ansible.md` |
  | `k8s` / `kubernetes` / `helm` | `../../ai/standards/rules/k8s.md` |
  | `terraform` / `tf` | `../../ai/standards/rules/terraform.md` |
  | `cpp` / `c++` | `../../ai/standards/rules/cpp.md` |
  | `clickhouse` / `sql` | `../../ai/standards/rules/clickhouse-sql.md` |
  | `pki` / `tls` / `certs` | `../../ai/standards/rules/pki.md` |
  | `testing` / `test` | `../../ai/standards/rules/testing.md` |
  | `security` / `sec` | `../../ai/standards/rules/security.md` |
  | `errors` / `error-handling` | `../../ai/standards/rules/error-handling.md` |
  | `mocks` / `mocking` | `../../ai/standards/rules/mocks-policy.md` |
  | `design` / `principles` | `../../ai/standards/rules/design-principles.md` |
  | `universal` / `common` | `../../ai/standards/rules/UNIVERSAL.md` |

  If the argument does not match any entry, say: "Unknown domain `<argument>`.
  Run `/standards` without arguments to load all, or use one of: python, bash,
  typescript, rust, golang, docker, ansible, k8s, terraform, cpp, clickhouse,
  pki, testing, security, errors, mocks, design, universal."

---

## Step 2: Read and output the file(s)

Read each matched file using the Read tool and display its content so it enters
your context window.

Announce which files you are loading (e.g. "Loading bash standards…").

---

## Step 3: Confirm

State briefly which standards are now active in this session.
