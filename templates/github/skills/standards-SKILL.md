---
name: standards
description: HyperSec coding standards - always use for code quality
---

# HyperSec Coding Standards

See the full standards document at: `ai/standards/STANDARDS-QUICKSTART.md`

## Quick Reference

### Code Quality
- Human-readable code with clear variable names
- Single responsibility functions (<50 lines preferred)
- Explicit over implicit - no magic

### Git Conventions
- Conventional commits: `type(scope): description`
- Types: feat, fix, docs, style, refactor, test, chore, ci, perf, build
- Keep commits atomic and focused

### Error Handling
- Fail fast, fail loud
- Explicit error types
- No silent failures
- Log errors with context

### Testing
- Test behaviour, not implementation
- Arrange-Act-Assert pattern
- 80%+ coverage target

### Security
- Validate all external input
- Never log secrets
- Use parameterised queries
- Least privilege principle

For complete standards, read: `ai/standards/STANDARDS-QUICKSTART.md`
