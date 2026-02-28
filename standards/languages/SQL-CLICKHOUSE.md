---
name: clickhouse-sql-standards
description: ClickHouse SQL standards for schema design, query optimisation, and at-scale analytics. Use when writing ClickHouse SQL, designing schemas, or reviewing ClickHouse queries. LLMs default to PostgreSQL patterns that fail in ClickHouse - this document corrects that.
---

> **📌 ClickHouse Is Not PostgreSQL**
>
> Every LLM will produce PostgreSQL-flavoured SQL when you ask for ClickHouse
> queries. CTEs are not materialised. JOINs load the right table into memory.
> Nullable costs 2x performance. If you don't override these habits, you get
> garbage queries at scale. We've been running PB-scale analytics pipelines for
> over 10 years now — the patterns in this doc come from that, not from Stack
> Overflow examples on toy datasets.
>
> **Improvements are WELCOME.** Found a better pattern? Fix it or ping me.

# ClickHouse SQL Standards for HyperI Projects

ClickHouse-specific patterns for analytical databases, time-series, log analytics,
and real-time dashboards. If you know PostgreSQL or MySQL, unlearn most of it here.
ClickHouse is a columnar append-only OLAP database — it has more in common w/ Parquet
files than w/ anything you've used in OLTP.

**Current stable:** v26.1 | **Current LTS:** v25.8 | **Previous LTS:** v25.3

---

## Table of Contents

