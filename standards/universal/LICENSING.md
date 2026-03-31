---
name: licensing-standards
description: HyperI licensing policy — FSL-1.1-ALv2 for all projects. No GPL/AGPL/SSPL dependencies. AI/ML training restrictions.
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
| `LICENSE` | FSL-1.1-ALv2 license with Australian law notice and AI/ML restriction |
| `AI-TRAINING-POLICY.md` | AI / Machine Learning training restriction policy |
| `COMMERCIAL.md` | Commercial licensing requirements and corporate group rules |
| `CONTRIBUTING.md` | Contribution guidelines (DCO, Conventional Commits) |
| `SECURITY.md` | Vulnerability disclosure policy |
| `robots.txt` | AI training crawler blocklist (permits standard search indexing) |

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
| SPDX (with AI restriction) | `LicenseRef-FSL-1.1-ALv2-NoAI` |
| Copyright | `(c) YYYY HYPERI PTY LIMITED` |
| Commercial Use | Requires commercial license |
| Internal Use | Permitted without license |
| AI/ML Training | **Not permitted** without written consent |
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

## AI / Machine Learning Training Restriction

All HyperI repositories include an explicit AI/ML training restriction in
the LICENSE file and a standalone `AI-TRAINING-POLICY.md`.

### What Is Prohibited

Without prior written consent from HYPERI PTY LIMITED:

- Direct training of ML models on the source code, documentation, or metadata
- Fine-tuning or transfer learning using any part of the Software
- Inclusion in any dataset, corpus, or data pipeline for ML training
- RAG systems that index or retrieve from the Software
- AI-assisted reverse engineering to replicate functionality
- NLP training, benchmarking, or evaluation using the Software

### What Is Permitted

- **Search engine indexing** — standard web crawlers for search results
- **Human reading and review** — individuals studying the code
- **AI-assisted development** — using AI coding tools (Claude Code, Copilot,
  Cursor, etc.) to write code that interacts with or extends the Software,
  provided the Software itself is not used as training data for those tools
- All uses permitted under the LICENSE (internal use, education, etc.)

### AI Training Crawler Blocking (robots.txt)

Every repository includes a `robots.txt` that blocks known AI training
crawlers while permitting standard search engines:

| Blocked | Permitted |
|---------|-----------|
| GPTBot, ClaudeBot, Google-Extended, CCBot | Googlebot, Bingbot, DuckDuckBot |
| Meta, Bytespider, DeepSeekBot, PetalBot | YandexBot, Slurp, Baiduspider |
| All AI training/data collection crawlers | Standard search engine crawlers |

**Important:** The `robots.txt` in the repo root is a policy declaration.
It only becomes functionally active if the content is served on a web domain
(e.g., GitHub Pages, docs sites). GitHub.com serves its own `robots.txt` at
`github.com/robots.txt` — the in-repo file does not affect access to repos
via the GitHub platform, API, or git protocol.

### GitHub Copilot Org Settings

HyperI uses **Copilot Business** (exempt from GitHub AI training data
collection). Org-level settings at
`https://github.com/organizations/hyperi-io/settings/copilot/policies`:

| Setting | Value | Reason |
|---------|-------|--------|
| Suggestions matching public code | **Block** | Avoid copyleft code leaking in |
| Content exclusion | Sensitive file patterns | Prevent Copilot from reading secrets |

Contributors using Copilot on personal (Free/Pro) plans must opt out of AI
training at `https://github.com/settings/copilot/features` — disable
"Allow GitHub to use my data for AI model training" (before April 24, 2026).

### Requesting an AI/ML Training Exception

**Email:** sales@hyperi.io — include your organisation, intended use, specific
Materials, the AI system, and whether the use is commercial or non-commercial.

---

## AI Code Assistants — Accessing HyperI Repos

### How robots.txt Affects AI Coding Agents

**It doesn't.** The in-repo `robots.txt` only affects web crawlers hitting a
domain that serves the file. When you use AI coding tools to work on HyperI
code, they access repos through channels that do not check `robots.txt`:

| Access Method | robots.txt Applies? | Notes |
|---------------|---------------------|-------|
| `gh` CLI / GitHub API | **No** | Authenticated API access |
| `git clone` / `git pull` | **No** | Git protocol, not HTTP crawling |
| Local file reads (Claude Code, Cursor) | **No** | Reading from local filesystem |
| `WebFetch` on github.com URLs | **Possibly** | Depends on crawler UA compliance |

**If an AI agent needs to fetch a GitHub URL and gets blocked**, use the `gh`
CLI instead:

```bash
# Instead of WebFetch on a GitHub URL:
gh api repos/hyperi-io/REPO/contents/PATH --jq '.content' | base64 -d

# View a file from a specific branch:
gh api repos/hyperi-io/REPO/contents/PATH?ref=BRANCH --jq '.content' | base64 -d

# View a PR:
gh pr view 123 --repo hyperi-io/REPO

# View issue:
gh issue view 456 --repo hyperi-io/REPO
```

### Default Behaviour for AI Assistants

1. **Access repos via `gh` CLI or local filesystem** — never via web scraping
2. Use FSL-1.1-ALv2 for all new projects
3. Copy template files via `ci/attach.sh --init licensing`
4. Never create custom LICENSE files — always use the template
5. Include `AI-TRAINING-POLICY.md` and `robots.txt` in all new repos

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
license = "LicenseRef-FSL-1.1-ALv2-NoAI"
license-files = ["LICENSE", "COMMERCIAL.md", "AI-TRAINING-POLICY.md"]
classifiers = ["License :: Other/Proprietary License"]

[project.urls]
"License" = "https://github.com/hyperi-io/licensing/blob/main/LICENSE"
"AI Training Policy" = "https://github.com/hyperi-io/licensing/blob/main/AI-TRAINING-POLICY.md"
"Commercial Licensing" = "https://github.com/hyperi-io/licensing/blob/main/COMMERCIAL.md"
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

**Commercial licensing:** <sales@hyperi.io>
**AI/ML licensing enquiries:** <sales@hyperi.io>

---

## For AI Code Assistants

### Default Behaviour

1. Use FSL-1.1-ALv2 for all new projects
2. Copy template files via `ci/attach.sh --init licensing`
3. Never create custom LICENSE files — always use the template
4. Include `AI-TRAINING-POLICY.md` and `robots.txt` in all repos

### When Creating New Projects

```bash
# Copy standard files via CI (includes AI policy and robots.txt)
ci/attach.sh --init licensing

# Set license in project config
# Cargo.toml: license = "FSL-1.1-ALv2"
# pyproject.toml: license = "LicenseRef-FSL-1.1-ALv2-NoAI"
```

### Dependency License Check

Before adding any dependency:

1. Check its license
2. If GPL/AGPL/SSPL/no-license → find alternative
3. If permissive (MIT/BSD/Apache) → proceed
