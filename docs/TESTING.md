# Testing Strategy - HyperSec AI Code Assistant Standards

**Comprehensive test plan for installation and setup scripts**

---

## Overview

This document defines the testing strategy for the AI repository scripts. Testing ensures scripts work correctly across all three usage modes and all supported platforms.

**Test Philosophy:** Simple, fast, reliable - no complex frameworks needed.

---

## Test Scope

### In Scope

- Script functionality (file deployment, symlink creation)
- Usage mode detection (submodule, clone, standalone)
- Cross-platform compatibility (macOS, Ubuntu, Fedora)
- Idempotence (safe to run multiple times)
- Error handling (missing files, invalid paths)
- Command-line flags (--help, --dry-run, --force, --path)

### Out of Scope

- Template content validation (templates are reviewed separately)
- AI assistant behaviour (that's integration testing for AI tools)
- Performance testing (scripts are trivially fast)
- Load testing (single-user scripts)

---

## Test Levels

### Level 1: Manual Smoke Tests

**Purpose:** Quick verification during development

**When:** After every code change

**How:**
```bash
# Quick test of both scripts
./install.sh --dry-run
./claude-code.sh --dry-run
```

**Pass criteria:** No errors, correct dry-run output

### Level 2: Integration Tests

**Purpose:** Verify end-to-end functionality

**When:** Before commits

**How:** Run test script (see Test Script section)

**Pass criteria:** All test cases pass

### Level 3: Platform Tests

**Purpose:** Verify cross-platform compatibility

**When:** Before releases

**How:** Test on macOS, Ubuntu, Fedora

**Pass criteria:** All tests pass on all platforms

---

## Test Environment Setup

### Directory Structure

```
/projects/
├── ai/                      # This repository
│   ├── install.sh
│   ├── claude-code.sh
│   ├── standards/
│   ├── templates/
│   └── docs/
│
└── ai-test/                 # Test environment (gitignored)
    ├── test-submodule/      # Simulates submodule mode
    │   ├── .git/            # Real git repo
    │   └── ai/              # Submodule (symlink or actual)
    │
    ├── test-clone/          # Simulates clone mode
    │   └── ai/              # Clone with .git directory
    │
    └── test-standalone/     # Simulates standalone mode
        └── ai/              # No .git (unzipped)
```

### Setup Test Environment

**Script: `setup-test-env.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="/projects/ai-test"
AI_SOURCE="/projects/ai"

# Clean up old tests
rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT"

# Test 1: Submodule mode
echo "Setting up submodule test..."
mkdir -p "$TEST_ROOT/test-submodule"
cd "$TEST_ROOT/test-submodule"
git init
git submodule add "$AI_SOURCE" ai
echo "Submodule test ready: $TEST_ROOT/test-submodule"

# Test 2: Clone mode
echo "Setting up clone test..."
git clone "$AI_SOURCE" "$TEST_ROOT/test-clone/ai"
echo "Clone test ready: $TEST_ROOT/test-clone"

# Test 3: Standalone mode
echo "Setting up standalone test..."
mkdir -p "$TEST_ROOT/test-standalone/ai"
cp -r "$AI_SOURCE"/{install.sh,claude-code.sh,standards,templates} \
      "$TEST_ROOT/test-standalone/ai/"
echo "Standalone test ready: $TEST_ROOT/test-standalone"

echo "Test environment setup complete!"
```

---

## Test Cases

### install.sh Tests

#### TC-001: Submodule Mode Detection

**Precondition:** Project with ai as git submodule

**Steps:**
```bash
cd /projects/ai-test/test-submodule
./ai/install.sh --verbose
```

**Expected:**
- Detects mode as "submodule"
- Deploys STATE.md to project root
- Deploys TODO.md to project root
- Prints summary showing mode detected

**Verification:**
```bash
[ -f STATE.md ] && echo "PASS: STATE.md created"
[ -f TODO.md ] && echo "PASS: TODO.md created"
```

#### TC-002: Clone Mode Detection

**Precondition:** Standalone git clone of ai repo

**Steps:**
```bash
cd /projects/ai-test/test-clone
./ai/install.sh --verbose
```

**Expected:**
- Detects mode as "clone"
- Deploys STATE.md
- Deploys TODO.md

**Verification:**
```bash
[ -f STATE.md ] && echo "PASS"
[ -f TODO.md ] && echo "PASS"
```

#### TC-003: Standalone Mode Detection

**Precondition:** Unzipped ai directory (no .git)

**Steps:**
```bash
cd /projects/ai-test/test-standalone
./ai/install.sh --verbose
```

**Expected:**
- Detects mode as "standalone"
- Deploys STATE.md
- Deploys TODO.md

**Verification:**
```bash
[ -f STATE.md ] && echo "PASS"
[ -f TODO.md ] && echo "PASS"
```

#### TC-004: Idempotence (Run Twice)

**Precondition:** install.sh already run once

**Steps:**
```bash
cd /projects/ai-test/test-submodule
./ai/install.sh          # First run
./ai/install.sh          # Second run
```

**Expected:**
- Second run skips existing files
- Prints "Skipped (exists): STATE.md"
- Prints "Skipped (exists): TODO.md"
- Exit code 0 (success)

**Verification:**
```bash
# Check files weren't modified
stat -f %m STATE.md > before
./ai/install.sh
stat -f %m STATE.md > after
diff before after && echo "PASS: File not modified"
```

#### TC-005: Force Overwrite

**Precondition:** Files already exist

**Steps:**
```bash
cd /projects/ai-test/test-submodule
echo "modified" >> STATE.md
./ai/install.sh --force
```

**Expected:**
- Overwrites STATE.md
- Overwrites TODO.md
- Prints "Deployed: STATE.md" (not "Skipped")

**Verification:**
```bash
! grep -q "modified" STATE.md && echo "PASS: File overwritten"
```

#### TC-006: Dry Run Mode

**Precondition:** Clean test directory

**Steps:**
```bash
cd /projects/ai-test/test-submodule
./ai/install.sh --dry-run
```

**Expected:**
- Prints "Would deploy: STATE.md"
- Prints "Would deploy: TODO.md"
- Does NOT create files
- Exit code 0

**Verification:**
```bash
[ ! -f STATE.md ] && echo "PASS: Dry run didn't create files"
```

#### TC-007: Custom Path

**Precondition:** Clean environment

**Steps:**
```bash
cd /projects/ai-test
./test-submodule/ai/install.sh --path /tmp/custom-project
```

**Expected:**
- Deploys to /tmp/custom-project/STATE.md
- Deploys to /tmp/custom-project/TODO.md
- NOT to test-submodule/

**Verification:**
```bash
[ -f /tmp/custom-project/STATE.md ] && echo "PASS"
[ ! -f /projects/ai-test/test-submodule/STATE.md ] && echo "PASS"
```

#### TC-008: Help Flag

**Steps:**
```bash
./install.sh --help
```

**Expected:**
- Prints usage information
- Explains all flags
- Exit code 0

**Verification:**
```bash
./install.sh --help | grep -q "Usage:" && echo "PASS"
```

#### TC-009: Invalid Path

**Steps:**
```bash
./install.sh --path /nonexistent/path
```

**Expected:**
- Prints error message
- Exit code 1 (error)
- No files created

**Verification:**
```bash
./install.sh --path /nonexistent 2>&1 | grep -q "ERROR" && echo "PASS"
```

---

### claude-code.sh Tests

#### TC-101: Prerequisites Check

**Precondition:** STATE.md does NOT exist

**Steps:**
```bash
cd /projects/ai-test/test-submodule
./ai/claude-code.sh
```

**Expected:**
- Prints "ERROR: STATE.md not found. Run install.sh first."
- Exit code 1
- Does NOT create .claude/

**Verification:**
```bash
./ai/claude-code.sh 2>&1 | grep -q "install.sh first" && echo "PASS"
[ ! -d .claude ] && echo "PASS: .claude not created"
```

#### TC-102: Full Setup

**Precondition:** STATE.md exists

**Steps:**
```bash
cd /projects/ai-test/test-submodule
./ai/install.sh
./ai/claude-code.sh --verbose
```

**Expected:**
- Creates .claude/ directory
- Deploys .claude/settings.json
- Deploys .claude/commands/start.md
- Deploys .claude/commands/save.md
- Creates CLAUDE.md -> STATE.md symlink
- Prints summary

**Verification:**
```bash
[ -d .claude ] && echo "PASS: .claude created"
[ -f .claude/settings.json ] && echo "PASS: settings deployed"
[ -f .claude/commands/start.md ] && echo "PASS: start command deployed"
[ -f .claude/commands/save.md ] && echo "PASS: save command deployed"
[ -L CLAUDE.md ] && echo "PASS: symlink created"
readlink CLAUDE.md | grep -q "STATE.md" && echo "PASS: correct symlink target"
```

#### TC-103: Idempotence

**Precondition:** claude-code.sh already run

**Steps:**
```bash
cd /projects/ai-test/test-submodule
./ai/claude-code.sh  # First run
./ai/claude-code.sh  # Second run
```

**Expected:**
- Second run skips existing settings.json
- Second run UPDATES commands (versioned)
- Second run skips existing symlink
- Exit code 0

**Verification:**
```bash
# Modify settings and verify it's preserved
echo "/* custom */" >> .claude/settings.json
./ai/claude-code.sh
grep -q "custom" .claude/settings.json && echo "PASS: Settings preserved"
```

#### TC-104: Force Overwrite Settings

**Precondition:** Custom settings exist

**Steps:**
```bash
cd /projects/ai-test/test-submodule
echo "/* custom */" >> .claude/settings.json
./ai/claude-code.sh --force
```

**Expected:**
- Overwrites settings.json
- Custom content removed

**Verification:**
```bash
! grep -q "custom" .claude/settings.json && echo "PASS: Settings overwritten"
```

#### TC-105: Commands Always Updated

**Precondition:** Old version of commands exist

**Steps:**
```bash
cd /projects/ai-test/test-submodule
echo "OLD VERSION" > .claude/commands/start.md
./ai/claude-code.sh
```

**Expected:**
- start.md is overwritten (always updates)
- Contains current template content

**Verification:**
```bash
! grep -q "OLD VERSION" .claude/commands/start.md && echo "PASS"
grep -q "Read critical documentation" .claude/commands/start.md && echo "PASS"
```

---

### Cross-Platform Tests

#### TC-201: macOS (bash 3.2)

**Platform:** macOS 13+ (bash 3.2.57)

**Steps:**
```bash
# Verify bash version
bash --version | grep "3.2"

# Run all tests
./run-all-tests.sh
```

**Expected:**
- All tests pass
- No bash 4+ features used
- No errors about unsupported syntax

#### TC-202: Ubuntu 22.04 (bash 5.1)

**Platform:** Ubuntu 22.04+ (bash 5.1+)

**Steps:**
```bash
# Run in Ubuntu container or VM
docker run -it ubuntu:22.04
./run-all-tests.sh
```

**Expected:**
- All tests pass
- Scripts work with newer bash

#### TC-203: Fedora 42 (bash 5.2)

**Platform:** Fedora 42+ (bash 5.2+)

**Steps:**
```bash
# Run in Fedora container or VM
docker run -it fedora:42
./run-all-tests.sh
```

**Expected:**
- All tests pass

---

## Test Framework: Bats

### Why Bats?

**Bats (Bash Automated Testing System)** is the standard for testing bash scripts:
- Clean, readable test syntax
- TAP (Test Anything Protocol) output
- Wide adoption (used by Homebrew, Docker, etc.)
- Works on macOS and Linux

### Installation

```bash
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt install bats

# Fedora
sudo dnf install bats

# Manual
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

### Test Structure

```
tests/
├── install.bats         # Tests for install.sh
├── claude-code.bats     # Tests for claude-code.sh
└── test_helper.bash     # Shared test functions
```

## Test Scripts

### File: `tests/install.bats`

```bash
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
}

