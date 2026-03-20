# DFE Metrics Standard

Authoritative standard for metrics across all DFE pipeline applications.
Feature-gated in `hyperi-rustlib` (`metrics-dfe` feature). Opt-in, DFE-specific.

Non-DFE apps using rustlib are unaffected.

## Naming Convention

```
dfe_{app}_{metric_name}[_{unit}]
```

| Rule | Example |
|------|---------|
| App prefix required | `dfe_loader_`, `dfe_receiver_`, `dfe_archiver_` |
| Counters end in `_total` | `dfe_loader_rows_inserted_total` |
| Durations end in `_seconds` | `dfe_loader_insert_duration_seconds` |
| Byte metrics end in `_bytes` | `dfe_loader_buffer_bytes` |
| Ratios end in `_ratio` | `dfe_archiver_compression_ratio` |
| `dfe_*` (no app) reserved for rustlib `DfeMetrics` | `dfe_records_received_total` |

**App identifiers:** `receiver`, `loader`, `archiver`, `fetcher`, `transform_wasm`, `transform_vector`, `transform_vrl`

## Standard Labels

| Label | Values | Cardinality | Used By |
|-------|--------|-------------|---------|
| `transport` | `kafka`, `http`, `grpc`, `clickhouse`, `storage` | Low | Transport metrics |
| `reason` | Bounded enum per context | Low | Auth, validation, DLQ |
| `backend` | `file`, `s3`, `minio`, `gcs`, `azure` | Low | Storage operations |
| `table` | ClickHouse table name | Medium (bounded by schema) | Loader per-table |
| `trigger` | `size`, `age`, `eviction`, `records` | Low | Buffer flush, archive roll |
| `state` | `closed`, `open`, `half_open` | Low (3) | Circuit breaker |
| `to_state` | `closed`, `open`, `half_open` | Low (3) | CB transitions |
| `target` | Downstream identifier | Medium | Circuit breaker |
| `result` | `success`, `error`, `rejected` | Low | Config reloads |
| `format` | `json`, `msgpack`, `csv` | Low | Parse/serde |
| `stage` | `deserialise`, `transform`, `produce` | Low | Error breakdown |
| `status` | `success`, `error` | Low | Fetch/request results |
| `source` | Source config name | Medium | Fetcher per-source |

### Cardinality Rules

- **Low (<10):** Use freely
- **Medium (10-100):** OK with bounded set. Monitor growth
- **High (100+):** Cap at `max_label_cardinality` (default 50), roll overflow into `_other`
- **Unbounded:** NEVER use as label (no user IDs, IPs, request paths)

## Layer 1: Platform Metrics (rustlib DfeMetrics)

Emitted by `DfeMetrics::register()`. Every DFE app gets these automatically.
No changes needed. Namespace: `dfe_*` (no app qualifier).

### Transport

| Metric | Type | Labels |
|--------|------|--------|
| `dfe_transport_sent_total` | counter | `transport` |
| `dfe_transport_send_errors_total` | counter | `transport` |
| `dfe_transport_backpressured_total` | counter | `transport` |
| `dfe_transport_refused_total` | counter | `transport` |
| `dfe_transport_healthy` | gauge | `transport` |
| `dfe_transport_queue_size` | gauge | `transport` |
| `dfe_transport_queue_capacity` | gauge | `transport` |
| `dfe_transport_inflight` | gauge | `transport` |
| `dfe_transport_send_duration_seconds` | histogram | `transport` |

### Pipeline

| Metric | Type |
|--------|------|
| `dfe_pipeline_ready` | gauge |
| `dfe_pipeline_stall_seconds_total` | counter |

### Records

| Metric | Type |
|--------|------|
| `dfe_records_received_total` | counter |
| `dfe_records_delivered_total` | counter |
| `dfe_records_filtered_total` | counter |
| `dfe_records_dlq_total` | counter |

### Scaling

| Metric | Type |
|--------|------|
| `dfe_scaling_pressure` | gauge |
| `dfe_scaling_circuit_open` | gauge |
| `dfe_scaling_memory_pressure` | gauge |

### Spool

| Metric | Type |
|--------|------|
| `dfe_spool_bytes` | gauge |
| `dfe_spool_messages` | gauge |
| `dfe_spool_disk_available` | gauge |

### Security

| Metric | Type | Labels |
|--------|------|--------|
| `dfe_auth_failures_total` | counter | `reason` |
| `dfe_validation_failures_total` | counter | `reason` |

## Layer 2: Common Metric Groups (rustlib, opt-in)

Composable structs in rustlib. Each app picks which groups to use.
All metrics auto-prefixed with `dfe_{app}_` via `MetricsManager` namespace.

