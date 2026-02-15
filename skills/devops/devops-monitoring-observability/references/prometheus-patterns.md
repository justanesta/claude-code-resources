# Prometheus Metrics Patterns

## Metric Types and When to Use Each

| Type | Behavior | Use For | Example |
|------|----------|---------|---------|
| **Counter** | Monotonically increases, resets on restart | Total requests, errors, bytes sent | `http_requests_total` |
| **Gauge** | Goes up and down | Queue depth, temperature, active connections | `active_connections` |
| **Histogram** | Counts observations in configurable buckets | Latency, request size, batch duration | `http_request_duration_seconds` |
| **Summary** | Client-side quantiles (avoid; prefer histograms) | Legacy systems where server-side aggregation is impossible | `rpc_duration_seconds` |

## Counter Patterns

```python
from prometheus_client import Counter

# Always use _total suffix for counters
requests_total = Counter(
    "http_requests_total",
    "Total HTTP requests by method, endpoint, and status",
    ["method", "endpoint", "status_code"],
)

errors_total = Counter(
    "pipeline_errors_total",
    "Total pipeline processing errors",
    ["pipeline", "stage", "error_type"],
)

# Increment on events
requests_total.labels(method="POST", endpoint="/orders", status_code="201").inc()
errors_total.labels(pipeline="etl_daily", stage="transform", error_type="schema_mismatch").inc()
```

### PromQL for Counters

```promql
# Request rate over last 5 minutes
rate(http_requests_total[5m])

# Error rate as percentage
100 * sum(rate(http_requests_total{status_code=~"5.."}[5m]))
    / sum(rate(http_requests_total[5m]))

# Per-endpoint error rates, top 10
topk(10,
  sum by (endpoint) (rate(http_requests_total{status_code=~"5.."}[5m]))
  / sum by (endpoint) (rate(http_requests_total[5m]))
)

# Rate of increase over time (for alerting on spikes)
deriv(rate(http_requests_total[5m])[1h:5m])
```

## Histogram Patterns

```python
from prometheus_client import Histogram

# Buckets aligned to SLO targets
# If p99 SLO is 500ms, ensure buckets bracket that threshold
request_duration = Histogram(
    "http_request_duration_seconds",
    "Request latency distribution",
    ["method", "endpoint"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
)

# For data pipelines: batch processing duration
batch_duration = Histogram(
    "pipeline_batch_duration_seconds",
    "Pipeline batch processing time",
    ["pipeline", "stage"],
    buckets=[1, 5, 10, 30, 60, 120, 300, 600, 1800, 3600],
)

# Use as context manager for automatic timing
with request_duration.labels(method="GET", endpoint="/users").time():
    result = fetch_users()
```

### PromQL for Histograms

```promql
# p50, p95, p99 latency
histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Per-service p99
histogram_quantile(0.99,
  sum by (le, service) (rate(http_request_duration_seconds_bucket[5m]))
)

# Apdex score (satisfied < 0.25s, tolerating < 1s)
(
  sum(rate(http_request_duration_seconds_bucket{le="0.25"}[5m]))
  + sum(rate(http_request_duration_seconds_bucket{le="1.0"}[5m]))
) / 2
/ sum(rate(http_request_duration_seconds_count[5m]))

# Average request duration (use with caution -- hides distribution)
sum(rate(http_request_duration_seconds_sum[5m]))
/ sum(rate(http_request_duration_seconds_count[5m]))
```

## Recording Rules

Pre-compute expensive aggregations to speed up dashboard queries and reduce load on Prometheus.

```yaml
# prometheus/recording_rules.yml
groups:
  - name: service_red_metrics
    interval: 15s
    rules:
      # Request rate by service
      - record: service:http_requests:rate5m
        expr: sum by (service) (rate(http_requests_total[5m]))

      # Error rate by service
      - record: service:http_errors:ratio5m
        expr: |
          sum by (service) (rate(http_requests_total{status_code=~"5.."}[5m]))
          / sum by (service) (rate(http_requests_total[5m]))

      # p99 latency by service
      - record: service:http_duration:p99_5m
        expr: |
          histogram_quantile(0.99,
            sum by (le, service) (rate(http_request_duration_seconds_bucket[5m]))
          )

      # SLO: availability over 30 days
      - record: slo:availability:ratio30d
        expr: |
          1 - (
            sum(increase(http_requests_total{status_code=~"5.."}[30d]))
            / sum(increase(http_requests_total[30d]))
          )

  - name: pipeline_metrics
    interval: 30s
    rules:
      - record: pipeline:batch_duration:p95_5m
        expr: |
          histogram_quantile(0.95,
            sum by (le, pipeline) (rate(pipeline_batch_duration_seconds_bucket[5m]))
          )

      - record: pipeline:records_processed:rate5m
        expr: sum by (pipeline) (rate(pipeline_records_processed_total[5m]))
```