- [ClickHouse Is Not PostgreSQL](#clickhouse-is-not-postgresql) — mental model reset
- [Schema Design](#schema-design) — ENGINE, ORDER BY, partitions, TTL, codecs, indexes
- [Data Types](#data-types) — LowCardinality, Nullable, JSON, DateTime
- [Query Patterns](#query-patterns) — SELECT, JOINs, aggregation, CTEs
- [EXPLAIN: Always Verify Your Queries](#explain-always-verify-your-queries) — AST, PLAN, PIPELINE
- [Insert Strategy](#insert-strategy) — batch sizing, async inserts, dedup
- [Updates and Deletes](#updates-and-deletes) — lightweight DELETE, mutations, RMT
- [Materialised Views and Projections](#materialised-views-and-projections) — incremental, refreshable
- [New Features (v24.x — v26.x)](#new-features-v24x--v26x) — JSON type, text index
- [Use Case Patterns](#use-case-patterns) — data warehouse, time-series, logs
- [DFE (Data Fusion Engine)](#dfe-data-fusion-engine) — common header, dfe-loader, dfe-receiver, Arrow pipeline
- [For AI Assistants: Stop Making These Mistakes](#for-ai-assistants-stop-making-these-mistakes)
- [Other Useful Reads](#other-useful-reads)

---

## ClickHouse Is Not PostgreSQL

Stop. If you've only used PostgreSQL or MySQL, you need to unlearn most of what
you know about SQL databases. They share syntax. That's about it.

PostgreSQL is row-oriented OLTP — designed for transactions, point lookups,
normalised schemas. ClickHouse is column-oriented OLAP — designed for scanning
billions of rows across denormalised tables. Getting this wrong costs you 10-100x
performance on every query you write.

### Mental Model Reset

| In PostgreSQL I would... | In ClickHouse you must... |
|---|---|
| Use `BEGIN`/`COMMIT` for transactions | No transactions. Each `INSERT` is atomic. Design for idempotent inserts. |
| Use `INSERT ... ON CONFLICT UPDATE` | No UPSERT. Use `ReplacingMergeTree` — insert the new row, old one gets deduplicated on merge. |
| Rely on CTEs being materialised | CTEs are **re-executed at every reference**. Three references = three full scans. Use temp tables. |
| Put the big table first in a `JOIN` | Put the **dimension table** (small) on the **right**. Right table gets loaded into a hash table in memory. Get this backwards on a billion-row fact table and you OOM. |
| Use `SELECT *` freely | **Never** `SELECT *`. Each column is a separate file on disk. `SELECT *` on a 200-column table reads 200 files. Name what you need. |
| Use `DISTINCT` for unique values | Use `GROUP BY` — 4.5x faster than `DISTINCT` (1.3s vs 5.8s on 1.8B rows). |
| Use `Nullable` columns freely | `Nullable` adds a separate UInt8 bitmap column. **2x performance penalty** — measured 229M rows/s → 98M rows/s on `GROUP BY` w/ `Nullable(Int64)`. Use defaults instead. |
| Create B-tree indexes on columns | No B-tree indexes. Sparse primary index on `ORDER BY` columns (one entry per ~8192 rows) plus optional skip indexes on granules. |
| Normalise into 3NF w/ foreign keys | **Denormalise**. Wide flat fact tables. No foreign keys, no constraints. Use dictionaries for dimension lookups. |
| Update rows in place | Rows are immutable. Use `ReplacingMergeTree`, `CollapsingMergeTree`, or lightweight `DELETE`. |
| Expect millisecond point lookups | ClickHouse scans billions of rows in seconds. Point lookups work but they're not the strength — that's what Redis is for. |

### Architecture in 30 Seconds

```text
PostgreSQL:                          ClickHouse:
┌─────────────────────┐              ┌─────────────────────┐
│ Row 1: [A][B][C][D] │              │ Column A: [1][2][3] │
│ Row 2: [A][B][C][D] │              │ Column B: [x][y][z] │
│ Row 3: [A][B][C][D] │              │ Column C: [.][.][.] │
└─────────────────────┘              └─────────────────────┘
Read row = read all columns          Read column = skip others entirely
Good for: OLTP, point lookups        Good for: OLAP, scanning billions of rows
```

ClickHouse stores data in immutable **parts** — sorted chunks of rows grouped by
your `ORDER BY`. Background merges combine small parts into larger ones. Everything
flows from this:

- Inserts are append-only — each INSERT creates a new part
- Updates/deletes are expensive — they rewrite entire parts
- `ORDER BY` is your physical data layout, not just sort order — it IS the index
- Small frequent inserts create thousands of tiny parts → "Too many parts" error at 300+ active parts per partition, then everything stops

---

## Schema Design

Schema is 80% of ClickHouse performance. You can't query-tune your way out of a
bad schema — we've tried. Get the ENGINE, ORDER BY, and partitioning right up front
because ORDER BY is immutable once the table exists.

### ENGINE Selection

Start w/ `ReplicatedMergeTree` for self-hosted (vanilla ClickHouse) or
`SharedMergeTree` for ClickHouse Cloud. These are the production-grade defaults
— they give you replication, failover, and insert deduplication out of the box.
Plain `MergeTree` is fine for single-node dev/test but don't ship it to prod
without replication.

Only reach for the specialised engines when you need their specific behaviour.

| Use Case | Engine | Why |
|---|---|---|
| Append-only (logs, events, metrics) | `(Replicated)MergeTree` | Fastest writes, simplest. Default choice. |
| Deduplicate by key (CDC, idempotent) | `ReplacingMergeTree(version)` | Keeps latest version per ORDER BY key on merge |
| Pre-aggregate additive metrics | `SummingMergeTree` | Auto-sums numeric columns on merge |
| Complex pre-aggregation (MV target) | `AggregatingMergeTree` | Stores intermediate aggregate states (-State/-Merge pattern) |
| Mutable data, single-thread insert | `CollapsingMergeTree(sign)` | +1/-1 sign column for insert/cancel |
| Mutable data, multi-thread / CDC | `VersionedCollapsingMergeTree(sign, ver)` | Handles out-of-order inserts safely |

All MergeTree variants have a `Replicated*` counterpart (e.g.
`ReplicatedReplacingMergeTree`, `ReplicatedAggregatingMergeTree`). In prod, always
use the replicated version.

```sql
-- Append-only threat events
CREATE TABLE threat_events (
    _timestamp DateTime64(3, 'UTC'),
    _timestamp_load DateTime64(3, 'UTC') DEFAULT now64(3),
    _org_id LowCardinality(String),
    _uuid UUID DEFAULT generateUUIDv7(),
    severity LowCardinality(String),
    source_ip IPv4,
    destination_ip IPv4,
    rule_id UInt32,
    _json JSON
) ENGINE = ReplicatedMergeTree()
PARTITION BY (toYYYYMM(_timestamp_load), _org_id)
ORDER BY (_org_id, severity, _timestamp_load);

-- Latest-state table w/ deduplication (asset inventory)
CREATE TABLE asset_inventory (
    asset_id UInt64,
    hostname String,
    ip_address IPv4,
    classification LowCardinality(String),
    last_seen DateTime('UTC')
) ENGINE = ReplicatedReplacingMergeTree(last_seen)
ORDER BY asset_id;

-- Pre-aggregated daily detection counts
CREATE TABLE daily_detection_counts (
    date Date,
    _org_id LowCardinality(String),
    severity LowCardinality(String),
    detection_count UInt64,
    unique_sources Float64
) ENGINE = ReplicatedSummingMergeTree()
ORDER BY (_org_id, severity, date);
```

### ORDER BY / Primary Key

This is the single most important decision you'll make. ORDER BY determines the
physical sort order on disk, the sparse primary index (one entry per ~8192 rows),
and which queries can use the index at all. You cannot ALTER it later. Measure twice.

We've fixed production tables because someone put a UUID first in ORDER BY —
the sparse index became useless and every query was a full scan across 2TB.

**Rules:**

- **3-5 columns max** — more columns = larger index w/ diminishing returns
- **Low cardinality first** — first column uses binary search, rest only help when
  predecessors span multiple granules. Tenant ID (~100 values) is a great first column.
- **Most-filtered columns first** — columns that appear in every WHERE clause go early
- **Timestamp last** (not first!) — timestamps have too many distinct values per granule
  on their own. As a trailing column they enable efficient range scans within the higher-level groups.
- **Never put UUIDs or high-cardinality strings first** — destroys compression and index.
  UUID-first ORDER BY = 18000/18562 granules read (full scan). Tenant-first = 47/18562.

```sql
-- ❌ WRONG: High cardinality first (OLTP habit from PostgreSQL)
CREATE TABLE threat_events (...)
ENGINE = ReplicatedMergeTree()
ORDER BY (_uuid, _org_id, severity, _timestamp_load);
-- _uuid is unique — every granule has different values
-- sparse index cannot skip anything

-- ❌ WRONG: Timestamp first (common LLM mistake)
CREATE TABLE threat_events (...)
ENGINE = ReplicatedMergeTree()
ORDER BY (_timestamp_load, _org_id, severity);
-- Filtering WHERE _org_id = 'acme' cannot use index
-- (_org_id is not a prefix of ORDER BY)

-- ✅ RIGHT: Low cardinality first, filtered columns first
CREATE TABLE threat_events (...)
ENGINE = ReplicatedMergeTree()
ORDER BY (_org_id, severity, _timestamp_load);
-- _org_id (~100 tenants) → binary search
-- severity (~5 levels) → good exclusion within tenant
-- _timestamp_load → range scans within tenant+severity
```

**The ORDER BY is immutable.** You cannot `ALTER` it afterwards. Measure twice.

### Partition Strategy

Partitioning is for **data management** — TTL drops, tiered storage moves, backup
granularity. It is NOT a query optimisation tool. People coming from PostgreSQL
expect partition pruning to speed up queries. In ClickHouse, the sparse primary
index handles that. Partitioning the wrong way actively hurts performance.

The single most important partition design rule: **the `PARTITION BY` column and the
`TTL` column must be the same.** When they align, TTL can drop entire partitions in
one metadata operation — instant, zero I/O. When they don't, ClickHouse rewrites
every part row-by-row to remove expired data. On a billion-row table, that's hours
of I/O vs milliseconds.

**Rules:**

- **Monthly by default:** `PARTITION BY toYYYYMM(timestamp)` — this covers 90% of use cases
- **TTL column = PARTITION BY column** — always. This is non-negotiable for clean drops.
- **Target 10 GB — 1 TB per partition** — smaller = too many parts, larger = slow DDL operations
- **Never partition by high-cardinality columns** — we've seen "Too many parts" kill
  servers when someone partitioned by user_id. 300+ active parts per partition = error.
- **Daily only if volume justifies it** — you need 10+ GB/day. At 1 GB/day you get 365
  tiny partitions/year and the merge scheduler struggles.
- **No partition at all for small tables** (< few GB) — just skip the PARTITION BY clause

```sql
-- ❌ WRONG: Partitioning by raw timestamp (millions of partitions)
PARTITION BY timestamp

-- ❌ WRONG: Partitioning by day on low-volume table
PARTITION BY toYYYYMMDD(timestamp)  -- 365 partitions/year

-- ❌ WRONG: Partitioning by high-cardinality column
PARTITION BY user_id  -- millions of partitions

-- ❌ WRONG: TTL column doesn't match PARTITION BY (row-by-row rewrite)
PARTITION BY toYYYYMM(ingest_ts)
TTL event_ts + INTERVAL 90 DAY DELETE

-- ✅ RIGHT: Monthly, TTL aligned (whole-partition drops)
PARTITION BY toYYYYMM(timestamp)
TTL timestamp + INTERVAL 365 DAY DELETE

-- ✅ RIGHT: No partition for small reference tables
CREATE TABLE countries (...)
ENGINE = MergeTree()
ORDER BY country_code;  -- no PARTITION BY

-- ✅ RIGHT: Daily for very high volume (100+ GB/day)
PARTITION BY toYYYYMMDD(timestamp)
```

#### TTL and Tiered Storage

TTL is the reason partitioning exists. Design the partition first, TTL second — and
make sure they use the same column. The `ttl_only_drop_parts = 1` setting is
non-negotiable: it drops entire parts where all rows have expired instead of
rewriting every part row-by-row. Without it, TTL cleanup on a billion-row table burns
hours of I/O.

```sql
CREATE TABLE logs (
    timestamp DateTime('UTC'),
    level LowCardinality(String),
    message String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (level, timestamp)
TTL
    timestamp + INTERVAL 30 DAY TO VOLUME 'warm',
    timestamp + INTERVAL 90 DAY TO VOLUME 'cold',
    timestamp + INTERVAL 365 DAY DELETE
SETTINGS
    ttl_only_drop_parts = 1;  -- drop whole parts, not row-by-row
```

The lifecycle here: hot → warm at 30d → cold at 90d → deleted at 365d. Each transition
is a metadata operation because the partition boundaries align w/ the TTL column.
Tiered storage (`TO VOLUME`) moves data between hot/warm/cold storage policies defined
in `storage.xml` — same principle, same column alignment requirement.

```sql
-- ❌ (TTL column ≠ PARTITION BY column — row-by-row rewrite on cleanup)
PARTITION BY toYYYYMM(ingest_ts)
TTL event_ts + INTERVAL 90 DAY DELETE

-- ✅ (same column — clean partition drops)
PARTITION BY toYYYYMM(ingest_ts)
TTL ingest_ts + INTERVAL 90 DAY DELETE
```

### Codec Selection

Codecs compress data per column. Pick based on the data pattern, not the data type.
Default LZ4 is fine for prototyping, but on a table w/ billions of rows the right
codec saves terabytes of storage and proportionally speeds up every query (less I/O
= faster scans). We've seen 3-5x compression improvements on timestamp and float
columns just by adding DoubleDelta and Gorilla.

| Data Pattern | Codec | Why |
|---|---|---|
| Sorted timestamps, monotonic IDs | `DoubleDelta, LZ4` | Sequential values have near-zero deltas |
| Float metrics (gauge, sensor) | `Gorilla, ZSTD(1)` | IEEE 754 XOR compression for floats |
| Small integers in large types | `T64, LZ4` | Bit-packing (skip for random hashes) |
| LowCardinality strings | `LZ4` | Already dictionary-encoded, LZ4 is enough |
| High-entropy strings (log messages) | `ZSTD(3)` | General compression, levels above 3 rarely help |
| Random data (hashes, UUIDs) | `ZSTD(1)` | Nothing compresses random data well |

```sql
CREATE TABLE metrics (
    timestamp DateTime('UTC') CODEC(DoubleDelta, LZ4),
    metric_name LowCardinality(String) CODEC(LZ4),
    host LowCardinality(String) CODEC(LZ4),
    value Float64 CODEC(Gorilla, ZSTD(1)),
    tags Map(String, String) CODEC(ZSTD(1))
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (metric_name, host, timestamp);
```

**ZSTD levels:** 1-3 cover 95% of use cases. We tested ZSTD(1) vs ZSTD(9) on a
500M row log table — 3% better compression for 4x more CPU time on insert. Not
worth it. Level 9+ is almost never justified.

### Skip Indexes

Not B-tree indexes. Don't think of them as indexes in the PostgreSQL sense at all.
They work on **granules** (blocks of ~8192 rows) and answer one question: "does
this granule definitely NOT contain my value?" If yes, ClickHouse skips the entire
granule. They can't seek to a specific row — they just eliminate blocks. On a
well-correlated column this cuts scan time by 10-50x. On a randomly distributed
column they're useless overhead.

| Index Type | Use Case | Notes |
|---|---|---|
| `minmax` | Range filtering on numeric/date columns | Stores min/max per granule. Built-in for ORDER BY cols. |
| `set(N)` | Equality checks, N distinct values per granule | Exact match. N = max stored distinct values. |
| `bloom_filter` | Point lookups on high-cardinality (trace_id) | Probabilistic — has false positives, no false negatives. |
| `tokenbf_v2(size, hashes, seed)` | Tokenised text search (log messages) | Bloom filter over word-level tokens. |
| `ngrambf_v1(n, size, hashes, seed)` | Substring matching | Bloom filter over character n-grams. |
| `full_text` | Full-text search (GA redesign v25.10) | Deterministic inverted index. No false positives. Row-level filtering. |

```sql
-- Skip index on trace_id for point lookups
ALTER TABLE logs ADD INDEX idx_trace_id trace_id
    TYPE bloom_filter GRANULARITY 4;

-- Token-based index for log message search
ALTER TABLE logs ADD INDEX idx_message message
    TYPE tokenbf_v2(32768, 3, 0) GRANULARITY 1;
```

Skip indexes only help when the indexed column correlates w/ ORDER BY columns —
i.e. similar values tend to cluster in the same granules. If values are randomly
scattered (like a UUID on a table ordered by timestamp), the index can't skip
anything and just burns CPU checking every granule. Always verify w/
`EXPLAIN PLAN indexes = 1` — if the granule ratio doesn't drop, the index is dead
weight.

**After adding an index, materialise it for existing data:**

```sql
ALTER TABLE logs MATERIALIZE INDEX idx_trace_id;
```

### Full-Text Search / Text Index (GA v25.10)

Derek's baby with ClickHouse and Melvin for 3 years.  
This changes the game for log analytics. The text index (previously the experimental
"inverted" index) was completely redesigned in v25.10 — proper on-disk inverted
index that handles datasets larger than RAM. The key difference from `tokenbf_v2`
and `ngrambf_v1`: it's **deterministic**. No false positives. Row-level filtering
instead of granule-level. On the Hackernews dataset (28.7M rows), `hasToken('ClickHouse')`
runs in 0.008s w/ the text index vs 0.362s without — 45x faster.

**Syntax (v25.10+):**

```sql
-- Create w/ table definition
CREATE TABLE logs (
    timestamp DateTime64(3, 'UTC'),
    service LowCardinality(String),
    message String,
    INDEX idx_ft_message(message) TYPE text(
        tokenizer = splitByNonAlpha,
        preprocessor = lower(message)     -- case-insensitive matching
    )
) ENGINE = MergeTree()
ORDER BY (service, timestamp);

-- Add to existing table
ALTER TABLE logs ADD INDEX idx_ft_message(message) TYPE text(
    tokenizer = splitByNonAlpha,
    preprocessor = lower(message)
);

-- Materialise for existing data (new inserts are indexed automatically)
ALTER TABLE logs MATERIALIZE INDEX idx_ft_message
    SETTINGS mutations_sync = 2;
```

**Tokeniser options:**

| Tokeniser | What It Does | Use Case |
|---|---|---|
| `splitByNonAlpha` | Splits on non-alphanumeric ASCII chars | Log messages, general text (default choice) |
| `splitByString[(S)]` | Splits by custom separator (default: space) | Structured text w/ known delimiters |
| `ngrams[(N)]` | Character n-grams, default N=3, range 1-8 | Substring matching, partial words |
| `sparseGrams[(min, max, cutoff)]` | Variable-length n-grams | Large text bodies, URL search |
| `array` | No tokenisation — entire value is one token | Array element matching, exact value lookup |

**Note on tokenisers for AI / DFE workloads:** The built-in tokenisers are fine for
spike projects and general log search. For production AI work (DFE, membank, LLM
token accounting) we use our enhanced tiktoken layer — see
[DFE > dfe-loader](#dfe-loader). The ClickHouse text index tokeniser operates at
the search/indexing level, not the semantic level. Don't conflate the two.

**Preprocessor:** An optional expression applied before tokenisation. Must be
`String` → `String`, deterministic, and reference only the indexed column.
Common: `lower(col)` for case-insensitive search, `extractTextFromHTML(col)`.

**Functions accelerated by the text index:**

```sql
-- hasToken / hasAllTokens / hasAnyTokens — the primary query functions
SELECT timestamp, service, message
FROM logs
WHERE hasToken(message, 'error')              -- single word match
ORDER BY timestamp DESC LIMIT 100;

SELECT * FROM logs
WHERE hasAllTokens(message, ['connection', 'refused']);  -- AND logic

SELECT * FROM logs
WHERE hasAnyTokens(message, ['error', 'fatal', 'panic']);  -- OR logic

-- LIKE works when complete tokens can be extracted
SELECT * FROM logs
WHERE message LIKE '%connection refused%';

-- match() works w/ splitByNonAlpha, ngrams, sparseGrams tokenisers
SELECT * FROM logs
WHERE match(message, 'error|warning|critical');
```

**Direct read optimisation (v26.2+, default on):** For `hasToken`, `hasAllTokens`,
`hasAnyTokens` — ClickHouse reads the answer directly from the index without
touching the column data at all. This is where the 45x speedup comes from.

**What it does NOT accelerate:**

- Leading wildcards (`LIKE '%foo'`) — no token to extract
- `PREWHERE` — the text index is not used in PREWHERE (open issue #89975). Use
  `WHERE` for full-text queries.
- CJK text — produces huge indexes and slow queries. Stick w/ bloom-filter indexes
  for Chinese/Japanese/Korean text until better language support lands.

**For versions before v26.2**, you need to enable three settings:

```sql
SET enable_full_text_index = true;
SET query_plan_direct_read_from_text_index = true;
SET use_skip_indexes_on_data_read = true;
```

**Text index vs bloom-filter indexes:**

| | `text` (inverted) | `tokenbf_v2` / `ngrambf_v1` |
|---|---|---|
| False positives | None | Yes (probabilistic) |
| Filtering granularity | Row-level | Block-level (granule) |
| Storage per part | 10s-100s MB | 1s-10s KB |
| Query speed (w/ direct read) | 10-100x faster | Good for simple filtering |
| Substring matching | Via `ngrams` tokeniser or LIKE | `ngrambf_v1` is better here |
| Multi-token search | Native (`hasAllTokens`, `hasAnyTokens`) | Limited |
| Minimum version | v25.10 (GA redesign) | Stable for years |

**When to use which:**

- **`text`** — log analytics, observability, any workload where you search message
  text regularly. Default choice for v25.10+.
- **`tokenbf_v2`** — older CH versions, or when index storage overhead matters more
  than accuracy. Still fine for coarse "does this granule contain the word" filtering.
- **`ngrambf_v1`** — arbitrary substring matching (partial hostnames, error codes
  embedded in longer strings). Text index w/ `ngrams` tokeniser is an alternative.
- **`bloom_filter`** — point lookups on high-cardinality IDs (trace_id, request_id).
  Not for text search.

---

## Data Types

### LowCardinality(String) — The Single Biggest Win

If a `String` column has fewer than ~10K distinct values, wrap it in
`LowCardinality`. Dictionary encoding — each unique string stored once, rows
reference a small integer. 5-10x better compression and query speed on columns
like status codes, service names, country codes. This is the lowest-effort,
highest-impact change you can make to most schemas.

```sql
-- ❌ Plain String for low-cardinality columns
CREATE TABLE logs (
    level String,           -- 5 values: DEBUG, INFO, WARN, ERROR, FATAL
    service String,         -- ~20 services
    country String,         -- ~200 countries
    message String          -- high cardinality, variable length
) ENGINE = MergeTree() ORDER BY (level, timestamp);

-- ✅ LowCardinality where appropriate
CREATE TABLE logs (
    level LowCardinality(String),
    service LowCardinality(String),
    country LowCardinality(FixedString(2)),  -- ISO codes, fixed 2 chars
    message String                            -- high cardinality, leave as String
) ENGINE = MergeTree() ORDER BY (level, timestamp);
```

Works best below ~10K distinct values. Above ~100K it can actually perform **worse**
than plain `String` — the dictionary gets too large and you lose the benefit. Check
first: `SELECT uniq(col) FROM table`.

### Nullable — The Performance Tax

`Nullable(T)` stores a separate `UInt8` bitmap column alongside the data. Costs:

- **2x storage** per nullable column (data + bitmap)
- **2x slower queries** — extra column read + null checks on every row
- Worse compression — bitmap has a different pattern from the data

**Hard numbers:** `GROUP BY` on `Int64` = 229M rows/s. Same query on
`Nullable(Int64)` = 98M rows/s. That's more than half your throughput gone for
one Nullable column.

Replace Nullable w/ defaults wherever the semantics allow it.

```sql
-- ❌ Nullable everywhere (PostgreSQL habit)
CREATE TABLE asset_inventory (
    asset_id UInt64,
    hostname Nullable(String),
    os_version Nullable(String),
    classification Nullable(String),
    risk_score Nullable(Float64)
) ENGINE = ReplicatedMergeTree() ORDER BY asset_id;

-- ✅ Defaults instead of Nullable
CREATE TABLE asset_inventory (
    asset_id UInt64,
    hostname String DEFAULT '',
    os_version String DEFAULT '',
    classification LowCardinality(String) DEFAULT 'unclassified',
    risk_score Float64 DEFAULT 0.0
) ENGINE = ReplicatedMergeTree() ORDER BY asset_id;
```

### When Nullable Is Unavoidable (ETL / Ingestion Workloads)

In practice, many data engineering workloads can't dodge Nullable. If you're
ingesting from PostgreSQL, Kafka, Parquet files, or any external source where NULL
means "not provided" — that's semantically different from empty string or zero.
Collapsing NULL to a default is a data quality bug, not an optimisation. You'll
corrupt downstream analytics.

When Nullable is the right call:

- **External data ingestion** — source systems send NULLs and downstream consumers
  or regulatory requirements need that distinction preserved
- **Outer JOINs** — non-matching side produces NULLs by definition
- **Sparse data** — wide tables where most rows populate a subset of columns
  (event payloads w/ optional fields)
- **Data quality tracking** — NULL means "unknown/missing", zero means "measured
  at zero". Collapsing these is a data quality bug.

**Managing the performance hit:**

```sql
-- Keep Nullable OFF the ORDER BY and PARTITION BY columns.
-- Nullable in the primary key destroys index effectiveness.
-- ❌
ORDER BY (Nullable(_org_id), _timestamp_load)
-- ✅
ORDER BY (_org_id, _timestamp_load)

-- Push Nullable to "payload" columns, not filter/sort columns.
CREATE TABLE ingested_alerts (
    -- Filter/sort columns: NOT Nullable
    _timestamp_load DateTime64(3, 'UTC') DEFAULT now64(3),
    _org_id LowCardinality(String),
    source_system LowCardinality(String),
    -- Payload columns: Nullable where genuinely needed
    -- (external systems send NULLs and we preserve that)
    assignee_id Nullable(UInt64),
    resolution_time Nullable(Float64),
    external_ticket_ref Nullable(String),
    raw_payload Nullable(String)
) ENGINE = ReplicatedMergeTree()
ORDER BY (_org_id, source_system, _timestamp_load);
```

**Managing the hit:**

- **Never** Nullable in ORDER BY, PARTITION BY, or primary key columns — destroys index
- **Minimise** in columns you filter or GROUP BY — null check runs on every row
- **Acceptable** in payload columns that are read, rarely filtered
- **Prefer** `Nullable(T)` over sentinel values when NULL genuinely means "not provided"
  — data integrity matters more than a query speed bump
- **Consider** materialised views that strip Nullable for the hot query path — keep
  the raw table faithful to source, aggregate table optimised for speed
- Use `COALESCE(col, default)` or `ifNull(col, default)` in queries — don't let
  NULLs propagate through aggregations silently

### FixedString

Use for data with a known, fixed byte length. Not padded — must be exact length.

```sql
-- Good candidates for FixedString
trace_id FixedString(32),     -- 32-char hex trace ID
country_code FixedString(2),  -- ISO 3166-1 alpha-2
md5_hash FixedString(16),     -- 16 bytes raw MD5
```

Do **not** use `FixedString` for variable-length data. ClickHouse will pad with null
bytes to fill the length, wasting storage and causing surprising string comparison
behaviour.

### DateTime and Timezones

```sql
-- ✅ Always declare timezone explicitly
CREATE TABLE audit_log (
    _timestamp DateTime64(3, 'UTC'),
    _timestamp_load DateTime64(3, 'UTC'),
    _org_id LowCardinality(String),
    action LowCardinality(String),
    actor_id String
) ENGINE = ReplicatedMergeTree()
ORDER BY (_org_id, action, _timestamp_load);

-- ✅ Store UTC, convert in SELECT only
SELECT
    toTimeZone(_timestamp, 'Australia/Sydney') AS local_time
FROM audit_log
WHERE _timestamp >= '2026-01-01 00:00:00'   -- filter on raw column (uses index)
ORDER BY _timestamp;                          -- sort on raw column (uses index)

-- ❌ WRONG: Function on column in WHERE (breaks index usage)
WHERE toTimeZone(_timestamp, 'Australia/Sydney') > '2026-01-01 10:00:00'

-- ❌ WRONG: Timezone abbreviations (ambiguous, no DST)
SELECT toDateTime('2026-01-15 10:00:00', 'AEST');  -- use IANA name instead
```

Use IANA timezone names (`Australia/Sydney`, `America/New_York`), never abbreviations
(`AEST`, `PST`).

### Enum8 and Enum16

Small, fixed set of values w/ type safety. Insert a value not in the enum and
ClickHouse rejects it — unlike `LowCardinality` which accepts anything.

```sql
CREATE TABLE alerts (
    severity Enum8('low' = 1, 'medium' = 2, 'high' = 3, 'critical' = 4),
    status Enum8('open' = 1, 'acknowledged' = 2, 'resolved' = 3)
) ENGINE = MergeTree() ORDER BY severity;
```

`Enum8` = 1 byte (128 values), `Enum16` = 2 bytes (32,768 values). For most cases
`LowCardinality(String)` is more flexible and almost as fast. Use Enum only when
you need strict value enforcement at the storage layer.

### Array, Map, Tuple

```sql
-- Array
SELECT [1, 2, 3];                                    -- literal
SELECT groupArray(source_ip) FROM threat_events;     -- aggregate into array
SELECT arrayJoin(tags) AS tag FROM articles;         -- expand array to rows
-- Preferred: ARRAY JOIN clause (optimised, uses indexes)
SELECT tag FROM articles ARRAY JOIN tags AS tag;

-- Lambda functions on arrays
SELECT arrayMap(x -> x * 2, [1, 2, 3]);             -- [2, 4, 6]
SELECT arrayFilter(x -> x > 2, [1, 2, 3, 4]);      -- [3, 4]
SELECT arrayExists(x -> x = 'error', levels);       -- true/false

-- Map
CREATE TABLE kv (data Map(String, UInt64)) ENGINE = Memory;
INSERT INTO kv VALUES ({'clicks': 10, 'views': 100});
SELECT data['clicks'] FROM kv;         -- access by key (linear scan, not O(1))
SELECT mapKeys(data) FROM kv;          -- ['clicks', 'views']

-- Tuple
SELECT tuple(1, 'hello', 3.14);       -- named or unnamed
SELECT (1, 'hello').1;                 -- access by index (1-based)
```

**Gotcha:** `arrayJoin()` w/ two arrays produces a cross-product. Use the `ARRAY
JOIN` clause for parallel expansion of multiple arrays — it zips them instead.

### JSON Type (GA v25.3)

Derek's baby with ClickHouse and Tanya for 3 years.  
The new `JSON` type (not the old experimental `Object('json')` which is removed)
stores each JSON path in its own sub-column w/ preserved types. This is columnar
JSON — not a blob, not a string parse on every query.

For large-scale ingestion, the practical pattern is: land everything in a `JSON`
column first, then progressively break out high-query paths to dedicated typed
columns as query patterns emerge. See [DFE > The Ingest-First Pattern](#the-ingest-first-pattern)
for how this works in the DFE pipeline.

```sql
-- Schema-flexible table with JSON
CREATE TABLE raw_events (
    timestamp DateTime64(3, 'UTC'),
    source LowCardinality(String),
    _json JSON
) ENGINE = ReplicatedMergeTree()
ORDER BY (source, timestamp)
SETTINGS max_dynamic_paths = 1024;

-- Query directly against JSON sub-columns
SELECT _json.user_id, _json.action, _json.metadata.page
FROM raw_events
WHERE source = 'web'
  AND timestamp >= '2026-01-01';

-- Break out hot paths to typed columns as query patterns emerge
CREATE TABLE events_v2 (
    timestamp DateTime64(3, 'UTC'),
    source LowCardinality(String),
    -- Broken out: these showed up in 80% of dashboard queries
    user_id UInt64,
    action LowCardinality(String),
    -- Everything else stays in JSON
    _json JSON
) ENGINE = ReplicatedMergeTree()
ORDER BY (source, action, timestamp)
SETTINGS max_dynamic_paths = 1024;
```

**Typed path hints** — when you know certain paths exist and their types, declare
them upfront. ClickHouse skips type inference for those paths and stores them more
efficiently:

```sql
CREATE TABLE api_events (
    timestamp DateTime('UTC'),
    payload JSON(
        user_id UInt64,              -- always present, always integer
        action String,               -- always present
        metadata.source String       -- nested path hint
    )
) ENGINE = ReplicatedMergeTree()
ORDER BY timestamp
SETTINGS max_dynamic_paths = 1024;

-- Typed paths are faster to query (no dynamic dispatch)
SELECT payload.user_id, payload.action FROM api_events;

-- Dynamic paths still work for everything else
SELECT payload.metadata.custom_field FROM api_events;
```

**SKIP and REGEXP for path management:**

```sql
-- Skip paths you never query (reduces storage + memory)
CREATE TABLE logs (
    timestamp DateTime('UTC'),
    data JSON(
        SKIP debug_info,                    -- never store this path
        SKIP REGEXP 'internal\..*'          -- skip all internal.* paths
    )
) ENGINE = ReplicatedMergeTree()
ORDER BY timestamp;
```

**Key settings:**

| Setting | Default | What It Does |
|---|---|---|
| `max_dynamic_paths` | 1024 | Max unique paths stored as sub-columns per data block. Paths beyond this go to shared overflow column. |
| `max_dynamic_types` | 32 | Max distinct types per dynamic path column |
| `output_format_json_quote_64bit_integers` | 1 | Quote 64-bit ints in JSON output (prevents JS precision loss) |

**Performance guidance:**

- **Typed path hints** are 2-5x faster than dynamic paths — declare what you know
- **`max_dynamic_paths = 1024`** is the sweet spot for most workloads. Going higher
  increases memory during merges. Going lower pushes more paths to shared overflow
  (which is slower to query — linear scan).
- **Don't query `SELECT _json` on wide JSON** — same problem as `SELECT *`, just
  worse. Name the paths: `SELECT _json.user_id, _json.action`
- **JSON columns in ORDER BY** — don't. Break the path out to a typed column first.
- **Filtering on JSON paths in WHERE** works but is slower than typed columns.
  If you're filtering on a JSON path in every query, that's your signal to break it
  out to a typed column.

**When to use what:**

| Pattern | Use When |
|---|---|
| Typed columns only | Schema is stable, known, and performance-critical |
| `_json` column only | Rapid prototyping, schema discovery phase, flexible ingestion |
| Typed columns + `_json` for the rest | **Production default.** Break out what's hot, keep flexibility for the rest. |
| `String` w/ JSON blob | You never query individual fields — just store and retrieve |

---

## Query Patterns

### Never SELECT *

Each column is a separate file on disk. `SELECT *` on a 200-column table reads
200 files. On a wide fact table that's the difference between a 3 GB scan and
a 100+ GB scan — for the same number of rows. Name your columns.

```sql
-- ❌ Reads ALL columns (100+ GB scan on a wide table)
SELECT * FROM threat_events WHERE _timestamp_load > now() - INTERVAL 1 HOUR;

-- ✅ Reads only the 3 columns you need (~3 GB)
SELECT severity, source_ip, _timestamp_load
FROM threat_events
WHERE _timestamp_load > now() - INTERVAL 1 HOUR;
```

### PREWHERE vs WHERE

`PREWHERE` reads filter columns first, evaluates the condition, then reads remaining
columns only for rows that match. ClickHouse auto-promotes selective `WHERE`
conditions to `PREWHERE` (`optimize_move_to_prewhere = 1` by default), so most of
the time you don't need to think about it.

When to use explicit `PREWHERE`:

```sql
-- PREWHERE is disabled with FINAL — use explicit PREWHERE to bypass
SELECT asset_id, hostname, classification
FROM asset_inventory FINAL
PREWHERE status = 'active';   -- 9x faster than WHERE with FINAL

-- For highly selective filters on large tables
SELECT severity, source_ip, _timestamp_load
FROM threat_events
PREWHERE is_critical = 1       -- filters 99.9% of rows cheaply
WHERE matchIPSubnet(source_ip, '10.0.0.0/8');
```

### JOINs — Fact Table Left, Dimension Table Right

The right table in a JOIN gets loaded into a hash table in memory. This is the
critical thing to understand: if you put a billion-row fact table on the right,
you OOM. Fact table goes on the left (streamed), dimension table goes on the right
(loaded into memory).

```sql
-- ❌ WRONG: Fact table on the right (loaded into memory → OOM)
SELECT u.*, e.event_type
FROM dim_users u
LEFT JOIN fact_events e ON u.user_id = e.user_id;

-- ✅ RIGHT: Dimension table on the right (small, fits in memory)
SELECT e.event_type, u.name
FROM fact_events e
LEFT JOIN dim_users u ON e.user_id = u.user_id;
```

**Alternatives to JOINs (prefer these when possible):**

```sql
-- IN for existence checks — builds a HashSet, no data extraction
SELECT * FROM fact_events
WHERE user_id IN (SELECT user_id FROM dim_active_users);

-- Dictionaries for dimension lookups — fastest option, cached in memory
CREATE DICTIONARY country_dict (
    code String,
    name String
) PRIMARY KEY code
SOURCE(CLICKHOUSE(TABLE 'dim_countries' DB 'default'))
LAYOUT(FLAT())
LIFETIME(3600);

SELECT dictGet('country_dict', 'name', country_code) AS country_name
FROM fact_events;

-- ANY JOIN for first-match lookups (no row multiplication)
SELECT e.*, u.name
FROM fact_events e
ANY LEFT JOIN dim_users u ON e.user_id = u.user_id;
```

**Type matching:** ClickHouse does NOT implicitly cast types in JOIN conditions
(unlike PostgreSQL). If your fact table has `user_id UInt64` and your dimension
table has `user_id Int64`, the JOIN silently produces wrong results. Types must
match exactly.

### GROUP BY vs DISTINCT

Hard numbers on 1.8B rows:

```sql
-- ❌ DISTINCT: 5.8s
SELECT DISTINCT source_ip FROM threat_events;

-- ✅ GROUP BY: 1.3s (4.5x faster)
SELECT source_ip FROM threat_events GROUP BY source_ip;

-- Exception: DISTINCT + LIMIT short-circuits (stops after N unique values)
SELECT DISTINCT source_ip FROM threat_events LIMIT 1000;  -- 0.014s, perfectly fine

-- For approximate counts, use HyperLogLog (not count(DISTINCT))
-- ❌ Exact but slow and memory-heavy
SELECT count(DISTINCT source_ip) FROM threat_events;  -- scans everything, allocates hash set

-- ✅ ~2% error, 10-100x faster, fraction of the memory
SELECT uniq(source_ip) FROM threat_events;

-- ✅ Even faster, tunable accuracy
SELECT uniqCombined(source_ip) FROM threat_events;
```

### CTEs Are Not Materialised

In ClickHouse, a CTE is a macro — it gets re-executed at every reference. Reference
it three times, the underlying query runs three times. We've seen people write CTEs
that scan 500GB of data and reference them twice in a UNION ALL — that's a TB of
I/O for no reason.

```sql
-- ❌ CTE referenced 3 times = 3 full executions
WITH by_source AS (
    SELECT source_ip, count() AS hits
    FROM threat_events
    WHERE _timestamp_load > now() - INTERVAL 7 DAY
    GROUP BY source_ip
)
SELECT * FROM by_source WHERE hits > 1000
UNION ALL
SELECT * FROM by_source WHERE hits BETWEEN 100 AND 1000
UNION ALL
SELECT * FROM by_source WHERE hits < 100;

-- ✅ Materialise into a temporary table
CREATE TEMPORARY TABLE tmp_by_source AS
    SELECT source_ip, count() AS hits
    FROM threat_events
    WHERE _timestamp_load > now() - INTERVAL 7 DAY
    GROUP BY source_ip;

SELECT * FROM tmp_by_source WHERE hits > 1000
UNION ALL
SELECT * FROM tmp_by_source WHERE hits BETWEEN 100 AND 1000
UNION ALL
SELECT * FROM tmp_by_source WHERE hits < 100;

-- ✅ Or restructure as a single pass
SELECT
    source_ip,
    hits,
    multiIf(hits > 1000, 'critical', hits >= 100, 'elevated', 'noise') AS threat_tier
FROM (
    SELECT source_ip, count() AS hits
    FROM threat_events
    WHERE _timestamp_load > now() - INTERVAL 7 DAY
    GROUP BY source_ip
);
```

Single-reference CTEs are fine — just syntactic sugar for a subquery, no penalty.

### LIMIT BY (Top-N Per Group)

ClickHouse-specific clause — no window functions needed. Simpler and faster than
the `row_number() OVER (PARTITION BY ...)` pattern every LLM defaults to.

```sql
-- ❌ PostgreSQL habit: window function for top-N per group
SELECT * FROM (
    SELECT *, row_number() OVER (PARTITION BY source_ip ORDER BY _timestamp_load DESC) AS rn
    FROM threat_events
) WHERE rn <= 3;

-- ✅ ClickHouse: LIMIT BY
SELECT severity, source_ip, rule_name, _timestamp_load
FROM threat_events
ORDER BY source_ip, _timestamp_load DESC
LIMIT 3 BY source_ip;
```

**Note:** `LIMIT BY` does not replace `LIMIT`. You can combine them:
`LIMIT 3 BY source_ip LIMIT 1000` — three events per source, up to 1000 total rows.

### Approximate Functions

For dashboards and monitoring you rarely need exact counts. ClickHouse's approximate
functions trade ~2% error for 10-100x speed and a fraction of the memory.

| Exact | Approximate | Error | Speed Gain |
|---|---|---|---|
| `count(DISTINCT x)` | `uniq(x)` | ~2% | 10-100x faster |
| `count(DISTINCT x)` | `uniqCombined(x)` | ~2% | Faster still, less memory |
| `quantileExact(0.99)(x)` | `quantile(0.99)(x)` | ~1% | 5-20x faster |
| `median(x)` | `quantile(0.5)(x)` | ~1% | 5-20x faster |

These compose across materialised views using the `-State` / `-Merge` pattern (see
[Materialised Views and Projections](#materialised-views-and-projections)). That's the real power — you
pre-aggregate w/ `uniqState()` on insert and finalise w/ `uniqMerge()` on query.

### Regex Is Evil

Every LLM reaches for `match()`, `extract()`, or `LIKE '%pattern%'` when asked to
search text in ClickHouse. At scale, regex is a performance disaster — it runs on
every row, can't use indexes, and the backtracking engine can turn a simple query
into a multi-minute scan. ClickHouse has native string functions that are 10-100x
faster for almost every pattern people use regex for.

**The rule:** if you can express it w/ a native function, do that. Regex is the
last resort, not the first tool.

#### Regex → Native Function Replacement Table

| Pattern | Regex (Slow) | Native (Fast) | Why Native Wins |
|---|---|---|---|
| Contains word | `match(msg, '\\berror\\b')` | `hasToken(msg, 'error')` | Uses text index (45x faster), no backtracking |
| Contains any word | `match(msg, 'error\|fatal\|panic')` | `hasAnyTokens(msg, ['error', 'fatal', 'panic'])` | Text index, single pass |
| Contains all words | `match(msg, '(?=.*conn)(?=.*refused)')` | `hasAllTokens(msg, ['connection', 'refused'])` | Text index, no lookahead |
| Starts with | `match(url, '^https://api\\.example')` | `startsWith(url, 'https://api.example')` | Short-circuits, no regex engine |
| Ends with | `match(path, '\\.json$')` | `endsWith(path, '.json')` | Short-circuits |
| Contains substring | `match(msg, 'connection refused')` | `position(msg, 'connection refused') > 0` | SIMD-accelerated string search |
| Case-insensitive contains | `match(msg, '(?i)error')` | `positionCaseInsensitive(msg, 'error') > 0` | SIMD, no regex engine |
| Extract domain | `extract(url, '://([^/]+)')` | `domain(url)` | Purpose-built URL parser |
| Extract path | `extract(url, '://[^/]+(.*)')` | `path(url)` | Purpose-built URL parser |
| Extract top-level domain | `extract(url, '\\.([a-z]+)$')` | `topLevelDomain(url)` | Purpose-built URL parser |
| Extract query parameter | `extract(url, 'utm_source=([^&]+)')` | `extractURLParameter(url, 'utm_source')` | Purpose-built URL parser |
| Split by delimiter | `extractAll(line, '[^,]+')` | `splitByChar(',', line)` | No regex, simple char split |
| Split by string | `extractAll(line, '[^::]+')` | `splitByString('::', line)` | No regex, string delimiter |
| Match IP address | `match(ip, '^\\d+\\.\\d+\\.\\d+\\.\\d+$')` | `isIPv4String(ip)` | Type check, no parsing |
| IPv4 subnet match | `match(ip, '^10\\.66\\..*')` | `isIPAddressInRange(ip, '10.66.0.0/16')` | CIDR-native |
| Numeric extraction | `toUInt64OrNull(extract(s, '(\\d+)'))` | `toUInt64OrNull(s)` | Direct conversion, no regex |
| Replace pattern | `replaceRegexpAll(s, '\\s+', ' ')` | `replaceAll(s, '  ', ' ')` | No regex engine (for simple cases) |

#### ClickHouse String Functions You Should Know

ClickHouse has ~50 native string functions. These are the ones that replace 90% of
regex usage:

**Search/match:**

- `hasToken(s, token)` — word-level match, uses text index
- `hasAllTokens(s, [...])` / `hasAnyTokens(s, [...])` — multi-word AND/OR
- `position(s, needle)` — SIMD substring search, returns position (0 = not found)
- `positionCaseInsensitive(s, needle)` — case-insensitive variant
- `multiSearchAny(s, ['a', 'b', 'c'])` — true if any needle found (Aho-Corasick, single pass)
- `multiSearchFirstPosition(s, ['a', 'b'])` — position of first match
- `startsWith(s, prefix)` / `endsWith(s, suffix)` — obvious
- `like(s, '%pattern%')` — glob-style, can use text index if tokens extractable
- `notLike(s, pattern)` — negated

**Extract/transform:**

- `substring(s, offset, length)` — positional extract
- `splitByChar(sep, s)` / `splitByString(sep, s)` — split to array
- `trimBoth(s)` / `trimLeft(s)` / `trimRight(s)` — whitespace trim
- `lower(s)` / `upper(s)` — case conversion
- `replaceOne(s, from, to)` / `replaceAll(s, from, to)` — literal replacement
- `base64Encode(s)` / `base64Decode(s)` — encoding

**URL-specific (for log analytics / clickstream):**

- `domain(url)` — extract domain
- `domainWithoutWWW(url)` — domain minus www prefix
- `topLevelDomain(url)` — TLD extraction
- `path(url)` — URL path
- `extractURLParameter(url, name)` — query parameter by name
- `extractURLParameters(url)` — all query params as array
- `cutQueryString(url)` — URL without query string
- `protocol(url)` — http/https

**JSON path (for String columns containing JSON, not the JSON type):**

- `JSONExtractString(s, 'key')` / `JSONExtractUInt(s, 'key')` — type-safe extraction
- `JSONExtractRaw(s, 'key')` — raw JSON fragment
- `JSON_VALUE(s, '$.path')` — JSONPath syntax

#### When Regex Is Acceptable

Not trying to ban regex entirely. It's the right tool when:

- **Complex pattern matching** — actual regex patterns w/ quantifiers, alternation,
  grouping that can't be expressed w/ native functions
- **One-off ad-hoc investigation** — you're debugging in the CLI, not building a
  dashboard query
- **Spike/prototype** — proving a concept before productionising it

When you do use regex, prefer `match()` over `LIKE` w/ leading wildcards, and
`extract()` over `replaceRegexpAll()` where possible. Avoid `.*` and nested
quantifiers — these trigger catastrophic backtracking.

#### The Regex-to-ClickHouse Productionisation Path

Derek has a spike project for a regex → ClickHouse native function transpiler —
on the roadmap for GA in later quarters. See [DFE > dfe-loader](#dfe-loader) for
details. Until then, the manual replacement table above covers the common patterns.

---

## EXPLAIN: Always Verify Your Queries

If you have a dataset, **verify every non-trivial query w/ EXPLAIN before
deploying it**. Don't guess whether the primary index is being used. Don't assume
PREWHERE is engaged. Don't hope the JOIN order is right. We've caught queries that
looked correct but were doing full table scans on 2TB tables — EXPLAIN showed the
issue in 0.1s. The alternative was a 45-minute scan in prod.

### EXPLAIN Types

| Command | Shows | Use When |
|---|---|---|
| `EXPLAIN AST` | Abstract syntax tree | Debugging parse issues, macro expansion |
| `EXPLAIN SYNTAX` | Optimised query rewrite | See what ClickHouse actually runs after optimisation |
| `EXPLAIN PLAN` | Execution plan with index usage | **Primary tool.** Validate index usage, PREWHERE, parts read. |
| `EXPLAIN PIPELINE` | Thread/stream parallelism layout | Performance tuning, identifying bottlenecks |
| `EXPLAIN ESTIMATE` | Estimated rows/parts/marks to read | Quick sizing without running the query |
| `EXPLAIN CURRENT SETTINGS` | Active settings for the query | Debug configuration issues |

### EXPLAIN PLAN — Start Here

Always start here. `indexes = 1` shows primary key and skip index usage — this is
the single most useful diagnostic you have.

```sql
EXPLAIN PLAN indexes = 1
SELECT _org_id, count()
FROM threat_events
WHERE _org_id = 'acme'
  AND severity = 'critical'
  AND _timestamp_load >= '2026-01-01'
  AND _timestamp_load < '2026-02-01'
GROUP BY _org_id;
```

Example output (annotated):

```text
Expression ((Project names + Projection))
  Aggregating
    Expression (Before GROUP BY)
      Filter (WHERE)
        ReadFromMergeTree (default.threat_events)
        Indexes:
          PrimaryKey                              ← sparse index on ORDER BY columns
            Keys: _org_id, severity, _timestamp_load
            Condition: (_org_id = 'acme') AND (severity = 'critical')
                       AND (_timestamp_load >= '2026-01-01') AND (_timestamp_load < '2026-02-01')
            Parts: 3/24                           ← only 3 of 24 parts read
            Granules: 47/18562                    ← only 47 of 18562 granules read
          Skip
            Name: idx_rule_name                   ← skip index (if defined)
            Description: bloom_filter GRANULARITY 4
            Parts: 3/3
            Granules: 45/47                       ← further reduced by skip index
```

**What to look for:**

| Field | Good | Bad |
|---|---|---|
| `Parts: 3/24` | Low ratio = good index selectivity | `24/24` = full scan, index not used |
| `Granules: 47/18562` | Low ratio = reading small fraction | High ratio = scanning too much data |
| `PrimaryKey Keys:` | Your WHERE columns appear | Your filter columns are missing |
| `Condition:` | All filter conditions listed | Some conditions missing (not in ORDER BY prefix) |

### EXPLAIN PIPELINE — Parallelism Analysis

```sql
EXPLAIN PIPELINE
SELECT _org_id, count()
FROM threat_events
WHERE _org_id = 'acme'
GROUP BY _org_id;
```

Example output:

```text
(Expression)
ExpressionTransform × 16                    ← 16 parallel threads for projection
  (Aggregating)
  Resize 16 → 16
    AggregatingTransform × 16               ← 16 parallel aggregation streams
      (Expression)
      ExpressionTransform × 16
        (Filter)
        FilterTransform × 16                ← 16 parallel filter streams
          (ReadFromMergeTree)
          MergeTreeSelect(pool: ReadPool, algorithm: Thread) × 16
                                             ← 16 parallel disk reads
```

**What to look for:**

- `× N` — the parallelism level. Should match your core count for large queries.
- `Resize X → Y` — stream count changes. Watch for `→ 1` bottlenecks.
- `MergeTreeSelect algorithm: Thread` — parallel reads (good). `InOrder` means
  sequential (may be needed for ORDER BY but slower).

### EXPLAIN ESTIMATE — Quick Sizing

Doesn't execute the query. Fast estimate of how much work it'll do.

```sql
EXPLAIN ESTIMATE
SELECT * FROM threat_events WHERE _org_id = 'acme';
```

```text
┌─database─┬─table──────────┬─parts─┬─rows──────┬─marks─┐
│ default  │ threat_events  │     3 │ 384_712   │    47 │
└──────────┴────────────────┴───────┴───────────┴───────┘
```

Sanity-check before running expensive queries. If `rows` is in the billions for
what should be a filtered query, your index isn't being used — fix the ORDER BY
or add a skip index before running it for real.

### EXPLAIN SYNTAX — See What Actually Runs

Shows the query after ClickHouse's optimiser rewrites it. Check whether PREWHERE
was auto-applied, predicates pushed down, aliases resolved.

```sql
EXPLAIN SYNTAX
SELECT *
FROM threat_events
WHERE severity = 'critical' AND _timestamp_load > '2026-01-01';
```

```text
SELECT
    _timestamp,
    _timestamp_load,
    _org_id,
    _uuid,
    severity,
    source_ip,
    rule_name,
    _json
FROM threat_events
PREWHERE severity = 'critical'       ← auto-promoted from WHERE to PREWHERE
WHERE _timestamp_load > '2026-01-01'
```

### Worked Example: Diagnosing a Slow Query

Real scenario: billion-row table, query takes 30 seconds when it should take 2:

```sql
SELECT source_ip, count() AS cnt
FROM threat_events
WHERE severity = 'critical'
  AND _timestamp_load >= '2026-01-01'
  AND _timestamp_load < '2026-02-01'
GROUP BY source_ip
ORDER BY cnt DESC
LIMIT 100;
```

**Step 1:** Check the execution plan.

```sql
EXPLAIN PLAN indexes = 1
SELECT source_ip, count() AS cnt
FROM threat_events
WHERE severity = 'critical'
  AND _timestamp_load >= '2026-01-01'
  AND _timestamp_load < '2026-02-01'
GROUP BY source_ip
ORDER BY cnt DESC
LIMIT 100;
```

If you see `Granules: 18000/18562` — the index is doing almost nothing. Check your
`ORDER BY`. If the table is `ORDER BY (source_ip, _timestamp_load)` but you're filtering
on `severity`, the index can't help — `severity` isn't a prefix of ORDER BY.

**Step 2:** Check the pipeline.

```sql
EXPLAIN PIPELINE
SELECT source_ip, count() AS cnt ...
```

If you see `MergeTreeSelect × 1` instead of `× 16`, parallelism isn't engaged.
Check `max_threads` setting — someone may have set it to 1 for a debugging session
and forgot to revert.

**Step 3:** Check what the optimiser actually runs.

```sql
EXPLAIN SYNTAX
SELECT source_ip, count() AS cnt ...
```

Verify that PREWHERE is engaged for the most selective condition.

**Step 4:** Fix the issue. In this case, the table needs:
`ORDER BY (_org_id, severity, _timestamp_load)` — or add a projection with that order.

### Mandatory EXPLAIN Rule for AI Assistants

**RULE:** Before suggesting any query on a table w/ more than 1M rows, or any
JOIN on non-trivial tables:

1. Run `EXPLAIN PLAN indexes = 1` — verify primary key columns appear in `Indexes`
2. Check `Parts` and `Granules` ratios — reading > 50% = near-full scan, fix it
3. Run `EXPLAIN PIPELINE` — verify parallelism (`× N` where N > 1)
4. If `FINAL` is used, run `EXPLAIN SYNTAX` — PREWHERE won't be auto-applied w/
   FINAL, so check it's there

If you don't have access to run EXPLAIN, say so explicitly and state your
assumptions about the schema. Don't just hope the query is efficient.

---

## Insert Strategy

Each `INSERT` creates a new **part** on disk. The merge scheduler combines small
parts in the background, but it can only keep up w/ so many. Hit 300+ active parts
per partition and ClickHouse throws "Too many parts" and refuses writes. We've seen
this kill production when someone deployed a microservice doing single-row inserts
in a loop — 500 inserts/second = 500 parts/second = dead in under a minute.

### Batch Sizing

```sql
-- ❌ Single-row inserts in a loop (1 part per INSERT)
INSERT INTO threat_events VALUES (now64(3), now64(3), 'acme', generateUUIDv7(), 'high', ...);
INSERT INTO threat_events VALUES (now64(3), now64(3), 'acme', generateUUIDv7(), 'low', ...);
INSERT INTO threat_events VALUES (now64(3), now64(3), 'acme', generateUUIDv7(), 'medium', ...);
-- 1000 inserts = 1000 parts = dead server

-- ❌ Tiny batches (still too many parts)
INSERT INTO threat_events VALUES (...), (...);  -- 2 rows

-- ✅ Min 1K rows per INSERT, aim for 10K-100K
INSERT INTO threat_events VALUES
    (now64(3), now64(3), 'acme', generateUUIDv7(), 'high', ...),
    (now64(3), now64(3), 'acme', generateUUIDv7(), 'medium', ...),
    -- ... 10,000+ rows ...
    (now64(3), now64(3), 'acme', generateUUIDv7(), 'low', ...);
```

**Target:** one INSERT per second max, 1K+ rows per INSERT. Sweet spot is
10K-100K rows per batch — one part per batch, merge scheduler stays happy.

### Async Inserts (Server-Side Batching)

When client-side batching isn't practical — many independent producers, edge devices,
serverless functions — shift batching to the server. ClickHouse collects small
inserts and flushes them as a single part.

```sql
-- Per-query async inserts
INSERT INTO audit_log VALUES (now64(3), now64(3), 'acme', 'login', 'user-42')
SETTINGS
    async_insert = 1,
    wait_for_async_insert = 1,             -- wait for server to flush
    async_insert_max_data_size = 10000000, -- flush at 10 MB
    async_insert_busy_timeout_ms = 1000;   -- or flush every 1 second
```

Or set globally per user:

```sql
ALTER USER myapp SETTINGS
    async_insert = 1,
    wait_for_async_insert = 1;
```

### Deduplication

ClickHouse deduplicates inserts by default in replicated tables (based on a hash of
the insert block). This is idempotent: retrying the same INSERT is safe.

```sql
-- Deduplication window (number of recent blocks to track)
-- Default: 100 for ReplicatedMergeTree
SET replicated_deduplication_window = 1000;
```

For non-replicated tables, deduplication is off by default.
`ReplacingMergeTree` deduplicates by ORDER BY key during background merges (eventual,
not immediate).

---

## Updates and Deletes

### Lightweight DELETE (GA since v23.3)

Masks rows w/ a `_row_exists` column — fast, non-blocking. Rows are physically
removed during the next merge cycle. Use for targeted deletes (GDPR erasure, data
corrections). Not for bulk deletes — if you're deleting millions of rows, rethink
your approach (TTL, partitioned DROP, or redesign the table).

```sql
-- Lightweight delete — fast, non-blocking
DELETE FROM dfe.default WHERE _uuid = '01936f1e-...-abcd1234';

-- Check for pending deletes
SELECT * FROM system.mutations WHERE is_done = 0;
```

### Mutations (ALTER TABLE UPDATE/DELETE) — Heavy, Async

These rewrite entire data parts. On a 500GB table, a mutation that touches 10% of
parts still rewrites ~50GB of data. Use only when lightweight delete or
ReplacingMergeTree won't work.

```sql
-- ❌ Heavy mutation — rewrites all parts containing matching rows
ALTER TABLE dfe.default UPDATE severity = 'archived'
    WHERE _timestamp_load < '2023-01-01';

-- ❌ Heavy mutation — rewrites parts
ALTER TABLE dfe.default DELETE WHERE _org_id = '';

-- Monitor mutation progress
SELECT * FROM system.mutations
WHERE database = 'dfe' AND table = 'events' AND is_done = 0;
```

### ReplacingMergeTree: argMax vs FINAL

`ReplacingMergeTree` keeps only the latest row per ORDER BY key, but dedup only
happens during background merges. Until merge runs, multiple versions exist. This
is the single most misunderstood ClickHouse concept — people expect immediate
dedup like a PostgreSQL UPSERT. It's eventual, not immediate.

```sql
-- ❌ FINAL forces merge at query time (10-100x slower)
SELECT * FROM users FINAL WHERE user_id = 123;

-- ✅ argMax pattern — works correctly without FINAL
SELECT
    user_id,
    argMax(name, updated_at) AS name,
    argMax(email, updated_at) AS email,
    max(updated_at) AS updated_at
FROM users
WHERE user_id = 123
GROUP BY user_id;

-- If you must use FINAL, tune it:
SELECT * FROM users FINAL
PREWHERE tenant_id = 42          -- explicit PREWHERE (9x faster with FINAL)
SETTINGS
    do_not_merge_across_partitions_select_final = 1,
    max_final_threads = 16;
```

**Hard numbers on 1B rows:** Regular query = 0.149s. With FINAL = 2.399s (16x slower).
With tuned FINAL (PREWHERE + partition scoping) = 0.309s (2x slower, acceptable).

### CollapsingMergeTree / VersionedCollapsingMergeTree

When you need query-time correctness before merge runs — i.e. you can't wait for
background dedup — use sign-based cancellation. More complex to work w/ but gives
you correct results immediately.

```sql
-- VersionedCollapsingMergeTree (safe for multi-threaded inserts)
CREATE TABLE orders (
    order_id UInt64,
    status LowCardinality(String),
    amount Decimal(10, 2),
    sign Int8,       -- +1 = insert, -1 = cancel
    version UInt64
) ENGINE = VersionedCollapsingMergeTree(sign, version)
ORDER BY order_id;

-- Insert original
INSERT INTO orders VALUES (1001, 'pending', 99.99, 1, 1);

-- "Update": cancel old row + insert new row
INSERT INTO orders VALUES
    (1001, 'pending', 99.99, -1, 1),     -- cancel version 1
    (1001, 'confirmed', 99.99, 1, 2);    -- insert version 2

-- Query with sign-aware aggregation
SELECT
    order_id,
    argMax(status, version) AS status,
    sum(amount * sign) AS amount
FROM orders
GROUP BY order_id
HAVING sum(sign) > 0;  -- exclude fully cancelled orders
```

---

## Materialised Views and Projections

### Incremental Materialised Views (Trigger on INSERT)

ClickHouse MVs are **insert triggers**, not periodic refreshes like PostgreSQL or
dbt. When data lands in the source table, the MV's SELECT runs on the inserted
block (not the full table) and writes results to the target table. This is how we
build sub-second dashboards on PB-scale data — the heavy aggregation happens at
insert time, not query time.

```sql
-- Step 1: Create the target table
CREATE TABLE hourly_stats (
    hour DateTime,
    _org_id LowCardinality(String),
    event_count UInt64,
    unique_sources AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (_org_id, hour);

-- Step 2: Create the MV with TO clause
CREATE MATERIALIZED VIEW hourly_stats_mv TO hourly_stats AS
SELECT
    toStartOfHour(_timestamp_load) AS hour,
    _org_id,
    count() AS event_count,
    uniqState(source_ip) AS unique_sources  -- -State suffix for aggregate storage
FROM dfe.default
GROUP BY hour, _org_id;

-- Step 3: Backfill from existing data (after MV creation)
INSERT INTO hourly_stats
SELECT
    toStartOfHour(_timestamp_load) AS hour,
    _org_id,
    count() AS event_count,
    uniqState(source_ip) AS unique_sources
FROM dfe.default
GROUP BY hour, _org_id;

-- Step 4: Query with -Merge suffix
SELECT
    hour,
    _org_id,
    sum(event_count) AS total_events,
    uniqMerge(unique_sources) AS sources   -- -Merge suffix to finalise
FROM hourly_stats
GROUP BY hour, _org_id;
```

**Critical:** `GROUP BY` in an MV only aggregates within each insert block — not
across all data. That's why you pair MVs w/ `AggregatingMergeTree` or
`SummingMergeTree` — they merge partial aggregates across blocks during background
merges.

**Do not use `POPULATE`** — it races w/ concurrent inserts and can miss or
duplicate data. Create the MV first, then backfill w/ a manual INSERT INTO ... SELECT.

### AggregatingMergeTree -State / -Merge Pattern

This is the pattern every AI tool gets wrong. Every single one. The rule:

- `-State` functions when **writing** — stores intermediate aggregate state as binary
- `-Merge` functions when **reading** — finalises the aggregation from stored state

```sql
-- ❌ WRONG: Plain aggregates in AggregatingMergeTree target
CREATE TABLE agg (
    date Date,
    user_count UInt64       -- plain type, will not merge correctly
) ENGINE = AggregatingMergeTree() ORDER BY date;

-- ✅ RIGHT: AggregateFunction types
CREATE TABLE agg (
    date Date,
    user_count AggregateFunction(uniq, UInt64),
    total AggregateFunction(sum, Float64)
) ENGINE = AggregatingMergeTree() ORDER BY date;

-- Write with -State
INSERT INTO agg SELECT
    toDate(_timestamp_load) AS date,
    uniqState(source_ip),
    sumState(bytes_transferred)
FROM dfe.default GROUP BY date;

-- Read with -Merge
SELECT date, uniqMerge(user_count), sumMerge(total)
FROM agg GROUP BY date;
```

### Refreshable Materialised Views (GA v24.10)

For periodic full-refresh patterns — replaces cron jobs and dbt runs w/ native
ClickHouse scheduling.

```sql
CREATE MATERIALIZED VIEW daily_report
REFRESH EVERY 1 HOUR
TO daily_report_table
AS SELECT
    toDate(_timestamp_load) AS date,
    _org_id,
    count() AS total_events,
    uniqExact(source_ip) AS unique_sources
FROM dfe.default
WHERE _timestamp_load >= today() - 7
GROUP BY date, _org_id;

-- Monitor refresh status
SELECT * FROM system.view_refreshes;
```

Use `DEPENDS ON` for chaining refreshable MVs in sequence.

### Projections (Alternative Sort Orders)

Projections store an alternative sort order within the same table — ClickHouse
auto-selects the best one at query time. No query rewriting, no separate tables to
manage. The tradeoff: extra storage and write amplification.

```sql
CREATE TABLE dfe.default (
    _timestamp DateTime64(3, 'UTC'),
    _timestamp_load DateTime64(3, 'UTC'),
    _org_id LowCardinality(String),
    _uuid UUID DEFAULT generateUUIDv7(),
    severity LowCardinality(String),
    source_ip String,
    rule_name LowCardinality(String),
    _json JSON,
    PROJECTION by_source_ip (
        SELECT * ORDER BY source_ip, _timestamp_load  -- alternative sort for IP lookups
    ),
    PROJECTION daily_counts (
        SELECT
            toDate(_timestamp_load) AS date,
            _org_id,
            count() AS cnt
        GROUP BY date, _org_id
    )
) ENGINE = ReplicatedMergeTree()
ORDER BY (_org_id, severity, _timestamp_load);

-- Backfill projections for existing data
ALTER TABLE dfe.default MATERIALIZE PROJECTION by_source_ip;
ALTER TABLE dfe.default MATERIALIZE PROJECTION daily_counts;
```

**Projections vs Materialised Views:**

| | Projections | Materialised Views |
|---|---|---|
| Storage | Within same table | Separate table |
| Query transparency | Automatic selection | Must query target table |
| Chaining | No | Yes |
| Complex transforms | No (simple GROUP BY only) | Yes |
| TTL | Follows source table | Independent |
| FINAL support | No (until v25.8+) | Yes |

---

## New Features (v24.x — v26.x)

Features AI assistants need to know about — these weren't in your training data.
All GA unless noted.

### JSON Type (GA v25.3)

Completely redesigned — the old `Object('json')` is removed. See
[Data Types > JSON Type](#json-type-ga-v253) for typed path hints, SKIP/REGEXP
directives, and performance guidance. See [DFE > The Ingest-First Pattern](#the-ingest-first-pattern)
for the progressive break-out workflow.

### Dynamic and Variant Types (GA v25.3)

**Variant** — discriminated union (tagged enum). Use when you know the possible types:

```sql
CREATE TABLE mixed_data (
    id UInt64,
    value Variant(UInt64, String, Array(String))
) ENGINE = MergeTree() ORDER BY id;

INSERT INTO mixed_data VALUES (1, 42), (2, 'hello'), (3, ['a', 'b']);
```

**Dynamic** — stores any type w/o declaring them upfront. Use when you don't know:

```sql
CREATE TABLE flexible (
    id UInt64,
    data Dynamic(max_types = 16)
) ENGINE = MergeTree() ORDER BY id;
```

Both are column-oriented internally — much faster than storing as `String` and
parsing on every query. The JSON type uses Dynamic under the hood for its dynamic
paths.

### Full-Text Search / Text Index (GA Redesign v25.10)

Completely redesigned inverted index — deterministic (no false positives), row-level
filtering, 45x faster than without index on the Hackernews benchmark. See
[Schema Design > Full-Text Search](#full-text-search--text-index-ga-v2510) for the
full treatment including tokeniser options, preprocessor, and direct read
optimisation.

### Query Condition Cache (v25.3)

Caches scan results for repeated queries w/ selective WHERE clauses. Stores 1 bit
per filter condition per granule. Transparent — no config needed.

Dashboard queries that run every few seconds w/ the same filters: 0.8s → 50ms
after the first execution. Basically free.

### Lazy Materialisation (v25.4)

Defers reading column data until actually needed. Massive I/O reduction for Top-N
queries on wide tables.

```sql
-- Lazy materialisation kicks in here:
SELECT source_ip, rule_name, severity, _json
FROM dfe.default
WHERE _org_id = 'acme'
ORDER BY _timestamp_load DESC
LIMIT 100;
-- ClickHouse reads ONLY _timestamp_load + _org_id for filtering/sorting,
-- then reads the other columns for just the final 100 rows.
```

**Hard numbers:** 219s → 0.14s. 40x less data read. 300x lower memory. This is
one of those features that makes previously impossible queries trivial.

### Vector Similarity Search (GA v25.8)

For embedding-based search in AI/ML applications.

```sql
CREATE TABLE embeddings (
    id UInt64,
    text String,
    vector Array(Float32),
    INDEX idx_vec vector TYPE vector_similarity('hnsw', 'cosineDistance')
) ENGINE = MergeTree() ORDER BY id;

-- Find 10 nearest neighbours
SELECT id, text, cosineDistance(vector, [0.1, 0.2, ...]) AS dist
FROM embeddings
ORDER BY dist
LIMIT 10;
```

### Lightweight Updates / Patch Parts (Experimental v25.7)

Standard SQL `UPDATE` using a patch-part mechanism — up to 1,000x faster than
classic mutations. **Still experimental** — requires manual enablement. Watch for
GA. This could change ClickHouse's "immutable rows" limitation significantly.

---

## Use Case Patterns

### Data Warehouse / Analytics

Wide denormalised fact tables. Dimension lookups via dictionaries or small JOINs
(dimension table on the right). Pre-aggregate w/ materialised views for dashboard
queries — raw fact table for ad-hoc analysis.

```sql
CREATE TABLE fact_detections (
    _timestamp DateTime64(3, 'UTC'),
    _timestamp_load DateTime64(3, 'UTC') DEFAULT now64(3),
    _org_id LowCardinality(String),
    severity LowCardinality(String),
    rule_category LowCardinality(String),
    rule_id UInt32,
    source_ip IPv4,
    destination_ip IPv4,
    bytes_transferred UInt64,
    risk_score Float32
) ENGINE = ReplicatedMergeTree()
PARTITION BY (toYYYYMM(_timestamp_load), _org_id)
ORDER BY (_org_id, rule_category, severity, _timestamp_load)
SETTINGS index_granularity = 8192;

-- Pre-aggregation for security dashboards
CREATE TABLE daily_detection_agg (
    date Date,
    _org_id LowCardinality(String),
    rule_category LowCardinality(String),
    total_detections AggregateFunction(count),
    unique_sources AggregateFunction(uniq, IPv4),
    total_bytes AggregateFunction(sum, UInt64)
) ENGINE = AggregatingMergeTree()
ORDER BY (_org_id, rule_category, date);

CREATE MATERIALIZED VIEW daily_detection_mv TO daily_detection_agg AS
SELECT
    toDate(_timestamp_load) AS date,
    _org_id,
    rule_category,
    countState() AS total_detections,
    uniqState(source_ip) AS unique_sources,
    sumState(bytes_transferred) AS total_bytes
FROM fact_detections
GROUP BY date, _org_id, rule_category;
```

### Time-Series (IoT, Metrics)

For multi-tenant time-series w/ the DFE common header pattern (dual timestamps,
`_org_id`, `_uuid`), see [DFE > Common Header](#common-header).

#### Standard Time-Series Schema

For simpler use cases w/o multi-tenant or DFE requirements:

```sql
CREATE TABLE device_metrics (
    timestamp DateTime('UTC') CODEC(DoubleDelta, LZ4),
    device_id UInt32 CODEC(Delta, LZ4),
    metric_name LowCardinality(String) CODEC(LZ4),
    value Float64 CODEC(Gorilla, ZSTD(1)),
    tags Map(LowCardinality(String), String) CODEC(ZSTD(1))
) ENGINE = ReplicatedMergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (metric_name, device_id, timestamp)
TTL
    timestamp + INTERVAL 30 DAY TO VOLUME 'warm',
    timestamp + INTERVAL 180 DAY DELETE;
```

#### Downsampling w/ Materialised Views

```sql
-- 1-minute raw → 1-hour rollups
CREATE TABLE device_metrics_hourly (
    hour DateTime,
    device_id UInt32,
    metric_name LowCardinality(String),
    avg_value AggregateFunction(avg, Float64),
    min_value AggregateFunction(min, Float64),
    max_value AggregateFunction(max, Float64),
    sample_count AggregateFunction(count)
) ENGINE = AggregatingMergeTree()
ORDER BY (metric_name, device_id, hour);

CREATE MATERIALIZED VIEW device_metrics_hourly_mv TO device_metrics_hourly AS
SELECT
    toStartOfHour(timestamp) AS hour,
    device_id,
    metric_name,
    avgState(value) AS avg_value,
    minState(value) AS min_value,
    maxState(value) AS max_value,
    countState() AS sample_count
FROM device_metrics
GROUP BY hour, device_id, metric_name;
```

### Log Analytics / Observability

This is where text indexes (v25.10+) really shine. Bloom filter indexes were
adequate — text indexes are 45x faster w/ no false positives.

```sql
CREATE TABLE logs (
    timestamp DateTime64(3, 'UTC') CODEC(DoubleDelta, LZ4),
    trace_id FixedString(32) CODEC(ZSTD(1)),
    span_id FixedString(16) CODEC(ZSTD(1)),
    service LowCardinality(String) CODEC(LZ4),
    level LowCardinality(String) CODEC(LZ4),
    message String CODEC(ZSTD(3)),
    attributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    INDEX idx_trace trace_id TYPE bloom_filter GRANULARITY 4,
    INDEX idx_message message TYPE tokenbf_v2(32768, 3, 0) GRANULARITY 1
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (service, level, timestamp)
TTL
    timestamp + INTERVAL 7 DAY TO VOLUME 'warm',
    timestamp + INTERVAL 30 DAY TO VOLUME 'cold',
    timestamp + INTERVAL 90 DAY DELETE;

-- Find logs by trace ID (bloom filter skip index)
SELECT timestamp, service, level, message
FROM logs
WHERE trace_id = '0af7651916cd43dd8448eb211c80319c'
ORDER BY timestamp;

-- Full-text search on messages (v25.10+ text index)
-- ALTER TABLE logs ADD INDEX idx_ft message TYPE full_text GRANULARITY 1;
-- ALTER TABLE logs MATERIALIZE INDEX idx_ft;
SELECT timestamp, service, message
FROM logs
WHERE hasToken(message, 'connection') AND hasToken(message, 'refused')
ORDER BY timestamp DESC
LIMIT 100;
```

### Real-Time Dashboards

Pre-aggregate everything. Dashboard queries hit aggregated tables, not raw data.
The raw table is for ad-hoc investigation. If your dashboard query scans the raw
table, it's wrong — you need an MV.

```sql
-- Pre-aggregated security dashboard table
CREATE TABLE security_dashboard (
    window_start DateTime,
    _org_id LowCardinality(String),
    severity LowCardinality(String),
    detection_count SimpleAggregateFunction(sum, UInt64),
    unique_sources AggregateFunction(uniq, IPv4),
    p99_response_ms AggregateFunction(quantile(0.99), Float64)
) ENGINE = AggregatingMergeTree()
ORDER BY (_org_id, severity, window_start);

CREATE MATERIALIZED VIEW security_dashboard_mv TO security_dashboard AS
SELECT
    toStartOfMinute(_timestamp_load) AS window_start,
    _org_id,
    severity,
    count() AS detection_count,
    uniqState(source_ip) AS unique_sources,
    quantileState(0.99)(response_time_ms) AS p99_response_ms
FROM threat_events
GROUP BY window_start, _org_id, severity;

-- Dashboard query (fast — hits small pre-aggregated table)
SELECT
    window_start,
    sum(detection_count) AS detections,
    uniqMerge(unique_sources) AS sources,
    quantileMerge(0.99)(p99_response_ms) AS p99_ms
FROM security_dashboard
WHERE _org_id = 'acme'
  AND window_start >= now() - INTERVAL 1 HOUR
GROUP BY window_start
ORDER BY window_start;
```

### Incident Response Workflow / Funnel Analysis

ClickHouse was literally named for clickstream ("Click" + "House"), but
`windowFunnel()` works for any sequential event analysis — incident response
workflows are a natural fit.

```sql
CREATE TABLE incident_events (
    _timestamp DateTime64(3, 'UTC') CODEC(DoubleDelta, LZ4),
    _timestamp_load DateTime64(3, 'UTC') DEFAULT now64(3) CODEC(DoubleDelta, LZ4),
    _org_id LowCardinality(String) CODEC(LZ4),
    incident_id UInt64 CODEC(Delta, LZ4),
    analyst_id UInt32 CODEC(Delta, LZ4),
    event_type LowCardinality(String) CODEC(LZ4),
    severity LowCardinality(String) CODEC(LZ4),
    asset_hostname String CODEC(ZSTD(1)),
    notes String CODEC(ZSTD(3))
) ENGINE = ReplicatedMergeTree()
PARTITION BY (toYYYYMM(_timestamp_load), _org_id)
ORDER BY (_org_id, incident_id, _timestamp_load);

-- Incident response funnel: how far do incidents progress?
SELECT
    level,
    count() AS incidents
FROM (
    SELECT
        incident_id,
        windowFunnel(86400)(        -- 24-hour window
            _timestamp,
            event_type = 'detected',
            event_type = 'analyst_assigned',
            event_type = 'investigation_complete',
            event_type = 'remediation_deployed'
        ) AS level
    FROM incident_events
    WHERE _org_id = 'acme'
      AND _timestamp_load >= today() - 30
    GROUP BY incident_id
)
GROUP BY level
ORDER BY level;
-- level 0 = not even detected (shouldn't happen)
-- level 4 = full lifecycle completed
-- drop-off between levels shows where the process breaks down
```

---

## DFE (Data Fusion Engine)

This section covers HyperI's DFE pipeline — how data flows from source systems
into ClickHouse via `dfe-receiver` and `dfe-loader`. The generic ClickHouse advice
above applies to any project. This section is DFE-specific.

### Common Header

> **This section is NOT authoritative for the common header schema.** The source of
> truth is `dfe-loader/schemas/common_header.csv` and `common_table.sql`. This is a
> summary for context — it will drift as the schema evolves. Check the source.

Every DFE table gets a standardised header w/ underscore-prefixed system fields that
don't collide w/ source data field names. The underscore prefix is deliberate — it
separates DFE infrastructure from source data so you never get field name collisions
when ingesting arbitrary JSON.

**Current common header fields:**

| Column | Type | Expression | Notes |
|---|---|---|---|
| `_timestamp_load` | `DateTime64(3)` | `@generated: now64(3)` | When ClickHouse received the row. Primary query filter, in ORDER BY. |
| `_timestamp` | `DateTime64(3)` | `@source: timestamp \| now()` | When the event actually occurred. Minmax indexed. |
| `_timestamp_received` | `Nullable(DateTime64(3))` | `@source: timestamp_received` | When dfe-receiver got it. Nullable — only present if source includes it. |
| `_uuid` | `UUID` | `@generated: generateUUIDv7()` | Time-ordered unique ID. Generated by ClickHouse DEFAULT. |
| `_org_id` | `LowCardinality(String)` | `@source: org_id` | Tenant ID. First in ORDER BY for row-level security. |
| `_source` | `LowCardinality(String)` | `@source: first(_source) \| topic_name` | Data source / destination table identifier. |
| `_raw` | `Nullable(String)` | `@renamed: logoriginal` | Original log line (zero-copy rename from source field). |
| `_json` | `Nullable(JSON)` | `@captured: raw_payload as JSON` | Complete Kafka message as JSON. The ingest-first column. |
| `_tags` | `Nullable(JSON)` | `@source: first(tags/_tags/meta/metadata.tags)` | Metadata and collector/agent info. |

**Why two timestamps:** `_timestamp_load` is when ClickHouse received the data —
this is in ORDER BY, used for partition pruning, TTL, and "show me the last hour"
operational queries. `_timestamp` is when the event actually happened — used for
analytical queries ("show me events from last Tuesday"). PARTITION BY uses
`_timestamp_load` because that's what controls data arrival patterns.

**Standard ORDER BY:** `(_org_id, _timestamp_load, _uuid)` — tenant first for
row-level security, load time second for time-window queries, UUID last for
deterministic ordering within the same millisecond.

**Standard PARTITION BY:** `(toYYYYMM(_timestamp_load), _org_id)` — monthly by
load time, includes org_id for partition pruning (acceptable cardinality w/ <100
orgs).

```sql
-- DFE common header schema (simplified from common_table.sql)
CREATE TABLE IF NOT EXISTS {db}.{table}
(
    `_timestamp_load` DateTime64(3) DEFAULT now64(3) CODEC(Delta, ZSTD(1)),
    `_timestamp` DateTime64(3) CODEC(Delta, ZSTD(1)),
    `_timestamp_received` Nullable(DateTime64(3)) CODEC(Delta, ZSTD(1)),
    `_uuid` UUID DEFAULT generateUUIDv7(),
    `_org_id` LowCardinality(String) CODEC(ZSTD(1)),
    `_source` LowCardinality(String) CODEC(ZSTD(1)),
    `_raw` Nullable(String) CODEC(ZSTD(3)),
    `_json` Nullable(JSON) CODEC(ZSTD(3)),
    `_tags` Nullable(JSON) CODEC(ZSTD(3)),

    -- Indexes for non-primary key columns
    INDEX idx_timestamp _timestamp TYPE minmax GRANULARITY 1
)
ENGINE = {engine}
ORDER BY (_org_id, _timestamp_load, _uuid)
PARTITION BY (toYYYYMM(_timestamp_load), _org_id)
SETTINGS index_granularity = 8192;
```

**Engine auto-detection priority** (in dfe-loader):

1. `SharedMergeTree` — ClickHouse Cloud / v24.1+
2. `ReplicatedMergeTree` — clustered w/ ZooKeeper/Keeper
3. `MergeTree` — single-node fallback

### dfe-receiver

`dfe-receiver` is the HTTP/gRPC ingestion gateway — the entry point to the DFE
pipeline. It receives JSON payloads, validates them, routes them to Kafka topics
(or directly to dfe-loader), and applies backpressure when downstream is slow.

```text
Sources (Vector, APIs, agents)
    │
    ▼
dfe-receiver (axum HTTP / tonic gRPC / OTLP)
    ├─ Auth (header, bearer, mTLS)
    ├─ JSON validation (sonic-rs lazy parse — no full DOM)
    ├─ Enrich: inject _timestamp_received (epoch ms)
    ├─ Route: extract _source from payload → topic mapping
    │
    ├─→ Kafka topics ({source}_land)     ← default path
    └─→ dfe-loader (direct)             ← optional shortcut
```

**What it does NOT do:** No schema awareness, no ClickHouse interaction, no
transformation. It's a traffic splitter — authenticate, validate, route, deliver.
All transformation happens in dfe-loader.

**Key capabilities:**

- **Zero-copy hot path** — payload stays as `bytes::Bytes` through the pipeline;
  field extraction uses `Cow<str>` (borrow when no escaping needed)
- **SIMD JSON validation** — sonic-rs `LazyValue` validates structure w/o building
  a DOM tree
- **Per-topic batching** — 10K messages or 8 MiB or 20ms, whichever comes first
- **Backpressure** — memory pressure tracking (67% of available), returns 503 when
  saturated
- **Circuit breaker** — TieredSink w/ in-memory queue during downstream failures
- **Routing rules** — field-based source extraction (`key_value_use`,
  `key_present`, `key_value_set`) w/ topic suffix mapping
- **DLQ** — invalid JSON or unroutable messages go to a dead letter topic
- **Config hot-reload** — SIGHUP or periodic timer, no restart needed

**Routing example:**

```yaml
# Source rules: extract _source from payload
source_rules:
  - field: "_source"
    mode: "key_value_use"        # use field value as source name

# Topic mapping: source → Kafka topic
routing:
  source_to_topic:
    auth: "logs_auth"            # → logs_auth_land
    network: "logs_network"      # → logs_network_land
  default_source: "dfe"
  topic_suffix: "_land"
```

### dfe-loader

`dfe-loader` is the Kafka-to-ClickHouse transform and load engine. It consumes
from Kafka, parses JSON (SIMD), transforms to match the ClickHouse schema, builds
Arrow RecordBatches, and bulk-inserts via `clickhouse-arrow`.

The key differentiator: **the ClickHouse DDL is the schema definition**. Column
comments in `CREATE TABLE` statements contain an expression language that drives
all loader behaviour — field mapping, renaming, generation, computed columns. No
separate config file, no mapping YAML. The DDL IS the config.

#### DDL Expression Language

Column comments use `@` directives to declare how each column gets populated:

| Directive | Syntax | What It Does |
|---|---|---|
| `@source` | `@source: field_name \| fallback` | Copy from source JSON field. Supports `first(a/b/c)` for first non-null. |
| `@generated` | `@generated: expression` | Value produced by ClickHouse DEFAULT. Loader omits this field — CH generates it. |
| `@captured` | `@captured: description` | Raw payload captured before transformation (the `_json` column). |
| `@renamed` | `@renamed: source_field` | Zero-copy field rename. Supports `first(a/b)` for fallback names. |
| `@computed` | `@computed: expression` | Enrichment — `geoip(ip).country_code`, `risk(ip).score`, etc. |
| `@config` | `@config: config.path` | Marks the mapping as configurable from YAML/ENV. Always paired w/ another directive. |

```sql
-- Example: DDL comments drive loader behaviour
CREATE TABLE dfe.auth_events (
    -- @generated: now64(3)
    `_timestamp_load` DateTime64(3) DEFAULT now64(3) CODEC(Delta, ZSTD(1)),

    -- @source: timestamp | now()
    `_timestamp` DateTime64(3) CODEC(Delta, ZSTD(1)),

    -- @generated: generateUUIDv7()
    `_uuid` UUID DEFAULT generateUUIDv7(),

    -- @source: org_id
    -- @config: routing.org_id_field (default: "org_id")
    `_org_id` LowCardinality(String) CODEC(ZSTD(1)),

    -- @renamed: logoriginal
    `_raw` Nullable(String) CODEC(ZSTD(3)),

    -- @captured: raw_payload as JSON
    `_json` Nullable(JSON) CODEC(ZSTD(3)),

    -- @source: first(user/username/user_name)
    `user` String,

    -- @computed: geoip(src_ip).country_code
    `geo_country` LowCardinality(String)
) ENGINE = ReplicatedMergeTree()
ORDER BY (_org_id, _timestamp_load, _uuid);
```

The loader reads these comments from `system.columns` at runtime — no recompile
for new field mappings. Schema caching w/ TTL handles refresh.

**Field mapping precedence** (highest → lowest):

1. ClickHouse column comments (`@renamed` directives)
2. Config per-field overrides (YAML)
3. External remap files (CSV/YAML)
4. Built-in presets (ECS, CIM, Beats)

#### Transform Pipeline

Ordered transformations on each JSON message:

1. **Extract tags** (before flattening — preserves nesting)
2. **Flatten** nested JSON objects (dot notation)
3. **Validate timestamp** (`timestamp` → `_timestamp` w/ fallback to `now()`)
4. **Rename fields** via `@renamed` directives (zero-copy `data.remove()`)
5. **Inject common header** (`_tags`, `_org_id`, `_source`, `_json`)
6. **Remove routing fields** (no longer needed in payload)
7. **Sanitise field names** (strip `@`, collapse `__`, trim `_`)

#### ClickHouse + Arrow Bulk Load

Apache Arrow gives you a columnar in-memory format that maps almost 1:1 to how
ClickHouse stores data on disk. Both are column-oriented — the alignment isn't a
coincidence.

We built `clickhouse-arrow` — a high-performance async Rust client for ClickHouse
w/ native Arrow integration. We expanded the original codebase by ~4x to get the
performance and feature set we needed for PB-scale ingestion.

```text
dfe-loader:
  Kafka consumer
    → sonic-rs SIMD JSON parse
    → nested structure flattening
    → field enrichment (computed columns, common header)
    → per-table ArrowBatchBuilder (buffered w/ flush thresholds)
    → RecordBatch (owned, Arc<ArrayData> per column)
        │
        ▼
clickhouse-arrow:
  RecordBatch::write_async()
    ├─ PrimitiveArray::values() → cast_slice → &[u8]  (zero-copy)
    ├─ StringArray offsets → batched varint → pooled buffer
    └─ write_vectored_all([bitmap, values])  (single syscall per column)
        │
        ▼
  LZ4 streaming compress → TCP socket → ClickHouse native protocol
  (constant memory, no intermediate buffer allocation)
        │
        ▼
ClickHouse server:
  Receive → decompress → write part → background merge
```

**Responsibility split:**

| Layer | What It Does |
|---|---|
| **dfe-loader** | SIMD JSON parsing (sonic-rs), nested structure flattening, field enrichment, per-table buffering w/ flush thresholds, schema caching w/ TTL, concurrent inserts w/ semaphore limiting, binary-split salvage for failed rows |
| **clickhouse-arrow** | Zero-copy Arrow → ClickHouse native serialisation, vectored I/O, streaming compression, connection pooling, parallel EXPLAIN, schema introspection |
| **ClickHouse server** | Storage, merges, replication, query execution |

**clickhouse-arrow capabilities:**

- **Zero-copy insert** — primitive columns via `bytemuck::cast_slice`, no intermediate buffers
- **Vectored I/O** — null bitmap + values in a single syscall (15-25% reduction)
- **Streaming LZ4** — constant memory, no BytesMut spikes
- **Deferred flush** — 98% fewer syscalls (102 → 2 for 100 blocks)
- **SIMD null bitmap expansion** — 2.2x speedup
- **Buffer pooling** — size-tiered, thread-local, 21% faster allocations
- **Connection pooling** — up to 16, load-balanced
- **Schema introspection** — `system.columns` → Arrow Schema → round-trip validation
- **Parallel EXPLAIN** — runs EXPLAIN alongside actual query in separate tokio task
- **io_uring** — feature-gated, runtime detection for Linux 5.10+

**Performance (v0.4.x vs row-based inserts):** 40-60% throughput improvement for
bulk operations, 20-35% for string-heavy workloads.

**Arrow ↔ ClickHouse type mapping:**

| Arrow Type | ClickHouse Type | Notes |
|---|---|---|
| `Utf8` / `LargeUtf8` | `String` | Clean |
| `Dictionary(Int8, Utf8)` | `LowCardinality(String)` | Needs `SchemaConversions` hint |
| Arrow nullable flag | `Nullable(T)` | Arrow nullable ≠ CH Nullable — be explicit |
| `Decimal128(p, s)` | `Decimal(P, S)` | Precision/scale must match exactly |
| `Timestamp(ns, tz)` | `DateTime64(9, tz)` | Precision must match |
| `Struct` | `Tuple` | Field names preserved |

**Failed row handling:** Binary-split salvage — splits the batch in half recursively
until it isolates failing rows. Good rows get inserted, bad rows go to DLQ. No data
loss, no blocking.

#### Parallel EXPLAIN in the DFE Pipeline

This matters enough that we built parallel EXPLAIN into `clickhouse-arrow`. Every
query can optionally run its EXPLAIN alongside the actual execution:

```rust
// clickhouse-arrow: EXPLAIN runs in a separate tokio task alongside the query
let opts = QueryOptions::new().with_explain(ExplainOptions::plan());
let mut response = client.query_with_options("SELECT ...", opts).await?;

// Consume query results (streaming)
while let Some(batch) = response.next().await { /* ... */ }

// Get explain result (blocks only when you ask for it)
if let Some(explain) = response.explain().await { /* ... */ }
```

This isn't just for debugging — it's critical infrastructure for:

- **AI-supported query optimisation** — the meta schema uses EXPLAIN ESTIMATE
  (parts, rows, marks as structured Arrow data) to detect inefficient queries
  and recommend ORDER BY / partition changes automatically
- **Continuous schema improvement** — when DFE breaks out hot JSON paths to typed
  columns, EXPLAIN validates that the new schema actually improves query plans
- **Production monitoring** — parallel explain adds negligible overhead, so you can
  sample it on live traffic

EXPLAIN ESTIMATE returns structured tabular data (database, table, parts, rows,
marks) — not text to parse. This feeds directly into automated optimisation
pipelines.

#### The Ingest-First Pattern

Land everything in a `_json` column first. Don't try to design the perfect typed
schema upfront — you don't know what you'll need to query fast until production
traffic tells you. Progressively break out hot paths to dedicated typed columns
as query patterns emerge. Incremental improvement, not upfront perfection.

```sql
-- Stage 1: Everything in JSON (fast to ship, schema-flexible)
CREATE TABLE dfe.raw_events (
    _timestamp_load DateTime64(3) DEFAULT now64(3) CODEC(Delta, ZSTD(1)),
    _timestamp DateTime64(3) CODEC(Delta, ZSTD(1)),
    _org_id LowCardinality(String) CODEC(ZSTD(1)),
    _uuid UUID DEFAULT generateUUIDv7(),
    _json Nullable(JSON) CODEC(ZSTD(3)),
    INDEX idx_timestamp _timestamp TYPE minmax GRANULARITY 1
) ENGINE = ReplicatedMergeTree()
PARTITION BY (toYYYYMM(_timestamp_load), _org_id)
ORDER BY (_org_id, _timestamp_load, _uuid)
SETTINGS max_dynamic_paths = 1024;

-- Query directly against JSON sub-columns
SELECT _json.user_id, _json.action, _json.metadata.page
FROM dfe.raw_events
WHERE _org_id = 'acme'
  AND _timestamp_load >= '2026-01-01';

-- Stage 2: Break out hot paths as you learn what's queried heavily
CREATE TABLE dfe.default (
    _timestamp_load DateTime64(3) DEFAULT now64(3) CODEC(Delta, ZSTD(1)),
    _timestamp DateTime64(3) CODEC(Delta, ZSTD(1)),
    _org_id LowCardinality(String) CODEC(ZSTD(1)),
    _uuid UUID DEFAULT generateUUIDv7(),
    -- Broken out: these showed up in 80% of dashboard queries
    severity LowCardinality(String),
    source_ip String,
    -- Everything else stays in JSON
    _json Nullable(JSON) CODEC(ZSTD(3)),
    INDEX idx_timestamp _timestamp TYPE minmax GRANULARITY 1
) ENGINE = ReplicatedMergeTree()
PARTITION BY (toYYYYMM(_timestamp_load), _org_id)
ORDER BY (_org_id, severity, _timestamp_load)
SETTINGS max_dynamic_paths = 1024;
```

The feedback loop that makes this work at scale:

1. `clickhouse-arrow` fetches the current schema via `system.columns`
2. Runs `EXPLAIN ESTIMATE` on sample queries — parts/rows/marks as structured
   Arrow data
3. Compares before/after: does a new typed column reduce granules read?
4. Generates `ALTER TABLE ADD COLUMN` + backfill migration
5. Validates Arrow ↔ ClickHouse type round-trip is clean

You're not guessing which paths to promote — you're measuring.

#### Tokenisers and AI Workloads

The ClickHouse text index tokenisers (`splitByNonAlpha`, `ngrams`, etc.) are fine
for spike projects and general log search. For production AI work — DFE, membank,
LLM token accounting — we use our enhanced tiktoken layer that sits on top of
engine-specific tokenisers (Anthropic, OpenAI, Google). The ClickHouse text index
tokeniser operates at the search/indexing level, not the semantic level. Don't
conflate the two.

#### Regex Transpiler (Spike → GA Roadmap)

Derek has a spike project for a regex → ClickHouse native function transpiler. The
approach: parse the regex AST, identify which native functions cover the same
semantics, emit the rewritten query, and verify equivalence on a sample dataset
before deploying. Most real-world regex in analytics SQL falls into a small number
of patterns (substring search, starts/ends with, word boundary, URL extraction)
that map directly to native functions. See [Regex Is Evil](#regex-is-evil) for the
manual replacement table.

---

## For AI Assistants: Stop Making These Mistakes

Every AI coding assistant makes the same ClickHouse mistakes. Every single one.
These aren't suggestions — they're hard rules w/ hard numbers. If you're generating
ClickHouse SQL, read this and follow it.

### Do Not Use `SELECT *`

Each column is a separate file. `SELECT *` on a 200-column table = 200 file reads.
100+ GB scan vs 3 GB for 3 named columns on the same table, same row
count. Name your columns.

```sql
-- ❌
SELECT * FROM dfe.default WHERE _timestamp_load > now() - INTERVAL 1 HOUR;
-- ✅
SELECT severity, source_ip, _timestamp_load
FROM dfe.default WHERE _timestamp_load > now() - INTERVAL 1 HOUR;
```

### Do Not Use CTEs Expecting Materialisation

CTEs are macros — re-executed at every reference. Three references = three full
scans. We've seen this turn a 500GB scan into a TB of I/O.

```sql
-- ❌ (2 references = 2 full scans)
WITH by_src AS (SELECT source_ip, count() AS hits FROM dfe.default GROUP BY source_ip)
SELECT * FROM by_src WHERE hits > 1000
UNION ALL SELECT * FROM by_src WHERE hits <= 1000;
-- ✅
CREATE TEMPORARY TABLE tmp AS
    SELECT source_ip, count() AS hits FROM dfe.default GROUP BY source_ip;
SELECT * FROM tmp WHERE hits > 1000
UNION ALL SELECT * FROM tmp WHERE hits <= 1000;
```

### Do Not Put the Fact Table on the Right Side of a JOIN

Right table gets loaded into a hash table in memory. Billion-row fact table on the
right = OOM. Fact table left, dimension table right. Always.

```sql
-- ❌ (fact_events loaded into memory → OOM)
SELECT * FROM dim_users u JOIN fact_events e ON u.id = e.user_id;
-- ✅ (dim_users loaded into memory — small, fits easily)
SELECT * FROM fact_events e JOIN dim_users u ON e.user_id = u.id;
```

### Do Not Use `DISTINCT` When `GROUP BY` Works

On 1.8B rows: `DISTINCT` = 5.8s. `GROUP BY` = 1.3s. 4.5x faster.

```sql
-- ❌
SELECT DISTINCT source_ip FROM dfe.default;
-- ✅
SELECT source_ip FROM dfe.default GROUP BY source_ip;
```

### Do Not Use `Nullable` Columns by Default

`GROUP BY` on `Int64` = 229M rows/s. `Nullable(Int64)` = 98M rows/s.
That's 57% throughput lost for one Nullable column. Use defaults (`''`, `0`) unless
NULL has genuine semantic meaning. See [Data Types > Nullable](#nullable--the-performance-tax)
for when Nullable is unavoidable in ETL workloads.

### Do Not Insert One Row at a Time

Min 1K rows per INSERT, aim for 10K-100K. Single-row inserts = one part per INSERT.
500 inserts/second = 500 parts/second = "Too many parts" error in under a minute =
dead server. Use client-side batching or async inserts.

### Do Not Use `FINAL` Without Considering Alternatives

On 1B rows: regular query = 0.149s. With FINAL = 2.399s (16x slower).
Use `argMax()` pattern for ReplacingMergeTree. If you must use FINAL, add explicit
`PREWHERE` (not auto-applied w/ FINAL) and scope to partition.

```sql
-- ❌
SELECT * FROM asset_inventory FINAL WHERE _org_id = 'acme';
-- ✅ (argMax pattern — correct results, no FINAL overhead)
SELECT asset_id, argMax(hostname, updated_at) AS hostname, argMax(classification, updated_at) AS classification
FROM asset_inventory WHERE _org_id = 'acme' GROUP BY asset_id;
-- ✅ (tuned FINAL — 0.309s instead of 2.399s)
SELECT * FROM asset_inventory FINAL
PREWHERE _org_id = 'acme'
SETTINGS do_not_merge_across_partitions_select_final = 1;
```

### Do Not Put High-Cardinality Columns First in ORDER BY

UUID-first ORDER BY = 18000/18562 granules read (full scan). Tenant-first
= 47/18562 granules. Low cardinality first, most-filtered first, timestamp last.

```sql
-- ❌ (UUID first = useless index)
ORDER BY (event_id, tenant_id, timestamp)
-- ✅ (low cardinality first)
ORDER BY (tenant_id, event_type, timestamp)
```

### Do Not Use `BEGIN` / `COMMIT` / `ROLLBACK`

No multi-statement transactions. Each INSERT is atomic. Design for idempotent
inserts.

### Do Not Use `UPSERT`, `MERGE INTO`, or `ON CONFLICT`

Don't exist. Use ReplacingMergeTree (insert new version, old one deduplicated on
merge) or CollapsingMergeTree (cancel and re-insert pattern).

### Do Not Assume Skip Indexes Work Like B-Tree Indexes

Skip indexes work on granules (~8192 rows), not rows. They answer "does this
granule definitely NOT contain my value?" — that's it. Not B-tree. Can't seek to
a row. On randomly distributed data they're pure overhead.

### Do Not Forget `MATERIALIZE INDEX` After Adding an Index

`ALTER TABLE ... ADD INDEX` only applies to new inserts. Existing data stays
unindexed. Run `ALTER TABLE ... MATERIALIZE INDEX` — we've seen people add bloom
filter indexes and wonder why queries aren't faster, forgetting this step.

### Do Not Skip Codec Specifications on Large Tables

DoubleDelta for timestamps, Gorilla for floats = 3-5x better compression than
default LZ4. On billion-row tables that's terabytes of storage savings and
proportionally faster queries (less I/O = faster scans).

### Do Not Over-Partition

Monthly (`toYYYYMM`) is the default. Daily only if 10+ GB/day. At 1 GB/day you
get 365 tiny partitions/year and the merge scheduler struggles. Small tables (< few
GB) need no partitioning at all.

### Do Not Use `String` When `LowCardinality(String)` Applies

Under ~10K distinct values (status codes, country codes, service names) →
`LowCardinality(String)` gives 5-10x better compression and query speed via
dictionary encoding. Check first: `SELECT uniq(col) FROM table`.

### Do Not Write Queries Without Running `EXPLAIN PLAN`

If you have database access, verify every non-trivial query w/
`EXPLAIN PLAN indexes = 1`. Check `Parts` and `Granules` ratios — reading > 50% of
total granules = near-full scan. Fix the ORDER BY or add a skip index.

### Do Not Use the Old `Object('json')` Type

Removed. Use `JSON` (GA v25.3) — stores each path as a typed sub-column. See
[Data Types > JSON Type](#json-type-ga-v253).

### Do Not Wrap Columns in Functions in WHERE Clauses

Functions on columns in WHERE break index usage. Filter on raw column, transform in
SELECT.

```sql
-- ❌ (breaks index on timestamp)
WHERE toDate(timestamp) = '2026-01-15'
-- ✅ (preserves index usage)
WHERE timestamp >= '2026-01-15' AND timestamp < '2026-01-16'
```

### Do Not Use `OPTIMIZE TABLE FINAL` as Routine Maintenance

ClickHouse auto-merges. `OPTIMIZE TABLE FINAL` on a large table blocks for hours
and burns massive I/O. Only use for specific needs — and target partitions.

```sql
-- ❌ (blocks for hours)
OPTIMIZE TABLE dfe.default FINAL;
-- ✅ (scoped to partition)
OPTIMIZE TABLE dfe.default PARTITION '202601' FINAL;
```

### Do Not Assume `CASE` / `if()` / `multiIf()` Short-Circuits

ClickHouse evaluates **ALL branches** before checking the condition — it's vectorised,
not row-by-row. Your "safe" division guard still crashes w/ `Division by zero`.

```sql
-- ❌ (crashes — ELSE branch evaluated regardless of WHEN)
SELECT CASE WHEN total = 0 THEN 0 ELSE hits / total END AS rate
FROM dfe.default;
-- ❌ (same crash w/ if())
SELECT if(total != 0, hits / total, 0) FROM dfe.default;
-- ✅ (nullIf on the denominator — always safe)
SELECT hits / nullIf(total, 0) AS rate FROM dfe.default;
-- ✅ (OrZero variants — purpose-built for this)
SELECT intDivOrZero(hits, total) AS rate FROM dfe.default;
```

Open since 2017 ([#1562](https://github.com/ClickHouse/ClickHouse/issues/1562)).
`short_circuit_function_evaluation` setting exists but isn't on by default and still
has edge cases w/ Decimal types. `nullIf()` or `*OrZero` — just use those.

### Do Not Use `coalesce()` — Use `ifNull()`

PostgreSQL habit. `coalesce()` works but it's a multi-arg wrapper. `ifNull()` is
ClickHouse-native and 3.4x faster (1.42B rows/s vs 419M rows/s on 1B rows). If
you're certain NULLs don't exist, `assumeNotNull()` skips the null-mask entirely —
zero overhead, but returns garbage if NULLs are actually present.

```sql
-- ❌ (PostgreSQL habit — 3.4x slower)
SELECT coalesce(latency_ms, 0) FROM dfe.default;
-- ✅
SELECT ifNull(latency_ms, 0) FROM dfe.default;
```

### Do Not Expect Materialised Views to Backfill

MVs are `AFTER INSERT` triggers — they only process rows arriving via new INSERTs.
Creating an MV on a table w/ 1B existing rows gives you an **empty** MV. `POPULATE`
exists but is discouraged — it can miss concurrent inserts and OOM on large tables.

```sql
-- ❌ (MV is empty — existing data not processed)
CREATE MATERIALIZED VIEW hourly_stats
ENGINE = AggregatingMergeTree() ORDER BY hour
AS SELECT toStartOfHour(_timestamp_load) AS hour, countState() AS cnt
FROM dfe.default GROUP BY hour;
-- ✅ (create MV, then manually backfill in chunks)
CREATE MATERIALIZED VIEW hourly_stats
ENGINE = AggregatingMergeTree() ORDER BY hour
AS SELECT toStartOfHour(_timestamp_load) AS hour, countState() AS cnt
FROM dfe.default GROUP BY hour;
INSERT INTO hourly_stats
SELECT toStartOfHour(_timestamp_load) AS hour, countState() AS cnt
FROM dfe.default
WHERE _timestamp_load >= '2025-01-01' AND _timestamp_load < '2025-02-01'
GROUP BY hour;
-- repeat for each month
```

### Do Not Forget `-State` / `-Merge` w/ AggregatingMergeTree

`AggregatingMergeTree` stores intermediate aggregate states, not final values. Plain
`count()` / `avg()` / `uniq()` = wrong types on insert, wrong results on query.
Background merges silently corrupt the data — and it's cumulative, so the longer
you don't notice, the worse it gets.

```sql
-- ❌ (plain aggregates — type mismatch or silent corruption)
INSERT INTO daily_stats
SELECT toDate(_timestamp_load) AS day, count() AS cnt, avg(latency_ms) AS avg_lat
FROM dfe.default GROUP BY day;
-- ✅ (insert w/ -State, query w/ -Merge — GROUP BY still required)
INSERT INTO daily_stats
SELECT toDate(_timestamp_load) AS day, countState() AS cnt, avgState(latency_ms) AS avg_lat
FROM dfe.default GROUP BY day;

SELECT day, countMerge(cnt) AS cnt, avgMerge(avg_lat) AS avg_lat
FROM daily_stats GROUP BY day;
```

### Do Not Query ReplacingMergeTree Without Dedup Logic

Dedup only happens during background merges — timing is unpredictable. Until a merge
runs, duplicate rows coexist. Every query on a ReplacingMergeTree must handle this.

```sql
-- ❌ (returns multiple rows per asset — un-merged duplicates)
SELECT asset_id, hostname FROM asset_inventory WHERE _org_id = 'acme';
-- ✅ (argMax — fastest, correct)
SELECT asset_id, argMax(hostname, updated_at) AS hostname
FROM asset_inventory WHERE _org_id = 'acme' GROUP BY asset_id;
-- ✅ (FINAL — simpler but slower, see above)
SELECT asset_id, hostname FROM asset_inventory FINAL WHERE _org_id = 'acme';
```

And do NOT put the version column in `ORDER BY`. It becomes part of the dedup key,
so rows w/ different versions are distinct — dedup completely broken.

```sql
-- ❌ (version in ORDER BY = never deduplicates)
ENGINE = ReplacingMergeTree(version) ORDER BY (asset_id, version)
-- ✅ (version selects the winner, not part of the key)
ENGINE = ReplacingMergeTree(version) ORDER BY (asset_id)
```

### Do Not Query CollapsingMergeTree Without `sign`

Cancel rows (`sign = -1`) coexist w/ state rows (`sign = 1`) until merges run.
Queries must multiply values by `sign` and filter w/ `HAVING sum(sign) > 0`.

```sql
-- ❌ (counts both +1 and -1 rows — inflated)
SELECT user_id, count() AS sessions FROM user_sessions GROUP BY user_id;
-- ✅ (account for sign in every aggregate)
SELECT user_id, sum(sign) AS sessions
FROM user_sessions GROUP BY user_id HAVING sum(sign) > 0;
SELECT user_id, sum(duration * sign) AS total_duration
FROM user_sessions GROUP BY user_id HAVING sum(sign) > 0;
```

Cancel row must come before state row in insert order for `CollapsingMergeTree`.
Can't guarantee order? Use `VersionedCollapsingMergeTree` instead.

### Do Not Use `OFFSET` for Pagination

`OFFSET` is O(n). At OFFSET 100000, ClickHouse reads and throws away 100K rows.
Keyset pagination — constant time regardless of page depth.

```sql
-- ❌ (O(n) — gets worse w/ every page)
SELECT _uuid, _timestamp_load, severity
FROM dfe.default ORDER BY _timestamp_load DESC LIMIT 50 OFFSET 2450;
-- ✅ (keyset — pass last seen values from previous page)
SELECT _uuid, _timestamp_load, severity
FROM dfe.default
WHERE (_timestamp_load, _uuid) < ('2026-02-01 12:00:00', last_seen_uuid)
ORDER BY _timestamp_load DESC, _uuid DESC
LIMIT 50;
```

ClickHouse's sort is **unstable** — rows w/ identical sort values can reorder between
queries. Always add a tiebreaker column (`_uuid`) to `ORDER BY` when paginating,
otherwise rows appear on multiple pages or get skipped entirely.

### Do Not Combine `PREWHERE` w/ `FINAL`

`PREWHERE` filters **before** `FINAL` applies replacing/collapsing. If the newest
version of a row gets filtered out by `PREWHERE`, the old version survives. This is
a **correctness bug**, not a performance issue — deleted/replaced rows come back.

```sql
-- ❌ (PREWHERE runs before FINAL — replaced rows reappear)
SELECT * FROM asset_inventory FINAL PREWHERE status = 'active';
-- ✅ (WHERE runs after FINAL — dedup first, then filter)
SELECT * FROM asset_inventory FINAL WHERE status = 'active';
```

### Do Not Use `COUNT(DISTINCT col)` on Large Columns

Maps to `uniqExact()` internally — stores ALL distinct values in memory. Millions of
distinct values = 20x slower than `uniq()` and can OOM.

```sql
-- ❌ (stores every distinct value in memory)
SELECT COUNT(DISTINCT source_ip) FROM dfe.default;
-- ✅ (HyperLogLog — 0.81% error, 20x faster, constant memory)
SELECT uniq(source_ip) FROM dfe.default;
-- ✅ (or change the default)
SET count_distinct_implementation = 'uniq';
```

### Do Not Use `Float64` for Money or Exact Arithmetic

`Float64` can't represent `0.1` exactly. ClickHouse's parallel execution means float
addition order varies between runs — `sum(amount)` is **non-deterministic**. And
numeric literals w/ decimals default to `Float64`, not `Decimal`.

```sql
-- ❌ (non-deterministic sums, rounding errors)
CREATE TABLE invoices (amount Float64) ENGINE = MergeTree() ORDER BY id;
SELECT 9.2;  -- returns 9.19999999999999929
-- ✅
CREATE TABLE invoices (amount Decimal64(2)) ENGINE = MergeTree() ORDER BY id;
SELECT toDecimal64(9.2, 1);  -- returns 9.2 (exact)
```

`Decimal128`/`Decimal256` don't check for overflow — results silently wrap to
meaningless values. Prefer `Decimal64` where range allows.

### Do Not Use `CAST()` on Nullable Columns

`CAST()` silently strips `Nullable` and `LowCardinality`. NULLs become empty strings
or zeros — no error, no warning. Breaks every downstream `isNull()` check.

```sql
-- ❌ (NULLs silently become '' — data loss)
SELECT CAST(nullable_col AS String) FROM dfe.default;
-- ✅ (toString preserves Nullable)
SELECT toString(nullable_col) FROM dfe.default;
-- ✅ (explicit Nullable in CAST if you must use CAST)
SELECT CAST(nullable_col AS Nullable(String)) FROM dfe.default;
```

### Do Not Use `ALTER TABLE UPDATE/DELETE` as Routine Operations

Mutations rewrite entire data parts. They share the merge thread pool, can't be
rolled back, and stack up if you run them faster than ClickHouse can process.
Running them per-request = "Too many mutations" error = cluster instability.

```sql
-- ❌ (heavyweight — rewrites full parts, blocks merges)
ALTER TABLE dfe.default UPDATE status = 'processed' WHERE _uuid = '...';
-- ✅ (ReplacingMergeTree — insert new version, old one deduped on merge)
INSERT INTO dfe.default (_uuid, status, version) VALUES ('...', 'processed', now());
-- ✅ (TTL for time-based cleanup — automatic, zero maintenance)
ALTER TABLE dfe.default MODIFY TTL _timestamp_load + INTERVAL 1 YEAR DELETE;
-- ✅ (lightweight DELETE for GDPR — batch weekly, not per-request)
DELETE FROM dfe.default WHERE user_id IN (SELECT user_id FROM deletion_queue);
```

### Do Not Forget `ON CLUSTER` for Replicated Tables

Without `ON CLUSTER`, DDL only runs on the node that receives the query. Other
replicas stay unchanged — schema drift, intermittent failures, fun debugging.

```sql
-- ❌ (only changes one node)
ALTER TABLE dfe.default ADD COLUMN new_col String DEFAULT '';
-- ✅ (propagates to all replicas)
ALTER TABLE dfe.default ON CLUSTER '{cluster}' ADD COLUMN new_col String DEFAULT '';
```

### Do Not Forget `GLOBAL` in Distributed Subqueries

Without `GLOBAL`, each shard runs the right-side subquery locally. If tables are
sharded differently, each shard only sees a fraction of the data. Silently incomplete
results — no error, just missing rows.

```sql
-- ❌ (each shard only joins its LOCAL user data)
SELECT e.*, u.name
FROM distributed_events e
JOIN distributed_users u ON e.user_id = u.user_id;
-- ✅ (broadcasts right table to all shards)
SELECT e.*, u.name
FROM distributed_events e
GLOBAL JOIN distributed_users u ON e.user_id = u.user_id;
```

### Do Not Use Correlated Subqueries

Still Beta. Known bugs w/ distributed tables, column propagation, potential SEGV.
Rewrite as JOINs — always works, always stable.

```sql
-- ❌ (Beta — can crash or give wrong results on distributed)
SELECT user_id, amount,
    (SELECT max(amount) FROM dfe.default e2 WHERE e2._org_id = e._org_id) AS max_amount
FROM dfe.default e;
-- ✅ (rewrite as JOIN)
SELECT e.user_id, e.amount, m.max_amount
FROM dfe.default e
JOIN (SELECT _org_id, max(amount) AS max_amount FROM dfe.default GROUP BY _org_id) m
  ON e._org_id = m._org_id;
```

### Do Not Misalign TTL w/ PARTITION BY

TTL column must match PARTITION BY column. When they align, TTL drops whole partitions
— instant, zero I/O. When they don't, ClickHouse rewrites every part row-by-row. On a
10TB table that's a multi-hour mutation vs a millisecond metadata operation.

```sql
-- ❌ (different columns — row-by-row rewrite, hours of I/O)
PARTITION BY toYYYYMM(ingest_ts)
TTL event_ts + INTERVAL 90 DAY DELETE
-- ✅ (same column — clean partition drops)
PARTITION BY toYYYYMM(ingest_ts)
TTL ingest_ts + INTERVAL 90 DAY DELETE
SETTINGS ttl_only_drop_parts = 1;
```

Always set `ttl_only_drop_parts = 1`. See
[Partition Strategy > TTL](#ttl-and-tiered-storage).

### Do Not Generate PostgreSQL Syntax for ClickHouse

The meta-rule. If you're writing any of these, stop:

| PostgreSQL | ClickHouse Equivalent |
|---|---|
| `SERIAL` / `BIGSERIAL` / `AUTO_INCREMENT` | Not supported — use `generateUUIDv7()` or application-generated IDs |
| `VARCHAR(N)` | `String` or `FixedString(N)` |
| `BOOLEAN` | `UInt8` (0/1) or `Bool` |
| `TEXT` | `String` |
| `JSONB` | `JSON` (v25.3+) or `String` |
| `CREATE INDEX ... USING btree` | Not supported — use skip indexes |
| `ALTER TABLE ... ADD CONSTRAINT` | Not supported |
| `FOREIGN KEY` | Not supported |
| `VACUUM` / `ANALYZE` | Not applicable |
| `DISTINCT ON (col)` | `LIMIT 1 BY col` |
| `INSERT ... RETURNING` | Not supported |
| `string \|\| string` | `concat(string, string)` |
| `COALESCE(x, y)` | `ifNull(x, y)` (3.4x faster) |
| `DATE_TRUNC('hour', ts)` | `toStartOfHour(ts)` (10-15% faster) |
| `EXTRACT(YEAR FROM ts)` | `toYear(ts)` — and use range filters, not `toYear(ts) = 2026` |
| `POSITION(needle IN haystack)` | `position(haystack, needle)` (reversed args) |
| `SUBSTRING(s FROM 1 FOR 10)` | `substring(s, 1, 10)` — use `substringUTF8()` for Unicode |
| `lag(val) OVER (...)` | `lagInFrame(val, 1, 0) OVER (... ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)` |
| `GROUPS` frame / `EXCLUDE` clause | Not supported — use `ROWS` or `RANGE` |
| `COUNT(DISTINCT col)` | `uniq(col)` (HyperLogLog — 20x faster, constant memory) |
| Correlated subqueries | Rewrite as JOINs (still Beta in ClickHouse) |

---

## Other Useful Reads

- **ClickHouse Documentation:** <https://clickhouse.com/docs>
- **SQL Reference:** <https://clickhouse.com/docs/en/sql-reference>
- **EXPLAIN Statement:** <https://clickhouse.com/docs/en/sql-reference/statements/explain>
- **Best Practices:** <https://clickhouse.com/docs/en/best-practices>
- **ClickHouse Blog:** <https://clickhouse.com/blog>
- **ClickHouse Playground:** <https://play.clickhouse.com>
- **Altinity Knowledge Base:** <https://kb.altinity.com>
- **MergeTree Engine Family:** <https://clickhouse.com/docs/en/engines/table-engines/mergetree-family>
- **Data Types Reference:** <https://clickhouse.com/docs/en/sql-reference/data-types>