### AppMetrics (mandatory for all DFE apps)

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `info` | gauge (1) | `version`, `commit`, `app` | Service discovery |
| `start_time_seconds` | gauge | | Unix timestamp of process start |
| `records_received_total` | counter | | Records from source |
| `records_processed_total` | counter | | Records successfully processed |
| `records_error_total` | counter | | Records that failed |
| `bytes_received_total` | counter | | Bytes from source |
| `bytes_written_total` | counter | | Bytes to sink |
| `memory_used_bytes` | gauge | | Current memory (cgroup-aware) |
| `memory_limit_bytes` | gauge | | Effective memory limit |
| `config_reloads_total` | counter | `result` | Hot-reload attempts |

### BufferMetrics (receiver, loader, archiver)

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `buffer_bytes` | gauge | | Current buffer size |
| `buffer_records` | gauge | | Current buffered records |
| `buffer_flush_total` | counter | | Flush operations |
| `buffer_flush_duration_seconds` | histogram | | Flush latency |
| `buffer_flush_trigger_total` | counter | `trigger` | Flush reason (size/age/eviction/records) |

### ConsumerMetrics (Kafka consumer apps)

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `consumer_lag` | gauge | `topic`, `partition` | Offset lag per partition |
| `consumer_partitions_assigned` | gauge | | Current partition count |
| `consumer_rebalance_total` | counter | | Consumer group rebalances |
| `consumer_poll_duration_seconds` | histogram | | Time per poll/recv call |
| `offsets_committed_total` | counter | | Kafka offsets committed |

### SinkMetrics (apps with a downstream)

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `sink_duration_seconds` | histogram | `backend` | Sink write latency |
| `sink_errors_total` | counter | `backend` | Sink write errors |
| `bytes_sent_total` | counter | `format` | Bytes sent to sink |
| `concurrent_inserts` | gauge | | In-flight insert/write count |

### CircuitBreakerMetrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `circuit_breaker_state` | gauge | `target` | 0=closed, 1=open, 2=half-open |
| `circuit_breaker_transitions_total` | counter | `target`, `to_state` | State changes |

### BackpressureMetrics

| Metric | Type | Description |
|--------|------|-------------|
| `backpressure_events_total` | counter | Backpressure activations |
| `backpressure_duration_seconds_total` | counter | Cumulative pause time |

### EnrichmentMetrics (apps with GeoIP/reputation/lookup)

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `enrichment_cache_hits_total` | counter | `type` | Cache hits |
| `enrichment_cache_misses_total` | counter | `type` | Cache misses |
| `enrichment_cache_size` | gauge | `type` | Current cache entries |
| `enrichment_duration_seconds` | histogram | `type` | Lookup latency |

### SchemaCacheMetrics (apps with dynamic schema)

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `schema_cache_hits_total` | counter | | Cache hits |
| `schema_cache_misses_total` | counter | | Cache misses (triggers fetch) |
| `schema_cache_tables` | gauge | | Cached table count |
| `schema_recovery_total` | counter | `table` | Schema mismatch recovery events |

## Layer 3: App-Specific Metrics (in each app)

Only metrics unique to a single app. Registered directly via `MetricsManager`.

### dfe-receiver

| Metric | Type | Labels |
|--------|------|--------|
| `requests_total` | counter | `transport` |
| `request_duration_seconds` | histogram | `transport` |
| `active_connections` | gauge | `transport` |
| `body_size_rejected_total` | counter | |
| `request_timeouts_total` | counter | |
| `tls_handshake_failures_total` | counter | |
| `messages_spilled_total` | counter | |
| `messages_drained_total` | counter | |

### dfe-loader

| Metric | Type | Labels |
|--------|------|--------|
| `rows_inserted_total` | counter | |
| `batches_flushed_total` | counter | |
| `insert_duration_seconds` | histogram | `table` |
| `buffer_rows_by_table` | gauge | `table` |
| `buffer_bytes_by_table` | gauge | `table` |
| `salvage_attempts_total` | counter | `table` |
| `messages_by_table_total` | counter | `table` |
| `route_default_total` | counter | |

### dfe-archiver

| Metric | Type | Labels |
|--------|------|--------|
| `files_created_total` | counter | |
| `files_closed_total` | counter | |
| `archive_roll_total` | counter | `trigger` |
| `archive_file_size_bytes` | histogram | |
| `hot_buffers_active` | gauge | |
| `hot_buffers_bytes` | gauge | |
| `compression_ratio` | gauge | |
| `compression_duration_seconds` | histogram | |
| `bytes_compressed_total` | counter | |
| `unique_destinations` | gauge | |
| `pipeline_last_batch_timestamp_seconds` | gauge | |

