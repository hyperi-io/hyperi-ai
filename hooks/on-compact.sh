#!/usr/bin/env bash
# Project:   HyperI AI
# File:      hooks/on-compact.sh
# Purpose:   Re-inject coding standards after context compaction
#
# License:   Proprietary
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# This script runs as a Claude Code SessionStart hook (matcher: compact).
# Its stdout is injected into Claude's context after compaction.
set -euo pipefail

# $CLAUDE_PROJECT_DIR is set by Claude Code to the parent project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
AI_DIR="${PROJECT_DIR}/ai"
UNIVERSAL="${AI_DIR}/standards/rules/UNIVERSAL.md"

# Preamble
cat << 'EOF'

---

## Context Recovery (Post-Compaction)

Context was compacted. Coding standards have been re-injected below.
**Run `/load` to restore full project state** (STATE.md, TODO.md, git sync).

---

EOF

# Re-inject all detected standards (UNIVERSAL + language/infra rules)
INJECT_SCRIPT="${AI_DIR}/hooks/inject-standards.sh"
if [ -x "$INJECT_SCRIPT" ]; then
    bash "$INJECT_SCRIPT"
else
    # Fallback: at minimum inject UNIVERSAL.md directly
    if [ -f "$UNIVERSAL" ]; then
        cat "$UNIVERSAL"
    else
        echo "WARNING: UNIVERSAL.md not found at ${UNIVERSAL}"
        echo "The ai/ submodule may not be initialised. Run /load manually."
    fi
fi

echo ""
echo "**Run \`/load\` now** to restore full project context (STATE.md, TODO.md, submodule updates)."
