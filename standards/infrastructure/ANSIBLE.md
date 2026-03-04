---
name: ansible-standards
description: Ansible standards for playbooks, roles, and configuration management. Use when writing Ansible playbooks, reviewing automation, or managing server configurations.
---

# Ansible Standards for HyperI Projects

**Configuration management and automation standards for infrastructure-as-code**

---

## Quick Reference

**Lint:** `ansible-lint playbook.yml`
**Test:** `molecule test`
**Run:** `ansible-playbook -i inventories/dev/inventory.yml playbooks/site.yml`
**Check:** `ansible-playbook --check --diff playbook.yml`

**Non-negotiable:**

- `ansible.builtin` FQCN for all core modules
- Every task has a descriptive `name:`
- Role-prefix all variables (`rolename_varname`)
- Idempotent operations only
- `ansible-lint` with zero warnings

---

## Project Structure

### Standard Layout

```text
project/
├── ansible.cfg               # Project-specific config
├── requirements.yml          # Galaxy dependencies
│
├── inventories/
│   ├── localhost/
│   │   └── inventory.yml
│   ├── dev/
│   │   ├── inventory.yml
│   │   ├── group_vars/
│   │   │   └── all.yml
│   │   └── host_vars/
│   ├── staging/
│   │   └── ...
│   └── prod/
│       └── ...
│
├── playbooks/
│   ├── site.yml              # Main entry point
│   ├── deploy.yml            # Deployment playbook
│   └── group_vars/
│       └── all.yml           # Global vars for playbooks
│
└── roles/
    ├── role_name/
    │   ├── README.md         # Role documentation
    │   ├── CHANGELOG.md      # Version history
    │   ├── defaults/
    │   │   └── main.yml      # Default variables
    │   ├── tasks/
    │   │   ├── main.yml      # Task orchestrator
    │   │   ├── init.yml      # Validation tasks
    │   │   └── install.yml   # Installation tasks
    │   ├── handlers/
    │   │   └── main.yml
    │   ├── templates/
    │   │   └── config.j2
    │   ├── files/            # Static files
    │   ├── vars/
    │   │   └── main.yml      # Internal variables
    │   └── meta/
    │       └── main.yml      # Galaxy metadata
    └── deprecated/           # Archived roles
```

---

## ansible.cfg Configuration

```ini
[defaults]
inventory = inventories/localhost/inventory.yml
roles_path = roles
host_key_checking = false
interpreter_python = /usr/bin/python3
retry_files_enabled = false
stdout_callback = yaml
callback_result_format = yaml
forks = 5

[ssh_connection]
ssh_args = -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
pipelining = true

[privilege_escalation]
become = true
become_method = sudo
become_user = root
```

---

## Inventory Structure

### YAML Inventory Format

```yaml
---
# inventories/prod/inventory.yml
all:
  children:
    webservers:
      hosts:
        web1.example.com:
        web2.example.com:
      vars:
        http_port: 80

    dbservers:
      hosts:
        db1.example.com:
          ansible_host: 10.0.1.10
        db2.example.com:
          ansible_host: 10.0.1.11
      vars:
        db_port: 5432

  vars:
    ansible_user: deploy
    ansible_python_interpreter: /usr/bin/python3
```

### Localhost Inventory

```yaml
---
# inventories/localhost/inventory.yml
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
```

---

## Playbook Structure

### Main Playbook (site.yml)

```yaml
---
# playbooks/site.yml
- name: Configure all servers
  hosts: all
  become: true
  gather_facts: true

  pre_tasks:
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600
      when: ansible_os_family == 'Debian'

  roles:
    - common
    - security
    - monitoring

  post_tasks:
    - name: Verify services running
      ansible.builtin.service_facts:
```

### Role Import Patterns

```yaml
# Static import (processed at parse time)
- name: Apply security hardening
  ansible.builtin.import_role:
    name: security
  vars:
    security_level: high

# Dynamic include (processed at runtime)
- name: Apply optional monitoring
  ansible.builtin.include_role:
    name: monitoring
  when: monitoring_enabled | default(false)
```

