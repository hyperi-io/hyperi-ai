# Licensing Standards

**HyperSec licensing policy and implementation guide for all projects**

---

## Supported Licenses

HyperSec permits exactly two license types:

| License | SPDX Identifier | Approval | Use For |
|---------|-----------------|----------|---------|
| **HyperSec EULA** | `LicenseRef-HyperSec-EULA` | Default (none required) | All proprietary/commercial projects |
| **Apache 2.0** | `Apache-2.0` | Management approval required | Open source projects only |

⚠️ **MIT license is NOT permitted** - lacks patent protection required for enterprise use.

---

## HyperSec EULA (Default)

**Use for:** All commercial HyperSec products, internal tools, client projects, and any code not explicitly approved for open source release.

| Property | Value |
|----------|-------|
| SPDX Identifier | `LicenseRef-HyperSec-EULA` |
| Copyright | `(c) YYYY HyperSec` |
| Approval | None required (default for all projects) |
| Full Terms | <https://hypersec.io/eula/> |

### When to Use

- ✅ Internal tools and utilities
- ✅ Client deliverables
- ✅ Commercial products
- ✅ Proprietary libraries
- ✅ Any code not approved for open source

### LICENSE File Template

Create `LICENSE` in project root:

```text
HyperSec End User License Agreement (EULA)

Copyright (c) 2025 HyperSec. All rights reserved.

This software and associated documentation files (the "Software") are
proprietary to HyperSec and are protected by copyright law and
international treaties.

NOTICE: This is proprietary software. Unauthorized copying, modification,
distribution, or use of this Software, via any medium, is strictly prohibited.

For licensing inquiries: legal@hypersec.io
Full terms: https://hypersec.io/eula/
```

---

## Apache 2.0 (Open Source)

**Use for:** Open source projects intended for public release, community tools, and reference implementations.

| Property | Value |
|----------|-------|
| SPDX Identifier | `Apache-2.0` |
| Copyright | `(c) YYYY HyperSec` |
| Approval | **Management approval required** |
| Full Terms | <https://www.apache.org/licenses/LICENSE-2.0> |

### Why Apache 2.0 (Not MIT)

Apache 2.0 is required because:

1. **Patent grant** - Protects users from patent litigation
2. **Contribution terms** - Clear IP assignment from contributors
3. **Enterprise acceptance** - Preferred by enterprise legal teams
4. **Trademark protection** - Explicit trademark provisions

MIT license lacks these protections and is NOT acceptable for HyperSec projects.

### When to Use

- ✅ Community tools (with approval)
- ✅ Reference implementations (with approval)
- ✅ Open source contributions (with approval)
- ❌ Never without management approval

### Approval Process

**Before creating a public repository:**

1. **Create proposal** documenting:
   - Project name and purpose
   - Business justification for open source
   - Competitive analysis (similar projects)
   - Maintenance commitment

2. **Submit for approval** to engineering management

3. **Wait for written approval** - Do not create public repo until received

4. **Document approval** in project README:

   ```markdown
   ## License

   This project is licensed under Apache 2.0.

   Open source release approved by [Name], [Date].
   ```

### LICENSE File Template

Create `LICENSE` in project root with full Apache 2.0 text:

```text
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.
      [... full license text ...]
```

**Get full text from:** <https://www.apache.org/licenses/LICENSE-2.0.txt>

---

## Project Configuration

### ci.yaml

Every project specifies license in `ci.yaml`:

```yaml
project:
  name: my-project
  license: hypersec-eula  # Default - no approval needed
  # license: apache-2.0   # Requires management approval
```

### Python (pyproject.toml)

```toml
[project]
name = "my-project"
version = "1.0.0"

# HyperSec EULA (proprietary - default)
license = { text = "LicenseRef-HyperSec-EULA" }

# OR Apache 2.0 (open source - requires approval)
# license = { text = "Apache-2.0" }

[project.urls]
License = "https://hypersec.io/eula/"
# License = "https://www.apache.org/licenses/LICENSE-2.0"
```

### Go

Go doesn't have a license field in `go.mod`. Implementation:

1. **LICENSE file** in repo root (required)
2. **Package comment** (optional but recommended):

```go
// Package mypackage provides [description].
//
// License: LicenseRef-HyperSec-EULA
// Copyright (c) 2025 HyperSec
package mypackage
```

### TypeScript/JavaScript (package.json)

**Proprietary (default):**

```json
{
  "name": "my-project",
  "version": "1.0.0",
  "license": "SEE LICENSE IN LICENSE",
  "private": true
}
```

**Open source (with approval):**

