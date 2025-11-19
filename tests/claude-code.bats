#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

@test "TC-101: Requires STATE.md (prerequisite check)" {
    cd "$TEST_SUBMODULE"
    run ./ai/claude-code.sh

    [ "$status" -eq 1 ]
    [[ "$output" =~ "install.sh first" ]]
    [ ! -d ".claude" ]
}

@test "TC-102: Full Claude Code setup" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh

    run ./ai/claude-code.sh --verbose

    [ "$status" -eq 0 ]
    [ -d ".claude" ]
    [ -f ".claude/settings.json" ]
    [ -f ".claude/commands/start.md" ]
    [ -f ".claude/commands/save.md" ]
    [ -L "CLAUDE.md" ]
    [ "$(readlink CLAUDE.md)" = "STATE.md" ]
}

@test "TC-103: Idempotent - preserves settings" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh
    ./ai/claude-code.sh

    # Modify settings
    echo '/* custom */' >> .claude/settings.json

    # Run again
    run ./ai/claude-code.sh

    [ "$status" -eq 0 ]
    grep -q "custom" .claude/settings.json
}

@test "TC-104: Force flag overwrites settings" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh
    ./ai/claude-code.sh

    echo '/* custom */' >> .claude/settings.json
    run ./ai/claude-code.sh --force

    [ "$status" -eq 0 ]
    ! grep -q "custom" .claude/settings.json
}

@test "TC-105: Commands always updated (versioned)" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh
    ./ai/claude-code.sh

    # Modify command
    echo "OLD VERSION" > .claude/commands/start.md

    run ./ai/claude-code.sh

    [ "$status" -eq 0 ]
    ! grep -q "OLD VERSION" .claude/commands/start.md
    grep -q "Read critical documentation" .claude/commands/start.md
}

@test "TC-106: Dry run preview" {
    cd "$TEST_SUBMODULE"
    ./ai/install.sh

    run ./ai/claude-code.sh --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would" ]]
    [ ! -d ".claude" ]
}

@test "TC-107: Help flag" {
    run "$AI_SOURCE/claude-code.sh" --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "TC-108: Custom path" {
    TMP_DIR="$(mktemp -d)"
    "$AI_SOURCE/install.sh" --path "$TMP_DIR"

    run "$AI_SOURCE/claude-code.sh" --path "$TMP_DIR"

    [ "$status" -eq 0 ]
    [ -d "$TMP_DIR/.claude" ]

    rm -rf "$TMP_DIR"
}