---

## Role Structure

### defaults/main.yml

```yaml
---
# Role parameter defaults (lowest priority)
# Users override these in group_vars/host_vars

# Package configuration
myapp_package_name: myapp
myapp_version: "1.0.0"

# Service configuration
myapp_service_enabled: true
myapp_service_state: started

# Network settings
myapp_listen_address: "0.0.0.0"
myapp_listen_port: 8080

# Feature flags
myapp_ssl_enabled: false
myapp_logging_enabled: true
```

### tasks/main.yml

```yaml
---
# Task orchestrator - imports subtasks

- name: Include OS-specific variables
  ansible.builtin.include_vars: "{{ item }}"
  with_first_found:
    - "{{ ansible_distribution }}-{{ ansible_distribution_major_version }}.yml"
    - "{{ ansible_distribution }}.yml"
    - "{{ ansible_os_family }}.yml"
    - default.yml

- name: Validate prerequisites
  ansible.builtin.import_tasks: validate.yml

- name: Install packages
  ansible.builtin.import_tasks: install.yml

- name: Configure application
  ansible.builtin.import_tasks: configure.yml

- name: Manage service
  ansible.builtin.import_tasks: service.yml
```

### handlers/main.yml

```yaml
---
- name: Restart myapp
  ansible.builtin.service:
    name: myapp
    state: restarted
  become: true

- name: Reload nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded
  become: true
```

### meta/main.yml

```yaml
---
galaxy_info:
  author: HyperI
  company: HyperI
  description: Installs and configures myapp
  license: FSL-1.1-ALv2
  min_ansible_version: "2.12"

  platforms:
    - name: EL
      versions: [8, 9]
    - name: Debian
      versions: [11, 12]
    - name: Ubuntu
      versions: ['22.04', '24.04']

dependencies: []
```

---

## Task Naming

### Standards

```yaml
# ✅ Good - descriptive, present tense
- name: Install nginx package
- name: Configure SSH baseline settings
- name: Create application user
- name: Wait for database port 5432 to become available

# ✅ Good - platform indicator in parentheses
- name: Install Docker CE (Fedora)
- name: Add Docker repository (Ubuntu)

# ❌ Bad - vague or no name
- apt:
    name: nginx
- name: Do stuff
- name: Step 1
```

### Section Comments

```yaml
# ============================================================================
# PACKAGE INSTALLATION
# ============================================================================

- name: Install required packages
  ansible.builtin.package:
    name: "{{ packages }}"
    state: present

# ============================================================================
# CONFIGURATION
# ============================================================================

- name: Deploy configuration file
  ansible.builtin.template:
    src: config.j2
    dest: /etc/myapp/config.yml
```

---

## Variable Naming

### Role-Prefixed Variables

```yaml
# Role: nginx
nginx_worker_processes: auto
nginx_worker_connections: 1024
nginx_ssl_enabled: true
nginx_ssl_certificate: /etc/ssl/certs/server.crt

# Role: postgresql
postgresql_version: 15
postgresql_data_directory: /var/lib/postgresql/15/main
postgresql_listen_addresses: localhost
```

### Variable Types

```yaml
# Booleans - explicit true/false
feature_enabled: true
debug_mode: false

# Strings - quote if special chars
service_name: "my-app"
config_path: "/etc/myapp"

# Lists
allowed_users:
  - admin
  - deploy
  - monitoring

# Dictionaries
server_config:
  host: localhost
  port: 8080
  workers: 4
```

### Variable Precedence

```text
1. defaults/main.yml          (lowest - role defaults)
2. group_vars/all.yml         (global groups)
3. group_vars/{group}.yml     (specific groups)
4. host_vars/{host}.yml       (host-specific)
5. playbook vars              (highest)
```

---

## FQCN (Fully Qualified Collection Names)