```json
{
  "name": "my-project",
  "version": "1.0.0",
  "license": "Apache-2.0"
}
```

### Rust (Cargo.toml)

```toml
[package]
name = "my-project"
version = "1.0.0"

# HyperSec EULA (proprietary - default)
license = "LicenseRef-HyperSec-EULA"

# OR Apache 2.0 (open source - requires approval)
# license = "Apache-2.0"
```

### Bash Scripts

Include license in file header:

```bash
#!/usr/bin/env bash
#
#  Project:      my-project
#  File:         script.sh
#  Purpose:      [Description]
#  Language:     Bash
#
#  License:      LicenseRef-HyperSec-EULA
#  Copyright:    (c) 2025 HyperSec
#
```

---

## File Headers

Every source file includes license in header. See `CODE-HEADER.md` for:

- Header format by language
- Required fields
- Examples

**Key rule:** File headers reference the project license - they don't define it.

---

## Third-Party Dependencies and License Compatibility

### License Compatibility Matrix

This matrix shows which dependency licenses are compatible with HyperSec project licenses:

| Dependency License | HyperSec EULA | Apache 2.0 | Notes |
|--------------------|---------------|------------|-------|
| **MIT** | ✅ Yes | ✅ Yes | Most permissive, always safe |
| **BSD-2-Clause** | ✅ Yes | ✅ Yes | Permissive, always safe |
| **BSD-3-Clause** | ✅ Yes | ✅ Yes | Permissive, always safe |
| **ISC** | ✅ Yes | ✅ Yes | Equivalent to MIT |
| **Apache-2.0** | ✅ Yes | ✅ Yes | Permissive with patent grant |
| **Unlicense/CC0** | ✅ Yes | ✅ Yes | Public domain equivalent |
| **MPL-2.0** | ⚠️ Caution | ⚠️ Caution | File-level copyleft (see below) |
| **LGPL-2.1/3.0** | ⚠️ Caution | ⚠️ Caution | Library linking only (see below) |
| **GPL-2.0** | ❌ No | ❌ No | Viral copyleft - infects project |
| **GPL-3.0** | ❌ No | ❌ No | Viral copyleft - infects project |
| **AGPL-3.0** | ❌ No | ❌ No | Network copyleft - even stricter |
| **SSPL** | ❌ No | ❌ No | MongoDB's restrictive license |
| **BSL** | ❌ No | ❌ No | Time-delayed open source |
| **No License** | ❌ No | ❌ No | All rights reserved by default |

### Understanding License Types

**Permissive Licenses (Safe):**

Permissive licenses allow you to use, modify, and distribute code with minimal restrictions. You can include permissive-licensed code in any project type.

```text
MIT → Apache 2.0    ✅ Works (MIT is more permissive)
MIT → EULA          ✅ Works (MIT allows proprietary use)
Apache 2.0 → EULA   ✅ Works (Apache allows proprietary use)
BSD → anything      ✅ Works (BSD is permissive)
```

**Copyleft Licenses (Caution):**

Copyleft licenses require derivative works to use the same license. The "viral" effect varies:

| License | Copyleft Scope | Safe to Use As |
|---------|----------------|----------------|
| **GPL** | Entire program | ❌ Never in HyperSec projects |
| **LGPL** | Library only | ✅ Dynamic linking only |
| **MPL** | Modified files only | ⚠️ Keep MPL files separate |

### Can I Include MIT Code in Apache 2.0 Projects?

**Yes.** MIT is more permissive than Apache 2.0, so MIT-licensed code can be included in Apache 2.0 projects.

**Example:** Using a MIT-licensed utility in your Apache 2.0 project:

```text
my-project/                      # Apache-2.0
├── LICENSE                      # Apache-2.0 (project license)
├── src/
│   └── main.py                  # Apache-2.0 (your code)
└── vendor/
    └── some-mit-lib/            # MIT (dependency)
        ├── LICENSE              # MIT license file preserved
        └── util.py              # MIT licensed code
```

**Requirements when including MIT code:**

1. ✅ Preserve the MIT LICENSE file
2. ✅ Preserve copyright notices in source files
3. ✅ Your project can still be Apache-2.0
4. ❌ Don't claim the MIT code is Apache-2.0

### Can I Include Apache 2.0 Code in HyperSec EULA Projects?

**Yes.** Apache 2.0 permits use in proprietary projects.

**Requirements:**

1. ✅ Preserve Apache 2.0 LICENSE/NOTICE files
2. ✅ Include attribution (usually in a THIRD-PARTY-LICENSES file)
3. ✅ Preserve copyright notices
4. ✅ Your project remains HyperSec EULA

