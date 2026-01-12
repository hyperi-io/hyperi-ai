#!/usr/bin/env bats

# Load test helpers
load test_helper

setup() {
    # Run before each test
    setup_test_env
}

teardown() {
    # Run after each test
    cleanup_test_env
    clear_mocks
}

@test "TC-001: Detects submodule mode" {
    cd "$TEST_SUBMODULE"
    run ./ai/attach.sh --verbose --no-agent

    [ "$status" -eq 0 ]
    [[ "$output" =~ "submodule" ]]
    [ -f "STATE.md" ]
    [ -f "TODO.md" ]
}

@test "TC-002: Detects clone mode" {
    cd "$TEST_CLONE"
    run ./ai/attach.sh --verbose --no-agent

    [ "$status" -eq 0 ]
    [[ "$output" =~ "clone" ]]
    [ -f "STATE.md" ]
    [ -f "TODO.md" ]
}

@test "TC-003: Detects standalone mode" {
    cd "$TEST_STANDALONE"
    run ./ai/attach.sh --verbose --no-agent

    [ "$status" -eq 0 ]
    [[ "$output" =~ "standalone" ]]
    [ -f "STATE.md" ]
    [ -f "TODO.md" ]
}

@test "TC-004: Idempotent - safe to run twice" {
    cd "$TEST_SUBMODULE"

    # First run
    run ./ai/attach.sh --no-agent
    [ "$status" -eq 0 ]

    # Second run
    run ./ai/attach.sh --no-agent
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipped" ]]
}

@test "TC-005: Force flag overwrites files" {
    cd "$TEST_SUBMODULE"
    ./ai/attach.sh --no-agent

    echo "modified" >> STATE.md
    run ./ai/attach.sh --force --no-agent

    [ "$status" -eq 0 ]
    ! grep -q "modified" STATE.md
}

@test "TC-006: Dry run shows actions without executing" {
    cd "$TEST_SUBMODULE"
    run ./ai/attach.sh --dry-run --no-agent

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would deploy" ]]
    [ ! -f "STATE.md" ]
}

@test "TC-007: Custom path deployment" {
    TMP_DIR="$(mktemp -d)"
    run "$AI_SOURCE/attach.sh" --path "$TMP_DIR" --no-agent

    [ "$status" -eq 0 ]
    [ -f "$TMP_DIR/STATE.md" ]
    [ -f "$TMP_DIR/TODO.md" ]

    rm -rf "$TMP_DIR"
}

@test "TC-008: Help flag shows usage" {
    run "$AI_SOURCE/attach.sh" --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "TC-009: Invalid path returns error" {
    run "$AI_SOURCE/attach.sh" --path /nonexistent/path/12345 --no-agent

    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR" ]]
}

@test "TC-010: Preserves existing files by default" {
    cd "$TEST_SUBMODULE"

    # First install
    ./ai/attach.sh --no-agent

    # Modify file
    echo "CUSTOM CONTENT" >> STATE.md

    # Second install (should skip)
    run ./ai/attach.sh --no-agent

    [ "$status" -eq 0 ]
    grep -q "CUSTOM CONTENT" STATE.md
    [[ "$output" =~ "Skipped" ]]
}

# New tests for agent detection

@test "TC-011: Auto-detection finds agent or warns if none" {
    cd "$TEST_SUBMODULE"
    ./ai/attach.sh --no-agent  # First deploy STATE.md

    run ./ai/attach.sh

    # Should succeed whether agents are found or not
    [ "$status" -eq 0 ]
    # Either configures an agent, warns about none found, or shows manual setup
    [[ "$output" =~ "Agent Detection" ]] || [[ "$output" =~ "No AI agent CLIs found" ]] || [[ "$output" =~ "Setup your AI assistant manually" ]]
}

@test "TC-012: --agent flag runs specific agent" {
    cd "$TEST_SUBMODULE"
    ./ai/attach.sh --no-agent
    mock_cli "claude"

    run ./ai/attach.sh --agent claude

    [ "$status" -eq 0 ]
    [ -d ".claude" ]
}

@test "TC-013: --no-agent skips agent detection" {
    cd "$TEST_SUBMODULE"
    mock_cli "claude"

    run ./ai/attach.sh --no-agent

    [ "$status" -eq 0 ]
    [ ! -d ".claude" ]
}

@test "TC-014: Deprecated --claude flag shows warning" {
    cd "$TEST_SUBMODULE"
    ./ai/attach.sh --no-agent
    mock_cli "claude"

    run ./ai/attach.sh --claude

    [ "$status" -eq 0 ]
    [[ "$output" =~ "deprecated" ]] || [[ "$output" =~ "DEPRECATED" ]]
    [ -d ".claude" ]
}

@test "TC-015: --copilot flag errors with migration message" {
    cd "$TEST_SUBMODULE"

    run ./ai/attach.sh --copilot

    [ "$status" -eq 1 ]
    [[ "$output" =~ "codex" ]]
}
