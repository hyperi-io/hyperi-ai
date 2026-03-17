---
paths:
  - "**/*.sql"
detect_markers:
  - "glob:*.sql"
  - "deep_glob:*.sql"
source: languages/SQL-CLICKHOUSE.md
---

<!-- override: manual -->
## Schema Design

- ENGINE: Use `ReplicatedMergeTree` (self-hosted) or `SharedMergeTree` (Cloud) as default. Plain `MergeTree` for dev only.
- `ReplacingMergeTree(version)` for dedup/CDC, `SummingMergeTree` for additive metrics, `AggregatingMergeTree` for MV targets with `-State/-Merge`, `VersionedCollapsingMergeTree(sign, ver)` for mutable data.
- ORDER BY is immutable, determines physical layout and sparse index. 3–5 columns max.
- Low cardinality first → most-filtered → timestamp last. Never UUID or high-cardinality first.
- ❌ `ORDER BY (_uuid, _org_id, severity, _timestamp)` — unique col first = full scan
- ✅ `ORDER BY (_org_id, severity, _timestamp_load)` — tenant→severity→time
- PARTITION BY is for data management (TTL drops), NOT query optimization. Monthly default: `toYYYYMM(ts)`.
- TTL column MUST equal PARTITION BY column. Always set `ttl_only_drop_parts = 1`.
- ❌ `PARTITION BY toYYYYMM(ingest_ts)` with `TTL event_ts + INTERVAL 90 DAY` — row-by-row rewrite
- ✅ `PARTITION BY toYYYYMM(ingest_ts)` with `TTL ingest_ts + INTERVAL 90 DAY DELETE`
- Never partition by high-cardinality columns. No partition for tables < few GB. Daily only if 10+ GB/day.
- Codecs: `DoubleDelta, LZ4` for timestamps/monotonic IDs; `Gorilla, ZSTD(1)` for floats; `ZSTD(3)` for high-entropy strings; `LZ4` for LowCardinality. ZSTD levels above 3 rarely help.
- Skip indexes work on granules (~8192 rows), not rows. Only useful when column correlates with ORDER BY. Always verify with `EXPLAIN PLAN indexes = 1`.
- After `ALTER TABLE ADD INDEX`, run `ALTER TABLE MATERIALIZE INDEX` for existing data.
- Text index (GA v25.10): deterministic inverted index, row-level, 45x faster. Use `hasToken`/`hasAllTokens`/`hasAnyTokens`. Not used in PREWHERE (open issue).

## Data Types

- `LowCardinality(String)` for < ~10K distinct values — 5–10x compression/speed gain. Above ~100K it hurts.
- `Nullable(T)` adds UInt8 bitmap: 2x storage, 2x slower queries (229M→98M rows/s). Use defaults (`''`, `0`) unless NULL has genuine semantic meaning.
- Never Nullable in ORDER BY, PARTITION BY, or primary key columns.
- `FixedString(N)` only for known fixed-length data (e.g., `FixedString(2)` for ISO country codes).
- Always declare timezone: `DateTime64(3, 'UTC')`. Use IANA names, never abbreviations.
- JSON type (GA v25.3): columnar sub-columns per path. Use typed path hints for known paths. `max_dynamic_paths = 1024`. Don't put JSON paths in ORDER BY.
- `Enum8`/`Enum16` only when strict value enforcement needed; otherwise prefer `LowCardinality(String)`.
- `Float64` is non-deterministic for sums. Use `Decimal64(N)` for money/exact arithmetic.

## Query Patterns

- **Never `SELECT *`** — name columns explicitly. Each column = separate file on disk.
- **JOINs**: fact table LEFT, dimension table RIGHT. Right table loaded into hash table in memory. Types must match exactly in JOIN conditions (no implicit cast).
- Prefer `IN`, dictionaries (`dictGet`), or `ANY JOIN` over full JOINs when possible.
- **GROUP BY over DISTINCT** — 4.5x faster on large tables. Exception: `DISTINCT` + `LIMIT` short-circuits.
- **CTEs are macros** — re-executed at every reference. Multi-reference CTEs: use `CREATE TEMPORARY TABLE`.
- **LIMIT BY** for top-N per group instead of `row_number() OVER (PARTITION BY ...)`.
- **Approximate functions**: `uniq()` over `COUNT(DISTINCT)` (20x faster, ~2% error); `quantile()` over `quantileExact()`.
- **`ifNull()` over `coalesce()`** — 3.4x faster.
- `toStartOfHour(ts)` over `DATE_TRUNC('hour', ts)`.
- `position(haystack, needle)` — args reversed from PostgreSQL.
- **Never wrap columns in functions in WHERE** — breaks index usage.
- ❌ `WHERE toDate(timestamp) = '2026-01-15'`
- ✅ `WHERE timestamp >= '2026-01-15' AND timestamp < '2026-01-16'`
- **CASE/if()/multiIf() evaluate ALL branches** (vectorized). Use `nullIf()` or `*OrZero` for safe division.
- ❌ `CASE WHEN total = 0 THEN 0 ELSE hits / total END`
- ✅ `hits / nullIf(total, 0)` or `intDivOrZero(hits, total)`
- **Keyset pagination**, not OFFSET (O(n)). Add tiebreaker column for stable sort.
- Regex is last resort. Use native functions: `hasToken`, `startsWith`, `position`, `domain()`, `splitByChar`, `multiSearchAny`.
- `PREWHERE` with `FINAL` is a correctness bug — newest version filtered out, old version survives. Use `WHERE` after `FINAL`.
- Correlated subqueries: still Beta, can crash. Rewrite as JOINs.
- `GLOBAL JOIN`/`GLOBAL IN` required for distributed subqueries to avoid silently incomplete results.

