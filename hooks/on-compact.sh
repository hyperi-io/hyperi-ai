#!/usr/bin/env bash
# Project:   HyperI AI
# File:      hooks/on-compact.sh
# Purpose:   Re-inject coding standards after Claude Code context compaction
#
# License:   FSL-1.1-ALv2
# Copyright: (c) 2026 HYPERI PTY LIMITED
#
# This script runs as a Claude Code SessionStart hook (matcher: compact).
# Its stdout is injected into Claude's context after compaction.
set -euo pipefail

# $CLAUDE_PROJECT_DIR is set by Claude Code to the parent project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
AI_DIR="${PROJECT_DIR}/ai"
QUICKSTART="${AI_DIR}/standards/STANDARDS-QUICKSTART.md"

# Preamble
cat << 'EOF'

---

## Context Recovery (Post-Compaction)

Context was compacted. Coding standards have been re-injected below.

**Run `/load` to restore full project state** (STATE.md, TODO.md, language-specific standards).

---

EOF

# Re-inject the full STANDARDS-QUICKSTART.md
if [ -f "$QUICKSTART" ]; then
    cat "$QUICKSTART"
else
    echo "WARNING: STANDARDS-QUICKSTART.md not found at ${QUICKSTART}"
    echo "The ai/ submodule may not be initialised. Run /load manually."
fi

# Dynamic git context
echo ""
echo "---"
echo ""
echo "## Current Git State"
echo ""

if command -v git >/dev/null 2>&1 && [ -d "${PROJECT_DIR}/.git" ]; then
    BRANCH="$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo 'unknown')"
    echo "Branch: \`${BRANCH}\`"
    echo ""
    echo "Recent commits:"
    echo '```'
    git -C "$PROJECT_DIR" log --oneline -5 2>/dev/null || echo "(unable to read git log)"
    echo '```'
else
    echo "(git state unavailable)"
fi

echo ""
echo "---"
echo ""
echo "**Run \`/load\` now** to restore full project context (STATE.md, TODO.md, language-specific standards)."
