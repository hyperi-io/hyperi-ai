---
paths:
  - "**/playbook*.yml"
  - "**/ansible.cfg"
  - "**/roles/**/*.yml"
  - "**/inventory/**/*"
detect_markers:
  - "file:ansible.cfg"
  - "glob:playbook*.yml"
  - "dir:playbooks"
  - "deep_file:ansible.cfg"
  - "deep_glob:playbook*.yml"
source: infrastructure/ANSIBLE.md
---

<!-- override: manual -->
## Quick Reference

- **Lint:** `ansible-lint playbook.yml`
- **Test:** `molecule test`
- **Run:** `ansible-playbook -i inventories/dev/inventory.yml playbooks/site.yml`
- **Check:** `ansible-playbook --check --diff playbook.yml`

## Non-Negotiable Rules

- Use `ansible.builtin` FQCN for all core modules — never short names
- Every task MUST have a descriptive `name:`
- Role-prefix all variables (`rolename_varname`)
- All operations must be idempotent
- `ansible-lint` with zero warnings before commit
- Always specify `mode:` on file/copy/template operations
- Use `ansible.builtin.command` over `ansible.builtin.shell` unless shell features needed

## Project Layout

```
project/
├── ansible.cfg
├── requirements.yml
├── inventories/{localhost,dev,staging,prod}/
│   ├── inventory.yml
│   ├── group_vars/
│   └── host_vars/
├── playbooks/
│   ├── site.yml
│   └── group_vars/all.yml
└── roles/
    └── role_name/
        ├── defaults/main.yml    # Lowest-priority defaults
        ├── tasks/main.yml       # Task orchestrator importing subtasks
        ├── handlers/main.yml
        ├── templates/
        ├── files/
        ├── vars/main.yml        # Internal variables
        └── meta/main.yml        # Galaxy metadata
```

## ansible.cfg Essentials

```ini
[defaults]
inventory = inventories/localhost/inventory.yml
roles_path = roles
host_key_checking = false
interpreter_python = /usr/bin/python3
retry_files_enabled = false
stdout_callback = yaml
forks = 5

[ssh_connection]
pipelining = true

[privilege_escalation]
become = true
become_method = sudo
```

## Variable Precedence (low→high)

1. `defaults/main.yml` → 2. `group_vars/all.yml` → 3. `group_vars/{group}.yml` → 4. `host_vars/{host}.yml` → 5. playbook vars

## FQCN — Common Modules

- `ansible.builtin.{apt,dnf,package,copy,template,file,service,command,shell,user,group,lineinfile,blockinfile,debug,fail,assert,set_fact,include_vars,import_tasks,include_role,import_role,sysctl,get_url,apt_repository,yum_repository,service_facts}`
- `community.general.{flatpak,homebrew,homebrew_cask}`
- `community.docker.docker_container`, `community.postgresql.postgresql_db`
- Verify unknown collection modules on Galaxy before using — AI may hallucinate module names

## Task Naming

- Use descriptive present tense: "Install nginx package", "Configure SSH baseline settings"
- Add platform in parentheses for OS-specific tasks: "Install Docker CE (Fedora)"
- ❌ `- apt: name: nginx` (unnamed) / ✅ `- name: Install nginx` then `ansible.builtin.apt:`

## Idempotence

- Use `creates:` guard on command/shell tasks
- Set `changed_when: false` on read-only commands
- Use custom `changed_when:` for commands with detectable changes
- ❌ `ansible.builtin.shell: ./setup.sh` (always runs)
- ✅ `ansible.builtin.shell: ./setup.sh` with `args: creates: /app/.setup_complete`

## Conditionals and Loops

- Use `when: ansible_os_family == 'Debian'` / `'RedHat'` for platform-specific tasks
- Use `block:` to group tasks sharing a `when:` condition
- Use `ansible.builtin.include_vars` with `with_first_found` for OS-specific vars
- Use `| bool` filter on boolean conditions: `when: enable_feature | bool`
- Use `ansible.builtin.import_tasks` (static) for unconditional subtasks
- Use `ansible.builtin.include_role` (dynamic) with `when:` for conditional roles

## File Modification Patterns

- `lineinfile` + `loop` for key-value config (e.g., sshd_config settings)
- `blockinfile` with `marker: "# {mark} ANSIBLE MANAGED BLOCK"` for multi-line blocks
- `template` with `validate:` parameter where possible (e.g., `validate: nginx -t -c %s`)
- Always add `# Managed by Ansible - DO NOT EDIT MANUALLY` header in templates

## Error Handling

- Use `retries:` + `delay:` + `until:` for flaky operations (apt locks, network)
- Use `failed_when: false` + `register:` to check before acting
- Use `ansible.builtin.assert` to validate required variables early
- Use `ansible.builtin.fail` for unsupported OS/config detection

## Vault for Secrets

```bash
ansible-vault encrypt group_vars/prod/vault.yml
ansible-vault edit group_vars/prod/vault.yml
ansible-playbook site.yml --vault-password-file ~/.vault_pass
```

- Prefix vault vars with `vault_` in encrypted file
- Reference in plain vars file: `db_password: "{{ vault_db_password }}"`

## Molecule Testing

```bash
molecule init scenario -r my_role -d docker
molecule test          # Full test sequence
molecule converge      # Run playbook only
molecule verify        # Run verification only
```

- Test against multiple platforms (Ubuntu 22.04/24.04, Fedora, EL 8/9)
- Verification tasks: use `check_mode: true` + `failed_when: result.changed`

## Ansible-Lint Config (.ansible-lint)

```yaml
profile: production
skip_list: [yaml[line-length]]
warn_list: [experimental]
exclude_paths: [.cache/, .git/, roles/external/]
```

## AI-Specific Rules

- Never generate placeholder tasks or TODO comments — code must be complete
- Never hardcode example IPs or credentials
- Never assume single platform — add OS conditionals or use `ansible.builtin.package`
- Always include `mode:`, `owner:`, `group:` on file operations
- Always add `changed_when:` or `creates:` to command/shell tasks
- Always role-prefix variables to avoid cross-role conflicts
- Run `ansible-lint` on all generated code before accepting