## EXPLAIN — Always Verify

- `EXPLAIN PLAN indexes = 1` — primary tool. Check Parts and Granules ratios; >50% = near-full scan.
- `EXPLAIN PIPELINE` — verify parallelism (`× N` where N > 1).
- `EXPLAIN SYNTAX` — see if PREWHERE was auto-applied. Not auto-applied with `FINAL`.
- `EXPLAIN ESTIMATE` — quick sizing without executing.

## Insert Strategy

- Each INSERT creates a new part. 300+ active parts/partition = "Too many parts" error.
- Min 1K rows/INSERT, target 10K–100K. Max ~1 INSERT/second.
- Use async inserts (`async_insert = 1`) when client-side batching isn't practical.
- Replicated tables deduplicate by insert block hash. `ReplacingMergeTree` dedup is eventual (on merge).

## Updates and Deletes

- Lightweight `DELETE` (GA v23.3): masks rows, removed on merge. For targeted deletes only.
- `ALTER TABLE UPDATE/DELETE`: rewrites entire parts — heavyweight, async. Don't use per-request.
- `ReplacingMergeTree`: dedup is eventual. Use `argMax(col, version)` pattern, not `FINAL` (16x slower). Never put version column in ORDER BY.
- ❌ `SELECT * FROM users FINAL` — 2.4s on 1B rows
- ✅ `SELECT user_id, argMax(name, updated_at) FROM users GROUP BY user_id` — 0.15s
- `CollapsingMergeTree`: multiply values by `sign`, filter `HAVING sum(sign) > 0`.
- `OPTIMIZE TABLE FINAL` is not routine maintenance. Scope to partition if needed.

## Materialized Views and Projections

- MVs are INSERT triggers, not periodic refreshes. Only process new inserts.
- Do NOT use `POPULATE`. Create MV, then backfill with manual `INSERT INTO ... SELECT` in chunks.
- **AggregatingMergeTree requires `-State` on write, `-Merge` on read.** Plain aggregates = silent corruption.
- ❌ `INSERT INTO agg SELECT day, count() AS cnt ...` with `AggregateFunction(count)` column
- ✅ `INSERT INTO agg SELECT day, countState() ...` then `SELECT countMerge(cnt) ...`
- Refreshable MVs (GA v24.10): `REFRESH EVERY 1 HOUR` for periodic full-refresh patterns.
- Projections: alternative sort orders within same table, auto-selected at query time.

## PostgreSQL Syntax That Doesn't Exist

- No `SERIAL`/`AUTO_INCREMENT` — use `generateUUIDv7()` or app-generated IDs
- No `VARCHAR(N)` — use `String`; No `BOOLEAN` — use `Bool` or `UInt8`
- No `JSONB` — use `JSON` (v25.3+); No `CREATE INDEX USING btree` — skip indexes only
- No `FOREIGN KEY`, `CONSTRAINT`, `BEGIN/COMMIT/ROLLBACK`, `UPSERT/ON CONFLICT`, `INSERT RETURNING`
- No `VACUUM`/`ANALYZE`; No `DISTINCT ON` — use `LIMIT 1 BY`
- `lag()` requires explicit frame: `lagInFrame(val, 1, 0) OVER (... ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)`
- `CAST()` silently strips `Nullable` and `LowCardinality`. Use `toString()` or explicit `CAST(col AS Nullable(T))`.
- `ON CLUSTER '{cluster}'` required for DDL on replicated tables — without it, only one node changes.

## Notable Features (v24–v26)

- JSON type GA v25.3: columnar sub-columns, typed path hints, SKIP/REGEXP directives
- Text index GA redesign v25.10: deterministic inverted index, direct-read optimization v26.2+
- Query condition cache (v25.3): transparent caching for repeated WHERE filters
- Lazy materialization (v25.4): defers column reads for Top-N queries (219s→0.14s)
- Vector similarity search GA v25.8: HNSW index for embedding search
- Dynamic/Variant types GA v25.3: discriminated unions and flexible typing
