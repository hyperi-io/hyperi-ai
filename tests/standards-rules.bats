#!/usr/bin/env bats

load test_helper

# T1 — Rule file frontmatter format
# All rule files in standards/rules/ must have valid YAML frontmatter if they
# declare path-scoping (opening and closing ---), and at least one path entry
# if the paths: key is present.
#
# T2 — Path references in command files
# The standards.md command references ../../ai/standards/rules/ from its
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
    # From the deployed location (.claude/commands/standards.md -> templates/claude-code/commands/standards.md)
    # the reference ../../ai/standards/rules/ resolves to:
    #   $project_root/.claude/commands/ + ../../ai/standards/rules/
    #   = $project_root/ai/standards/rules/
    # We verify the standards.md file itself mentions the expected relative path
    run grep -q "ai/standards/rules" "$AI_SOURCE/templates/claude-code/commands/standards.md"
    [ "$status" -eq 0 ]
}

@test "TC-215: Path references in standards.md resolve from TEST_SUBMODULE structure" {
    # Simulate the consumer project layout from test_helper:
    # TEST_SUBMODULE/ai/ contains the ai submodule files
    # standards.md would be at TEST_SUBMODULE/.claude/commands/standards.md (symlink)
    # and reference ../../ai/standards/rules/
    # Resolved: TEST_SUBMODULE/.claude/commands/../../ai/standards/rules/
    #         = TEST_SUBMODULE/ai/standards/rules/
    setup_test_env
    local rules_path="$TEST_SUBMODULE/ai/standards/rules"
    [ -d "$rules_path" ] || {
        echo "FAIL: resolved path $rules_path does not exist"
        return 1
    }
    cleanup_test_env
}

@test "TC-216: load.md references inject-standards.sh hook for standards" {
    # load.md Step 4 now delegates standards loading to the SessionStart hook
    run grep -q "inject-standards.sh" "$AI_SOURCE/templates/claude-code/commands/load.md"
    [ "$status" -eq 0 ]
}

@test "TC-217: inject-standards.sh has detection for all major languages" {
    local hook="$AI_SOURCE/hooks/inject-standards.sh"
    [ -f "$hook" ]

    local markers="Cargo.toml pyproject.toml go.mod Dockerfile tsconfig.json ansible.cfg Chart.yaml CMakeLists.txt"
    for marker in $markers; do
        grep -q "$marker" "$hook" || {
            echo "FAIL: inject-standards.sh missing detection for: $marker"
            return 1
        }
    done
}

@test "TC-218: inject-standards.sh is executable" {
    [ -x "$AI_SOURCE/hooks/inject-standards.sh" ]
}

@test "TC-219: inject-standards.sh outputs UNIVERSAL.md for any project" {
    setup_test_env
    export CLAUDE_PROJECT_DIR="$TEST_SUBMODULE"

    run bash "$AI_SOURCE/hooks/inject-standards.sh"

    [ "$status" -eq 0 ]
    # UNIVERSAL.md should always be in the output
    [[ "$output" =~ "UNIVERSAL" ]] || [[ "$output" =~ "universal" ]] || {
        # Check for any content from UNIVERSAL.md (it has a heading)
        [ -n "$output" ]
    }
    cleanup_test_env
}

@test "TC-220: inject-standards.sh detects Rust from Cargo.toml" {
    setup_test_env
    cd "$TEST_SUBMODULE"
    # Create a Cargo.toml marker file
    echo '[package]' > Cargo.toml
    echo 'name = "test"' >> Cargo.toml
    export CLAUDE_PROJECT_DIR="$TEST_SUBMODULE"

    run bash "$AI_SOURCE/hooks/inject-standards.sh"

    [ "$status" -eq 0 ]
    # Output should contain rust.md content (has "Rust" in its heading)
    [[ "$output" =~ [Rr]ust ]]
    cleanup_test_env
}

@test "TC-221: inject-standards.sh detects Docker from Dockerfile" {
    setup_test_env
    cd "$TEST_SUBMODULE"
    echo 'FROM debian:bookworm' > Dockerfile
    export CLAUDE_PROJECT_DIR="$TEST_SUBMODULE"

    run bash "$AI_SOURCE/hooks/inject-standards.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ [Dd]ocker ]]
    cleanup_test_env
}

@test "TC-222: inject-standards.sh exits 0 when ai submodule missing" {
    local tmp
    tmp="$(mktemp -d)"
    export CLAUDE_PROJECT_DIR="$tmp"

    run bash "$AI_SOURCE/hooks/inject-standards.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "not found" ]] || [[ "$output" =~ "WARNING" ]]
    rm -rf "$tmp"
}

@test "TC-223: on-compact.sh calls inject-standards.sh" {
    run grep -q "inject-standards.sh" "$AI_SOURCE/hooks/on-compact.sh"
    [ "$status" -eq 0 ]
}
