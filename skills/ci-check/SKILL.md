---
name: ci-check
description: >-
  Run local CI validation using hyperi-ci before pushing code.
  Use when the user says /ci-check, asks to validate, or before any push.
user-invocable: true
---

# Local CI Check (hyperi-ci projects)

## Prerequisites

This skill is ONLY for projects using hyperi-ci. Verify `.hyperi-ci.yaml` exists.

## Commands

| Command | What it does | When to use |
|---------|-------------|-------------|
| `hyperi-ci check` | Quality + test | **Default — always before push** |
| `hyperi-ci check --quick` | Quality only (lint, format, type check) | Fast WIP validation |
| `hyperi-ci check --full` | Quality + test + build (native target) | Pre-release validation |

## Procedure

### 1. Run the Check

Default to `hyperi-ci check` unless the user specifies otherwise:

```bash
hyperi-ci check
```

### 2. Interpret Results

The output shows each stage (quality, test, optionally build) with pass/fail.

**If everything passes:** Report success, proceed with whatever the user was doing.

**If quality fails:**
- Formatting issues → run the formatter (`cargo fmt`, `ruff format .`, etc.)
- Lint issues → fix the code
- Type errors → fix types
- Re-run `hyperi-ci check --quick` to verify the fix

**If tests fail:**
- Read the test output carefully
- Fix the failing test or the code under test
- Re-run `hyperi-ci check` (full, not quick)

### 3. Never Push Red

Do NOT proceed with `git push` if `hyperi-ci check` fails. Fix first.

## Language-Specific Details

The check command auto-detects the project language from `.hyperi-ci.yaml`.

| Language | Quality includes | Test includes |
|----------|-----------------|---------------|
| **Rust** | `cargo fmt --check`, `cargo clippy`, `cargo audit` | `cargo nextest run` or `cargo test` |
| **Python** | `ruff check`, `ruff format --check`, type checker, `pip-audit`, `bandit` | `pytest` with coverage |
| **TypeScript** | `eslint`, `prettier --check`, `tsc --noEmit` | `vitest` or `jest` |
| **Go** | `golangci-lint`, `go vet`, `govulncheck` | `go test ./...` |

## Equivalent Make Targets

All hyperi-ci projects also have Makefile targets:

```bash
make check     # = hyperi-ci check
make quality   # = hyperi-ci run quality
make test      # = hyperi-ci run test
make build     # = hyperi-ci run build
```
