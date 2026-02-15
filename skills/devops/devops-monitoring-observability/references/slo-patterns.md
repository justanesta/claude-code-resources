# SLO Patterns: SLIs, SLOs, and Error Budgets

## SLI Definitions

Service Level Indicators (SLIs) are measurable signals that reflect user experience.

### The Four Golden SLIs

| SLI Type | What It Measures | Formula | Good For |
|----------|-----------------|---------|----------|
| **Availability** | Proportion of successful requests | `successful / total requests` | APIs, web services |
| **Latency** | Proportion of fast requests | `requests < threshold / total` | User-facing endpoints |
| **Throughput** | Processing at expected rate | `actual rate / expected rate` | Data pipelines, queues |
| **Correctness** | Proportion of correct outputs | `correct / total results` | Pipelines, ML models |

### Availability SLI

```promql
# HTTP: non-5xx / total
sum(rate(http_requests_total{status!~"5.."}[5m]))
/ sum(rate(http_requests_total[5m]))

# gRPC: OK / total
sum(rate(grpc_server_handled_total{grpc_code="OK"}[5m]))
/ sum(rate(grpc_server_handled_total[5m]))
```

### Latency SLI

```promql
# Proportion of requests completing under 500ms
sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
/ sum(rate(http_request_duration_seconds_count[5m]))
```

### Data Pipeline SLIs

```promql
# Freshness
(time() - pipeline_last_success_timestamp_seconds)

# Throughput: actual vs expected records
pipeline_records_processed_total / pipeline_records_expected_total

# Correctness
pipeline_records_valid_total / pipeline_records_processed_total
```

## SLO Target Selection

```python
from dataclasses import dataclass

@dataclass
class SLOTarget:
    name: str
    sli_type: str
    target: float
    window_days: int

    @property
    def error_budget_minutes_per_month(self) -> float:
        return (1 - self.target) * 30 * 24 * 60

# Common targets and their budgets
targets = [
    SLOTarget("basic",    "availability", 0.99,   30),  # 432 min/month = 7.2 hr
    SLOTarget("standard", "availability", 0.999,  30),  # 43.2 min/month
    SLOTarget("premium",  "availability", 0.9999, 30),  # 4.32 min/month
]
```

### Decision Framework

- **User expectations** -- What latency/availability do users actually notice?
- **Business impact** -- What is the cost per minute of downtime?
- **Dependency budget** -- Your SLO cannot exceed your dependencies' SLOs
- **Engineering cost** -- Each additional nine roughly doubles operational cost
- **Current performance** -- Set target slightly below actual (e.g., running at 99.95%, set SLO at 99.9%)

## Error Budget Tracking

```python
from dataclasses import dataclass

@dataclass
class ErrorBudgetTracker:
    slo_target: float
    window_days: int

    @property
    def total_budget(self) -> float:
        return 1.0 - self.slo_target

    def calculate_status(
        self, total_requests: int, failed_requests: int, elapsed_days: float,
    ) -> dict:
        error_rate = failed_requests / total_requests if total_requests > 0 else 0
        budget_consumed = error_rate / self.total_budget if self.total_budget > 0 else 0
        expected_consumption = elapsed_days / self.window_days
        return {
            "slo_target": self.slo_target,
            "current_sli": 1 - error_rate,
            "meeting_slo": error_rate <= self.total_budget,
            "budget_consumed_pct": round(budget_consumed * 100, 2),
            "budget_remaining_pct": round((1 - budget_consumed) * 100, 2),
            "burn_rate": round(budget_consumed / expected_consumption, 2)
                if expected_consumption > 0 else 0,
        }

# 99.9% SLO, 15 days in, 300 errors out of 1M requests
tracker = ErrorBudgetTracker(slo_target=0.999, window_days=30)
status = tracker.calculate_status(1_000_000, 300, 15)
# budget_consumed_pct: 30% (in 50% of window = healthy, burn_rate: 0.6)
```

## Burn Rate Alerting

Burn rate measures how fast the error budget is consumed relative to the SLO window.