@test "TC-003: Detects standalone mode" {
    cd "$TEST_STANDALONE"
    run ./ai/install.sh --verbose

    [ "$status" -eq 0 ]
    [[ "$output" =~ "standalone" ]]
    [ -f "STATE.md" ]
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
    run /projects/ai/install.sh --path "$TMP_DIR"

    [ "$status" -eq 0 ]
    [ -f "$TMP_DIR/STATE.md" ]
    [ -f "$TMP_DIR/TODO.md" ]

    rm -rf "$TMP_DIR"
}

@test "TC-008: Help flag shows usage" {
    run ./install.sh --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "TC-009: Invalid path returns error" {
    run ./install.sh --path /nonexistent/path/12345

    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR" ]]
}
```

### File: `tests/claude-code.bats`

```bash
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
```

### File: `tests/test_helper.bash`

```bash
#!/usr/bin/env bash

# Test environment paths
export TEST_ROOT="/projects/ai-test"
export AI_SOURCE="/projects/ai"
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
    git submodule add -q "$AI_SOURCE" ai 2>/dev/null || true

    # Setup clone test
    git clone -q "$AI_SOURCE" "$TEST_CLONE/ai" 2>/dev/null || true

    # Setup standalone test
    mkdir -p "$TEST_STANDALONE/ai"
    cp -r "$AI_SOURCE"/{install.sh,claude-code.sh,standards,templates} \
          "$TEST_STANDALONE/ai/" 2>/dev/null || true
}

