# Structured Logging Patterns

## JSON Logging Fundamentals

Every log entry should be a JSON object with consistent top-level fields for machine parsing and aggregation.

### Standard Log Fields

```json
{
  "timestamp": "2025-03-15T14:22:31.456Z",
  "level": "info",
  "service": "order-service",
  "version": "1.4.2",
  "environment": "production",
  "trace_id": "abc123def456",
  "span_id": "789ghi012",
  "correlation_id": "req-550e8400-e29b",
  "message": "order_processed",
  "order_id": "ORD-12345",
  "duration_ms": 142
}
```

## Log Level Guidelines

| Level | When to Use | Examples |
|-------|-------------|---------|
| **DEBUG** | Detailed diagnostics; disabled in production by default | Variable values, SQL queries, cache hit/miss |
| **INFO** | Normal business operations worth recording | Request started/completed, order placed, job finished |
| **WARNING** | Unexpected but recoverable situations | Retry attempt, deprecated API called, cache fallback |
| **ERROR** | Operation failed but service continues | Payment declined, API timeout, validation failure |
| **CRITICAL** | Service is about to crash or is unusable | DB connection lost, out of memory, cert expired |

```python
# Good: level reflects severity
logger.info("order_created", order_id=order_id, item_count=len(items))
logger.warning("payment_retry", order_id=order_id, attempt=3, max_attempts=5)
logger.error("payment_failed", order_id=order_id, error=str(e), provider="stripe")

# Bad: wrong levels obscure signal
logger.error("order_created")     # Not an error
logger.debug("payment_failed")    # Critical path failure
```

## Python: structlog Configuration

```python
import structlog
import logging
import sys
import os

def configure_logging(service_name: str, log_level: str = "INFO"):
    """Production-ready structlog configuration with JSON output."""
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    logging.basicConfig(format="%(message)s", stream=sys.stdout,
                        level=getattr(logging, log_level))
    structlog.contextvars.bind_contextvars(
        service=service_name, environment=os.getenv("ENVIRONMENT", "development"),
    )
```

## Correlation ID Propagation

### HTTP Services (FastAPI)

```python
import uuid
import structlog
from starlette.middleware.base import BaseHTTPMiddleware

class CorrelationMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            correlation_id=correlation_id,
            trace_id=request.headers.get("X-Trace-ID", ""),
            method=request.method, path=request.url.path,
        )
        logger = structlog.get_logger()
        logger.info("request_started")
        response = await call_next(request)
        logger.info("request_completed", status_code=response.status_code)
        response.headers["X-Correlation-ID"] = correlation_id
        return response
```

### Propagating to Downstream Services

```python
import httpx
import structlog

async def call_downstream(url: str, payload: dict) -> dict:
    ctx = structlog.contextvars.get_contextvars()
    headers = {
        "X-Correlation-ID": ctx.get("correlation_id", ""),
        "X-Trace-ID": ctx.get("trace_id", ""),
    }
    async with httpx.AsyncClient() as client:
        response = await client.post(url, json=payload, headers=headers)
        response.raise_for_status()
        return response.json()
```

### Async Task Propagation (Celery)

```python
import structlog
from celery import signals

@signals.before_task_publish.connect
def propagate_context_to_task(headers=None, **kwargs):
    ctx = structlog.contextvars.get_contextvars()
    if headers is not None:
        headers["correlation_id"] = ctx.get("correlation_id", "")
        headers["trace_id"] = ctx.get("trace_id", "")

@signals.task_prerun.connect
def restore_context_in_worker(task_id=None, task=None, **kwargs):
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(
        correlation_id=getattr(task.request, "correlation_id", ""),
        trace_id=getattr(task.request, "trace_id", ""),
        task_name=task.name, task_id=task_id,
    )
```

## Node.js: Pino Configuration

```javascript
const pino = require("pino");
const { randomUUID } = require("crypto");

const logger = pino({
  level: process.env.LOG_LEVEL || "info",
  timestamp: pino.stdTimeFunctions.isoTime,
  formatters: { level(label) { return { level: label }; } },
  base: {
    service: "order-service",
    version: process.env.APP_VERSION || "unknown",
    environment: process.env.NODE_ENV || "development",
  },
  redact: {
    paths: ["req.headers.authorization", "password", "ssn", "credit_card"],
    censor: "[REDACTED]",
  },
});

function requestLogger(req, res, next) {
  const correlationId = req.headers["x-correlation-id"] || randomUUID();
  req.log = logger.child({ correlation_id: correlationId, method: req.method, path: req.url });
  req.log.info("request_started");
  const startTime = process.hrtime.bigint();
  res.on("finish", () => {
    const durationMs = Number(process.hrtime.bigint() - startTime) / 1e6;
    req.log.info({ status_code: res.statusCode, duration_ms: durationMs }, "request_completed");
  });
  res.setHeader("X-Correlation-ID", correlationId);
  next();
}
```

## Sensitive Data Redaction

```python
import structlog

REDACT_FIELDS = {"password", "token", "secret", "api_key", "authorization", "ssn", "credit_card"}

def redact_sensitive_fields(logger, method_name, event_dict):
    for key in list(event_dict.keys()):
        if key.lower() in REDACT_FIELDS:
            event_dict[key] = "[REDACTED]"
    return event_dict

# Add to structlog processor chain before JSONRenderer
structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        redact_sensitive_fields,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
)
```

## Log Aggregation Pipeline

```yaml
# Fluent Bit configuration
[SERVICE]
    Flush        5
    Log_Level    info

[INPUT]
    Name         tail
    Path         /var/log/containers/*.log
    Parser       docker
    Tag          kube.*
    Mem_Buf_Limit 5MB

[FILTER]
    Name         kubernetes
    Match        kube.*
    Merge_Log    On

[OUTPUT]
    Name         es
    Match        *
    Host         elasticsearch.internal
    Port         9200
    Index        logs-%Y.%m.%d
    Retry_Limit  5

[OUTPUT]
    Name         loki
    Match        *
    Host         loki.internal
    Port         3100
    Labels       service=$service, environment=$environment
```

## Edge Cases and Gotchas

- **Circular references** -- JSON serialization fails on objects with circular refs. Use `format_exc_info` and avoid logging raw request/response objects.
- **High-cardinality fields** -- Logging unique request bodies inflates index size. Log a hash or summary instead.
- **Log volume spikes** -- A retry loop logging ERROR on every attempt generates thousands of entries. Log the first failure and a summary after retries complete.
- **Timezone consistency** -- Always log in UTC (ISO 8601 with Z suffix). Local timestamps cause confusion across regions.
- **Multi-line exceptions** -- Stack traces break line-based parsers. Embed tracebacks as a single JSON field.
