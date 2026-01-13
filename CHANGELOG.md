## [1.10.0](https://github.com/hypersec-io/ai/compare/1.9.5...1.10.0) (2026-01-13)


### Features

* implement SSoT for STATE.md and TODO.md ([a9bc8e0](https://github.com/hypersec-io/ai/commit/a9bc8e02fd294d082715eca54928f8da414dcdb5))

## [1.9.5](https://github.com/hypersec-io/ai/compare/1.9.4...1.9.5) (2026-01-13)


### Bug Fixes

* auto-update ai submodule on /load with reload detection ([57e60b4](https://github.com/hypersec-io/ai/commit/57e60b46d9d9968d17ff9be48cc618ea4611651a))

## [1.9.4](https://github.com/hypersec-io/ai/compare/1.9.3...1.9.4) (2026-01-13)


### Bug Fixes

* add markdownlint config and fix lint errors across all docs ([9be3f4f](https://github.com/hypersec-io/ai/commit/9be3f4f4565727bfd7b30e3d1acde3b399cb6829))

## [1.9.3](https://github.com/hypersec-io/ai/compare/1.9.2...1.9.3) (2026-01-13)


### Bug Fixes

* add rebase-before-push guidance for semantic-release sync ([f94411b](https://github.com/hypersec-io/ai/commit/f94411b20d48afbb1b6ac890193182b2d4b40140))

## [1.9.2](https://github.com/hypersec-io/ai/compare/1.9.1...1.9.2) (2026-01-13)


### Bug Fixes

* clarify commit approval flow with Yes/No/Change options ([d852415](https://github.com/hypersec-io/ai/commit/d85241563654c7339debcce328cd17e5d356da3c))

## [1.9.1](https://github.com/hypersec-io/ai/compare/1.9.0...1.9.1) (2026-01-13)


### Bug Fixes

* add execute permissions to agent scripts ([5215fc6](https://github.com/hypersec-io/ai/commit/5215fc6e40fa5c7f3af378d07fa57b62297784d5))

## [1.9.0](https://github.com/hypersec-io/ai/compare/1.8.2...1.9.0) (2026-01-12)


### ⚠ BREAKING CHANGES

* Agent scripts moved from root to agents/ directory.
copilot.sh removed (use codex.sh). attach.sh now auto-detects agents.

### Features

* reorganise agent scripts with CLI detection and VS Code 1.108 support ([760db60](https://github.com/hypersec-io/ai/commit/760db603011d6318c8d626b431db359a9564d77e))


### Bug Fixes

* add PKI/TLS standards doc ([1dab840](https://github.com/hypersec-io/ai/commit/1dab840728efa38985a2111a910535042ada9149))

## [1.9.0](https://github.com/hypersec-io/ai/compare/1.8.2...1.9.0) (2026-01-12)


### Features

* reorganise agent scripts into agents/ directory with CLI detection ([#TBD](https://github.com/hypersec-io/ai/commit/TBD))
* add auto-detection of installed AI agents in attach.sh ([#TBD](https://github.com/hypersec-io/ai/commit/TBD))
* add VS Code 1.108 Agent Skills support (.github/skills/) ([#TBD](https://github.com/hypersec-io/ai/commit/TBD))
* add codex.sh for OpenAI Codex CLI with VS Code settings merge ([#TBD](https://github.com/hypersec-io/ai/commit/TBD))


### Breaking Changes

* Agent scripts moved from root to agents/ directory
* copilot.sh removed (replaced by codex.sh)
* attach.sh now auto-detects agents (use --no-agent to skip)
* Deprecated flags: --claude, --cursor, --gemini (use --agent NAME)


### New CLI Options

* `--agent NAME` - Setup specific agent (claude, cursor, gemini, codex)
* `--all-agents` - Setup all installed agents
* `--no-agent` - Skip agent detection entirely


## [1.8.2](https://github.com/hypersec-io/ai/compare/1.8.1...1.8.2) (2025-12-29)


### Bug Fixes

* add Helm repos and install commands for Bitnami replacements ([fe29d4c](https://github.com/hypersec-io/ai/commit/fe29d4c22a423e6608b26b902ea691573e3e3a8f))

## [1.8.1](https://github.com/hypersec-io/ai/compare/1.8.0...1.8.1) (2025-12-29)


### Bug Fixes

* add Bitnami prohibition and Gateway API policy to container standards ([1bdaed1](https://github.com/hypersec-io/ai/commit/1bdaed16da347e4d88e48d098d8ddb6873ae647c))

## [1.8.0](https://github.com/hypersec-io/ai/compare/1.7.5...1.8.0) (2025-12-28)


### Features

* add C++ standards and expand Rust guide for PB-scale data pipelines ([a63b870](https://github.com/hypersec-io/ai/commit/a63b870955f0067b1bdb297562d56b36ac8f500b))

## [1.7.5](https://github.com/hypersec-io/ai/compare/1.7.4...1.7.5) (2025-12-26)


### Bug Fixes

* remove all git hooks from AI project (owned by CI) ([59e8222](https://github.com/hypersec-io/ai/commit/59e82221158de4c4d4de4f3f5dd9725674d19df4))

## [1.7.4](https://github.com/hypersec-io/ai/compare/1.7.3...1.7.4) (2025-12-26)


### Bug Fixes

* remove duplicate hooks, keep only commit-msg for AI attribution ([6ec3674](https://github.com/hypersec-io/ai/commit/6ec3674a5e1142d5481735bf720f77e6f86c6251))

## [1.7.3](https://github.com/hypersec-io/ai/compare/1.7.2...1.7.3) (2025-12-24)


### Bug Fixes

* add skills support and date check to /load command ([86fef8a](https://github.com/hypersec-io/ai/commit/86fef8a558ec920ec234ed77ea47c668840808bd))

## [1.7.2](https://github.com/hypersec-io/ai/compare/1.7.1...1.7.2) (2025-12-17)


### Bug Fixes

* replace ISSUE-STANDARD.md with LINEAR-TICKETS.md ([65f7d43](https://github.com/hypersec-io/ai/commit/65f7d434867dfdc99b752baee985f6b2abbb6935))


### Documentation

* add greenfield instructions to QUICKSTART ([c05f773](https://github.com/hypersec-io/ai/commit/c05f773f3f62895c882886574bff684410b9e464))

## [1.7.1](https://github.com/hypersec-io/ai/compare/1.7.0...1.7.1) (2025-12-16)


### Bug Fixes

* add AI repo URL remediation to attach.sh ([c1d4b96](https://github.com/hypersec-io/ai/commit/c1d4b9685f73320d6c0bf9d5d09523e16eda4168))


### Documentation

* add QUICKSTART.md to root, simplify README ([dfbcedb](https://github.com/hypersec-io/ai/commit/dfbcedb16a346c15b09e52df397d2077c3e090f2))

## [1.7.0](https://github.com/hypersec-io/ai/compare/1.6.4...1.7.0) (2025-12-16)


### Features

* source org config from CI for URL configuration ([c99924a](https://github.com/hypersec-io/ai/commit/c99924ae139e5ebbf57e8e65dc592ef64ab0c906))

## [1.6.4](https://github.com/hypersec-io/ai/compare/1.6.3...1.6.4) (2025-12-16)


### Bug Fixes

* auto-fix deprecated CI repo URLs (hyperci, hs-ci) ([d0e0f99](https://github.com/hypersec-io/ai/commit/d0e0f9974cbd9828ceaa3265e68d170fe4a8e1a0))

## [1.6.3](https://github.com/hypersec-io/ai/compare/1.6.2...1.6.3) (2025-12-16)


### Bug Fixes

* enhanced submodule remediation based on real project configs ([844d5d7](https://github.com/hypersec-io/ai/commit/844d5d78402ced96685e3eaf31ab9f0d33db1c45))

## [1.6.2](https://github.com/hypersec-io/ai/compare/1.6.1...1.6.2) (2025-12-16)


### Bug Fixes

* improve submodule remediation in attach.sh ([a7c21b9](https://github.com/hypersec-io/ai/commit/a7c21b99b84982d40e75ddb3444c9f0a4b5c475d))

## [1.6.1](https://github.com/hypersec-io/ai/compare/1.6.0...1.6.1) (2025-12-16)


### Refactoring

* simplify attach workflow to submodule-first approach ([cb93785](https://github.com/hypersec-io/ai/commit/cb93785a2d8c0c21bcffd784c09cd7d7697f3e94))


### Documentation

* add TL;DR one-liner commands at top of README ([1cf6812](https://github.com/hypersec-io/ai/commit/1cf68121ceecdc7ec7d0c8a27022f0fac2530c34))

## [1.6.0](https://github.com/hypersec-io/ai/compare/1.5.0...1.6.0) (2025-12-16)


### Features

* add system-wide managed-settings.json installation ([ef8e45e](https://github.com/hypersec-io/ai/commit/ef8e45ec73a554fc9ca54155b586851369e2af84))

## [1.5.0](https://github.com/hypersec-io/ai/compare/1.4.3...1.5.0) (2025-12-16)


### Features

* rename scripts for consistency with CI repo ([e8a1488](https://github.com/hypersec-io/ai/commit/e8a1488334131e3c3e184072b622cf13e7247159))

## [1.4.3](https://github.com/hypersec-io/ai/compare/1.4.2...1.4.3) (2025-12-16)


### Bug Fixes

* sync settings.json template with current permissions ([4371a0f](https://github.com/hypersec-io/ai/commit/4371a0fb99fc9ae2c1b2da3d882a344b2718245b))

## [1.4.2](https://github.com/hypersec-io/ai/compare/1.4.1...1.4.2) (2025-12-15)


### Bug Fixes

* add .env file quoting standard - always quote values ([7365b52](https://github.com/hypersec-io/ai/commit/7365b52de023335ee9d9d1c9d80c7a2eba97d391))

## [1.4.1](https://github.com/hypersec-io/ai/compare/1.4.0...1.4.1) (2025-12-15)


### Bug Fixes

* use relative symlinks instead of copying in claude-code.sh ([3a99cb1](https://github.com/hypersec-io/ai/commit/3a99cb19ca2061ca5975279fd765df30283d3e71))

## [1.4.0](https://github.com/hypersec-io/ai/compare/1.3.8...1.4.0) (2025-12-11)


### Features

* enhance session state management and Claude Code permissions ([fdd6c4f](https://github.com/hypersec-io/ai/commit/fdd6c4f3c512b327dbb4656ad80f04d2b6d50303))

## [1.3.8](https://github.com/hypersec-io/ai/compare/1.3.7...1.3.8) (2025-12-10)


### Bug Fixes

* correct standards paths for attached submodule usage ([29bfcd7](https://github.com/hypersec-io/ai/commit/29bfcd707f886227f977a18fc175a6f27c67b42c))

## [1.3.7](https://github.com/hypersec-io/ai/compare/1.3.6...1.3.7) (2025-12-05)


### Bug Fixes

* require uv for all Python work ([4497318](https://github.com/hypersec-io/ai/commit/4497318ca8a7ab2a1e8abbdd51389fd565070739))

## [1.3.6](https://github.com/hypersec-io/ai/compare/1.3.5...1.3.6) (2025-12-05)


### Bug Fixes

* add CLI utility preferences for modern tools ([88a4cc4](https://github.com/hypersec-io/ai/commit/88a4cc4ccc4fbe6948849310a52b39bffc8bf98c))

## [1.3.5](https://github.com/hypersec-io/ai/compare/1.3.4...1.3.5) (2025-12-04)


### Bug Fixes

* clarify no mocks policy - internal vs external dependencies ([931750e](https://github.com/hypersec-io/ai/commit/931750e346c1e8ce55786e4efecc4a76e51034e8))

## [1.3.4](https://github.com/hypersec-io/ai/compare/1.3.3...1.3.4) (2025-12-01)


### Bug Fixes

* require main as default branch, never master ([5d55ee9](https://github.com/hypersec-io/ai/commit/5d55ee9408e48aeb29d327ce95bdc27ea42b778c))

## [1.3.3](https://github.com/hypersec-io/ai/compare/1.3.2...1.3.3) (2025-11-30)


### Bug Fixes

* correct command filename to load.md and add start.md cleanup ([a2692a2](https://github.com/hypersec-io/ai/commit/a2692a2987111aa6f58e8a912b0be8e5474104a4))

## [1.3.2](https://github.com/hypersec-io/ai/compare/1.3.1...1.3.2) (2025-11-30)


### Bug Fixes

* rename /start command to /load ([e883b9c](https://github.com/hypersec-io/ai/commit/e883b9c79c218bb7b0a50d7ea818dd4440314547))

## [1.3.1](https://github.com/hypersec-io/ai/compare/1.3.0...1.3.1) (2025-11-29)


### Bug Fixes

* remove outdated ci/ references from standards ([09cbdfd](https://github.com/hypersec-io/ai/commit/09cbdfd1a60f52d92863d8d1e566ca942c490048))

## [1.3.0](https://github.com/hypersec-io/ai/compare/1.2.7...1.3.0) (2025-11-29)


### BREAKING CHANGES

* Standards directory structure completely reorganised.
Projects using this module must update any direct file references.
Old paths like standards/python/PEP8.md are now standards/languages/PYTHON.md.

### Features

* reorganise standards into languages/ and infrastructure/ directories ([084ae29](https://github.com/hypersec-io/ai/commit/084ae29799153e1b0167ae4bcd0c4d1ce9b0184f))

## [1.2.7](https://github.com/hypersec-io/ai/compare/1.2.6...1.2.7) (2025-11-29)


### Bug Fixes

* rename STANDARDS-CONTEXT-SMALL.md to STANDARDS-QUICKSTART.md ([ffab725](https://github.com/hypersec-io/ai/commit/ffab725c91a119fa1cac3f3bd94919d86dbf1c94))

## [1.2.6](https://github.com/hypersec-io/ai/compare/1.2.5...1.2.6) (2025-11-29)


### Bug Fixes

* add identical context window decision to all three files ([8602a9e](https://github.com/hypersec-io/ai/commit/8602a9e3adb7376a0f8021fa528e6faa5193a5e4))

## [1.2.5](https://github.com/hypersec-io/ai/compare/1.2.4...1.2.5) (2025-11-29)


### Bug Fixes

* move context window selection to start.md only ([a4f0a4f](https://github.com/hypersec-io/ai/commit/a4f0a4f402113584801f9abed220abe247151eaa))


### Documentation

* add STANDARDS-CONTEXT-SMALL.md and context window branching ([b1f7d33](https://github.com/hypersec-io/ai/commit/b1f7d3341fa28d8ed87a2c2e5dc5634d5e067c78))

## [1.2.4](https://github.com/hypersec-io/ai/compare/1.2.3...1.2.4) (2025-11-25)

### Bug Fixes

* remove deprecated code and 1M context window options ([5cc3a4d](https://github.com/hypersec-io/ai/commit/5cc3a4dead08d26ae83530420d7b8f9ff42bd946))

## [1.2.3](https://github.com/hypersec-io/ai/compare/1.2.2...1.2.3) (2025-11-24)

### Bug Fixes

* remove optional gitignore enforcement for submodules ([9090e37](https://github.com/hypersec-io/ai/commit/9090e3708417ad0a791165ce64164a1795fedc3b))

## [1.2.2](https://github.com/hypersec-io/ai/compare/1.2.1...1.2.2) (2025-11-20)

### Bug Fixes

* update all standards paths to use $AI_ROOT variable ([65ef30d](https://github.com/hypersec-io/ai/commit/65ef30db0de864a353764f368108cf9ddbd9a6c3))

## [1.2.1](https://github.com/hypersec-io/ai/compare/1.2.0...1.2.1) (2025-11-20)

### Bug Fixes

* correct markdown link paths in AI-GUIDELINES.md ([0949f1b](https://github.com/hypersec-io/ai/commit/0949f1b0b4733a7361b45c4ed483e7988e9fa71a))

## [1.2.0](https://github.com/hypersec-io/ai/compare/1.1.1...1.2.0) (2025-11-20)

### Features

* add copilot, cursor, and gemini support ([96b9d11](https://github.com/hypersec-io/ai/commit/96b9d1196dd66f516b59a9b28c1fe952fb29b474))

## [1.1.1](https://github.com/hypersec-io/ai/compare/1.1.0...1.1.1) (2025-11-20)

### Refactoring

* simplify git standards and rename to GIT.md ([541be82](https://github.com/hypersec-io/ai/commit/541be82dba6628d5bbcef89016cb3a8457db9f8f))

## [1.1.0](https://github.com/hypersec-io/ai/compare/1.0.2...1.1.0) (2025-11-20)

### Features

* add git hooks for standards enforcement ([ab92dac](https://github.com/hypersec-io/ai/commit/ab92dac513f2d796d4ccb4a4db8f55ac32083ac7))

## [1.0.2](https://github.com/hypersec-io/ai/compare/1.0.1...1.0.2) (2025-11-20)

### Bug Fixes

* use portable temp directory for CI tests ([832cd66](https://github.com/hypersec-io/ai/commit/832cd664bfd380c7c2ed14e47e879d7e840b186e))

## [1.0.1](https://github.com/hypersec-io/ai/compare/1.0.0...1.0.1) (2025-11-20)

### Bug Fixes

* correct branch naming format in CONTRIBUTING.md ([2c2def2](https://github.com/hypersec-io/ai/commit/2c2def2c2d729389f2c0846aae15ed7efcefe9c9))

### Documentation

* consolidate and clarify documentation ([8672a22](https://github.com/hypersec-io/ai/commit/8672a22b89782a1007184d2ddbfd7faffc635476))

## 1.0.0 (2025-11-20)

### Features

* add 1M context window support to claude-code.sh ([3916aa0](https://github.com/hypersec-io/ai/commit/3916aa0ddc0529075ce173d19c74784d606e9971))
* add semantic-release automation ([68c3614](https://github.com/hypersec-io/ai/commit/68c3614deecc59bfa1ae8258b02a4ad1186c8e6e))
* complete MVP implementation ([448240c](https://github.com/hypersec-io/ai/commit/448240c87345f5262ffac452d57e3ed2b28b02cd))
* initial ai repository with standards and templates ([57ae6df](https://github.com/hypersec-io/ai/commit/57ae6df4a2ba9d8870ba278afe210104e84eb920))

### Bug Fixes

* add missing npm dependency and update description ([c8bdae5](https://github.com/hypersec-io/ai/commit/c8bdae5e6529717f174e8e0306b939c50aa54afb))
* add TODO.md template and fix gitignore ([1bb2b62](https://github.com/hypersec-io/ai/commit/1bb2b623a6c79a02685c7a1e4b7d2454086b070c))
* remove hardcoded versions from scripts and docs ([9be2308](https://github.com/hypersec-io/ai/commit/9be2308cf9acba8fe5a4ebd0bf2ae7a52cd0b6c5))

### Documentation

* add migration documentation ([67d0189](https://github.com/hypersec-io/ai/commit/67d018995a956d3a1bc1d0851d2e6fed507b554d))

# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are automated via [semantic-release](https://github.com/semantic-release/semantic-release).
