# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial repository structure with standards and templates
- `install.sh` - Deploy STATE.md and TODO.md to project root
- `claude-code.sh` - Setup Claude Code configuration
- Comprehensive standards documentation in `/standards/`
  - AI-specific guidance for code assistants
  - Language-agnostic coding standards (SOLID, DRY, KISS, YAGNI)
  - Python-specific standards (PEP 8, type hints, testing)
  - Design principles and best practices
- Generic templates for STATE.md and TODO.md
- Claude Code specific templates (settings.json, slash commands)
- Bats test suite for installation scripts
- Documentation:
  - ARCHITECTURE.md - Technical design
  - TESTING.md - Test strategy
  - SCOPE.md - Project scope and goals

### Changed
- Radical simplification from legacy hs-ci/ai (95% reduction)
- Pure bash implementation (no Python dependencies)
- Path-agnostic design (works anywhere, not just `/ai`)
- Cross-platform compatibility (bash 3.2+ for macOS, Linux, WSL)

### Removed
- Python-based installation (replaced with bash scripts)
- Complex templating (replaced with simple file copies)
- Tight coupling to hs-ci (now independent)

## [0.1.0] - 2025-01-20

### Added
- Initial release
- MVP implementation complete
- Ready for testing and iteration

---

**Note:** Version 1.0.0 will be released after successful pilot testing in real projects.
