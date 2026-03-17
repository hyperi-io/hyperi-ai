---
name: licensing-standards
description: HyperI licensing policy — FSL-1.1-ALv2 for all projects. No GPL/AGPL/SSPL dependencies.
---

# Licensing Standards

HyperI licensing policy - FSL-1.1-ALv2 for all projects.

---

## Single Source of Truth

All licensing files are maintained in the `hyperi-licensing` repository:

```bash
git clone https://github.com/hyperi-io/hyperi-licensing.git /projects/hyperi-licensing
```

**Template location:** `hyperi-licensing/github-template/`

| File | Purpose |
|------|---------|
| `LICENSE` | FSL-1.1-ALv2 license with Australian law notice |
| `COMMERCIAL.md` | Commercial licensing requirements and corporate group rules |
| `CONTRIBUTING.md` | Contribution guidelines (DCO, Conventional Commits) |
| `SECURITY.md` | Vulnerability disclosure policy |

---

## Quick Setup

Use CI attach to copy standard files:

```bash
ci/attach.sh --init licensing
```

Or copy manually from CI templates:

```bash
cp ci/templates/licensing/{LICENSE,COMMERCIAL.md,CONTRIBUTING.md,SECURITY.md} .
```

---

## FSL-1.1-ALv2 Overview

Functional Source License, Version 1.1, ALv2 Future License.

| Aspect | Detail |
|--------|--------|
| SPDX Identifier | `FSL-1.1-ALv2` |
| Copyright | `(c) YYYY HYPERI PTY LIMITED` |
| Commercial Use | Requires commercial license |
| Internal Use | Permitted without license |
| Future Open Source | Apache 2.0 after 2 years |

### When Commercial License Required

- Offering as SaaS/PaaS/managed service to third parties
- Embedding or bundling in commercial products
- Reselling or white-labelling
- Intra-group service provider (one entity hosting for others)

### When No Commercial License Needed

- Internal use within your own organisation
- Self-hosting for your own use
- Non-commercial education and research
- Professional services helping others deploy

**See `COMMERCIAL.md` in your repo for full details.**

---

## Project Configuration

### Cargo.toml (Rust)

```toml
[package]
name = "my-project"
version = "1.0.0"
license = "FSL-1.1-ALv2"
```

### pyproject.toml (Python)

```toml
[project]
name = "my-project"
version = "1.0.0"
license = { text = "FSL-1.1-ALv2" }
```

### package.json (TypeScript/JavaScript)

```json
{
  "name": "my-project",
  "version": "1.0.0",
  "license": "SEE LICENSE IN LICENSE"
}
```

### go.mod (Go)

Go doesn't have a license field. Include `LICENSE` file in repo root.

---

## File Headers

Every source file references the project license:

```rust
// Project:   my-project
// License:   FSL-1.1-ALv2
// Copyright: (c) 2025 HYPERI PTY LIMITED
```

```python
# Project:   my-project
# License:   FSL-1.1-ALv2
# Copyright: (c) 2025 HYPERI PTY LIMITED
```

```bash
#  Project:   my-project
#  License:   FSL-1.1-ALv2
#  Copyright: (c) 2025 HYPERI PTY LIMITED
```

**See `CODE-HEADER.md` for complete header format.**

---

## Third-Party Dependencies

### Acceptable Licenses

| License | Status |
|---------|--------|
| MIT, BSD-2-Clause, BSD-3-Clause, ISC | ✅ Always OK |
| Apache-2.0 | ✅ Always OK |
| Unlicense, CC0, 0BSD | ✅ Always OK |
| MPL-2.0 | ⚠️ OK if you don't modify MPL files |
| LGPL-2.1, LGPL-3.0 | ⚠️ Dynamic linking only, avoid in Go |
| GPL-2.0, GPL-3.0 | ❌ Never (viral copyleft) |
| AGPL-3.0 | ❌ Never (network copyleft) |
| SSPL, BSL | ❌ Never |
| No license | ❌ Never (all rights reserved) |

### License Audit in CI

```bash
# Rust
cargo deny check licenses

# Python
pip-licenses --fail-on="GPL;AGPL"

# Node.js
npx license-checker --failOn "GPL;AGPL"

# Go
go-licenses check ./...
```

---

## Maintenance

**Never edit LICENSE files in individual repos.** Update the source and propagate:

1. Edit files in `hyperi-licensing/github-template/` (private repo)
2. Sync to CI: `cp hyperi-licensing/github-template/* ci/templates/licensing/`
3. Commit and push to both repos
4. Projects get updates on next `ci/attach.sh --init licensing`

---

## Contact

**Licensor:** HYPERI PTY LIMITED (ABN 31 622 581 748)

**Commercial licensing:** <sales@hyperi.com.au>

---

## For AI Code Assistants

### Default Behaviour

1. Use FSL-1.1-ALv2 for all new projects
2. Copy template files via `ci/attach.sh --init licensing`
3. Never create custom LICENSE files - always use the template

### When Creating New Projects

```bash
# Copy standard files via CI
ci/attach.sh --init licensing

# Set license in project config
# Cargo.toml: license = "FSL-1.1-ALv2"
# pyproject.toml: license = { text = "FSL-1.1-ALv2" }
```

### Dependency License Check

Before adding any dependency:

1. Check its license
2. If GPL/AGPL/SSPL/no-license → find alternative
3. If permissive (MIT/BSD/Apache) → proceed
