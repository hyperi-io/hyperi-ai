# Log Flooding Protection

Patterns and techniques for preventing log spam in production services. Applies
to any high-throughput system where failure conditions can produce thousands to
millions of identical log messages per second.

> **Core problem:** Under sustained failure (downstream unavailable, disk full,
> memory pressure, auth misconfiguration), `warn!`/`error!` calls inside
> per-message or per-request loops produce unbounded log volume. This saturates
> log aggregators, inflates costs, and buries actionable signals in noise.

---

## Common Anti-Patterns

These patterns appear in virtually every production service that processes data
at volume. If your code has any of these, it has a log spam vulnerability.

| Anti-Pattern | Example | Risk |
|-------------|---------|------|
| `warn!`/`error!` inside per-message loops | `error!("send failed: {e}")` in a Kafka producer loop | Fires for every failed message during a Kafka outage |
| `warn!` inside tight `recv()` loops | `warn!("UDP recv error: {e}")` in a socket read loop | Socket errors repeat at recv frequency — thousands/sec |
| Logging sustained state, not transitions | `warn!("memory pressure high")` on every request while pressure is high | Scales with request rate, not with the problem |
| No level guards before expensive formatting | `debug!(payload = ?large_struct, ...)` | Constructs `Debug` output even when debug level is filtered |
| Retry loop logging per attempt | `warn!("retry {attempt}: {error}")` | N retries × M batches × P partitions = O(N×M×P) lines |

---

## Protection Techniques

### 1. Global Rate Limiting (Defence-in-Depth)

Apply a signature-based rate limiter as a logging layer. Events with identical
signatures (level + message + target + field values) are deduplicated and
throttled together. Unique events pass through unaffected.

**This is the baseline.** It requires zero per-site code changes and catches
spam from any source, including third-party libraries.

**Rust (`tracing` ecosystem):**

The `tracing-throttle` crate provides this as a drop-in `tracing::Layer`:

```rust
use tracing_throttle::TracingRateLimitLayer;
use tracing_subscriber::{Registry, layer::SubscriberExt};

let throttle = TracingRateLimitLayer::new()
    .burst(10)               // allow 10 rapid-fire identical messages
    .refill_rate(1)          // then 1 per second sustained
    .max_signatures(5000)    // LRU eviction at 5K unique signatures
    .exclude_fields(&["request_id", "span_id"]);  // ignore high-cardinality

let subscriber = Registry::default()
    .with(throttle)
    .with(fmt_layer);
```

**Configuration via environment (recommended defaults):**

| Env Var | Default | Description |
|---------|---------|-------------|
| `LOG_THROTTLE_ENABLED` | `true` | Disable for debugging |
| `LOG_THROTTLE_BURST` | `10` | Burst capacity before throttling |
| `LOG_THROTTLE_RATE` | `1` | Sustained messages/sec per signature |
| `LOG_THROTTLE_MAX_SIGNATURES` | `5000` | Max tracked signatures (LRU eviction) |

**Apply to `warn!` and `error!` only.** Leave `info!`, `debug!`, `trace!`
unthrottled — these are already filtered by level in production.

**Overhead:** ~50ns per event (lock-free sharded storage). Negligible for
logging; measurable only if applied to millions of `trace!` events/sec.

**Python (`logging` ecosystem):**

Use a custom `logging.Filter` with token bucket rate limiting per message
signature. The signature is `(logger_name, level, message_template)`.

```python
import logging
import time
from collections import defaultdict

class RateLimitFilter(logging.Filter):
    """Token bucket rate limiter per unique log signature."""

    def __init__(self, burst: int = 10, rate: float = 1.0):
        super().__init__()
        self.burst = burst
        self.rate = rate  # tokens per second
        self._buckets: dict[tuple, list] = defaultdict(lambda: [burst, time.monotonic()])

    def filter(self, record: logging.LogRecord) -> bool:
        if record.levelno < logging.WARNING:
            return True  # only throttle warn/error
        key = (record.name, record.levelno, record.msg)
        tokens, last = self._buckets[key]
        now = time.monotonic()
        tokens = min(self.burst, tokens + (now - last) * self.rate)
        self._buckets[key] = [tokens - 1, now] if tokens >= 1 else [tokens, now]
        return tokens >= 1

# Apply globally
logging.getLogger().addFilter(RateLimitFilter(burst=10, rate=1.0))
```

