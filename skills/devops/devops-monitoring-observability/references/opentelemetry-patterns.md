# OpenTelemetry Instrumentation Patterns

## SDK Setup and Configuration

### Python: Full Setup with OTLP Export

```python
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource, SERVICE_NAME, SERVICE_VERSION

def configure_opentelemetry(service_name: str, service_version: str):
    """Initialize OTel with traces and metrics, exporting to OTLP collector."""
    resource = Resource.create({
        SERVICE_NAME: service_name,
        SERVICE_VERSION: service_version,
        "deployment.environment": os.getenv("ENVIRONMENT", "development"),
    })
    # Traces
    trace_provider = TracerProvider(resource=resource)
    trace_provider.add_span_processor(
        BatchSpanProcessor(
            OTLPSpanExporter(endpoint="http://otel-collector:4317"),
            max_queue_size=2048, schedule_delay_millis=5000, max_export_batch_size=512,
        )
    )
    trace.set_tracer_provider(trace_provider)
    # Metrics
    metric_reader = PeriodicExportingMetricReader(
        OTLPMetricExporter(endpoint="http://otel-collector:4317"),
        export_interval_millis=30000,
    )
    metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))
```

### Environment Variable Configuration

```bash
export OTEL_SERVICE_NAME="order-service"
export OTEL_RESOURCE_ATTRIBUTES="service.version=1.2.0,deployment.environment=production"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector:4317"
export OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
export OTEL_TRACES_SAMPLER="parentbased_traceidratio"
export OTEL_TRACES_SAMPLER_ARG="0.1"  # Sample 10% of traces
```

## Auto-Instrumentation

### Python: Library Instrumentation

```python
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

def instrument_app(app):
    FastAPIInstrumentor.instrument_app(app)
    SQLAlchemyInstrumentor().instrument(engine=db_engine)
    RedisInstrumentor().instrument()
    HTTPXClientInstrumentor().instrument()
```

### Zero-Code Instrumentation via CLI

```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install

opentelemetry-instrument \
    --service_name order-service \
    --exporter_otlp_endpoint http://otel-collector:4317 \
    python app.py
```

### Node.js Auto-Instrumentation

```javascript
// tracing.js -- load BEFORE application code
const { NodeSDK } = require("@opentelemetry/sdk-node");
const { OTLPTraceExporter } = require("@opentelemetry/exporter-trace-otlp-grpc");
const { getNodeAutoInstrumentations } = require("@opentelemetry/auto-instrumentations-node");
const { Resource } = require("@opentelemetry/resources");
const { ATTR_SERVICE_NAME } = require("@opentelemetry/semantic-conventions");

const sdk = new NodeSDK({
  resource: new Resource({ [ATTR_SERVICE_NAME]: "order-service" }),
  traceExporter: new OTLPTraceExporter({ url: "http://otel-collector:4317" }),
  instrumentations: [
    getNodeAutoInstrumentations({
      "@opentelemetry/instrumentation-http": {
        ignoreIncomingPaths: ["/health", "/metrics"],
      },
    }),
  ],
});
sdk.start();
process.on("SIGTERM", () => sdk.shutdown());
```

## Custom Spans and Attributes

```python
from opentelemetry import trace
from opentelemetry.trace import StatusCode

tracer = trace.get_tracer("order-service.processing")

def process_order(order_id: str, items: list[dict]) -> dict:
    with tracer.start_as_current_span(
        "process_order",
        attributes={"order.id": order_id, "order.item_count": len(items)},
    ) as span:
        try:
            with tracer.start_as_current_span("check_inventory") as inv_span:
                available = inventory_service.check(items)
                inv_span.set_attribute("inventory.all_available", available)
                if not available:
                    span.set_status(StatusCode.ERROR, "Items out of stock")
                    raise OutOfStockError(order_id)

            with tracer.start_as_current_span("process_payment") as pay_span:
                payment = payment_service.charge(order_id, items)
                pay_span.set_attribute("payment.id", payment.id)
                pay_span.add_event("payment_authorized", {"amount": str(payment.amount)})

            span.set_status(StatusCode.OK)
            return {"order_id": order_id, "status": "completed"}
        except Exception as e:
            span.set_status(StatusCode.ERROR, str(e))
            span.record_exception(e)
            raise
```