### Required Usage

```yaml
# ✅ Good - FQCN for all modules
- name: Install package
  ansible.builtin.apt:
    name: nginx
    state: present

- name: Copy file
  ansible.builtin.copy:
    src: config.txt
    dest: /etc/app/config.txt

- name: Execute command
  ansible.builtin.command:
    cmd: /usr/bin/app --init

# ❌ Bad - short module names
- apt:
    name: nginx
- copy:
    src: config.txt
```

### Common FQCNs

```yaml
# Core modules
ansible.builtin.apt
ansible.builtin.yum
ansible.builtin.dnf
ansible.builtin.package
ansible.builtin.copy
ansible.builtin.template
ansible.builtin.file
ansible.builtin.service
ansible.builtin.command
ansible.builtin.shell
ansible.builtin.user
ansible.builtin.group
ansible.builtin.lineinfile
ansible.builtin.blockinfile
ansible.builtin.debug
ansible.builtin.fail
ansible.builtin.assert

# Community collections
community.general.flatpak
community.general.homebrew
community.docker.docker_container
community.postgresql.postgresql_db
```

---

## File Modification Patterns

### lineinfile for Key-Value Settings

```yaml
# Configure multiple SSH settings with loop
- name: Configure SSH baseline settings
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?{{ item.key }}'
    line: "{{ item.key }} {{ item.value }}"
    state: present
  loop:
    - { key: 'PasswordAuthentication', value: 'no' }
    - { key: 'PermitRootLogin', value: 'no' }
    - { key: 'X11Forwarding', value: 'no' }
    - { key: 'LogLevel', value: 'INFO' }
  notify: Reload sshd
```

### blockinfile for Multi-Line Content

```yaml
# Add managed configuration block
- name: Configure fail2ban for SSH
  ansible.builtin.copy:
    dest: /etc/fail2ban/jail.d/zzz-50-hyperi-sshd.conf
    content: |
      [sshd]
      enabled = true
      port = ssh
      maxretry = 5
      bantime = 600
    mode: "0644"

# blockinfile with marker
- name: Ensure Match block for IP restrictions
  ansible.builtin.blockinfile:
    path: /etc/ssh/sshd_config
    marker: "# {mark} ANSIBLE MANAGED BLOCK (HyperI)"
    block: |
      Match Address {{ allowed_ips | join(',') }}
        PermitRootLogin no
        PasswordAuthentication no
        PubkeyAuthentication no
  when: allowed_ips | length > 0
  notify: Reload sshd
```

### sysctl Configuration Pattern

```yaml
# Merge settings and deploy via template
- name: Merge network sysctl parameters
  ansible.builtin.set_fact:
    merged_sysctl_settings: >-
      {{ (merged_sysctl_settings | default({}))
         | combine(network_sysctl_settings) }}

- name: Deploy sysctl configuration
  ansible.builtin.template:
    src: zzz-50-hyperi-sysctl.conf.j2
    dest: /etc/sysctl.d/zzz-50-hyperi-sysctl.conf
    mode: "0644"

- name: Reload sysctl settings
  ansible.builtin.command: sysctl --system
  changed_when: false
```

---

## Template Patterns

### Jinja2 Template Structure

```jinja2
{# templates/config.yml.j2 #}
# Managed by Ansible - DO NOT EDIT MANUALLY
# Template: {{ template_path }}
# Generated: {{ ansible_date_time.iso8601 }}

# Server configuration
server:
  host: {{ myapp_listen_address }}
  port: {{ myapp_listen_port }}
{% if myapp_ssl_enabled %}
  ssl:
    enabled: true
    certificate: {{ myapp_ssl_certificate }}
    key: {{ myapp_ssl_key }}
{% endif %}

# Features
{% for feature in myapp_features | default([]) %}
  - {{ feature }}
{% endfor %}
```

### Template Best Practices

