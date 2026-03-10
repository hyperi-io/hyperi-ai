---
name: repo-naming-standards
description: Repository naming conventions for all HyperI projects. Prefix-based scheme by product scope.
universal: true
---

# Repository Naming Standards

Naming conventions for all HyperI repositories.

---

## Prefixes by Product / Scope

| Prefix | Scope | Examples |
|---|---|---|
| `hyperi-*` | Company-wide, product-agnostic | `hyperi-rustlib`, `hyperi-pylib`, `hyperi-ai` |
| `dfe-*` | DFE product | `dfe-ingest`, `dfe-api`, `dfe-developer` |
| `edge-*` | Edge Stream Hub | `edge-collector`, `edge-gateway` |

### Rules

- **`hyperi-*`** — use for shared libraries, internal tooling, or anything that serves the whole company regardless of product.
- **`dfe-*`** — use for anything that is DFE-specific.
- **`edge-*`** — use for anything that belongs to the Edge Stream Hub product.
- If a repo spans two products, favour the more general prefix (i.e. `hyperi-*`).

---

## External / Fork Repositories

Retain the upstream name for external projects and forks (e.g. a ClickHouse fork stays `ClickHouse`). This makes the origin obvious and avoids confusion when syncing upstream.

Exceptions may be discussed case-by-case; use common sense.

---

## General Rules

- Lowercase, hyphen-separated. No underscores, no camelCase.
- Be descriptive but concise — 1–3 words after the prefix.
- Avoid redundant words like `-service`, `-app`, `-repo`.

---

## Examples

```
hyperi-ai          ✅ company-wide AI standards/tooling
hyperi-rustlib     ✅ company-wide Rust shared library
dfe-ingest         ✅ DFE-specific ingestion service
dfe-api            ✅ DFE API
edge-collector     ✅ Edge Stream Hub collector
edge-gateway       ✅ Edge Stream Hub gateway
ClickHouse         ✅ external fork — keep upstream name
my-service         ❌ no prefix
dfe_ingest         ❌ underscore instead of hyphen
```
