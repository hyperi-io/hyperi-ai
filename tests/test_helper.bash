#!/usr/bin/env bash

# Test environment paths
# Use TMPDIR for CI compatibility, /projects/ai-test for local development
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

    # Create .git file (simulates submodule)
    echo "gitdir: ../.git/modules/ai" > "$TEST_SUBMODULE/ai/.git" 2>/dev/null || true
    mkdir -p "$TEST_SUBMODULE/ai"
    cp -r "$AI_SOURCE"/{install.sh,claude-code.sh,standards,templates} "$TEST_SUBMODULE/ai/" 2>/dev/null || true

    # Setup clone test
    mkdir -p "$TEST_CLONE/ai"
    cp -r "$AI_SOURCE"/{install.sh,claude-code.sh,standards,templates} "$TEST_CLONE/ai/"
    # Create .git directory (simulates clone)
    mkdir -p "$TEST_CLONE/ai/.git"

    # Setup standalone test
    mkdir -p "$TEST_STANDALONE/ai"
    cp -r "$AI_SOURCE"/{install.sh,claude-code.sh,standards,templates} "$TEST_STANDALONE/ai/" 2>/dev/null || true
    # No .git (simulates unzipped)
}

cleanup_test_env() {
    # Optional: clean up after tests
    # Commented out to allow inspection after failures
    # rm -rf "$TEST_ROOT"
    :
}
