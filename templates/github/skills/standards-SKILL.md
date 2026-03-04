---
name: standards
description: HyperI coding standards - always use for code quality
---

# HyperI Coding Standards

See the universal standards at: `ai/standards/rules/UNIVERSAL.md`

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
- Mock-aware: mock-only tests ≠ production tested

### Security

- Validate all external input
- Never log secrets
- Use parameterised queries
- Least privilege principle

For complete standards, read: `ai/standards/rules/UNIVERSAL.md`
Language-specific rules are in: `ai/standards/rules/<lang>.md`
