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
}

@test "TC-001: Detects submodule mode" {
    cd "$TEST_SUBMODULE"
    run ./ai/install.sh --verbose

    [ "$status" -eq 0 ]
    [[ "$output" =~ "submodule" ]]
    [ -f "STATE.md" ]
    [ -f "TODO.md" ]
}

@test "TC-002: Detects clone mode" {
    cd "$TEST_CLONE"
    run ./ai/install.sh --verbose

    [ "$status" -eq 0 ]
    [[ "$output" =~ "clone" ]]
    [ -f "STATE.md" ]
    [ -f "TODO.md" ]
}

@test "TC-003: Detects standalone mode" {
    cd "$TEST_STANDALONE"
    run ./ai/install.sh --verbose

    [ "$status" -eq 0 ]
    [[ "$output" =~ "standalone" ]]
    [ -f "STATE.md" ]
    [ -f "TODO.md" ]
}

@test "TC-004: Idempotent - safe to run twice" {
    cd "$TEST_SUBMODULE"

    # First run
    run ./ai/install.sh
    [ "$status" -eq 0 ]

    # Second run
    run ./ai/install.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipped" ]]
}

@test "TC-005: Force flag overwrites files" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh

    echo "modified" >> STATE.md
    run ./ai/install.sh --force

    [ "$status" -eq 0 ]
    ! grep -q "modified" STATE.md
}

@test "TC-006: Dry run shows actions without executing" {
    cd "$TEST_SUBMODULE"
    run ./ai/install.sh --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would deploy" ]]
    [ ! -f "STATE.md" ]
}

@test "TC-007: Custom path deployment" {
    TMP_DIR="$(mktemp -d)"
    run "$AI_SOURCE/install.sh" --path "$TMP_DIR"

    [ "$status" -eq 0 ]
    [ -f "$TMP_DIR/STATE.md" ]
    [ -f "$TMP_DIR/TODO.md" ]

    rm -rf "$TMP_DIR"
}

@test "TC-008: Help flag shows usage" {
    run "$AI_SOURCE/install.sh" --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "TC-009: Invalid path returns error" {
    run "$AI_SOURCE/install.sh" --path /nonexistent/path/12345

    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR" ]]
}

@test "TC-010: Preserves existing files by default" {
    cd "$TEST_SUBMODULE"

    # First install
    ./ai/install.sh

    # Modify file
    echo "CUSTOM CONTENT" >> STATE.md

    # Second install (should skip)
    run ./ai/install.sh

    [ "$status" -eq 0 ]
    grep -q "CUSTOM CONTENT" STATE.md
    [[ "$output" =~ "Skipped" ]]
}