For `structlog`, apply as a processor in the chain.

### 2. State-Transition Logging

Log only when a condition **changes**, not on every occurrence. Most effective
for sustained failure conditions.

```rust
use std::sync::atomic::{AtomicBool, Ordering};

fn check_and_log_pressure(flag: &AtomicBool, is_high: bool) {
    let was_high = flag.swap(is_high, Ordering::Relaxed);
    match (was_high, is_high) {
        (false, true) => warn!("pressure HIGH — backpressure active"),
        (true, false) => info!("pressure recovered"),
        _ => {} // no change, no log
    }
}
```

**Use for:** Memory pressure, circuit breaker state, disk full/recovered,
transport healthy/unhealthy, connection up/down.

**Pattern:** Log the **transition**, not the **state**. One line on failure,
one line on recovery. Never log per-check-cycle.

**Python:**

```python
import threading

class StateLogger:
    """Log only on state transitions."""

    def __init__(self):
        self._states: dict[str, bool] = {}
        self._lock = threading.Lock()

    def log_transition(self, key: str, is_active: bool, logger: logging.Logger,
                       active_msg: str, recovered_msg: str) -> bool:
        with self._lock:
            was_active = self._states.get(key, False)
            self._states[key] = is_active
        if not was_active and is_active:
            logger.warning(active_msg)
            return True
        if was_active and not is_active:
            logger.info(recovered_msg)
            return True
        return False

# Usage
state = StateLogger()
state.log_transition(
    "kafka_healthy", is_healthy,
    logger, "Kafka unhealthy — backpressure active", "Kafka recovered"
)
```

### 3. Sampled Error Logging

For per-message errors where every occurrence matters for **metrics** but not
for **logs**, emit a representative sample.

```rust
use std::sync::atomic::{AtomicU64, Ordering};

fn log_error_sampled(counter: &AtomicU64, error: &Error, sample_rate: u64) {
    let count = counter.fetch_add(1, Ordering::Relaxed) + 1;
    if count == 1 || count % sample_rate == 0 {
        warn!(
            error = %error,
            total_errors = count,
            "transport send failed (showing 1 in {sample_rate})"
        );
    }
    // Always increment the metric — metrics capture everything
    counter!("transport_send_errors_total").increment(1);
}
```

**Python:**

```python
import threading

class SampledLogger:
    """Log every Nth occurrence of an error, always count in metrics."""

    def __init__(self):
        self._counters: dict[str, int] = defaultdict(int)
        self._lock = threading.Lock()

    def log_sampled(self, key: str, sample_rate: int, logger: logging.Logger,
                    msg: str, **kwargs) -> None:
        with self._lock:
            self._counters[key] += 1
            count = self._counters[key]
        if count == 1 or count % sample_rate == 0:
            logger.warning(f"{msg} (total: {count}, showing 1 in {sample_rate})",
                           extra=kwargs)
        # Always record in metrics
        SEND_ERRORS.labels(**kwargs).inc()
```

**Use for:** Send failures, validation failures, type coercion errors, parse
errors — any per-record error in a hot path.

**Sample rate guidance:**
- 1 in 100 for moderate-volume paths (< 10K/sec)
- 1 in 1000 for high-volume paths (> 10K/sec)
- Always log the first occurrence (`count == 1`)
- Include the running total so operators can see scale

### 4. Debounced Logging

For conditions that repeat in tight loops, enforce a minimum interval between
log emissions.