### Handling LGPL Dependencies

LGPL allows use in proprietary software **only through dynamic linking**.

**✅ Safe - Dynamic linking:**

```python
# Python - importing is dynamic linking
import lgpl_library  # OK - LGPL allows this

result = lgpl_library.function()
```

```go
// Go - using as a module
import "github.com/some/lgpl-lib"  // OK if dynamically linked
```

**❌ Unsafe - Static linking or modification:**

```text
# Copying LGPL source into your codebase
cp lgpl-library/utils.c src/utils.c  # NOT OK - triggers copyleft
```

**LGPL Rules:**

- ✅ Import/link to LGPL libraries dynamically
- ✅ Call LGPL library functions
- ❌ Copy LGPL source code into your project
- ❌ Modify LGPL source and distribute
- ❌ Statically link LGPL code (Go binaries)

⚠️ **Go Warning:** Go statically links by default. LGPL Go libraries may require your entire binary to be LGPL. Avoid LGPL in Go projects.

### Handling MPL-2.0 Dependencies

MPL-2.0 has file-level copyleft - only modified MPL files must stay MPL.

**✅ Safe:**

```text
my-project/                      # Apache-2.0
├── src/
│   └── main.py                  # Apache-2.0 (your code)
└── vendor/
    └── mpl-lib/                 # MPL-2.0
        └── helper.py            # MPL-2.0 (don't modify)
```

**⚠️ Caution - If you modify MPL files:**

```text
my-project/                      # Apache-2.0
├── src/
│   └── main.py                  # Apache-2.0
└── vendor/
    └── mpl-lib/
        └── helper.py            # MPL-2.0 (modified → must stay MPL)
```

If you modify an MPL file, that specific file must remain MPL-2.0, but the rest of your project stays Apache-2.0/EULA.

### Why GPL is Never Acceptable

GPL's copyleft is "viral" - it requires the **entire combined work** to be GPL:

```text
your-project/                    # Want: Apache-2.0 or EULA
├── src/
│   └── main.py                  # Your code
└── vendor/
    └── gpl-lib/                 # GPL-3.0
        └── feature.py           # GPL-3.0
```

**Result:** Your entire project must become GPL-3.0. This is incompatible with:

- HyperSec EULA (proprietary)
- Apache 2.0 (permissive, not copyleft)

**Solution:** Find an alternative library with a permissive license.

### Acceptable Dependency Licenses Summary

**Always OK (Permissive):**

- MIT, ISC
- BSD-2-Clause, BSD-3-Clause
- Apache-2.0
- Unlicense, CC0-1.0, 0BSD
- WTFPL, Zlib

**Conditional (Copyleft with limits):**

- LGPL-2.1, LGPL-3.0 - Dynamic linking only, avoid in Go
- MPL-2.0 - Don't modify MPL files

**Never OK:**

- GPL-2.0, GPL-3.0 (viral)
- AGPL-3.0 (network viral)
- SSPL (MongoDB)
- BSL (time-delayed)
- CC-BY-NC (non-commercial)
- No license / Unknown

### Dependency Audit

Run license audit as part of CI:

```bash
# Python
pip-licenses --format=markdown
pip-licenses --fail-on="GPL;AGPL"

# Node.js
npx license-checker --summary
npx license-checker --failOn "GPL;AGPL"

# Go
go-licenses check ./...
go-licenses report ./... > THIRD-PARTY-LICENSES

# Rust
cargo deny check licenses
```

### THIRD-PARTY-LICENSES File

For projects with many dependencies, create a `THIRD-PARTY-LICENSES` file:

```text
This project includes third-party software with the following licenses:

================================================================================
requests (Python)
--------------------------------------------------------------------------------
License: Apache-2.0
Copyright (c) Kenneth Reitz

[Apache 2.0 license text or reference]

================================================================================
lodash (JavaScript)
--------------------------------------------------------------------------------
License: MIT
Copyright (c) JS Foundation

[MIT license text]
```

---

## Implementing Third-Party License Compliance

### Step 1: Check the License Before Adding

```bash
# Python - check before installing
pip show requests | grep License
# License: Apache-2.0  ✅ OK

# Node.js - check before installing
npm info lodash license
# MIT  ✅ OK

# Go - check go.mod or LICENSE file
cat go.mod  # Check module source, then check its LICENSE

# Rust - check Cargo.toml
cargo search serde --limit 1
# Check crates.io for license info
```

### Step 2: Add to Project Files

Dependencies are tracked automatically by package managers. No special action needed for permissive licenses (MIT, BSD, Apache).

### Step 3: Create THIRD-PARTY-LICENSES (Optional but Recommended)

