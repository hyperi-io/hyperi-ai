#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    mock_cli "claude"  # Mock claude CLI for all tests
}

teardown() {
    cleanup_test_env
    clear_mocks
}

@test "TC-101: Requires STATE.md (prerequisite check)" {
    cd "$TEST_SUBMODULE"
    run ./hyperi-ai/agents/claude.sh

    [ "$status" -eq 1 ]
    [[ "$output" =~ "attach.sh first" ]]
    [ ! -d ".claude" ]
}

@test "TC-102: Full Claude Code setup" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    run ./hyperi-ai/agents/claude.sh --verbose

    [ "$status" -eq 0 ]
    [ -d ".claude" ]
    [ -d ".claude/memory" ]
    [ -f ".claude/settings.json" ]
    [ -f ".claude/commands/load.md" ]
    [ -f ".claude/commands/save.md" ]
    [ -L "CLAUDE.md" ]
    [ "$(readlink CLAUDE.md)" = "STATE.md" ]
}

@test "TC-103: Idempotent - preserves settings" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    ./hyperi-ai/agents/claude.sh

    # Modify settings
    echo '/* custom */' >> .claude/settings.json

    # Run again
    run ./hyperi-ai/agents/claude.sh

    [ "$status" -eq 0 ]
    grep -q "custom" .claude/settings.json
}

@test "TC-104: Force flag overwrites settings" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    ./hyperi-ai/agents/claude.sh

    # Break the symlink and replace with a modified real file
    rm .claude/settings.json
    echo '/* custom */' > .claude/settings.json
    run ./hyperi-ai/agents/claude.sh --force

    [ "$status" -eq 0 ]
    ! grep -q "custom" .claude/settings.json
}

@test "TC-105: Commands always updated (versioned)" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    ./hyperi-ai/agents/claude.sh

    # Break the symlink and replace with stale content
    rm .claude/commands/load.md
    echo "OLD VERSION" > .claude/commands/load.md

    run ./hyperi-ai/agents/claude.sh

    [ "$status" -eq 0 ]
    ! grep -q "OLD VERSION" .claude/commands/load.md
    grep -q "Load Session" .claude/commands/load.md
}

@test "TC-106: Dry run preview" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent

    run ./hyperi-ai/agents/claude.sh --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would" ]]
    [ ! -d ".claude" ]
}

@test "TC-107: Help flag" {
    run "$AI_SOURCE/agents/claude.sh" --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "TC-108: Custom path" {
    TMP_DIR="$(mktemp -d)"
    "$AI_SOURCE/attach.sh" --path "$TMP_DIR" --no-agent

    run "$AI_SOURCE/agents/claude.sh" --path "$TMP_DIR"

    [ "$status" -eq 0 ]
    [ -d "$TMP_DIR/.claude" ]

    rm -rf "$TMP_DIR"
}

@test "TC-110: standards.md command is deployed" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    run ./hyperi-ai/agents/claude.sh --verbose

    [ "$status" -eq 0 ]
    [ -f ".claude/commands/standards.md" ]
}

@test "TC-111: common.py contains tech detection markers" {
    run grep -q "Cargo.toml" "$AI_SOURCE/hooks/common.py"
    [ "$status" -eq 0 ]

    run grep -q "pyproject.toml" "$AI_SOURCE/hooks/common.py"
    [ "$status" -eq 0 ]

    run grep -q "go.mod" "$AI_SOURCE/hooks/common.py"
    [ "$status" -eq 0 ]

    run grep -q "Dockerfile" "$AI_SOURCE/hooks/common.py"
    [ "$status" -eq 0 ]

    run grep -q "tsconfig.json" "$AI_SOURCE/hooks/common.py"
    [ "$status" -eq 0 ]
}

@test "TC-112: settings.json allows SlashCommand /standards" {
    run grep -q "SlashCommand(/standards)" "$AI_SOURCE/templates/claude-code/settings.json"
    [ "$status" -eq 0 ]
}

@test "TC-113: settings.json wires SessionStart startup hook" {
    run grep -q "inject_standards.py" "$AI_SOURCE/templates/claude-code/settings.json"
    [ "$status" -eq 0 ]

    run grep -q '"startup"' "$AI_SOURCE/templates/claude-code/settings.json"
    [ "$status" -eq 0 ]
}

@test "TC-114: settings.json wires Stop hook (lint_check.py)" {
    run grep -q "lint_check.py" "$AI_SOURCE/templates/claude-code/settings.json"
    [ "$status" -eq 0 ]

    run grep -q '"Stop"' "$AI_SOURCE/templates/claude-code/settings.json"
    [ "$status" -eq 0 ]
}

@test "TC-115: settings.json wires SubagentStart hook" {
    run grep -q "subagent_context.py" "$AI_SOURCE/templates/claude-code/settings.json"
    [ "$status" -eq 0 ]

    run grep -q '"SubagentStart"' "$AI_SOURCE/templates/claude-code/settings.json"
    [ "$status" -eq 0 ]
}

@test "TC-116: settings.json wires PreToolUse Bash hook" {
    run grep -q "safety_guard.py" "$AI_SOURCE/templates/claude-code/settings.json"
    [ "$status" -eq 0 ]

    run grep -q '"PreToolUse"' "$AI_SOURCE/templates/claude-code/settings.json"
    [ "$status" -eq 0 ]
}

@test "TC-109: Exit code 2 when CLI not installed" {
    cd "$TEST_SUBMODULE"
    ./hyperi-ai/attach.sh --no-agent
    unmock_cli "claude"

    # Use a restricted PATH so a system-installed claude is not found
    run env PATH="$TEST_ROOT/mock-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        ./hyperi-ai/agents/claude.sh

    [ "$status" -eq $EXIT_NOT_INSTALLED ]
    [[ "$output" =~ "not installed" ]]
}