cleanup_test_env() {
    # Optional: clean up after tests
    # Commented out to allow inspection after failures
    # rm -rf "$TEST_ROOT"
    :
}
```

### Running Tests

```bash
# Run all tests
cd /projects/ai
bats tests/

# Run specific test file
bats tests/install.bats

# Run with verbose output
bats --verbose tests/

# Run with TAP output (for CI)
bats --tap tests/

# Run and show timing
bats --timing tests/
```

### Expected Output

```
✓ TC-001: Detects submodule mode
✓ TC-002: Detects clone mode
✓ TC-003: Detects standalone mode
✓ TC-004: Idempotent - safe to run twice
✓ TC-005: Force flag overwrites files
✓ TC-006: Dry run shows actions without executing
✓ TC-007: Custom path deployment
✓ TC-008: Help flag shows usage
✓ TC-009: Invalid path returns error
✓ TC-101: Requires STATE.md (prerequisite check)
✓ TC-102: Full Claude Code setup
✓ TC-103: Idempotent - preserves settings
✓ TC-104: Force flag overwrites settings
✓ TC-105: Commands always updated (versioned)

14 tests, 0 failures
```

---

## Manual Testing Checklist

### Before Each Commit

- [ ] Run `./run-tests.sh` - all tests pass
- [ ] Test `./install.sh --help` - prints usage
- [ ] Test `./claude-code.sh --help` - prints usage
- [ ] Test `./install.sh --dry-run` - shows actions without executing
- [ ] Test idempotence - run scripts twice, no errors

### Before Each Release

- [ ] Test on macOS (bash 3.2)
- [ ] Test on Ubuntu 22.04
- [ ] Test on Fedora 42
- [ ] Test all three usage modes (submodule, clone, standalone)
- [ ] Test with custom --path
- [ ] Test --force flag
- [ ] Verify templates deploy correctly
- [ ] Verify symlinks work
- [ ] Check for shellcheck warnings

---

## Debugging Failed Tests

### Common Issues

**Problem:** "Permission denied" running scripts

**Solution:**
```bash
chmod +x install.sh claude-code.sh
```

**Problem:** Bash 4+ features used on macOS

**Solution:** Check for incompatible syntax:
```bash
# Find bash 4+ patterns
grep -r '&>' *.sh  # Should use 2>&1 instead
grep -r '\[\[' *.sh  # Should use [ instead (usually)
```

**Problem:** Test environment corrupt

**Solution:**
```bash
rm -rf /projects/ai-test
./setup-test-env.sh
```

### Verbose Output

```bash
# Run scripts with verbose flag
./install.sh --verbose
./claude-code.sh --verbose