For production deployments, create a `THIRD-PARTY-LICENSES` or `NOTICES` file:

```text
THIRD-PARTY SOFTWARE NOTICES

This software includes the following third-party components:

================================================================================
requests 2.31.0
https://github.com/psf/requests
License: Apache-2.0
================================================================================

================================================================================
numpy 1.26.0
https://github.com/numpy/numpy
License: BSD-3-Clause
================================================================================
```

### Step 4: Automate License Checking in CI

**Python (pyproject.toml):**

```toml
[tool.pip-licenses]
fail-on = "GPL;AGPL;SSPL"
```

**Node.js (package.json):**

```json
{
  "scripts": {
    "license-check": "npx license-checker --failOn 'GPL;AGPL'"
  }
}
```

**Rust (deny.toml):**

```toml
[licenses]
unlicensed = "deny"
deny = ["GPL-2.0", "GPL-3.0", "AGPL-3.0"]
```

**Go:**

```bash
# In CI pipeline
go-licenses check ./...
```

---

## Quick Reference: What To Do By License Type

### If It's MIT Licensed

✅ **You can use it.** MIT is the most permissive license.

```bash
# Example: Adding a MIT dependency
pip install requests  # MIT licensed - OK

# What you must do:
# 1. Nothing special - just use it
# 2. The MIT license travels with the dependency automatically
```

**Real examples:** requests, lodash, React, Vue.js, jQuery

---

### If It's BSD Licensed (2-Clause or 3-Clause)

✅ **You can use it.** BSD is permissive like MIT.

```bash
# Example: Adding a BSD dependency
pip install numpy  # BSD licensed - OK
```

**Real examples:** NumPy, Flask, Django, PostgreSQL drivers

---

### If It's Apache 2.0 Licensed

✅ **You can use it.** Apache 2.0 is permissive with patent protection.

```bash
# Example: Adding an Apache 2.0 dependency
pip install kubernetes  # Apache-2.0 licensed - OK
```

**Real examples:** Kubernetes client, Apache HTTP, TensorFlow, Android

---

### If It's ISC or Unlicense/CC0

✅ **You can use it.** These are equivalent to MIT or public domain.

```bash
# Example
npm install semver  # ISC licensed - OK
```

**Real examples:** semver, glob, minimatch

---

### If It's LGPL Licensed

⚠️ **Use with caution.** OK for importing, not for copying code.

```python
# ✅ OK - Importing/linking dynamically
import lgpl_library
result = lgpl_library.do_something()

# ❌ NOT OK - Copying source into your project
# Don't copy LGPL source files into src/
```

**Rules:**

- ✅ Import it as a dependency
- ✅ Call its functions
- ❌ Don't copy its source code into your repo
- ❌ Don't modify its source code
- ⚠️ Avoid in Go (Go statically links)

**Real examples:** GNU readline, some Qt bindings, FFmpeg (parts)

---

### If It's MPL-2.0 Licensed

⚠️ **Use with caution.** OK if you don't modify the MPL files.

```python
# ✅ OK - Using without modification
from mpl_lib import helper
helper.do_work()

# ⚠️ CAUTION - If you modify helper.py, it must stay MPL-2.0
```

**Rules:**

