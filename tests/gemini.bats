#!/usr/bin/env bats

# Load test helpers
load test_helper

setup() {
    # Run before each test
    setup_test_env
    mock_cli "gemini"  # Mock Gemini CLI for all tests
    # gemini.sh requires templates from attach.sh
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent > /dev/null
}

teardown() {
    # Run after each test
    cleanup_test_env
    clear_mocks
}

@test "TC-G01: Basic setup creates .gemini dir and symlink" {
    run ./hyperi-ai/agents/gemini.sh

    [ "$status" -eq 0 ]
    [ -d ".gemini" ]
    [ -f ".gemini/settings.json" ]
    [ -f ".gemini/commands/load.md" ]
    [ -f ".gemini/commands/save.md" ]
    [ -L "GEMINI.md" ]
    [[ "$(readlink GEMINI.md)" == "STATE.md" ]]
}

@test "TC-G02: Fails if STATE.md is missing" {
    rm STATE.md
    run ./hyperi-ai/agents/gemini.sh

    [ "$status" -eq 1 ]
    [[ "$output" =~ "attach.sh first" ]]
}

@test "TC-G03: Idempotent - safe to run twice" {
    # First run
    run ./hyperi-ai/agents/gemini.sh
    [ "$status" -eq 0 ]

    # Second run
    run ./hyperi-ai/agents/gemini.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipped (preserving existing):" ]]
    [[ "$output" =~ "Skipped (exists): ".*"GEMINI.md -> STATE.md" ]]
}

@test "TC-G04: Force flag overwrites settings.json" {
    ./hyperi-ai/agents/gemini.sh

    echo '{"model": "test"}' > .gemini/settings.json
    run ./hyperi-ai/agents/gemini.sh --force

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Deployed:" ]]
    grep -q "STANDARDS" .gemini/settings.json
}

@test "TC-G05: Dry run shows actions without executing" {
    run ./hyperi-ai/agents/gemini.sh --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would create:" ]]
    [[ "$output" =~ "Would deploy:" ]]
    [[ "$output" =~ "Would create:".*"GEMINI.md -> STATE.md" ]]
    [ ! -d ".gemini" ]
    [ ! -L "GEMINI.md" ]
}

@test "TC-G06: Custom path deployment" {
    TMP_DIR="$(mktemp -d)"
    "$AI_SOURCE/attach.sh" --path "$TMP_DIR" --no-agent > /dev/null
    run "$AI_SOURCE/agents/gemini.sh" --path "$TMP_DIR"

    [ "$status" -eq 0 ]
    [ -d "$TMP_DIR/.gemini" ]
    [ -L "$TMP_DIR/GEMINI.md" ]

    rm -rf "$TMP_DIR"
}

@test "TC-G07: Help flag shows usage" {
    run ./hyperi-ai/agents/gemini.sh --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "TC-G08: Exit code 2 when CLI not installed" {
    unmock_cli "gemini"
    run ./hyperi-ai/agents/gemini.sh

    [ "$status" -eq $EXIT_NOT_INSTALLED ]
    [[ "$output" =~ "not installed" ]]
}