# Or enable bash tracing
bash -x ./install.sh
```

---

## Test Coverage

### Current Coverage

**install.sh:**
- ✅ Mode detection (all 3 modes)
- ✅ File deployment
- ✅ Idempotence
- ✅ Force flag
- ✅ Dry-run mode
- ✅ Custom path
- ✅ Help text
- ✅ Error handling

**claude-code.sh:**
- ✅ Prerequisites check
- ✅ Directory creation
- ✅ Settings deployment
- ✅ Commands deployment
- ✅ Symlink creation
- ✅ Idempotence
- ✅ Force flag
- ✅ Settings preservation

**Coverage:** ~90% of functionality (adequate for MVP)

### Not Tested (Acceptable)

- Edge cases like filesystem full (rare, hard to simulate)
- Race conditions (single-user scripts)
- Unusual permissions scenarios
- Symbolic link loops (prevented by design)

---

## Performance Benchmarks

**Not required** - scripts are trivially fast (<1 second).

If needed:
```bash
time ./install.sh
# real    0m0.089s
```

---

## Continuous Integration

### GitHub Actions

**Future enhancement** (post-MVP):

```yaml
name: Test Scripts
on: [push, pull_request]
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: ./run-tests.sh
```

**Not in MVP** - manual testing sufficient for now.

---

## Test Maintenance

### Adding New Tests

1. Add test case to this document
2. Add test to `run-tests.sh`
3. Verify test passes
4. Document expected behaviour

### Updating Tests

When scripts change:
1. Update affected test cases
2. Update expected outputs
3. Re-run all tests
4. Update this document

---

**Last Updated:** 2025-01-20
**Version:** 0.1.0
**Status:** Planning Complete