```rust
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

fn log_debounced(last_ms: &AtomicU64, min_interval_ms: u64) -> bool {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;
    let last = last_ms.load(Ordering::Relaxed);
    if now.saturating_sub(last) >= min_interval_ms {
        last_ms.store(now, Ordering::Relaxed);
        true
    } else {
        false
    }
}
```

**Use for:** Tight recv/poll loops (UDP errors, Kafka consumer errors),
periodic health check failures, disk space checks.

**Interval guidance:**
- 5 seconds for socket/network errors
- 10 seconds for resource checks (disk, memory)
- 30 seconds for external service health

### 5. Level Guards for Expensive Formatting

Prevent `Debug`/`Display` formatting of large structures when the level is
filtered.

```rust
// Bad — formats even when debug is off
debug!(payload = ?large_vec, "processing batch");

// Good — skip formatting entirely
if tracing::enabled!(tracing::Level::DEBUG) {
    debug!(payload = ?large_vec, "processing batch");
}
```

**Use for:** Any `debug!` or `trace!` that formats collections, large structs,
or calls `Display`/`Debug` on non-trivial types. Not needed for simple scalars.

---

## Decision Matrix

| Scenario | Technique | Example |
|----------|-----------|---------|
| Sustained condition (pressure, circuit, disk) | State-transition | Log open/close, not every check |
| Per-message error in hot path | Sampled + metric | Log 1/1000, count all in metrics |
| Tight recv/poll loop error | Debounced | Max once per 5-10s |
| Flapping condition | Debounced | Max once per interval |
| Expensive debug formatting | Level guard | Skip `Debug` of large structs |
| Unknown/third-party code | Global rate limiter | Baseline safety net |

---

## What NOT to Do

- **Never suppress `error!` entirely.** Always emit at least periodically.
  Errors indicate data loss risk; total suppression hides incidents.
- **Never use log suppression as a substitute for fixing the root cause.**
  If a code path produces 10K warn/sec, fix the code path. Throttling is
  defence-in-depth, not a permanent workaround.
- **Never throttle startup/shutdown `info!`.** These are bounded by
  definition and essential for operational visibility.
- **Never drop compliance-required logs.** Audit trail events must emit
  regardless of rate.
- **Never log at `info!` or above inside per-message hot paths.**
  Per-message logging belongs at `debug!` (filtered in production).
  Use metrics for per-message visibility.

---

## Testing

Test that your protection mechanisms actually work:

```rust
#[test]
fn test_sampled_logging() {
    let counter = AtomicU64::new(0);
    assert!(log_sampled(&counter, 1000));       // first: logs
    for _ in 0..999 {
        assert!(!log_sampled(&counter, 1000));  // 2-1000: suppressed
    }
    assert!(log_sampled(&counter, 1000));       // 1001: logs
}

#[test]
fn test_state_transition() {
    let flag = AtomicBool::new(false);
    assert!(log_state_change(&flag, true));     // false→true: changed
    assert!(!log_state_change(&flag, true));    // true→true: no change
    assert!(log_state_change(&flag, false));    // true→false: changed
}
```

---

## Structured Logging Fundamentals

These apply regardless of language or framework:

- **Use structured formats** (JSON in containers, human-readable in terminals).
  Auto-detect via `stderr.is_terminal()`.
- **Include correlation IDs** (`trace_id`, `span_id`) for distributed tracing.
- **Use consistent field names** across services. Standardise on a small set
  (`error`, `duration_ms`, `count`, `component`).
- **ISO 8601 timestamps in UTC.** Not local time, not Unix epoch in logs.
- **Log level discipline:**
  - `error!` — action required, data loss risk
  - `warn!` — degraded but recovering, attention needed
  - `info!` — lifecycle events (start, stop, reload, connect, disconnect)
  - `debug!` — per-batch or per-operation detail
  - `trace!` — per-message or per-record detail (never in production)
- **Sensitive data masking** — mask passwords, tokens, API keys, PII
  before they reach the log sink. Use a masking layer, not per-site checks.

