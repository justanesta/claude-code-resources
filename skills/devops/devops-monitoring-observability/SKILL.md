---
name: devops-monitoring-observability
description: |
  Monitoring, observability, and alerting for production systems. Use this skill when
  implementing structured logging, Prometheus metrics, OpenTelemetry tracing, alerting
  strategies, SLOs/SLIs, or dashboard design. Covers the three pillars of observability,
  PromQL, distributed tracing, error budgets, and alert fatigue prevention for
  microservices and data pipelines.
---

# DevOps: Monitoring and Observability

Production-grade monitoring, observability, and alerting patterns for microservices, data pipelines, and distributed systems.

## Core Principles

1. **Three pillars of observability** -- Logs, metrics, and traces are complementary signals. Logs tell you what happened, metrics tell you how the system is performing, and traces tell you how a request flowed through services.
2. **SLIs drive SLOs drive alerts** -- Define Service Level Indicators (measurable signals), set Service Level Objectives (targets), and derive alerts from error budget burn rates. Never alert on raw thresholds disconnected from user impact.
3. **Structured logging everywhere** -- Emit JSON-formatted logs with consistent fields (timestamp, service, trace_id, level). Unstructured text logs are unsearchable at scale.
4. **Instrument at boundaries** -- Focus on service entry points, external calls (databases, APIs, queues), and critical business transactions. Over-instrumenting internal functions creates noise.
5. **Alerts must be actionable** -- Every alert should have a clear owner, a runbook, and a defined severity. If nobody needs to act, it should not be an alert.

## Structured Logging Patterns

Emit structured JSON logs with correlation IDs for cross-service tracing and consistent fields for aggregation.

```python
import structlog
import uuid

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer(),
    ],
)
logger = structlog.get_logger()

def handle_request(request):
    """Bind correlation ID at request entry, propagate through all log calls."""
    correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
    structlog.contextvars.bind_contextvars(
        correlation_id=correlation_id,
        service="order-service",
        endpoint=request.path,
    )
    logger.info("request_started", method=request.method, user_id=request.user_id)
    try:
        result = process_order(request)
        logger.info("request_completed", status="success", order_id=result.id)
        return result
    except Exception as e:
        logger.error("request_failed", error=str(e), exc_info=True)
        raise
```

See [structured-logging.md](references/structured-logging.md) for:
- Log level guidelines and when to use each
- Correlation ID propagation across async boundaries
- Python structlog and Node.js pino configuration
- Sensitive data redaction patterns

## Prometheus Metrics

Use counters, gauges, and histograms to capture system and business behavior. Query with PromQL for dashboards and alerts.

```python
from prometheus_client import Counter, Histogram, Gauge
import time

REQUEST_COUNT = Counter("http_requests_total", "Total HTTP requests",
    ["method", "endpoint", "status"])
REQUEST_DURATION = Histogram("http_request_duration_seconds", "Latency in seconds",
    ["method", "endpoint"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0])
ACTIVE_CONNECTIONS = Gauge("active_connections", "Active connections", ["service"])

def handle_request(method, endpoint):
    ACTIVE_CONNECTIONS.labels(service="api").inc()
    start = time.monotonic()
    try:
        result = process(method, endpoint)
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status="200").inc()
        return result
    except Exception:
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status="500").inc()
        raise
    finally:
        REQUEST_DURATION.labels(method=method, endpoint=endpoint).observe(
            time.monotonic() - start)
        ACTIVE_CONNECTIONS.labels(service="api").dec()
```

See [prometheus-patterns.md](references/prometheus-patterns.md) for:
- PromQL query patterns for RED and USE methods
- Recording rules for pre-computed aggregations
- Alerting rules with multi-window burn rates
- Histogram bucket selection strategies

## OpenTelemetry Instrumentation

Use OpenTelemetry for distributed tracing with automatic context propagation across service boundaries.

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

resource = Resource.create({"service.name": "order-service", "service.version": "1.2.0"})
provider = TracerProvider(resource=resource)
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="http://otel-collector:4317")))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

def process_order(order_id: str, items: list[dict]) -> dict:
    with tracer.start_as_current_span(
        "process_order",
        attributes={"order.id": order_id, "order.item_count": len(items)},
    ) as span:
        with tracer.start_as_current_span("validate_inventory"):
            available = check_inventory(items)
            span.set_attribute("order.items_available", available)
        with tracer.start_as_current_span("charge_payment"):
            payment = charge(order_id, items)
            span.add_event("payment_processed", {"payment.id": payment.id})
        return {"order_id": order_id, "status": "completed"}
