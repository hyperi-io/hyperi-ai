#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

@test "TC-201: Requires STATE.md (prerequisite check)" {
    cd "$TEST_SUBMODULE"
    run ./ai/cursor.sh

    [ "$status" -eq 1 ]
    [[ "$output" =~ "install.sh first" ]]
    [ ! -d ".cursor" ]
}

@test "TC-202: Full Cursor IDE setup" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh

    run ./ai/cursor.sh --verbose

    [ "$status" -eq 0 ]
    [ -d ".cursor" ]
    [ -f ".cursor/cli.json" ]
    [ -f ".cursor/rules/standards.mdc" ]
    [ -f ".cursor/rules/session-start.mdc" ]
    [ -f ".cursor/rules/session-save.mdc" ]
    [ -L "CURSOR.md" ]
    [ "$(readlink CURSOR.md)" = "STATE.md" ]
}

@test "TC-203: Idempotent - preserves cli.json" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh
    ./ai/cursor.sh

    # Modify cli.json
    echo '/* custom */' >> .cursor/cli.json

    # Run again
    run ./ai/cursor.sh

    [ "$status" -eq 0 ]
    grep -q "custom" .cursor/cli.json
}

@test "TC-204: Force flag overwrites cli.json" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh
    ./ai/cursor.sh

    echo '/* custom */' >> .cursor/cli.json
    run ./ai/cursor.sh --force

    [ "$status" -eq 0 ]
    ! grep -q "custom" .cursor/cli.json
}

@test "TC-205: Rules always updated (versioned)" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh
    ./ai/cursor.sh

    # Modify rule
    echo "OLD VERSION" > .cursor/rules/standards.mdc

    run ./ai/cursor.sh

    [ "$status" -eq 0 ]
    ! grep -q "OLD VERSION" .cursor/rules/standards.mdc
    grep -q "HyperSec Coding Standards" .cursor/rules/standards.mdc
}

@test "TC-206: Dry run preview" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh

    run ./ai/cursor.sh --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would" ]]
    [ ! -d ".cursor" ]
}

@test "TC-207: Help flag" {
    run "$AI_SOURCE/cursor.sh" --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "TC-208: Custom path" {
    TMP_DIR="$(mktemp -d)"
    "$AI_SOURCE/install.sh" --path "$TMP_DIR"

    run "$AI_SOURCE/cursor.sh" --path "$TMP_DIR"

    [ "$status" -eq 0 ]
    [ -d "$TMP_DIR/.cursor" ]

    rm -rf "$TMP_DIR"
}