### dfe-fetcher

| Metric | Type | Labels |
|--------|------|--------|
| `fetches_total` | counter | `source`, `status` |
| `fetch_duration_seconds` | histogram | `source` |
| `api_duration_seconds` | histogram | `source` |
| `api_errors_total` | counter | `source`, `code` |
| `cursor_age_seconds` | gauge | `source` |
| `active_fetches` | gauge | |
| `active_extractors` | gauge | |
| `extractor_runs_total` | counter | `name`, `status` |
| `cursor_writes_total` | counter | |
| `cursor_write_failures_total` | counter | |

### dfe-transform-wasm

| Metric | Type | Labels |
|--------|------|--------|
| `batches_processed_total` | counter | |
| `wasm_execution_duration_seconds` | histogram | |
| `pipeline_end_to_end_seconds` | histogram | |
| `produce_duration_seconds` | histogram | |
| `wasm_traps_total` | counter | |
| `wasm_epoch_interruptions_total` | counter | |
| `wasm_memory_bytes` | gauge | |
| `wasm_memory_limit_bytes` | gauge | |
| `wasm_memory_grow_total` | counter | |
| `wasm_memory_grow_denied_total` | counter | |
| `batch_retries_total` | counter | |
| `pipeline_last_batch_timestamp_seconds` | gauge | |

### dfe-transform-vector

| Metric | Type | Labels |
|--------|------|--------|
| `crashes_total` | counter | |
| `restarts_total` | counter | |
| `lifecycle_state` | gauge | `state` |
| `uptime_seconds` | gauge | |

Note: Transport metrics proxied from Vector's internal prometheus_exporter.

### dfe-transform-vrl

| Metric | Type | Labels |
|--------|------|--------|
| `execute_duration_seconds` | histogram | |
| `deserialise_duration_seconds` | histogram | `format` |
| `serialise_duration_seconds` | histogram | `format` |
| `batch_duration_seconds` | histogram | |
| `records_error_total` | counter | `stage` |
| `records_format_total` | counter | `format` |
| `programs_loaded` | gauge | |
| `abort_total` | counter | |
| `enrichment_table_rows` | gauge | `table` |
| `enrichment_lookup_total` | counter | `table`, `result` |

## Rustlib Implementation

### Feature Gate

```toml
# Cargo.toml
[features]
metrics-dfe = ["metrics"]
```

### Module Structure

```
src/metrics/
    mod.rs              # MetricsManager (existing, unchanged)
    dfe.rs              # DfeMetrics (existing, unchanged)
    dfe_groups/
        mod.rs          # Feature gate, re-exports
        app.rs          # AppMetrics
        buffer.rs       # BufferMetrics
        consumer.rs     # ConsumerMetrics
        sink.rs         # SinkMetrics
        circuit_breaker.rs
        backpressure.rs
        enrichment.rs
        schema_cache.rs
```

### API Pattern

```rust
use hyperi_rustlib::metrics::{MetricsManager, dfe_groups::*};

let mgr = MetricsManager::new("dfe_loader");

// Mandatory
let app = AppMetrics::new(&mgr, env!("CARGO_PKG_VERSION"), "abc123");

// Opt-in per concern
let buffer = BufferMetrics::new(&mgr);
let consumer = ConsumerMetrics::new(&mgr);
let sink = SinkMetrics::new(&mgr);
let cb = CircuitBreakerMetrics::new(&mgr);

// Recording
app.record_received();
buffer.record_flush(1024, 0.042, "size");
consumer.set_lag("events", 3, 1500);
sink.record_duration("clickhouse", 0.015);
cb.record_transition("db.events", "open");
```

### Migration Support

```rust
// During migration, emit both old and new names
let app = AppMetrics::builder(&mgr)
    .version(env!("CARGO_PKG_VERSION"))
    .commit("abc123")
    .legacy_names(true)  // Dual-emit old names alongside new
    .build();
```

### Histogram Bucket Defaults

Each group provides tuned defaults. Apps can override via config.

| Group | Default Buckets |
|-------|----------------|
| Buffer flush | `[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 5.0]` |
| Consumer poll | `[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 5.0]` |
| Sink write | `[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]` |
| Enrichment lookup | `[0.0001, 0.0005, 0.001, 0.005, 0.01, 0.025, 0.05, 0.1]` |

## OTel Alignment

Prometheus metrics are scraped by OTel Collector and forwarded via OTLP.
No double-instrumentation. OTel messaging semconv is in Development status.

