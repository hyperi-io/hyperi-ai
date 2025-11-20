#!/usr/bin/env bats

# Load test helpers
load test_helper

setup() {
    # Run before each test
    setup_test_env
    # copilot.sh requires templates from install.sh
    cd "$TEST_SUBMODULE"
    ./ai/install.sh > /dev/null
}

teardown() {
    # Run after each test
    cleanup_test_env
}

@test "TC-P01: Basic setup creates .github/copilot-instructions.md and symlink" {
    run ./ai/copilot.sh

    [ "$status" -eq 0 ]
    [ -f ".github/copilot-instructions.md" ]
    [ -L "COPILOT.md" ]
    [[ "$(readlink COPILOT.md)" == "STATE.md" ]]
}

@test "TC-P02: Fails if STATE.md is missing" {
    rm STATE.md
    run ./ai/copilot.sh

    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR: STATE.md not found" ]]
}

@test "TC-P03: Idempotent - safe to run twice" {
    # First run
    run ./ai/copilot.sh
    [ "$status" -eq 0 ]

    # Second run
    run ./ai/copilot.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipped (preserving existing):" ]]
    [[ "$output" =~ "Skipped (exists): ".*"COPILOT.md -> STATE.md" ]]
}

@test "TC-P04: Force flag overwrites copilot-instructions.md" {
    ./ai/copilot.sh

    echo '# CUSTOM' > .github/copilot-instructions.md
    run ./ai/copilot.sh --force

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Deployed:" ]]
    grep -q "HyperSec Coding Standards" .github/copilot-instructions.md
}

@test "TC-P05: Dry run shows actions without executing" {
    run ./ai/copilot.sh --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would create:" ]]
    [[ "$output" =~ "Would deploy:" ]]
    [[ "$output" =~ "Would create:".*"COPILOT.md -> STATE.md" ]]
    [ ! -f ".github/copilot-instructions.md" ]
    [ ! -L "COPILOT.md" ]
}

@test "TC-P06: Custom path deployment" {
    TMP_DIR="$(mktemp -d)"
    "$AI_SOURCE/install.sh" --path "$TMP_DIR" > /dev/null
    run "$AI_SOURCE/copilot.sh" --path "$TMP_DIR"

    [ "$status" -eq 0 ]
    [ -f "$TMP_DIR/.github/copilot-instructions.md" ]
    [ -L "$TMP_DIR/COPILOT.md" ]

    rm -rf "$TMP_DIR"
}

@test "TC-P07: Help flag shows usage" {
    run ./ai/copilot.sh --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "TC-P08: Instructions always updated on force" {
    ./ai/copilot.sh

    # Modify instructions
    echo "OLD VERSION" > .github/copilot-instructions.md

    run ./ai/copilot.sh --force

    [ "$status" -eq 0 ]
    ! grep -q "OLD VERSION" .github/copilot-instructions.md
    grep -q "HyperSec Coding Standards" .github/copilot-instructions.md
}
