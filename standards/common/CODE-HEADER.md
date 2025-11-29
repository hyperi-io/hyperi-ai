# Code Header Standards (All Languages)

This document defines code header standards for all AI assistants.
Headers are language-specific, but rules are universal.

---

## Header Requirements (REUSE/SPDX Compliant)

**CRITICAL:** All source code files MUST have a standard header.

### Minimum Required Fields

```text
Project:      <PROJECT_NAME>
File:         <FILENAME>
Purpose:      <One-sentence description>
Language:     <Python|Bash|C|Go|JavaScript|etc.>

License:      <SPDX-Identifier>
Copyright:    (c) <YEAR> <ORGANISATION>
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

## License in Headers

File headers reference the project's license (configured in ci.yaml).

**Supported licenses:**

| License | SPDX Identifier |
|---------|-----------------|
| HyperSec EULA (default) | `LicenseRef-HyperSec-EULA` |
| Apache 2.0 (requires approval) | `Apache-2.0` |

**Full licensing guide:** See [LICENSING.md](LICENSING.md) for:

- License selection and approval process
- LICENSE file templates
- Project file configuration (pyproject.toml, package.json, etc.)
- Third-party dependency requirements

---

## Rules for AI Assistants

### ALWAYS

✅ **Use project's license** - From ci.yaml configuration
✅ **Use current year** - From system date (not model training date)
✅ **Use organisation name** - From project configuration
✅ **Include SPDX identifier** - Standard format
✅ **One-sentence purpose** - Clear and concise
✅ **Language-appropriate comments** - # for Python, // for Go, etc.

### NEVER

❌ **Include version numbers** - Managed by CHANGELOG.md and git
❌ **Include change dates** - Managed by git history
❌ **Include author names** - Always "HyperSec" or organisation
❌ **Include file modification history** - That's what git is for
❌ **Copy headers from other projects** - Use project's configured license

---

## Header Placement

**Top of file, before any code:**

```python
# Python example
#  Project:      hs-lib
#  File:         config.py
#  Purpose:      Configuration management with Dynaconf
#  Language:     Python
#
#  License:      LicenseRef-HyperSec-EULA
#  Copyright:    (c) 2025 HyperSec
#
#  Description:
#      Provides configuration cascade: CLI > ENV > .env > yaml > defaults
#      Handles multiple config files with language-specific overrides.

"""Module docstring here."""

import os
...
```

```go
// Go example
//  Project:      my-service
//  File:         main.go
//  Purpose:      Service entry point
//  Language:     Go
//
//  License:      LicenseRef-HyperSec-EULA
//  Copyright:    (c) 2025 HyperSec

package main
```

```bash
#!/usr/bin/env bash
#
#  Project:      my-project
#  File:         deploy.sh
#  Purpose:      Deploy application to production
#  Language:     Bash
#
#  License:      LicenseRef-HyperSec-EULA
#  Copyright:    (c) 2025 HyperSec
#

set -euo pipefail
```

```typescript
/**
 * Project:      my-app
 * File:         index.ts
 * Purpose:      Application entry point
 * Language:     TypeScript
 *
 * License:      LicenseRef-HyperSec-EULA
 * Copyright:    (c) 2025 HyperSec
 */

import express from 'express';
```

```rust
//! Project:      my-crate
//! File:         lib.rs
//! Purpose:      Core library functionality
//! Language:     Rust
//!
//! License:      LicenseRef-HyperSec-EULA
//! Copyright:    (c) 2025 HyperSec

pub mod config;
```

---

## Language-Specific Templates

**Headers are language-specific** - see language modules:

- Python: `ci/modules/python/ai/CODE_HEADER.md`
- Bash: `ci/modules/bash/ai/CODE_HEADER.md` (future)
- Go: `ci/modules/go/ai/CODE_HEADER.md` (future)

Each language module provides:

- Comment syntax (# vs // vs /**/)
- Header template
- Examples

---

## REUSE Compliance

Follows REUSE Software Specification 3.3:

- ✅ SPDX license identifier
- ✅ Copyright notice
- ✅ No version/changelog in headers (managed separately)
- ✅ Machine-readable format
- ✅ Language-appropriate syntax

**For full spec:** <https://reuse.software/spec-3.3/>

---

## For AI Code Assistants

**When creating new files:**

1. Check project license from ci.yaml
2. Get current year from system date
3. Use appropriate comment syntax for language
4. Fill all required fields
5. Add header at top of file, before any code

**When editing existing files:**

1. Preserve existing headers (don't modify)
2. If header is missing, add one
3. Update Purpose only if file's purpose changed significantly

**See also:** [LICENSING.md](LICENSING.md) for full license implementation guide.
