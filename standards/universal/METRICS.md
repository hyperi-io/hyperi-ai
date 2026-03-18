# Metrics Standard

Naming, structure, and implementation patterns for production service metrics.
Covers Prometheus, OpenTelemetry, KEDA autoscaling, and alerting.

---

## Naming Conventions

### Two Ecosystems

| Aspect | OpenTelemetry (modern) | Prometheus (established) |
|--------|----------------------|------------------------|
| Delimiter | Dots (`.`) | Underscores (`_`) |
| Units in name | No — use metadata | Yes — suffix (`_seconds`, `_bytes`) |
| Type suffix | No | Yes — `_total` for counters |
| Namespace | Hierarchical dot (`http.server.request.duration`) | Flat prefix (`http_requests_total`) |

**Choose one convention per project and apply it consistently.** Both are valid.
Prometheus conventions are more common in Kubernetes/Grafana ecosystems.
OTel conventions are the direction new instrumentation is heading.

### Prometheus Convention Rules

```
{namespace}_{domain}_{metric_name}_{unit}
```

- Lowercase with underscores
- Include unit suffix: `_total` (counters), `_seconds`, `_bytes`, `_ratio`
- Single-word namespace prefix reflecting the product/org
- `_total` on ALL counters — Prometheus requires this
- Colons (`:`) reserved for recording rules only

### OpenTelemetry Convention Rules

```
{namespace}.{domain}.{metric_name}
```

- Lowercase with dots as hierarchy separators
- Units in metadata, NOT in the name
- Follow [OTel Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/general/metrics/) where they exist
- Custom metrics: prefix with reverse domain (`com.acme.shopname`) to avoid collision

### What Goes in the Name vs Labels

| In the metric name | In labels/attributes |
|-------------------|---------------------|
| What is being measured | Who/where/how it's being measured |
| Domain (`transport`, `pipeline`) | Service name, environment, version |
| Unit of measurement | Transport type (`kafka`, `grpc`) |
| | Failure reason, status code |
| | Protocol, table name |

**Rule:** If `sum()` or `avg()` across all label values produces a meaningful
result, the label is correct. If it produces nonsense, the dimension belongs
in the name.

---

## Label Cardinality

| Rule | Rationale |
|------|-----------|
| Labels MUST have bounded cardinality (< 100 unique values) | Unbounded labels create cardinality explosion — Prometheus OOMs |
| NEVER use request IDs, session IDs, or UUIDs | Each creates a new time series |
| NEVER use IP addresses or user-supplied strings | Unbounded by definition |
| Topic/table names are acceptable | Bounded by config (typically < 50) |
| Use consistent label names across services | `region` everywhere, not sometimes `location` |

---

## Standard Metric Categories

These categories apply to any data pipeline, network service, or message-passing
system. Specific metric names will vary by project — the categories and patterns
are universal.

### Transport Metrics

For any component that sends data downstream (Kafka producer, gRPC client, HTTP
client, file writer).

| Purpose | Type | Pattern |
|---------|------|---------|
| Messages sent successfully | counter | `{ns}_transport_sent_total` |
| Messages failed to send (fatal) | counter | `{ns}_transport_send_errors_total` |
| Messages rejected (backpressure) | counter | `{ns}_transport_backpressured_total` |
| Messages refused (queue full) | counter | `{ns}_transport_refused_total` |
| Transport health | gauge | `{ns}_transport_healthy` (1/0) |
| Send queue depth | gauge | `{ns}_transport_queue_size` |
| Send queue capacity | gauge | `{ns}_transport_queue_capacity` |
| Messages in-flight (awaiting ack) | gauge | `{ns}_transport_inflight` |
| Per-send latency | histogram | `{ns}_transport_send_duration_seconds` |

Use a `transport` label to differentiate backends (`kafka`, `grpc`, `http`, `file`).

### Pipeline Metrics

For the processing pipeline itself.

| Purpose | Type | Pattern |
|---------|------|---------|
| Pipeline readiness | gauge | `{ns}_pipeline_ready` (1/0) |
| Stall duration | counter | `{ns}_pipeline_stall_seconds_total` |