---

## DFE Platform Specifics

> This section applies to HyperI DFE projects only.

### Current State

No DFE project implements any form of log rate limiting or deduplication.
All five Rust services (dfe-receiver, dfe-loader, dfe-fetcher, dfe-archiver,
dfe-transform-vector) have identified log spam vulnerabilities under sustained
failure conditions. See the project-specific audit in
`dfe-receiver/docs/LOG-SPAMMING.md` for file:line details.

### Implementation Plan

**Rust (hyperi-rustlib):**

- Phase 1: Add `tracing-throttle` layer to `hyperi_rustlib::logger::setup()` — opt-in global safety net
- Phase 2: Add helper functions (`log_state_change`, `log_sampled`, `log_debounced`)
- Phase 3: Fix identified spam sites in each dfe-* Rust project

**Python (hyperi-pylib):**

- Phase 1: Add `RateLimitFilter` to `hyperi_pylib.logging.setup()` — opt-in global safety net
- Phase 2: Add helper classes (`StateLogger`, `SampledLogger`) to `hyperi_pylib.logging`
- Phase 3: Fix identified spam sites in dfe-engine and any other Python services

### Worst Offenders (Must Fix)

| Project | Site | Technique |
|---------|------|-----------|
| dfe-receiver | Memory pressure warn per-request | State-transition |
| dfe-receiver | Kafka send error per-message | Sampled (1/1000) |
| dfe-loader | Type coercion warn per-row | Sampled (1/1000) |
| dfe-loader | ClickHouse retry warn per-attempt | State-transition |
| dfe-fetcher | Container stderr warn per-line | Sampled (1/100) |
| dfe-archiver | Routing failure warn per-message | Sampled (1/1000) |

---

## AI Assistant Guidance

When generating code that logs errors or warnings:

- **Never put `warn!` or `error!` inside a per-message processing loop**
  without rate limiting. This is the single most common log spam source in
  AI-generated code. If the loop processes thousands of items per second,
  one failure condition produces thousands of identical log lines.
- **Use metrics for per-message visibility, not logs.** Increment a counter
  for every error. Log a sample for human readability.
- **Prefer state-transition logging for boolean conditions.** If you're
  checking a flag in a loop, log when it changes, not when it's true.
- **Check if the project has a log spam prevention standard** (this document)
  before adding new log sites.
- **Never add `info!` to request handlers.** Per-request `info!` at 10K
  req/sec = 10K lines/sec. Use `debug!` for request-level logging.
- **Never log full payloads at `warn!` or above.** Large payloads at error
  level multiply the cost of every error by the payload size.
- **Always include a running count** in sampled log messages so operators
  can assess severity: `"send failed (23,471 total, showing 1 in 1000)"`.
- **When generating retry logic, log the first failure and recovery only.**
  Don't log every retry attempt — that's N×M lines per outage where N is
  retries and M is affected operations.

---

## References

- [tracing-throttle](https://crates.io/crates/tracing-throttle) — signature-based rate limiting for Rust tracing
- [tokio-rs/tracing Discussion #3006](https://github.com/tokio-rs/tracing/discussions/3006) — rate limiter design
- [Logging Best Practices (Better Stack)](https://betterstack.com/community/guides/logging/logging-best-practices/)
- [Structured Logging Best Practices (OneUptime)](https://oneuptime.com/blog/post/2026-01-25-structured-logging-best-practices/view)
- [Log Management Best Practices 2026 (LogManager)](https://logmanager.com/blog/log-management/log-management-best-practices/)
- [Log Management Best Practices (StrongDM)](https://www.strongdm.com/blog/log-management-best-practices)
- [Observability Best Practices 2026 (Spacelift)](https://spacelift.io/blog/observability-best-practices)
- [OTel Collector Backpressure (Axoflow)](https://axoflow.com/blog/opentelemetry-controller-outages-pipelines-backpressure)
