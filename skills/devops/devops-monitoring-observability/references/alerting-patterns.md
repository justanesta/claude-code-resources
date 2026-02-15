# Alerting Design Patterns

## Severity Levels

Define severity levels consistently across all services. Each level has a clear response expectation.

| Severity | Response Time | Action | Notification | Example |
|----------|--------------|--------|-------------|---------|
| **P1 / Critical** | Immediate (< 5 min) | Page on-call, incident bridge | PagerDuty/phone call | Service down, data loss, SLO breach > 50% budget |
| **P2 / High** | < 30 min | Page on-call during business hours | PagerDuty/SMS | Error rate spike, degraded latency, partial outage |
| **P3 / Warning** | < 4 hours | Ticket created, addressed same day | Slack channel | Slow burn rate, certificate expiring in 7 days |
| **P4 / Info** | Next business day | Ticket for review | Email/Slack | Disk usage trending up, dependency deprecation |

## Alert Rule Design

### Good Alerts: Symptom-Based, SLO-Driven

```yaml
groups:
  - name: user_facing_alerts
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          / sum(rate(http_requests_total[5m])) > 0.01
        for: 5m
        labels:
          severity: critical
          team: platform
          slo: api-availability
        annotations:
          summary: "Error rate {{ $value | humanizePercentage }} exceeds 1% SLO"
          runbook: "https://runbooks.internal/alerts/high-error-rate"
          dashboard: "https://grafana.internal/d/service-overview"
          impact: "Users experiencing HTTP 500 errors on API requests"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 0.5
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "p99 latency {{ $value }}s exceeds 500ms SLO"
          runbook: "https://runbooks.internal/alerts/high-latency"
```

### Multi-Window Burn Rate Alerts

```yaml
groups:
  - name: slo_burn_rate
    rules:
      # Fast burn: 2% of 30-day budget consumed in 1 hour
      - alert: ErrorBudgetFastBurn
        expr: |
          (sum(rate(http_requests_total{status=~"5.."}[1h]))
           / sum(rate(http_requests_total[1h]))) > (14.4 * 0.001)
          and
          (sum(rate(http_requests_total{status=~"5.."}[5m]))
           / sum(rate(http_requests_total[5m]))) > (14.4 * 0.001)
        for: 2m
        labels:
          severity: critical

      # Slow burn: 10% of budget consumed in 3 days
      - alert: ErrorBudgetSlowBurn
        expr: |
          (sum(rate(http_requests_total{status=~"5.."}[6h]))
           / sum(rate(http_requests_total[6h]))) > (6 * 0.001)
          and
          (sum(rate(http_requests_total{status=~"5.."}[30m]))
           / sum(rate(http_requests_total[30m]))) > (6 * 0.001)
        for: 15m
        labels:
          severity: warning
```

## Alertmanager Routing and Configuration

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m
  pagerduty_url: "https://events.pagerduty.com/v2/enqueue"

inhibit_rules:
  - source_matchers: [severity="critical"]
    target_matchers: [severity="warning"]
    equal: ["alertname", "service"]

