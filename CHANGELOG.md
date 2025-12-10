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


### ⚠ BREAKING CHANGES

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
* add semantic-release automation ([68c3614](https://github.com/hypersec-io/ai/commit/68c3614deecc59bfa1ae8258b02a4ad1186c8c6e))
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