```python
def calculate_burn_rate_thresholds(slo_target: float) -> dict:
    error_budget = 1 - slo_target
    return {
        "page_fast": {
            "burn_rate": 14.4, "long_window": "1h", "short_window": "5m",
            "budget_consumed": "2% in 1 hour", "threshold": error_budget * 14.4,
            "severity": "critical",
        },
        "page_slow": {
            "burn_rate": 6.0, "long_window": "6h", "short_window": "30m",
            "budget_consumed": "5% in 6 hours", "threshold": error_budget * 6.0,
            "severity": "critical",
        },
        "ticket_slow": {
            "burn_rate": 3.0, "long_window": "1d", "short_window": "2h",
            "budget_consumed": "10% in 1 day", "threshold": error_budget * 3.0,
            "severity": "warning",
        },
    }
# For 99.9% SLO: fast burn threshold = 0.001 * 14.4 = 1.44% error rate
```

### Prometheus Burn Rate Rules

```yaml
groups:
  - name: slo_burn_rates
    interval: 30s
    rules:
      - record: slo:http_error_ratio:rate1h
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[1h]))
          / sum(rate(http_requests_total[1h]))
      - record: slo:http_error_ratio:rate5m
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          / sum(rate(http_requests_total[5m]))
      - record: slo:http_error_ratio:rate6h
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[6h]))
          / sum(rate(http_requests_total[6h]))
      - record: slo:budget_remaining:ratio
        expr: |
          1 - (
            sum(increase(http_requests_total{status=~"5.."}[30d]))
            / sum(increase(http_requests_total[30d]))
          ) / 0.001

  - name: slo_alerts
    rules:
      - alert: SLOFastBurn
        expr: |
          slo:http_error_ratio:rate1h > (14.4 * 0.001)
          and slo:http_error_ratio:rate5m > (14.4 * 0.001)
        for: 2m
        labels: { severity: critical }
        annotations:
          summary: "Fast error budget burn: 2% consumed in 1 hour"
      - alert: SLOSlowBurn
        expr: |
          slo:http_error_ratio:rate6h > (6 * 0.001)
        for: 15m
        labels: { severity: warning }
        annotations:
          summary: "Slow error budget burn: 5% consumed in 6 hours"
```

## Error Budget Policies

Define what happens at different budget levels.

```python
error_budget_policy = {
    "budget > 50%": "Normal velocity. Deploy at will. Monthly SLO review.",
    "budget 25-50%": "Caution. Require rollback plan. Weekly SLO review.",
    "budget 10-25%": "Restricted. Only critical fixes and reliability work. Daily check-in.",
    "budget < 10%": "Frozen. Feature freeze. Only reliability fixes. Incident-level response.",
}
```

## SLO Documentation Template

```yaml
# slo-definitions/api-service.yaml
slos:
  - name: api-availability
    description: "Proportion of HTTP requests that succeed (non-5xx)"
    owner: platform-team
    sli:
      type: availability
      good_events: 'http_requests_total{status!~"5.."}'
      total_events: 'http_requests_total'
    target: 0.999
    window: 30d
    alerts:
      fast_burn: { burn_rate: 14.4, severity: critical }
      slow_burn: { burn_rate: 6.0, severity: warning }
    consequences:
      budget_exhausted: "Feature freeze until budget recovers"
      budget_low: "Reduce deploy frequency, require rollback plans"
    dashboard: "https://grafana.internal/d/slo-api"
    runbook: "https://runbooks.internal/slo-api-availability"

  - name: pipeline-freshness
    description: "Data pipeline delivers fresh data within 1 hour"
    owner: data-engineering
    sli:
      type: freshness
      threshold: 3600  # seconds
    target: 0.999
    window: 30d
```

## Edge Cases and Gotchas

- **Zero-traffic periods** -- If there are no requests, the SLI is undefined (0/0). Exclude zero-traffic windows or treat them as "meeting SLO".
- **Client errors in SLI** -- A flood of 400 errors from a buggy client should not consume your budget. Exclude 4xx from availability SLIs unless they indicate server problems.
- **SLO above current performance** -- Never set a target higher than actual. Running at 99.8% with a 99.99% SLO means permanent budget violation.
- **Dependency chains** -- Service A depending on B (99.9%) and C (99.9%) has max theoretical availability of 99.8%.
- **Window reset games** -- Teams may wait for budget recovery. Use rolling windows (not calendar-based) to prevent gaming.
- **Multiple SLOs per service** -- Aim for 2-4 SLOs covering different user journeys. Too many dilute focus; too few miss failure modes.
