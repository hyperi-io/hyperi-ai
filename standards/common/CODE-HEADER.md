---
name: code-header-standards
description: Standard file header format for all HyperI projects, all languages.
universal: true
---

# Code Header Standards (All Languages)

Standard file headers for all HyperI projects.

---

## Header Format

Every source file includes a header with project info and license reference.

### Required Fields

```text
Project:      <PROJECT_NAME>
File:         <FILENAME>
Purpose:      <One-sentence description>
Language:     <Python|Bash|Go|Rust|TypeScript|etc.>

License:      FSL-1.1-ALv2
Copyright:    (c) <YEAR> HYPERI PTY LIMITED
```

### Optional Fields

```text
Description:
    <Multi-line purpose, notes, assumptions>

Notes:
    - Compatible with: <Platform/Runtime>
    - Follows: <Standards/Specs>
```

---

## NEVER Include

| Field | Reason |
|-------|--------|
| Version numbers | Use CHANGELOG.md and git tags |
| Change dates | Use git history |
| Author names | Always organisation (HYPERI PTY LIMITED) |
| Modification history | That's what git is for |

---

## Language Examples

### Python

```python
#  Project:      my-project
#  File:         config.py
#  Purpose:      Configuration management with Dynaconf
#  Language:     Python
#
#  License:      FSL-1.1-ALv2
#  Copyright:    (c) 2026 HYPERI PTY LIMITED
#
#  Description:
#      Provides configuration cascade: CLI > ENV > .env > yaml > defaults
#      Handles multiple config files with language-specific overrides.

"""Module docstring here."""

import os
```

### Rust

```rust
//! Project:      my-crate
//! File:         lib.rs
//! Purpose:      Core library functionality
//! Language:     Rust
//!
//! License:      FSL-1.1-ALv2
//! Copyright:    (c) 2026 HYPERI PTY LIMITED

pub mod config;
```

### Go

```go
// Project:      my-service
// File:         main.go
// Purpose:      Service entry point
// Language:     Go
//
// License:      FSL-1.1-ALv2
// Copyright:    (c) 2026 HYPERI PTY LIMITED

package main
```

### Bash

```bash
#!/usr/bin/env bash
#
#  Project:      my-project
#  File:         deploy.sh
#  Purpose:      Deploy application to production
#  Language:     Bash
#
#  License:      FSL-1.1-ALv2
#  Copyright:    (c) 2026 HYPERI PTY LIMITED

set -euo pipefail
```

### TypeScript

```typescript
/**
 * Project:      my-app
 * File:         index.ts
 * Purpose:      Application entry point
 * Language:     TypeScript
 *
 * License:      FSL-1.1-ALv2
 * Copyright:    (c) 2026 HYPERI PTY LIMITED
 */

import express from 'express';
```

---

## Header Placement

- **Top of file**, before any code
- After shebang line for scripts (`#!/usr/bin/env bash`)
- Before module docstrings (Python) or package declarations (Go)

---

## REUSE/SPDX Compliance

Follows REUSE Software Specification 3.3:

- ✅ SPDX license identifier (`FSL-1.1-ALv2`)
- ✅ Copyright notice with legal entity
- ✅ Machine-readable format
- ✅ Language-appropriate comment syntax

**For full spec:** <https://reuse.software/spec-3.3/>

---

## For AI Code Assistants

### When Creating New Files

1. Use `FSL-1.1-ALv2` license
2. Use current year from system date
3. Use `HYPERI PTY LIMITED` as copyright holder
4. Use appropriate comment syntax for language
5. Add header at top of file, before any code

### When Editing Existing Files

1. Preserve existing headers (don't modify)
2. If header is missing, add one
3. Update Purpose only if file's purpose changed significantly

**See also:** [LICENSING.md](LICENSING.md) for full license implementation guide.