## Context Propagation Across Boundaries

### HTTP Propagation

```python
from opentelemetry import context
from opentelemetry.propagate import inject, extract
import httpx

async def call_service(url: str, data: dict) -> dict:
    """Propagate trace context in outbound HTTP headers."""
    headers = {}
    inject(headers)  # Injects traceparent and tracestate headers
    async with httpx.AsyncClient() as client:
        response = await client.post(url, json=data, headers=headers)
        return response.json()

def extract_context_middleware(request):
    """Extract trace context from incoming HTTP headers."""
    ctx = extract(request.headers)
    token = context.attach(ctx)
    try:
        return handle_request(request)
    finally:
        context.detach(token)
```

### Message Queue Propagation (Kafka)

```python
from opentelemetry.propagate import inject, extract

def produce_message(topic: str, key: str, value: dict):
    headers = {}
    inject(headers)
    kafka_headers = [(k, v.encode()) for k, v in headers.items()]
    producer.produce(topic=topic, key=key, value=json.dumps(value), headers=kafka_headers)

def consume_message(message):
    carrier = {k: v.decode() for k, v in message.headers() or []}
    ctx = extract(carrier)
    with tracer.start_as_current_span(
        f"process_{message.topic()}", context=ctx, kind=trace.SpanKind.CONSUMER,
        attributes={"messaging.system": "kafka", "messaging.destination": message.topic()},
    ):
        process(message.value())
```

## Sampling Strategies

```python
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased, ParentBased, ALWAYS_ON

# Head-based: sample 10%, but always sample if parent was sampled
sampler = ParentBased(root=TraceIdRatioBased(0.1))

class AdaptiveSampler:
    """Sample all errors and a ratio of normal traffic."""
    def __init__(self, base_ratio: float = 0.1):
        self.base_sampler = TraceIdRatioBased(base_ratio)

    def should_sample(self, context, trace_id, name, kind, attributes, links):
        if attributes and attributes.get("error"):
            return ALWAYS_ON.should_sample(context, trace_id, name, kind, attributes, links)
        return self.base_sampler.should_sample(context, trace_id, name, kind, attributes, links)
```

## OTel Collector Configuration

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: "0.0.0.0:4317" }
      http: { endpoint: "0.0.0.0:4318" }

processors:
  batch: { timeout: 5s, send_batch_size: 1024 }
  memory_limiter: { check_interval: 1s, limit_mib: 512, spike_limit_mib: 128 }
  filter:
    traces:
      span:
        - 'attributes["http.target"] == "/health"'
        - 'attributes["http.target"] == "/metrics"'

exporters:
  otlp/tempo:
    endpoint: tempo:4317
    tls: { insecure: true }
  prometheus:
    endpoint: "0.0.0.0:8889"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, filter]
      exporters: [otlp/tempo]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
```

## Correlating Traces with Logs

```python
import structlog
from opentelemetry import trace

def add_trace_context(logger, method_name, event_dict):
    """Structlog processor: inject trace_id and span_id into every log entry."""
    span = trace.get_current_span()
    if span and span.is_recording():
        ctx = span.get_span_context()
        event_dict["trace_id"] = format(ctx.trace_id, "032x")
        event_dict["span_id"] = format(ctx.span_id, "016x")
    return event_dict

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        add_trace_context,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
)
```

## Edge Cases and Gotchas

- **Span name cardinality** -- Use low-cardinality names (`GET /users/:id`, not `GET /users/12345`). High-cardinality names degrade backend performance.
- **Missing context in thread pools** -- `ThreadPoolExecutor` does not propagate OTel context automatically. Use `opentelemetry.context.attach()` in worker threads.
- **Span attribute limits** -- Default max is 128 attributes per span. Exceeding this silently drops attributes. Increase via `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT`.
- **Baggage vs span attributes** -- Baggage propagates across service boundaries; span attributes do not. Use baggage for cross-service context like tenant ID.
- **Shutdown gracefully** -- Always call `trace_provider.shutdown()` on exit to flush buffered spans. Without this, the last batch may be lost.
- **Clock skew** -- Distributed traces rely on synchronized clocks. Use NTP on all hosts; skew > 100ms causes confusing trace timelines.
