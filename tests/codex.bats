#!/usr/bin/env bats

# Load test helpers
load test_helper

setup() {
    # Run before each test
    setup_test_env
    mock_cli "codex"  # Mock Codex CLI for all tests
    # codex.sh requires templates from attach.sh
    cd "$TEST_SUBMODULE"
    ./ai/attach.sh --no-agent > /dev/null
}

teardown() {
    # Run after each test
    cleanup_test_env
    clear_mocks
}

@test "TC-C01: Basic setup creates .github/copilot-instructions.md and symlink" {
    run ./ai/agents/codex.sh

    [ "$status" -eq 0 ]
    [ -f ".github/copilot-instructions.md" ]
    [ -L "CODEX.md" ]
    [[ "$(readlink CODEX.md)" == "STATE.md" ]]
}

@test "TC-C02: Fails if STATE.md is missing" {
    rm STATE.md
    run ./ai/agents/codex.sh

    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR: STATE.md not found" ]]
}

@test "TC-C03: Idempotent - safe to run twice" {
    # First run
    run ./ai/agents/codex.sh
    [ "$status" -eq 0 ]

    # Second run
    run ./ai/agents/codex.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipped (preserving existing):" ]]
}

@test "TC-C04: Force flag overwrites copilot-instructions.md" {
    ./ai/agents/codex.sh

    echo '# CUSTOM' > .github/copilot-instructions.md
    run ./ai/agents/codex.sh --force

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Deployed:" ]]
    grep -q "HyperSec Coding Standards" .github/copilot-instructions.md
}

@test "TC-C05: Dry run shows actions without executing" {
    run ./ai/agents/codex.sh --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would create:" ]]
    [[ "$output" =~ "Would deploy:" ]]
    [ ! -f ".github/copilot-instructions.md" ]
    [ ! -L "CODEX.md" ]
}

@test "TC-C06: Custom path deployment" {
    TMP_DIR="$(mktemp -d)"
    "$AI_SOURCE/attach.sh" --path "$TMP_DIR" --no-agent > /dev/null
    run "$AI_SOURCE/agents/codex.sh" --path "$TMP_DIR"

    [ "$status" -eq 0 ]
    [ -f "$TMP_DIR/.github/copilot-instructions.md" ]
    [ -L "$TMP_DIR/CODEX.md" ]

    rm -rf "$TMP_DIR"
}

@test "TC-C07: Help flag shows usage" {
    run ./ai/agents/codex.sh --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "TC-C08: Exit code 2 when CLI not installed" {
    unmock_cli "codex"
    run ./ai/agents/codex.sh

    [ "$status" -eq $EXIT_NOT_INSTALLED ]
    [[ "$output" =~ "not installed" ]]
}

@test "TC-C09: Creates .github/skills directory" {
    run ./ai/agents/codex.sh

    [ "$status" -eq 0 ]
    [ -d ".github/skills" ]
}

@test "TC-C10: Creates standards skill" {
    run ./ai/agents/codex.sh

    [ "$status" -eq 0 ]
    [ -d ".github/skills/standards" ]
    [ -f ".github/skills/standards/SKILL.md" ]
}

@test "TC-C11: Creates .vscode directory" {
    run ./ai/agents/codex.sh

    [ "$status" -eq 0 ]
    [ -d ".vscode" ]
}