```yaml
# Deploy template with validation
- name: Deploy nginx configuration
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    validate: nginx -t -c %s
  notify: Reload nginx
```

---

## Conditionals and Loops

### Platform-Specific Tasks

```yaml
# OS family conditional
- name: Install packages (Debian)
  ansible.builtin.apt:
    name: "{{ packages }}"
    state: present
  when: ansible_os_family == 'Debian'

- name: Install packages (RedHat)
  ansible.builtin.dnf:
    name: "{{ packages }}"
    state: present
  when: ansible_os_family == 'RedHat'

# Distribution + version
- name: Configure for Ubuntu 24.04
  ansible.builtin.template:
    src: ubuntu24.conf.j2
    dest: /etc/app/config.conf
  when:
    - ansible_distribution == 'Ubuntu'
    - ansible_distribution_version == '24.04'
```

### Block for Grouped Conditionals

```yaml
- name: Configure Docker on Fedora
  when: ansible_distribution == 'Fedora'
  block:
    - name: Add Docker repository
      ansible.builtin.yum_repository:
        name: docker-ce
        description: Docker CE Repository
        baseurl: https://download.docker.com/linux/fedora/$releasever/$basearch/stable
        gpgcheck: true

    - name: Install Docker packages
      ansible.builtin.dnf:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
        state: present
```

### Multi-Platform Tasks Pattern

From HyperI project patterns:

```yaml
# Pattern: Same task for multiple platforms

# Fedora
- name: Add Docker repository (Fedora)
  ansible.builtin.command:
    cmd: dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
  args:
    creates: /etc/yum.repos.d/docker-ce.repo
  when: ansible_distribution == 'Fedora'

# Ubuntu - block for multi-step
- name: Configure Docker repository (Ubuntu)
  when: ansible_distribution == 'Ubuntu'
  block:
    - name: Create GPG keyring directory
      ansible.builtin.file:
        path: /etc/apt/keyrings
        state: directory
        mode: '0755'

    - name: Add Docker GPG key
      ansible.builtin.get_url:
        url: "{{ docker_gpg_url }}"
        dest: /etc/apt/keyrings/docker.asc
        mode: '0644'

    - name: Add Docker repository
      ansible.builtin.apt_repository:
        repo: "deb [arch={{ docker_arch }} signed-by=/etc/apt/keyrings/docker.asc] {{ docker_repo_url }} {{ ansible_distribution_release }} stable"
        filename: docker
        state: present

# macOS (different approach entirely)
- name: Install Docker Desktop via Homebrew (macOS)
  community.general.homebrew_cask:
    name: docker
    state: present
  become: false
  when: ansible_distribution == 'MacOSX'
```

### Loops

```yaml
# Simple loop
- name: Create directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - /var/log/myapp
    - /var/lib/myapp
    - /etc/myapp

# Loop with dict
- name: Configure sysctl settings
  ansible.builtin.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    state: present
  loop: "{{ sysctl_settings | dict2items }}"
  vars:
    sysctl_settings:
      net.ipv4.ip_forward: 1
      vm.swappiness: 10
```

---

## Error Handling

### Retries for Flaky Operations

```yaml
- name: Wait for apt lock
  ansible.builtin.apt:
    update_cache: true
  register: apt_result
  retries: 12
  delay: 10
  until: apt_result is success
```

### Ignore Errors Selectively

```yaml
# Check if service exists (may not)
- name: Check if legacy service exists
  ansible.builtin.command: systemctl status legacy-app
  register: legacy_check
  failed_when: false
  changed_when: false

- name: Stop legacy service if running
  ansible.builtin.service:
    name: legacy-app
    state: stopped
  when: legacy_check.rc == 0
```

### Validation Tasks

```yaml
- name: Validate supported operating system
  ansible.builtin.fail:
    msg: "Unsupported OS: {{ ansible_distribution }} {{ ansible_distribution_version }}"
  when: ansible_distribution not in supported_distributions

- name: Assert required variables are defined
  ansible.builtin.assert:
    that:
      - myapp_api_key is defined
      - myapp_api_key | length > 0
    fail_msg: "myapp_api_key must be defined and non-empty"
```

