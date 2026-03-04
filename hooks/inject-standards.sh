#!/usr/bin/env bash
# Project:   HyperI AI
# File:      hooks/inject-standards.sh
# Purpose:   Detect project technologies and inject matching coding standards
#
# License:   FSL-1.1-ALv2
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# Used as a Claude Code SessionStart hook (matcher: startup).
# Also called by on-compact.sh for post-compaction re-injection.
# Stdout is injected into Claude's context.
set -euo pipefail

# $CLAUDE_PROJECT_DIR is set by Claude Code to the parent project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
AI_DIR="${PROJECT_DIR}/ai"
RULES_DIR="${AI_DIR}/standards/rules"

# Bail out silently if the ai submodule is not initialised
if [ ! -d "$RULES_DIR" ]; then
    echo "WARNING: ai/standards/rules/ not found. The ai submodule may not be initialised."
    exit 0
fi

# --- UNIVERSAL rules (always) ---
if [ -f "$RULES_DIR/UNIVERSAL.md" ]; then
    cat "$RULES_DIR/UNIVERSAL.md"
    echo ""
fi

# --- Technology detection ---
# Check project root for marker files/dirs and inject matching rule files.
# Each rule is a compact standards file (44-173 lines).

inject_rule() {
    local rule_file="$RULES_DIR/$1"
    if [ -f "$rule_file" ]; then
        echo "---"
        echo ""
        cat "$rule_file"
        echo ""
    fi
}

cd "$PROJECT_DIR" || exit 0

# Python
if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f requirements.txt ] || [ -f uv.lock ]; then
    inject_rule "python.md"
fi

# Bash / Shell
# Use find with maxdepth 1 to avoid glob expansion issues with set -e
if find . -maxdepth 1 -name '*.sh' -o -name '*.bats' 2>/dev/null | grep -q .; then
    inject_rule "bash.md"
fi

# TypeScript / JavaScript
if [ -f tsconfig.json ] || [ -f package.json ]; then
    inject_rule "typescript.md"
fi

# Rust
if [ -f Cargo.toml ]; then
    inject_rule "rust.md"
fi

# Go
if [ -f go.mod ]; then
    inject_rule "golang.md"
fi

# C++
if [ -f CMakeLists.txt ]; then
    inject_rule "cpp.md"
fi

# Docker
if [ -f Dockerfile ] || [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
    inject_rule "docker.md"
fi

# Ansible
if [ -f ansible.cfg ] || find . -maxdepth 1 -name 'playbook*.yml' 2>/dev/null | grep -q . || [ -d playbooks ]; then
    inject_rule "ansible.md"
fi

# Kubernetes / Helm
if [ -f Chart.yaml ] || [ -f values.yaml ] || [ -d charts ]; then
    inject_rule "k8s.md"
fi

# Terraform
if find . -maxdepth 1 -name '*.tf' 2>/dev/null | grep -q .; then
    inject_rule "terraform.md"
fi

# ClickHouse SQL
if find . -maxdepth 1 -name '*.sql' 2>/dev/null | grep -q .; then
    inject_rule "clickhouse-sql.md"
fi

# PKI / TLS
if [ -d certs ] || [ -d ssl ] || [ -d pki ]; then
    inject_rule "pki.md"
fi