- ✅ Use it as-is
- ⚠️ If you modify MPL files, those files stay MPL (but your code doesn't)

**Real examples:** Mozilla Firefox components, some Hashicorp tools

---

### If It's GPL Licensed (v2 or v3)

❌ **Do not use it.** GPL is viral - it will force your entire project to become GPL.

```bash
# ❌ NOT OK - Don't add GPL dependencies
pip install some-gpl-library  # NO - will infect your project
```

**What to do:**

1. Find an alternative with MIT/BSD/Apache license
2. If no alternative exists, request legal exception (rarely granted)
3. Consider if the functionality can be implemented differently

**Real examples to avoid:** GNU coreutils (in code), readline (sometimes), some scientific libraries

---

### If It's AGPL Licensed

❌ **Do not use it.** AGPL is even stricter than GPL - network use triggers copyleft.

```bash
# ❌ NOT OK
pip install some-agpl-library  # NO - even using over network triggers it
```

**What to do:** Same as GPL - find an alternative.

**Real examples to avoid:** MongoDB (older versions), Grafana (older), some SaaS tools

---

### If It's SSPL or BSL Licensed

❌ **Do not use it.** These are restrictive commercial licenses disguised as open source.

**Real examples to avoid:** MongoDB (current), Elasticsearch (current), CockroachDB

---

### If It Has No License

❌ **Do not use it.** No license = all rights reserved by the author.

**What to do:**

1. Contact the author and ask them to add a license
2. Find an alternative that has a proper license
3. Never assume "no license" means "free to use"

---

### If It's Dual-Licensed (e.g., "MIT OR Apache-2.0")

✅ **Choose the permissive option.** Pick whichever suits your project.

```toml
# Rust example - crate offers "MIT OR Apache-2.0"
# Choose Apache-2.0 for patent protection
[dependencies]
serde = "1.0"  # MIT OR Apache-2.0 - we use under Apache-2.0
```

**Preference order:**

1. Apache-2.0 (has patent grant)
2. MIT (simpler)

---

## Common Questions

### Q: Can I use MIT for a small utility I'm writing?

**No.** Your code uses HyperSec EULA (default) or Apache 2.0 (with approval). You can *use* MIT dependencies, but your own code is never MIT.

### Q: Do internal tools need a license?

**Yes.** All code needs a license. Internal tools default to HyperSec EULA.

### Q: Can I contribute to external open source projects?

**Yes**, but follow the external project's contribution guidelines. Your contributions will use their license, not HyperSec's.

### Q: What if a dependency has GPL?

**Do not use it.** Find an alternative with a permissive license, or request an exception from legal.

### Q: How do I handle dual-licensed dependencies?

Choose the permissive option. For example, if a crate offers "MIT OR Apache-2.0", use Apache-2.0 for patent protection.

---

## Checklist

### New Project

- [ ] Create `LICENSE` file with appropriate text
- [ ] Set `license` in ci.yaml
- [ ] Configure license in project file (pyproject.toml, package.json, etc.)
- [ ] For Apache 2.0: Confirm management approval exists
- [ ] Add license headers to all source files

### Adding Dependencies

- [ ] Check dependency license is acceptable
- [ ] Run license audit in CI
- [ ] Document any exceptions in README

### Code Review

- [ ] LICENSE file present and correct
- [ ] File headers include correct license reference
- [ ] No GPL/AGPL dependencies added
- [ ] ci.yaml license matches LICENSE file

---

## For AI Code Assistants

This section provides guidance specifically for AI code assistants (Claude Code, GitHub Copilot, Cursor, etc.).

### Default Behaviour

1. **Always use HyperSec EULA** unless user explicitly requests Apache 2.0
2. **Never suggest MIT license** - it's not permitted for HyperSec projects
3. **If user requests Apache 2.0**, remind them management approval is required

### When Creating New Projects

```bash
# 1. Create LICENSE file with HyperSec EULA
cat > LICENSE << 'EOF'
HyperSec End User License Agreement (EULA)

Copyright (c) 2025 HyperSec. All rights reserved.
...
EOF

# 2. Set license in ci.yaml
echo "project:
  license: hypersec-eula" >> ci.yaml

# 3. Configure in project file (example: pyproject.toml)
# license = { text = "LicenseRef-HyperSec-EULA" }

# 4. Add headers to all source files (see CODE-HEADER.md)
```

### When User Requests Open Source (Apache 2.0)

1. **Ask:** "Has this been approved by management for open source release?"
2. **If no approval:** Inform user that Apache 2.0 requires management approval first
3. **If approved:** Create project with Apache 2.0 license

```bash
# Only if approved
cat > LICENSE << 'EOF'
                             Apache License
                       Version 2.0, January 2004
...
EOF
```

### When User Asks About Dependencies

**If user wants to add a dependency:**

1. Check the license type
2. Respond based on this table:

| License | Response |
|---------|----------|
| MIT, BSD, Apache, ISC | "✅ Safe to use" |
| LGPL | "⚠️ OK to import, don't copy source code" |
| MPL | "⚠️ OK if you don't modify MPL files" |
| GPL, AGPL | "❌ Cannot use - find an alternative" |
| No license | "❌ Cannot use - no license means all rights reserved" |

### Example Responses

**User:** "Add the xyz library to this project"

**Check license first:**

```text
# Good response if MIT/BSD/Apache:
"Adding xyz (MIT licensed) - this is fine to use."

# Good response if GPL:
"The xyz library is GPL licensed, which would require our entire
project to become GPL. Can't use it. Let me find an alternative
with a permissive license (MIT, BSD, or Apache)."

# Good response if no license:
"The xyz library has no license, which means all rights are
reserved by the author. We can't legally use it. Let me find
an alternative that has a proper open source license."
```

### Never Do

- ❌ Never create a project with MIT license
- ❌ Never add GPL/AGPL dependencies without warning
- ❌ Never assume "no license" means "free to use"
- ❌ Never skip the license check when adding dependencies
