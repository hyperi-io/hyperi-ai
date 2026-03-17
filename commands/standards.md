# Load Standards

You are loading coding standards into context on demand.

## Usage

`/standards [domain]` — load a specific domain, or all domains if no argument given.

The argument (if any) is in `$ARGUMENTS`.

---

## Step 1: Determine what to load

Check `$ARGUMENTS`:

- **No argument (empty):** Load all rule files — read every `.md` file in
  `../../hyperi-ai/standards/rules/` and output its content.

- **Argument given (e.g. `python`, `bash`, `docker`):** Map to the corresponding
  rule file:

  | Argument | File |
  |---|---|
  | `python` | `../../hyperi-ai/standards/rules/python.md` |
  | `bash` / `shell` / `sh` | `../../hyperi-ai/standards/rules/bash.md` |
  | `typescript` / `ts` / `js` | `../../hyperi-ai/standards/rules/typescript.md` |
  | `rust` / `rs` | `../../hyperi-ai/standards/rules/rust.md` |
  | `golang` / `go` | `../../hyperi-ai/standards/rules/golang.md` |
  | `docker` | `../../hyperi-ai/standards/rules/docker.md` |
  | `ansible` | `../../hyperi-ai/standards/rules/ansible.md` |
  | `k8s` / `kubernetes` / `helm` | `../../hyperi-ai/standards/rules/k8s.md` |
  | `terraform` / `tf` | `../../hyperi-ai/standards/rules/terraform.md` |
  | `cpp` / `c++` | `../../hyperi-ai/standards/rules/cpp.md` |
  | `clickhouse` / `sql` | `../../hyperi-ai/standards/rules/clickhouse-sql.md` |
  | `pki` / `tls` / `certs` | `../../hyperi-ai/standards/rules/pki.md` |
  | `testing` / `test` | `../../hyperi-ai/standards/rules/testing.md` |
  | `security` / `sec` | `../../hyperi-ai/standards/rules/security.md` |
  | `errors` / `error-handling` | `../../hyperi-ai/standards/rules/error-handling.md` |
  | `mocks` / `mocking` | `../../hyperi-ai/standards/rules/mocks-policy.md` |
  | `design` / `principles` | `../../hyperi-ai/standards/rules/design-principles.md` |
  | `universal` / `common` | `../../hyperi-ai/standards/rules/universal.md` |

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
