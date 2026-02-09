#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    mock_cli "agent"  # Mock Cursor CLI for all tests
}

teardown() {
    cleanup_test_env
    clear_mocks
}

@test "TC-201: Requires STATE.md (prerequisite check)" {
    cd "$TEST_SUBMODULE"
    run ./ai/agents/cursor.sh

    [ "$status" -eq 1 ]
    [[ "$output" =~ "attach.sh first" ]]
    [ ! -d ".cursor" ]
}

@test "TC-202: Full Cursor IDE setup" {
    cd "$TEST_SUBMODULE"
    ./ai/attach.sh --no-agent

    run ./ai/agents/cursor.sh --verbose

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
    ./ai/attach.sh --no-agent
    ./ai/agents/cursor.sh

    # Modify cli.json
    echo '/* custom */' >> .cursor/cli.json

    # Run again
    run ./ai/agents/cursor.sh

    [ "$status" -eq 0 ]
    grep -q "custom" .cursor/cli.json
}

@test "TC-204: Force flag overwrites cli.json" {
    cd "$TEST_SUBMODULE"
    ./ai/attach.sh --no-agent
    ./ai/agents/cursor.sh

    echo '/* custom */' >> .cursor/cli.json
    run ./ai/agents/cursor.sh --force

    [ "$status" -eq 0 ]
    ! grep -q "custom" .cursor/cli.json
}

@test "TC-205: Rules always updated (versioned)" {
    cd "$TEST_SUBMODULE"
    ./ai/attach.sh --no-agent
    ./ai/agents/cursor.sh

    # Modify rule
    echo "OLD VERSION" > .cursor/rules/standards.mdc

    run ./ai/agents/cursor.sh

    [ "$status" -eq 0 ]
    ! grep -q "OLD VERSION" .cursor/rules/standards.mdc
    grep -q "HyperI Coding Standards" .cursor/rules/standards.mdc
}

@test "TC-206: Dry run preview" {
    cd "$TEST_SUBMODULE"
    ./ai/attach.sh --no-agent

    run ./ai/agents/cursor.sh --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would" ]]
    [ ! -d ".cursor" ]
}

@test "TC-207: Help flag" {
    run "$AI_SOURCE/agents/cursor.sh" --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "TC-208: Custom path" {
    TMP_DIR="$(mktemp -d)"
    "$AI_SOURCE/attach.sh" --path "$TMP_DIR" --no-agent

    run "$AI_SOURCE/agents/cursor.sh" --path "$TMP_DIR"

    [ "$status" -eq 0 ]
    [ -d "$TMP_DIR/.cursor" ]

    rm -rf "$TMP_DIR"
}

@test "TC-209: Exit code 2 when CLI not installed" {
    cd "$TEST_SUBMODULE"
    ./ai/attach.sh --no-agent
    unmock_cli "agent"

    run ./ai/agents/cursor.sh

    [ "$status" -eq $EXIT_NOT_INSTALLED ]
    [[ "$output" =~ "not installed" ]]
}