---

## Idempotence

### Ensure Idempotent Operations

```yaml
# ✅ Good - idempotent (uses state)
- name: Ensure user exists
  ansible.builtin.user:
    name: deploy
    state: present

# ✅ Good - creates guard
- name: Initialize application (once)
  ansible.builtin.command:
    cmd: /usr/bin/myapp --init
    creates: /var/lib/myapp/.initialized

# ❌ Bad - always runs
- name: Run init script
  ansible.builtin.command:
    cmd: /usr/bin/myapp --init
```

### changed_when Control

```yaml
# Command that doesn't change state
- name: Check application version
  ansible.builtin.command: myapp --version
  register: version_output
  changed_when: false

# Custom change detection
- name: Apply database migrations
  ansible.builtin.command: myapp migrate
  register: migrate_result
  changed_when: "'Applied' in migrate_result.stdout"
```

---

## Ansible Lint

### Configuration (.ansible-lint)

```yaml
---
# .ansible-lint
profile: production

skip_list:
  - yaml[line-length]  # Allow long lines in some cases

warn_list:
  - experimental

exclude_paths:
  - .cache/
  - .git/
  - roles/external/
```

### Common Lint Rules

```yaml
# name[missing] - All tasks must have names
# ❌ Bad
- apt:
    name: nginx

# ✅ Good
- name: Install nginx
  ansible.builtin.apt:
    name: nginx

# fqcn[action-core] - Use FQCN
# ❌ Bad
- copy:
    src: file.txt

# ✅ Good
- ansible.builtin.copy:
    src: file.txt

# no-changed-when - Commands should have changed_when
# ❌ Bad
- ansible.builtin.command: myapp --version

# ✅ Good
- ansible.builtin.command: myapp --version
  changed_when: false
```

---

## Vault for Secrets

### Encrypting Variables

```bash
# Encrypt a variable file
ansible-vault encrypt group_vars/prod/vault.yml

# Edit encrypted file
ansible-vault edit group_vars/prod/vault.yml

# Run playbook with vault
ansible-playbook site.yml --ask-vault-pass
ansible-playbook site.yml --vault-password-file ~/.vault_pass
```

### Vault Variable Pattern

```yaml
# group_vars/prod/vault.yml (encrypted)
vault_db_password: "s3cr3t_p@ssw0rd"
vault_api_key: "ak_prod_12345"

# group_vars/prod/vars.yml (references vault)
db_password: "{{ vault_db_password }}"
api_key: "{{ vault_api_key }}"
```

---

## Testing

### Playbook Dry Run

```bash
# Check mode (no changes)
ansible-playbook site.yml --check

# Check mode with diff
ansible-playbook site.yml --check --diff

# Limit to specific hosts
ansible-playbook site.yml --check --limit webservers
```

### Assert Module for Validation

```yaml
- name: Verify service is running
  ansible.builtin.service_facts:

- name: Assert nginx is running
  ansible.builtin.assert:
    that:
      - "'nginx.service' in ansible_facts.services"
      - "ansible_facts.services['nginx.service'].state == 'running'"
    fail_msg: "nginx service is not running"
```

### Molecule Testing

```bash
# Initialize molecule for a role
molecule init scenario -r my_role -d docker

# Run full test sequence
molecule test

# Individual steps
molecule create      # Create test instances
molecule converge    # Run playbook
molecule verify      # Run verification tests
molecule destroy     # Cleanup
```

**molecule.yml:**

```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: ubuntu2404
    image: geerlingguy/docker-ubuntu2404-ansible
    pre_build_image: true
  - name: fedora42
    image: fedora:42
    command: /sbin/init
    privileged: true
provisioner:
  name: ansible
verifier:
  name: ansible
```

**verify.yml:**