### Record/Message Metrics

For data flowing through the system.

| Purpose | Type | Pattern |
|---------|------|---------|
| Records received (before filtering) | counter | `{ns}_records_received_total` |
| Records delivered to output | counter | `{ns}_records_delivered_total` |
| Records dropped by filters | counter | `{ns}_records_filtered_total` |
| Records routed to DLQ | counter | `{ns}_records_dlq_total` |
| Bytes received | counter | `{ns}_bytes_received_total` |

### Scaling/Autoscaling Metrics

For KEDA, HPA, or custom autoscalers.

| Purpose | Type | Pattern |
|---------|------|---------|
| Composite pressure score (0-100) | gauge | `{ns}_scaling_pressure` |
| Circuit breaker open | gauge | `{ns}_scaling_circuit_open` (1/0) |
| Memory pressure ratio | gauge | `{ns}_scaling_memory_pressure` (0.0-1.0) |

### Process Metrics

Standard process-level metrics. Many libraries auto-register these.

| Purpose | Type | Pattern |
|---------|------|---------|
| CPU usage | gauge | `{ns}_process_cpu_seconds_total` |
| Resident memory | gauge | `{ns}_process_resident_memory_bytes` |
| Virtual memory | gauge | `{ns}_process_virtual_memory_bytes` |
| Open file descriptors | gauge | `{ns}_process_open_fds` |
| Container memory limit | gauge | `{ns}_container_memory_limit_bytes` |
| Container memory usage | gauge | `{ns}_container_memory_usage_bytes` |

---

## Alerting Ratios

These PromQL patterns are universal for any transport-based system.

| Alert | Query Pattern | Threshold |
|-------|--------------|-----------|
| Error rate | `rate(send_errors[5m]) / rate(sent[5m])` | > 0.01 (1%) |
| Backpressure rate | `rate(backpressured[5m])` | > 0 sustained |
| Queue saturation | `queue_size / queue_capacity` | > 0.8 |
| Pipeline stall | `pipeline_ready == 0` | > 60s |
| Scaling pressure | `scaling_pressure` | > 70 (KEDA) |

Implement graduated alerting:
- **70%** — informational (Slack)
- **85%** — warning (on-call page)
- **95%** — critical (escalation)

---

## Histogram Bucket Selection

| Domain | Recommended Buckets |
|--------|-------------------|
| Network latency | 1ms, 5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 2.5s, 5s, 10s |
| Payload size | 100B, 1KB, 10KB, 100KB, 1MB, 10MB |
| Batch processing | 10ms, 50ms, 100ms, 500ms, 1s, 5s, 30s, 60s |

Buckets should cover the expected range plus 2-3 buckets beyond for outlier
detection. Too many buckets increase storage cost; too few lose precision.

---

## KEDA Integration

KEDA queries Prometheus for scaling decisions. Key considerations:

- Prometheus scraping adds 30-60s latency — not suitable for sub-second
  scaling. For bursty workloads, combine with Kafka lag triggers.
- Use `avg()` for scaling pressure, not `max()` — avoids single-pod spikes
  causing unnecessary scale-up.
- Set `cooldownPeriod` to at least 60s to prevent flapping.
- Use `activationLagThreshold` to enable scale-from-zero only when real
  work exists.
- Add `fallback` configuration so KEDA maintains current replicas when
  Prometheus is unreachable.

```yaml
triggers:
  - type: prometheus
    metadata:
      serverAddress: "http://prometheus:9090"
      query: "avg({ns}_scaling_pressure{job='my-service'})"
      threshold: "70"
fallback:
  failureThreshold: 3
  replicas: 2
```

---

## Implementation Best Practices

- **Use your org's shared metrics library.** Don't hand-roll Prometheus text
  format. Don't import the `prometheus` crate directly when a wrapper exists.
- **Register metrics at startup, not lazily.** Missing metrics in Prometheus
  (as opposed to zero-valued) cause alerting gaps.
- **Initialise counters to 0.** A counter that doesn't exist vs one that
  equals 0 are different in PromQL (`absent()` vs `== 0`).
