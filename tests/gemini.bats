#!/usr/bin/env bats

# Load test helpers
load test_helper

setup() {
    # Run before each test
    setup_test_env
    # gemini.sh requires templates from install.sh
    cd "$TEST_SUBMODULE"
    ./ai/install.sh > /dev/null
}

teardown() {
    # Run after each test
    cleanup_test_env
}

@test "TC-G01: Basic setup creates .gemini dir and symlink" {
    run ./ai/gemini.sh

    [ "$status" -eq 0 ]
    [ -d ".gemini" ]
    [ -f ".gemini/settings.json" ]
    [ -f ".gemini/commands/local.md" ]
    [ -f ".gemini/commands/save.md" ]
    [ -L "GEMINI.md" ]
    [[ "$(readlink GEMINI.md)" == "STATE.md" ]]
}

@test "TC-G02: Fails if STATE.md is missing" {
    rm STATE.md
    run ./ai/gemini.sh

    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR: STATE.md not found" ]]
}

@test "TC-G03: Idempotent - safe to run twice" {
    # First run
    run ./ai/gemini.sh
    [ "$status" -eq 0 ]

    # Second run
    run ./ai/gemini.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipped (preserving existing):" ]]
    [[ "$output" =~ "Skipped (exists): ".*"GEMINI.md -> STATE.md" ]]
}

@test "TC-G04: Force flag overwrites settings.json" {
    ./ai/gemini.sh

    echo '{"model": "test"}' > .gemini/settings.json
    run ./ai/gemini.sh --force

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Deployed:" ]]
    grep -q "gemini-3-pro-preview" .gemini/settings.json
}

@test "TC-G05: Dry run shows actions without executing" {
    run ./ai/gemini.sh --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would create:" ]]
    [[ "$output" =~ "Would deploy:" ]]
    [[ "$output" =~ "Would create:".*"GEMINI.md -> STATE.md" ]]
    [ ! -d ".gemini" ]
    [ ! -L "GEMINI.md" ]
}

@test "TC-G06: Custom path deployment" {
    TMP_DIR="$(mktemp -d)"
    "$AI_SOURCE/install.sh" --path "$TMP_DIR" > /dev/null
    run "$AI_SOURCE/gemini.sh" --path "$TMP_DIR"

    [ "$status" -eq 0 ]
    [ -d "$TMP_DIR/.gemini" ]
    [ -L "$TMP_DIR/GEMINI.md" ]

    rm -rf "$TMP_DIR"
}

@test "TC-G07: Help flag shows usage" {
    run ./ai/gemini.sh --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