## Alerting Rules

```yaml
# prometheus/alerting_rules.yml
groups:
  - name: service_health
    rules:
      - alert: HighErrorRate
        expr: service:http_errors:ratio5m > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.service }} error rate above 5%"
          description: "Current error rate: {{ $value | humanizePercentage }}"
          runbook: "https://runbooks.internal/high-error-rate"

      - alert: HighLatencyP99
        expr: service:http_duration:p99_5m > 2.0
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.service }} p99 latency above 2s"

      - alert: NoRequests
        expr: service:http_requests:rate5m == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.service }} receiving zero traffic"

  - name: pipeline_health
    rules:
      - alert: PipelineSlow
        expr: pipeline:batch_duration:p95_5m > 1800
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Pipeline {{ $labels.pipeline }} p95 batch time exceeds 30 minutes"

      - alert: PipelineStalled
        expr: pipeline:records_processed:rate5m == 0
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: "Pipeline {{ $labels.pipeline }} has stopped processing records"
```

## RED Method Queries (Request, Error, Duration)

```promql
# Rate: requests per second
sum(rate(http_requests_total[5m])) by (service)

# Errors: error percentage
100 * sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (service)
    / sum(rate(http_requests_total[5m])) by (service)

# Duration: latency percentiles
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))
```

## USE Method Queries (Utilization, Saturation, Errors)

```promql
# CPU utilization
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory utilization
1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

# Disk I/O saturation (time spent doing I/O)
rate(node_disk_io_time_seconds_total[5m])

# Network saturation (dropped packets)
rate(node_network_receive_drop_total[5m]) + rate(node_network_transmit_drop_total[5m])

# Container resource utilization (Kubernetes)
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (pod)
/ sum(kube_pod_container_resource_requests{resource="cpu"}) by (pod)
```

## Label Best Practices and Cardinality Control

```python
# GOOD: bounded label values (known enums)
requests_total.labels(method="GET", endpoint="/api/users", status_code="200")

# BAD: unbounded label values (cardinality explosion)
requests_total.labels(method="GET", endpoint=f"/api/users/{user_id}", status_code="200")
# This creates a new time series for EVERY unique user_id

# GOOD: normalize dynamic paths
import re
def normalize_path(path: str) -> str:
    """Replace dynamic path segments with placeholders."""
    path = re.sub(r"/users/[^/]+", "/users/:id", path)
    path = re.sub(r"/orders/[^/]+", "/orders/:id", path)
    return path

# Monitor cardinality with PromQL
# Total time series count
# count({__name__=~".+"})

# Series per metric
# count by (__name__) ({__name__=~".+"})

# Top cardinality offenders
# topk(10, count by (__name__) ({__name__=~".+"}))
```

## Edge Cases

- **Counter resets** -- `rate()` and `increase()` handle Prometheus counter resets automatically. Never use raw counter values in dashboards; always wrap with `rate()`.
- **Stale markers** -- When a target goes away, Prometheus inserts stale markers. Use `up == 0` to detect scrape failures rather than absence of metrics.
- **Histogram quantile accuracy** -- `histogram_quantile()` interpolates within buckets. If your buckets are too coarse (e.g., [0.1, 1, 10]), p99 between 1 and 10 seconds will be linearly interpolated and likely inaccurate.
- **Recording rule staleness** -- If the underlying metric disappears, the recording rule produces no data (not zero). Use `or vector(0)` for metrics that should default to zero when absent.
- **irate vs rate** -- `irate()` uses the last two data points only, making it spiky but responsive. Use `rate()` for alerting (smoother) and `irate()` for interactive dashboards (more detail).