```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Check service is running
      ansible.builtin.service:
        name: myapp
        state: started
      check_mode: true
      register: service_check
      failed_when: service_check.changed
```

---

## Resources

- Ansible Documentation: <https://docs.ansible.com/>
- Ansible Lint: <https://ansible.readthedocs.io/projects/lint/>
- Good Practices for Ansible (Red Hat): <https://redhat-cop.github.io/automation-good-practices/>
- Ansible Best Practices Guide: <https://timgrt.github.io/Ansible-Best-Practices/>
- Molecule Testing: <https://molecule.readthedocs.io/>
- Ansible Style Guide (MET Norway): <https://github.com/metno/ansible-style-guide>

---

## For AI Code Assistants

The following sections are specific guidance for AI code assistants working with Ansible.

---

## AI Pitfalls to Avoid

**Before generating Ansible code, check these patterns:**

### DO NOT Generate

```yaml
# ❌ Missing FQCN (Fully Qualified Collection Name)
- name: Install package
  apt:
    name: nginx
# ✅ Always use FQCN
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
    state: present

# ❌ Unnamed tasks
- ansible.builtin.file:
    path: /etc/app
    state: directory
# ✅ Every task needs a descriptive name
- name: Create application config directory
  ansible.builtin.file:
    path: /etc/app
    state: directory
    mode: "0755"

# ❌ Missing mode on file operations
- name: Copy config
  ansible.builtin.copy:
    src: config.yml
    dest: /etc/app/config.yml
# ✅ Always specify mode
- name: Copy application config
  ansible.builtin.copy:
    src: config.yml
    dest: /etc/app/config.yml
    mode: "0644"
    owner: root
    group: root

# ❌ Non-idempotent shell/command
- name: Run setup
  ansible.builtin.shell: ./setup.sh
# ✅ Add creates/changed_when for idempotence
- name: Run initial setup
  ansible.builtin.shell: ./setup.sh
  args:
    creates: /etc/app/.setup_complete

# ❌ Using shell when command works
- name: List files
  ansible.builtin.shell: ls -la /etc/app
# ✅ Use command for simple operations
- name: List application directory
  ansible.builtin.command: ls -la /etc/app
  register: dir_listing
  changed_when: false

# ❌ Boolean conditions without filter
- name: Enable feature
  when: enable_feature  # May fail if string "false"
# ✅ Use bool filter
- name: Enable feature
  when: enable_feature | bool

# ❌ Variables without role prefix
vars:
  config_path: /etc/app  # Conflicts with other roles
# ✅ Prefix with role name
vars:
  myapp_config_path: /etc/app

# ❌ Hardcoded platform assumptions
- name: Install package
  ansible.builtin.apt:
    name: nginx
# ✅ Handle multiple platforms
- name: Install nginx (Debian/Ubuntu)
  ansible.builtin.apt:
    name: nginx
  when: ansible_os_family == 'Debian'

- name: Install nginx (RedHat/Fedora)
  ansible.builtin.dnf:
    name: nginx
  when: ansible_os_family == 'RedHat'
```

### Collection Verification

```yaml
# ❌ These may be hallucinations - verify on Galaxy:
- community.general.nonexistent_module:
- ansible.windows.fake_module:

# ✅ Well-known collections:
# ansible.builtin, ansible.posix, community.general
# community.docker, community.postgresql, amazon.aws
```

**Always run `ansible-lint` before accepting AI-generated Ansible code.**

---

## Mock-Aware Testing Policy (Production Playbooks)

Production Ansible code must be complete before committing.

❌ **NEVER:**

- Placeholder tasks (`# TODO: implement`)
- Hardcoded example values (`192.168.1.1`)
- Missing error handling (no `failed_when`, `retries`)
- Non-idempotent operations

✅ **ALWAYS:**

- Complete role with defaults, tasks, handlers
- Variables with role prefix
- Platform conditionals where needed
- Molecule tests for complex roles
- `ansible-lint` compliance
