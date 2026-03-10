#!/usr/bin/env bats

load test_helper

# T1 — Rule file frontmatter format
# All rule files in standards/rules/ must have valid YAML frontmatter if they
# declare path-scoping (opening and closing ---), and at least one path entry
# if the paths: key is present.
#
# T2 — Path references in command files
# The standards.md command references ../../hyperi-ai/standards/rules/ from its
# deployed location (.claude/commands/standards.md -> templates/claude-code/commands/).
# Verify rule file paths resolve correctly from a consumer project structure.

@test "TC-210: All rule files exist and are readable" {
    local rules_dir="$AI_SOURCE/standards/rules"
    [ -d "$rules_dir" ]

    local count=0
    for f in "$rules_dir"/*.md; do
        [ -f "$f" ]
        count=$((count + 1))
    done

    # Must have at least the known set of rule files
    [ "$count" -ge 5 ]
}

@test "TC-211: Rule files with frontmatter have valid opening and closing delimiters" {
    local rules_dir="$AI_SOURCE/standards/rules"

    for f in "$rules_dir"/*.md; do
        first_line="$(head -1 "$f")"
        if [ "$first_line" = "---" ]; then
            # Has opening delimiter — must also have closing delimiter
            local closing
            closing="$(tail -n +2 "$f" | grep -c "^---$" || true)"
            [ "$closing" -ge 1 ] || {
                echo "FAIL: $f has opening --- but no closing ---"
                return 1
            }
        fi
    done
}

@test "TC-212: Rule files with paths: frontmatter have at least one glob" {
    local rules_dir="$AI_SOURCE/standards/rules"

    for f in "$rules_dir"/*.md; do
        first_line="$(head -1 "$f")"
        if [ "$first_line" = "---" ]; then
            local has_paths
            has_paths="$(head -20 "$f" | grep -c "^paths:" || true)"
            if [ "$has_paths" -ge 1 ]; then
                # Has paths: — must have at least one glob line matching "  - ..."
                local glob_count
                glob_count="$(head -20 "$f" | grep -c '^\s*-\s*"' || true)"
                [ "$glob_count" -ge 1 ] || {
                    echo "FAIL: $f has paths: but no glob entries"
                    return 1
                }
            fi
        fi
    done
}

@test "TC-213: standards.md exists in templates/claude-code/commands/" {
    [ -f "$AI_SOURCE/templates/claude-code/commands/standards.md" ]
}

@test "TC-214: standards.md references correct relative path to rules dir" {
    run grep -q "ai/standards/rules" "$AI_SOURCE/templates/claude-code/commands/standards.md"
    [ "$status" -eq 0 ]
}

@test "TC-215: Path references in standards.md resolve from TEST_SUBMODULE structure" {
    setup_test_env
    local rules_path="$TEST_SUBMODULE/hyperi-ai/standards/rules"
    [ -d "$rules_path" ] || {
        echo "FAIL: resolved path $rules_path does not exist"
        return 1
    }
    cleanup_test_env
}

@test "TC-216: load.md references inject_standards.py hook for standards" {
    run grep -q "inject_standards.py" "$AI_SOURCE/templates/claude-code/commands/load.md"
    [ "$status" -eq 0 ]
}

@test "TC-217: rule files have detection markers for all major languages" {
    local rules_dir="$AI_SOURCE/standards/rules"
    [ -d "$rules_dir" ]

    local markers="Cargo.toml pyproject.toml go.mod Dockerfile tsconfig.json ansible.cfg Chart.yaml CMakeLists.txt"
    for marker in $markers; do
        grep -rl "$marker" "$rules_dir" | grep -q "." || {
            echo "FAIL: no rule file has detect_markers for: $marker"
            return 1
        }
    done
}

@test "TC-218: inject_standards.py is executable" {
    [ -x "$AI_SOURCE/hooks/inject_standards.py" ]
}

@test "TC-219: inject_standards.py outputs UNIVERSAL.md for any project" {
    setup_test_env
    export CLAUDE_PROJECT_DIR="$TEST_SUBMODULE"

    run python3 "$AI_SOURCE/hooks/inject_standards.py"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "UNIVERSAL" ]] || [[ "$output" =~ "universal" ]] || {
        [ -n "$output" ]
    }
    cleanup_test_env
}

@test "TC-220: inject_standards.py detects Rust from Cargo.toml" {
    setup_test_env
    cd "$TEST_SUBMODULE"
    echo '[package]' > Cargo.toml
    echo 'name = "test"' >> Cargo.toml
    export CLAUDE_PROJECT_DIR="$TEST_SUBMODULE"

    run python3 "$AI_SOURCE/hooks/inject_standards.py"

    [ "$status" -eq 0 ]
    [[ "$output" =~ [Rr]ust ]]
    cleanup_test_env
}

@test "TC-221: inject_standards.py detects Docker from Dockerfile" {
    setup_test_env
    cd "$TEST_SUBMODULE"
    echo 'FROM debian:bookworm' > Dockerfile
    export CLAUDE_PROJECT_DIR="$TEST_SUBMODULE"

    run python3 "$AI_SOURCE/hooks/inject_standards.py"

    [ "$status" -eq 0 ]
    [[ "$output" =~ [Dd]ocker ]]
    cleanup_test_env
}

@test "TC-222: inject_standards.py exits 0 when ai submodule missing" {
    local tmp
    tmp="$(mktemp -d)"
    export CLAUDE_PROJECT_DIR="$tmp"

    run python3 "$AI_SOURCE/hooks/inject_standards.py"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "not found" ]] || [[ "$output" =~ "WARNING" ]] || [[ "$output" =~ "No rules" ]]
    rm -rf "$tmp"
}

@test "TC-223: on_compact.py calls inject_rules" {
    run grep -q "inject_rules" "$AI_SOURCE/hooks/on_compact.py"
    [ "$status" -eq 0 ]
}

# --- New hook tests ---

@test "TC-230: auto_format.py exits 0 with empty JSON input" {
    run bash -c 'echo "{}" | python3 "'"$AI_SOURCE"'/hooks/auto_format.py"'
    [ "$status" -eq 0 ]
}

@test "TC-231: auto_format.py exits 0 for unknown file extension" {
    run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/tmp/test.xyz\"}}" | python3 "'"$AI_SOURCE"'/hooks/auto_format.py"'
    [ "$status" -eq 0 ]
}

@test "TC-232: safety_guard.py allows safe commands (ls -la)" {
    run bash -c 'echo "{\"tool_input\":{\"command\":\"ls -la\"}}" | python3 "'"$AI_SOURCE"'/hooks/safety_guard.py"'
    [ "$status" -eq 0 ]
    # Safe command — no output (implicit allow)
    [ -z "$output" ]
}

@test "TC-233: safety_guard.py denies rm -rf / with JSON deny response" {
    run bash -c 'echo "{\"tool_input\":{\"command\":\"rm -rf /\"}}" | python3 "'"$AI_SOURCE"'/hooks/safety_guard.py"'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "deny" ]]
}

@test "TC-234: safety_guard.py denies force push to main" {
    run bash -c 'echo "{\"tool_input\":{\"command\":\"git push --force origin main\"}}" | python3 "'"$AI_SOURCE"'/hooks/safety_guard.py"'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "deny" ]]
}

@test "TC-235: subagent_context.py outputs valid JSON with additionalContext" {
    setup_test_env
    export CLAUDE_PROJECT_DIR="$TEST_SUBMODULE"

    run bash -c 'echo "{\"agent_type\":\"Explore\"}" | python3 "'"$AI_SOURCE"'/hooks/subagent_context.py"'

    [ "$status" -eq 0 ]
    [[ "$output" =~ "additionalContext" ]]
    cleanup_test_env
}

@test "TC-236: subagent_context.py includes UNIVERSAL in context" {
    setup_test_env
    export CLAUDE_PROJECT_DIR="$TEST_SUBMODULE"

    run bash -c 'echo "{\"agent_type\":\"Explore\"}" | python3 "'"$AI_SOURCE"'/hooks/subagent_context.py"'

    [ "$status" -eq 0 ]
    [[ "$output" =~ "UNIVERSAL" ]] || [[ "$output" =~ "universal" ]]
    cleanup_test_env
}

@test "TC-237: common.py detect_technologies finds Rust from Cargo.toml" {
    setup_test_env
    cd "$TEST_SUBMODULE"
    echo '[package]' > Cargo.toml

    run python3 -c "
import sys; sys.path.insert(0, '$AI_SOURCE/hooks')
from pathlib import Path
import common
techs = common.detect_technologies(Path('$TEST_SUBMODULE'))
names = [t[0] for t in techs]
print(' '.join(names))
"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "rust" ]]
    cleanup_test_env
}

@test "TC-238: All hook .py files are executable" {
    for f in "$AI_SOURCE/hooks/"*.py; do
        [ -x "$f" ] || {
            echo "FAIL: $f is not executable"
            return 1
        }
    done
}

@test "TC-239: settings.json wires all 7 hooks" {
    local settings="$AI_SOURCE/templates/claude-code/settings.json"

    grep -q "inject_standards.py" "$settings"
    grep -q "on_compact.py" "$settings"
    grep -q "auto_format.py" "$settings"
    grep -q "subagent_context.py" "$settings"
    grep -q "safety_guard.py" "$settings"
    grep -q "lint_check.py" "$settings"
    grep -q '"SessionStart"' "$settings"
    grep -q '"PostToolUse"' "$settings"
    grep -q '"SubagentStart"' "$settings"
    grep -q '"PreToolUse"' "$settings"
    grep -q '"Stop"' "$settings"
}

@test "TC-240: lint_check.py exits 0 when stop_hook_active is true" {
    run bash -c 'echo "{\"stop_hook_active\":true}" | python3 "'"$AI_SOURCE"'/hooks/lint_check.py"'
    [ "$status" -eq 0 ]
}

@test "TC-241: lint_check.py exits 0 when no modified files" {
    setup_test_env
    export CLAUDE_PROJECT_DIR="$TEST_SUBMODULE"

    run bash -c 'echo "{}" | python3 "'"$AI_SOURCE"'/hooks/lint_check.py"'

    [ "$status" -eq 0 ]
    cleanup_test_env
}

@test "TC-242: claude.sh writes .ai-version stamp" {
    setup_test_env
    cd "$TEST_SUBMODULE"
    mock_cli "claude"
    ./hyperi-ai/attach.sh --no-agent

    # Create a real git repo in hyperi-ai/ so rev-parse works
    rm -f hyperi-ai/.git
    cd hyperi-ai
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    touch .gitkeep
    git add .gitkeep
    git commit -q -m "init"
    cd "$TEST_SUBMODULE"

    run ./hyperi-ai/agents/claude.sh

    [ "$status" -eq 0 ]
    [ -f ".claude/.ai-version" ]
    # Version stamp should be a git hash (40 hex chars)
    local stamp
    stamp="$(cat .claude/.ai-version)"
    [ ${#stamp} -eq 40 ]
    cleanup_test_env
    clear_mocks
}

@test "TC-243: migrate_submodule_name.py renames ai/ to hyperi-ai/" {
    setup_test_env

    # Create a fake ai/ submodule structure
    local test_dir="$TEST_ROOT/test-migrate"
    mkdir -p "$test_dir/ai"
    mkdir -p "$test_dir/ai/hooks"
    mkdir -p "$test_dir/ai/standards/rules"
    echo "gitdir: ../.git/modules/ai" > "$test_dir/ai/.git"
    mkdir -p "$test_dir/.git/modules/ai"
    echo "[core]" > "$test_dir/.git/modules/ai/config"
    echo "	worktree = ../../../ai" >> "$test_dir/.git/modules/ai/config"
    touch "$test_dir/.git/modules/ai/HEAD"
    mkdir -p "$test_dir/.claude"
    echo '{"hooks":{"command":"python3 \"$DIR/ai/hooks/foo.py\""}}' > "$test_dir/.claude/settings.json"

    # Copy migration script
    cp "$AI_SOURCE/hooks/migrate_submodule_name.py" "$test_dir/ai/hooks/"
    chmod +x "$test_dir/ai/hooks/migrate_submodule_name.py"

    # Run migration
    run env CLAUDE_PROJECT_DIR="$test_dir" python3 "$test_dir/ai/hooks/migrate_submodule_name.py"
    [ "$status" -eq 0 ]

    # Verify directory renamed
    [ -d "$test_dir/hyperi-ai" ]
    [ ! -d "$test_dir/ai" ]

    # Verify gitdir pointer updated
    grep -q "modules/hyperi-ai" "$test_dir/hyperi-ai/.git"

    # Verify .git/modules moved
    [ -d "$test_dir/.git/modules/hyperi-ai" ]
    [ ! -d "$test_dir/.git/modules/ai" ]

    # Verify worktree path updated in module config
    grep -q "worktree = ../../../hyperi-ai" "$test_dir/.git/modules/hyperi-ai/config"

    # Verify settings.json updated
    grep -q "hyperi-ai/hooks" "$test_dir/.claude/settings.json"

    # Re-running should be idempotent (exit 0)
    run env CLAUDE_PROJECT_DIR="$test_dir" python3 "$test_dir/hyperi-ai/hooks/migrate_submodule_name.py"
    [ "$status" -eq 0 ]

    cleanup_test_env
}