When OTel messaging metrics reach Stable:
1. Add `OTEL_SEMCONV_STABILITY_OPT_IN=messaging` env var support
2. Emit OTel-named metrics alongside `dfe_*` metrics
3. Eventually deprecate duplicates (years away)

## rdkafka Stats (transport-kafka feature)

librdkafka stats parsed in-process, emitted under `rdkafka_` prefix.
All DFE Kafka apps get this automatically via rustlib transport-kafka.

| Metric | Type | Labels |
|--------|------|--------|
| `rdkafka_broker_rtt_avg_seconds` | gauge | `broker` |
| `rdkafka_broker_outbuf_cnt` | gauge | `broker` |
| `rdkafka_broker_waitresp_cnt` | gauge | `broker` |
| `rdkafka_topic_partition_consumer_lag` | gauge | `topic`, `partition` |
| `rdkafka_topic_partition_committed_offset` | gauge | `topic`, `partition` |
| `rdkafka_global_msg_cnt` | gauge | |
| `rdkafka_global_msg_size_bytes` | gauge | |

Cardinality: capped at 256 partitions. Per-partition metrics only when
`statistics.interval.ms` is explicitly configured.

Client-side consumer lag is supplementary -- always use server-side lag
(KEDA ScaledObject / Kafka Exporter / Burrow) as primary.

## Per-Project Migration Tasks

### dfe-loader

- [ ] Change MetricsManager namespace from `loader` to `dfe_loader`
- [ ] Adopt `AppMetrics`, `BufferMetrics`, `ConsumerMetrics`, `SinkMetrics`, `CircuitBreakerMetrics`, `EnrichmentMetrics`, `SchemaCacheMetrics`
- [ ] Dual-emit legacy `loader_*` names during migration
- [ ] Add missing Tier 1 metrics: parse_errors, consumer_lag, flush_trigger, schema cache stats
- [ ] Remove dual-emit after dashboard migration

### dfe-receiver

- [ ] Change MetricsManager namespace from `receiver` to `dfe_receiver`
- [ ] Adopt `AppMetrics`, `BufferMetrics`, `SinkMetrics`, `CircuitBreakerMetrics`, `BackpressureMetrics`
- [ ] Fix counter names missing `_total` suffix
- [ ] Add `request_duration_seconds` histogram
- [ ] Wire `active_connections` gauge in handlers
- [ ] Dual-emit legacy names during migration

### dfe-archiver

- [ ] Namespace already correct (`dfe_archiver`)
- [ ] Adopt `AppMetrics`, `BufferMetrics`, `ConsumerMetrics`, `SinkMetrics`, `BackpressureMetrics`
- [ ] Add compression, archive roll, and storage backend metrics
- [ ] Add `pipeline_last_batch_timestamp_seconds` staleness gauge

### dfe-fetcher

- [ ] Change MetricsManager namespace from `dfe` to `dfe_fetcher` (fix collision)
- [ ] Adopt `AppMetrics`, `SinkMetrics`, `BackpressureMetrics`
- [ ] Fix counter names missing `_total` suffix
- [ ] Add per-source labels to fetch metrics
- [ ] Add `cursor_age_seconds` staleness gauge
- [ ] Add `api_duration_seconds` and `api_errors_total` with category labels

### dfe-transform-wasm

- [ ] Namespace already correct (`dfe_transform_wasm`)
- [ ] Adopt `AppMetrics`, `ConsumerMetrics`, `SinkMetrics`, `BackpressureMetrics`
- [ ] Add WASM execution duration (isolated from Kafka I/O)
- [ ] Add epoch interruption and memory grow counters
- [ ] Add `pipeline_last_batch_timestamp_seconds` staleness gauge

### dfe-transform-vector

- [ ] Namespace already correct (`dfe_transform_vector`)
- [ ] Adopt `AppMetrics` only (Vector manages its own transport metrics)
- [ ] Proxy Vector's internal metrics via `/metrics` endpoint

### dfe-transform-vrl

- [ ] Change MetricsManager namespace from `transform_vrl` to `dfe_transform_vrl`
- [ ] Adopt `AppMetrics`, `ConsumerMetrics`, `SinkMetrics`, `BackpressureMetrics`, `EnrichmentMetrics`
- [ ] Split `events_failed_total` into per-stage error counter
- [ ] Add isolated VRL execution duration histogram
- [ ] Remove legacy unprefixed metrics after dashboard migration

### hyperi-rustlib

- [ ] Add `metrics-dfe` feature gate
- [ ] Implement `dfe_groups/` module with all metric group structs
- [ ] Add `legacy_names` builder option for migration
- [ ] Add rdkafka stats parser to `transport-kafka` feature
- [ ] Document in `docs/metrics-standard.md`
- [ ] Publish release with new feature