- **Update gauges on a timer** (e.g., every 15s), not on every request.
  Per-request gauge updates are wasted work since Prometheus only scrapes
  every 15-60s.
- **Expose `/metrics` on a separate port** from your data plane if scraping
  competes with ingest traffic.

---

## DFE Platform Specifics

> This section applies to HyperI DFE projects only.

### Namespace

All DFE services use the `dfe` namespace. Service differentiation comes from
the Prometheus `job` label, not from the metric name.

```
dfe_transport_sent_total{job="dfe-receiver", transport="kafka"}
dfe_transport_sent_total{job="dfe-loader", transport="kafka"}
```

### Implementation

Use `hyperi_rustlib::metrics::MetricsManager::new("dfe")`. This auto-registers
process + container metrics and provides `/metrics` + `/healthz` + `/readyz`
endpoints.

### Per-Service Applicability

| Metric | receiver | loader | fetcher | archiver |
|--------|----------|--------|---------|----------|
| `dfe_transport_sent_total` | Yes | Yes | Yes | Yes |
| `dfe_transport_send_errors_total` | Yes | Yes | Yes | Yes |
| `dfe_transport_backpressured_total` | Yes | Yes | Yes | Yes |
| `dfe_transport_healthy` | Yes | Yes | Yes | Yes |
| `dfe_transport_queue_size` | Yes | Yes | - | Yes |
| `dfe_pipeline_ready` | Yes | Yes | Yes | Yes |
| `dfe_records_received_total` | Yes | Yes | Yes | Yes |
| `dfe_records_delivered_total` | Yes | Yes | Yes | Yes |
| `dfe_records_dlq_total` | Yes | Yes | - | Yes |
| `dfe_scaling_pressure` | Yes | Yes | Yes | Yes |
| `dfe_spool_bytes` | Yes | - | - | Yes |

### Migration

Phase 1: Emit both old names (`receiver_*`, `loader_*`) and new `dfe_*` names.
Phase 2: Update dashboards and alerts to new names.
Phase 3: Remove old names. Consolidate to rustlib `MetricsManager`.

---

## AI Assistant Guidance

When generating code that emits metrics:

- **Always check the project's existing metrics** before adding new ones.
  Don't create duplicates with different names for the same measurement.
- **Never invent metric names from thin air.** Check if the project has a
  metrics standard (this document) and follow it.
- **Never use high-cardinality labels.** Request IDs, trace IDs, IP
  addresses, and user-supplied strings MUST NOT be label values.
- **Prefer the project's metrics library** over raw Prometheus client.
  Check `Cargo.toml` / `requirements.txt` for what's available.
- **Counters must end in `_total`.** Gauges must not.
- **Include units in Prometheus metric names** (`_seconds`, `_bytes`).
  Omit units in OTel metric names.
- **Don't add metrics for things that are already measured.** Process CPU
  and memory are typically auto-collected — don't duplicate them.
- **Histograms need bucket configuration.** Never use default buckets for
  domain-specific measurements (network latency and batch duration have
  very different distributions).

---

## References

- [Prometheus Metric and Label Naming](https://prometheus.io/docs/practices/naming/)
- [OpenTelemetry Metrics Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/general/metrics/)
- [How to Name Your Metrics (OTel Blog)](https://opentelemetry.io/blog/2025/how-to-name-your-metrics/)
- [OTel Naming Best Practices (Honeycomb)](https://www.honeycomb.io/blog/opentelemetry-best-practices-naming)
- [Prometheus Labels Best Practices (CNCF)](https://www.cncf.io/blog/2025/07/22/prometheus-labels-understanding-and-best-practices/)
- [OTel Collector Internal Telemetry](https://opentelemetry.io/docs/collector/internal-telemetry/)
- [Monitor Collector Queue Depth and Backpressure](https://oneuptime.com/blog/post/2026-02-06-monitor-collector-queue-depth-backpressure/view)
- [KEDA Prometheus Scaler](https://keda.sh/docs/latest/scalers/prometheus/)
- [Prometheus Best Practices (Better Stack)](https://betterstack.com/community/guides/monitoring/prometheus-best-practices/)