route:
  receiver: default-slack
  group_by: ["alertname", "service"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - matchers: [severity="critical"]
      receiver: pagerduty-critical
      group_wait: 10s
      repeat_interval: 1h
    - matchers: [severity="warning"]
      receiver: team-slack-and-ticket
      repeat_interval: 8h
    - matchers: [team="data-engineering"]
      receiver: data-team-slack

receivers:
  - name: default-slack
    slack_configs:
      - channel: "#alerts-general"
        title: '{{ .GroupLabels.alertname }}'
        text: >-
          {{ range .Alerts }}
          *{{ .Labels.severity | toUpper }}*: {{ .Annotations.summary }}
          Runbook: {{ .Annotations.runbook }}
          {{ end }}
  - name: pagerduty-critical
    pagerduty_configs:
      - routing_key: "<pagerduty-integration-key>"
        severity: critical
        description: '{{ .GroupLabels.alertname }}: {{ .CommonAnnotations.summary }}'
  - name: team-slack-and-ticket
    slack_configs:
      - channel: "#alerts-platform"
    webhook_configs:
      - url: "https://jira-webhook.internal/create-ticket"
  - name: data-team-slack
    slack_configs:
      - channel: "#alerts-data-eng"
```

## Runbook Template

Every alert must link to a runbook. Use this structure.

```markdown
# Runbook: HighErrorRate

## Alert Description
Error rate exceeds 1% of requests returning 5xx, sustained for 5 minutes.

## Impact
Users experiencing failed API requests. Downstream services may also be affected.

## Investigation Steps
1. Check dashboard: https://grafana.internal/d/service-overview
2. Check recent deployments: `kubectl rollout history deployment/api-service -n production`
3. Check dependency health (database, redis, downstream APIs)
4. Check logs: `kubectl logs -l app=api-service --since=15m | jq 'select(.level=="error")'`
5. Check resources: `kubectl top pods -l app=api-service -n production`

## Remediation
| Cause | Action |
|-------|--------|
| Bad deployment | `kubectl rollout undo deployment/api-service -n production` |
| Database overload | Scale read replicas or enable connection pooling |
| Memory pressure | `kubectl rollout restart deployment/api-service` |

## Escalation
- P1: Escalate to platform-oncall after 15 min if unresolved
- P2: Escalate to engineering manager after 1 hour
```

## PagerDuty Integration

```python
import httpx
from datetime import datetime

class PagerDutyClient:
    """Send alerts to PagerDuty Events API v2."""

    def __init__(self, routing_key: str):
        self.routing_key = routing_key
        self.api_url = "https://events.pagerduty.com/v2/enqueue"

    async def trigger(
        self, summary: str, severity: str, source: str,
        dedup_key: str | None = None, custom_details: dict | None = None,
    ) -> str:
        payload = {
            "routing_key": self.routing_key,
            "event_action": "trigger",
            "dedup_key": dedup_key or f"{source}-{summary}",
            "payload": {
                "summary": summary,
                "severity": severity,
                "source": source,
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "custom_details": custom_details or {},
            },
            "links": [
                {"href": f"https://grafana.internal/d/{source}", "text": "Dashboard"},
                {"href": f"https://runbooks.internal/{source}", "text": "Runbook"},
            ],
        }
        async with httpx.AsyncClient() as client:
            response = await client.post(self.api_url, json=payload)
            response.raise_for_status()
            return response.json()["dedup_key"]

    async def resolve(self, dedup_key: str):
        payload = {
            "routing_key": self.routing_key,
            "event_action": "resolve",
            "dedup_key": dedup_key,
        }
        async with httpx.AsyncClient() as client:
            await client.post(self.api_url, json=payload)
```

## Alert Fatigue Prevention

```yaml
# 1. Require sustained conditions (for: clause)
- alert: HighMemoryUsage
  expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
  for: 15m  # Must persist 15 minutes, not just spike once
  labels:
    severity: warning

# 2. Use aggregated rates, not individual events
# BAD: alerts on a single error
- alert: SingleError
  expr: increase(errors_total[1m]) > 0
# GOOD: alerts on sustained error rate
- alert: HighErrorRate
  expr: rate(errors_total[5m]) > 0.05
  for: 5m
```

### Monthly Alert Quality Review

```python
alert_quality_metrics = {
    "total_fires": 142,
    "true_positives": 28,       # Required human action
    "false_positives": 89,      # No action needed
    "auto_resolved": 25,        # Resolved before investigation
    "action_rate": 0.197,       # true_positives / total_fires
    "recommendation": "delete", # < 10% action rate = delete alert
}
# Target: > 50% action rate. Below 10%: delete. 10-50%: tune thresholds.
```

## Data Pipeline Alert Patterns

```yaml
groups:
  - name: pipeline_alerts
    rules:
      - alert: PipelineFreshnessSLO
        expr: (time() - pipeline_last_success_timestamp_seconds) > 3600
        for: 5m
        labels:
          severity: critical
          team: data-engineering
        annotations:
          summary: "Pipeline {{ $labels.pipeline }} has not succeeded in over 1 hour"

      - alert: PipelineRecordCountAnomaly
        expr: |
          abs(pipeline_records_processed_total - pipeline_records_expected_total)
          / pipeline_records_expected_total > 0.2
        for: 10m
        labels:
          severity: warning
          team: data-engineering

      - alert: PipelineErrorRateHigh
        expr: |
          rate(pipeline_errors_total[15m])
          / rate(pipeline_records_processed_total[15m]) > 0.05
        for: 10m
        labels:
          severity: warning
          team: data-engineering
```

## Edge Cases

- **Flapping alerts** -- Alerts that fire and resolve in rapid cycles. Use longer `for` durations and hysteresis (different thresholds for trigger vs. resolve).
- **Missing metrics** -- If a service crashes, its metrics disappear. Use `absent()` to detect: `absent(up{job="api-service"})`.
- **Alert storms during outages** -- A single root cause triggers dozens of alerts. Use Alertmanager inhibition rules so the root-cause alert suppresses downstream alerts.
- **Timezone-dependent alerts** -- Business-hours-only alerting requires Alertmanager mute schedules. Do not hardcode UTC offsets.
- **Deployment-correlated spikes** -- Brief error spikes during rolling deployments are expected. Use `for: 5m` to ride through deployment windows.
