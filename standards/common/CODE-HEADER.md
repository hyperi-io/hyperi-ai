# Code Header Standards (All Languages)

**Auto-copied to `docs/standards/` by CI_AI_MERGE_MODE**

This document defines code header standards for all AI assistants.
Headers are language-specific, but rules are universal.

---

## Header Requirements (REUSE/SPDX Compliant)

**CRITICAL:** All source code files MUST have a standard header.

### Minimum Required Fields:

```
Project:      <PROJECT_NAME>
File:         <FILENAME>
Purpose:      <One-sentence description>
Language:     <Python|Bash|C|Go|JavaScript|etc.>

License:      <SPDX-Identifier>
Copyright:    (c) <YEAR> <ORGANISATION>
```

### Optional Fields:

```
Description:
    <Multi-line purpose, notes, assumptions>

Notes:
    - Compatible with: <Platform/Runtime>
    - Follows: <Standards/Specs>
```

---

## License Selection

**Project has ONE license type** (configured in ci.yaml):

### Supported Licenses:

**1. HyperSec EULA (Proprietary)**
- SPDX: `LicenseRef-HyperSec-EULA`
- Use for: Commercial HyperSec products
- Copyright: `(c) YYYY HyperSec Pty Ltd`
- File: `LICENSE` (HyperSec EULA text)
- Reference: https://hypersec.io/eula/

**2. Apache 2.0 (Open Source)**
- SPDX: `Apache-2.0`
- Use for: Open source projects
- Copyright: `(c) YYYY HyperSec` or `(c) YYYY <Author>`
- File: `LICENSE` (Apache 2.0 text)

**Future:** Can add MIT, BSD, GPL, etc.

### Configuration (ci.yaml):

```yaml
project:
  license: hypersec-eula  # or: apache-2.0 (HyperSec policy: hypersec-eula or apache-2.0 only)
```

---

## Rules for AI Assistants

### ALWAYS:

✅ **Use project's license** - From ci.yaml configuration
✅ **Use current year** - From system date (not model training date)
✅ **Use organisation name** - From project configuration
✅ **Include SPDX identifier** - Standard format
✅ **One-sentence purpose** - Clear and concise
✅ **Language-appropriate comments** - # for Python, // for Go, etc.

### NEVER:

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
#  Project:      hyperlib
#  File:         config.py
#  Purpose:      Configuration management with Dynaconf
#  Language:     Python
#
#  License:      Apache-2.0
#  Copyright:    (c) 2025 HyperSec
#
#  Description:
#      Provides configuration cascade: CLI > ENV > .env > yaml > defaults
#      Handles multiple config files with language-specific overrides.

"""Module docstring here."""

import os
...
```

---

## Language-Specific Templates

**Headers are language-specific** - see language modules:

- Python: `ci/modules/python/ai/CODE_HEADER.md`
- Bash: `ci/modules/bash/ai/CODE_HEADER.md` (future)
- Go: `ci/modules/go/ai/CODE_HEADER.md` (future)

Each language module provides:
- Comment syntax (# vs // vs /* */)
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

**For full spec:** https://reuse.software/spec-3.3/

---

## Example: License Selection

```python
# Get license from project config
from ci_lib import get_config_value

license_type = get_config_value("project.license", default="apache-2.0")

if license_type == "hypersec-eula":
    spdx_id = "LicenseRef-HyperSec-EULA"
    copyright_holder = "HyperSec Pty Ltd"
elif license_type == "apache-2.0":
    spdx_id = "Apache-2.0"
    copyright_holder = "HyperSec"
```

---

## For AI Assistants

**When creating new files:** Check project license (ci.yaml), get current year, load template, fill fields (project, filename, purpose, language), add at top.

**When editing existing files:** Preserve headers (don't modify). If missing, add one. Update Purpose if changed significantly.

---

**See language-specific CODE_HEADER.md for templates and examples.**
