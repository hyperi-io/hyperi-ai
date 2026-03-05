#!/usr/bin/env bash

# Test environment paths
# Use TMPDIR for CI compatibility, /projects/ai for local development
if [ -d "/projects/ai" ]; then
    # Local development
    export TEST_ROOT="/projects/ai-test"
    export AI_SOURCE="/projects/ai"
else
    # CI environment
    export TEST_ROOT="${TMPDIR:-/tmp}/ai-test"
    _script_dir="$(dirname "${BASH_SOURCE[0]}")"
    export AI_SOURCE="$(cd "$_script_dir/.." && pwd)"
fi
export TEST_SUBMODULE="$TEST_ROOT/test-submodule"
export TEST_CLONE="$TEST_ROOT/test-clone"
export TEST_STANDALONE="$TEST_ROOT/test-standalone"

# Exit codes (must match agents/common.sh)
export EXIT_SUCCESS=0
export EXIT_ERROR=1
export EXIT_NOT_INSTALLED=2

setup_test_env() {
    # Clean up old tests
    rm -rf "$TEST_ROOT"
    mkdir -p "$TEST_ROOT"

    # Setup submodule test
    mkdir -p "$TEST_SUBMODULE"
    cd "$TEST_SUBMODULE"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create hyperi-ai/ directory first, then .git file (simulates submodule)
    mkdir -p "$TEST_SUBMODULE/hyperi-ai"
    mkdir -p "$TEST_SUBMODULE/hyperi-ai/agents"
    echo "gitdir: ../.git/modules/hyperi-ai" > "$TEST_SUBMODULE/hyperi-ai/.git" 2>/dev/null || true
    cp -r "$AI_SOURCE"/{attach.sh,standards,templates,hooks} "$TEST_SUBMODULE/hyperi-ai/" 2>/dev/null || true
    cp -r "$AI_SOURCE"/agents/*.sh "$TEST_SUBMODULE/hyperi-ai/agents/" 2>/dev/null || true
    chmod +x "$TEST_SUBMODULE/hyperi-ai/attach.sh" "$TEST_SUBMODULE/hyperi-ai/agents/"*.sh "$TEST_SUBMODULE/hyperi-ai/hooks/"*.py 2>/dev/null || true

    # Setup clone test
    mkdir -p "$TEST_CLONE/hyperi-ai"
    mkdir -p "$TEST_CLONE/hyperi-ai/agents"
    cp -r "$AI_SOURCE"/{attach.sh,standards,templates,hooks} "$TEST_CLONE/hyperi-ai/"
    cp -r "$AI_SOURCE"/agents/*.sh "$TEST_CLONE/hyperi-ai/agents/" 2>/dev/null || true
    chmod +x "$TEST_CLONE/hyperi-ai/attach.sh" "$TEST_CLONE/hyperi-ai/agents/"*.sh "$TEST_CLONE/hyperi-ai/hooks/"*.py 2>/dev/null || true
    # Create .git directory (simulates clone)
    mkdir -p "$TEST_CLONE/hyperi-ai/.git"

    # Setup standalone test
    mkdir -p "$TEST_STANDALONE/hyperi-ai"
    mkdir -p "$TEST_STANDALONE/hyperi-ai/agents"
    cp -r "$AI_SOURCE"/{attach.sh,standards,templates,hooks} "$TEST_STANDALONE/hyperi-ai/" 2>/dev/null || true
    cp -r "$AI_SOURCE"/agents/*.sh "$TEST_STANDALONE/hyperi-ai/agents/" 2>/dev/null || true
    chmod +x "$TEST_STANDALONE/hyperi-ai/attach.sh" "$TEST_STANDALONE/hyperi-ai/agents/"*.sh "$TEST_STANDALONE/hyperi-ai/hooks/"*.py 2>/dev/null || true
    # No .git (simulates unzipped)
}

cleanup_test_env() {
    # Optional: clean up after tests
    # Commented out to allow inspection after failures
    # rm -rf "$TEST_ROOT"
    :
}

# Mock CLI commands for testing agent detection
# Creates fake CLI binaries in a temp directory and adds to PATH
mock_cli() {
    local cli_name="$1"
    local mock_dir="$TEST_ROOT/mock-bin"
    mkdir -p "$mock_dir"
    echo '#!/bin/bash' > "$mock_dir/$cli_name"
    echo "echo \"mock $cli_name\"" >> "$mock_dir/$cli_name"
    chmod +x "$mock_dir/$cli_name"
    export PATH="$mock_dir:$PATH"
}

# Remove mocked CLI
unmock_cli() {
    local cli_name="$1"
    local mock_dir="$TEST_ROOT/mock-bin"
    rm -f "$mock_dir/$cli_name"
}

# Clear all mocked CLIs
clear_mocks() {
    rm -rf "$TEST_ROOT/mock-bin"
}
