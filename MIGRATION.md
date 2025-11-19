# Migration from hs-ci to Separate ai Repository

**Date:** 2025-11-20
**Status:** Phase 1 Complete (ai repo created)

---

## Overview

Split AI/code standards from CI infrastructure into separate repositories:
- **ai** - Standards, documentation, AI guidance (this repo)
- **ci** - Build/test/release automation, git hooks

---

## Phase 1: Create ai Repository ✅

**Completed:**
1. Created `/projects/ai` directory structure
2. Copied all standards from `hs-ci/docs/standards/`:
   - `ai/` (AI-PRINCIPLES.md, TOKEN-ENGINEERING.md)
   - `code-assistant/` (AI-GUIDELINES.md, COMMON.md, HS-CI.md, PYTHON.md)
   - `common/` (10 standards files)
   - `python/` (3 standards files)
   - `STANDARDS.md` (root)
3. Copied templates from `hs-ci/modules/common/templates/`:
   - `settings.json` (Claude Code config)
   - `start.md` and `save.md` (slash commands)
   - `STATE.md` (project state template)
   - `SETTINGS-PROFILES.md` (AI profiles)
4. Created README, LICENSE, .gitignore
5. Initial commit: 28 files, 10,225 lines

**Repository location:** `/projects/ai`
**Remote:** https://github.com/hypersec-io/ai (to be created)

---

## Phase 2: Update hs-ci Repository (TODO)

**Actions needed in hs-ci:**
1. Remove `docs/standards/` directory (moved to ai repo)
2. Remove AI templates from `modules/common/templates/`:
   - settings.json
   - start.md, save.md
   - STATE.md (partial - keep CI marker section)
   - SETTINGS-PROFILES.md
3. Update bootstrap scripts that reference standards
4. Update documentation references
5. Tag as v2.0.0 (breaking change - standards moved)

**What stays in hs-ci:**
- All `modules/` (bootstrap.d/, run.d/ scripts)
- `bootstrap` and `run` orchestrators
- Git hooks
- Non-AI templates (.gitignore, .gitleaks.toml, pyproject.toml, ci.yaml, LICENSE files, .env.sample)

---

## Phase 3: Update Consumer Projects (TODO)

**For hs-lib and other projects:**

1. **Add ai submodule:**
   ```bash
   git submodule add https://github.com/hypersec-io/ai.git ai
   ```

2. **Update ci submodule:**
   ```bash
   cd ci
   git fetch origin
   git checkout v2.0.0  # New version without standards
   cd ..
   git add ci
   ```

3. **Update references:**
   - `.claude/commands/start.md` → read from `ai/docs/standards/`
   - Bootstrap scripts → copy templates from `ai/templates/`
   - STATE.md → reference `ai/docs/standards/` instead of `ci/docs/standards/`

4. **Test:**
   - `/start` command loads standards correctly
   - Bootstrap copies templates from ai repo
   - CI functionality unchanged

---

## Benefits of Separation

**Versioning:**
- AI standards can evolve independently from CI infrastructure
- Projects can update standards without updating CI scripts
- Clearer semantic versioning (standards vs automation)

**Clarity:**
- Single responsibility: ai = standards, ci = automation
- Easier to understand what each repo does
- Documentation separate from tooling

**Reusability:**
- Standards can be used without CI infrastructure
- AI guidance available to non-Python projects
- Templates shareable across organizations

---

## Next Steps

1. **Create GitHub repo:** https://github.com/hypersec-io/ai
2. **Push initial commit:**
   ```bash
   cd /projects/ai
   git remote add origin https://github.com/hypersec-io/ai.git
   git push -u origin main
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. **Update hs-ci:** Remove standards, tag v2.0.0
4. **Update hs-lib:** Add ai submodule, update references
5. **Test:** Verify hs-lib works with both submodules

---

## File Manifest

**28 files extracted from hs-ci:**

Standards (20 files):
- docs/standards/STANDARDS.md
- docs/standards/ai/ (2 files)
- docs/standards/code-assistant/ (4 files)
- docs/standards/common/ (10 files)
- docs/standards/python/ (3 files)

Templates (5 files):
- templates/claude-code/settings.json
- templates/claude-code/commands/start.md
- templates/claude-code/commands/save.md
- templates/STATE.md
- templates/SETTINGS-PROFILES.md

Meta (3 files):
- README.md
- LICENSE
- .gitignore

---

**Status:** Ready for GitHub remote creation and Phase 2 (hs-ci cleanup).