```

See [opentelemetry-patterns.md](references/opentelemetry-patterns.md) for:
- Auto-instrumentation for Flask, FastAPI, Django, SQLAlchemy
- Baggage and context propagation across async tasks
- Custom span attributes and events best practices
- Exporter configuration for Jaeger, Zipkin, and Grafana Tempo

## Alerting Design

Design alerts around user impact with clear severity levels and multi-window burn rate thresholds to prevent alert fatigue.

```yaml
groups:
  - name: slo_alerts
    rules:
      # Page: 2% budget consumed in 1 hour (fast burn)
      - alert: HighErrorBudgetBurn
        expr: |
          (sum(rate(http_requests_total{status=~"5.."}[1h]))
           / sum(rate(http_requests_total[1h]))) > (14.4 * 0.001)
          and
          (sum(rate(http_requests_total{status=~"5.."}[5m]))
           / sum(rate(http_requests_total[5m]))) > (14.4 * 0.001)
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error budget burn on {{ $labels.service }}"
          runbook: "https://runbooks.internal/slo-budget-burn"
```

See [alerting-patterns.md](references/alerting-patterns.md) for:
- Severity level definitions (P1-P4) and routing rules
- PagerDuty and Opsgenie integration patterns
- Runbook templates and incident response workflows
- Alert grouping, inhibition, and silencing strategies

## SLIs, SLOs, and Error Budgets

Define SLIs from real user signals, set SLO targets, and use error budgets to balance reliability with velocity.

```python
from dataclasses import dataclass

@dataclass
class SLODefinition:
    name: str
    sli_query: str        # PromQL query returning ratio 0-1
    target: float         # e.g. 0.999 for 99.9%
    window_days: int      # Rolling window (typically 30)
    burn_rate_pages: dict

    @property
    def error_budget(self) -> float:
        return 1.0 - self.target

    def budget_remaining(self, current_error_rate: float, elapsed_days: int) -> dict:
        budget_total = self.error_budget * self.window_days * 24 * 60
        budget_consumed = current_error_rate * elapsed_days * 24 * 60
        remaining_pct = max(0, (budget_total - budget_consumed) / budget_total)
        return {
            "remaining_pct": round(remaining_pct * 100, 2),
            "on_track": remaining_pct > (1 - elapsed_days / self.window_days),
        }

availability_slo = SLODefinition(
    name="api-availability",
    sli_query='sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))',
    target=0.999, window_days=30,
    burn_rate_pages={"critical": 14.4, "warning": 6.0, "ticket": 3.0},
)
```

See [slo-patterns.md](references/slo-patterns.md) for:
- SLI definitions for availability, latency, throughput, and correctness
- Error budget policies and decision frameworks
- Multi-window, multi-burn-rate alerting math
- SLO documentation templates and stakeholder reporting

## Dashboard Design Patterns

Structure dashboards around the RED method (Rate, Errors, Duration) for services and the USE method (Utilization, Saturation, Errors) for resources.

```yaml
# Grafana dashboard -- layered approach (Level 1: RED overview)
panels:
  - title: "Request Rate"
    expr: 'sum(rate(http_requests_total[5m])) by (service)'
  - title: "Error Rate (%)"
    expr: '100 * sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
           / sum(rate(http_requests_total[5m])) by (service)'
    thresholds: [{value: 1, color: "yellow"}, {value: 5, color: "red"}]
  - title: "p50 / p95 / p99 Latency"
    expr:
      - 'histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))'
      - 'histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))'
  - title: "Error Budget Remaining"
    expr: 'slo:budget_remaining:ratio * 100'
    type: gauge
```

## Anti-Patterns

| Avoid | Use Instead |
|-------|-------------|
| Logging unstructured text strings | JSON-formatted structured logs with consistent fields |
| Alerting on raw CPU/memory thresholds | Alert on SLO burn rates that reflect user impact |
| Creating one dashboard per incident | Layered dashboards: overview, service detail, debug |
| Using `rate()` over short windows on slow metrics | Match rate window to scrape interval (at least 4x) |
| Logging everything at DEBUG in production | Log at INFO by default, enable DEBUG per-service dynamically |
| Separate, uncorrelated logs, metrics, and traces | Correlate with shared trace_id across all three signals |
| Alerting on every single error occurrence | Alert on error rates exceeding SLO-derived thresholds |
| Cardinality explosion from unbounded label values | Bound labels to known enums; never use user IDs as labels |
| Ignoring alert noise until it becomes unbearable | Review alert quality monthly; delete alerts with < 10% action rate |
| Building custom monitoring from scratch | Use OpenTelemetry standards with vendor-neutral exporters |

## Performance

- **Control metric cardinality** -- Every unique label combination creates a new time series. Never use user IDs or unbounded values as labels
- **Use recording rules** -- Pre-compute frequently used PromQL aggregations to avoid expensive queries on every dashboard refresh
- **Batch span exports** -- Use `BatchSpanProcessor` to avoid blocking application threads
- **Sample traces at scale** -- Use head-based sampling (1-10%) for normal traffic, tail-based (100%) for errors
- **Buffer logs asynchronously** -- Use a local buffer (Fluent Bit, Vector) that ships in batches
- **Right-size histogram buckets** -- Align to SLO thresholds (e.g., 100ms, 250ms, 500ms, 1s, 2.5s)

source: Google SRE Book, OpenTelemetry documentation, Prometheus best practices, Grafana Labs documentation
