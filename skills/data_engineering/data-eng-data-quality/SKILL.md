---
name: data-eng-data-quality
description: |
  Data quality validation, observability, and monitoring for data pipelines. Use this skill
  when implementing data quality checks with Great Expectations or Soda Core, designing
  schema contracts, building anomaly detection, or establishing data observability practices.
  Covers validation frameworks, quality metrics, SLAs, freshness monitoring, and lineage tracking.
---

# Data Engineering: Data Quality

Comprehensive data quality validation, monitoring, and observability patterns for production data pipelines.

## Core Principles

1. **Validate early, validate often** -- Catch data issues at ingestion before they propagate downstream. Every pipeline stage should have quality gates.
2. **Schema contracts are APIs** -- Treat your data schemas as versioned contracts between producers and consumers. Breaking changes require coordination.
3. **Measure the six dimensions** -- Track completeness, accuracy, consistency, timeliness, uniqueness, and validity as quantifiable metrics with thresholds.
4. **Observability over monitoring** -- Move beyond threshold alerts to understanding data behavior through freshness, volume, schema, and lineage tracking.
5. **Quality is a pipeline, not a step** -- Data quality is not a single validation checkpoint; it is a continuous process woven into every stage of your data lifecycle.

## Great Expectations Fundamentals

Define expectations as declarative rules, organize them into suites, and run checkpoints in your pipeline.

```python
import great_expectations as gx

context = gx.get_context()
ds = context.data_sources.add_pandas("customer_source")
asset = ds.add_dataframe_asset(name="customers")
batch_def = asset.add_batch_definition_whole_dataframe("full_batch")

suite = context.suites.add(gx.ExpectationSuite(name="customer_ingestion_suite"))
suite.add_expectation(gx.expectations.ExpectColumnValuesToNotBeNull(column="customer_id"))
suite.add_expectation(gx.expectations.ExpectColumnValuesToBeUnique(column="customer_id"))
suite.add_expectation(gx.expectations.ExpectColumnValuesToMatchRegex(
    column="email", regex=r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
))
suite.add_expectation(gx.expectations.ExpectColumnValuesToBeBetween(
    column="account_balance", min_value=0, max_value=10_000_000
))

val_def = context.validation_definitions.add(
    gx.ValidationDefinition(name="customer_validation", data=batch_def, suite=suite)
)
checkpoint = context.checkpoints.add(
    gx.Checkpoint(name="customer_checkpoint", validation_definitions=[val_def])
)
result = checkpoint.run()
if not result.success:
    raise ValueError(f"Quality failed: {sum(1 for r in result.run_results.values() if not r.success)} checks")
```

See [great-expectations-patterns.md](references/great-expectations-patterns.md) for:
- Custom expectation development
- Data Docs generation and hosting
- Multi-datasource checkpoint orchestration
- Conditional and parameterized expectations

## Soda Core Checks

Define data quality checks in YAML and run them with Soda Core for lightweight, configuration-driven validation.

```yaml
checks for customers:
  - row_count > 0
  - missing_count(customer_id) = 0
  - duplicate_count(customer_id) = 0
  - invalid_count(email) = 0:
      valid regex: "^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$"
  - freshness(updated_at) < 2d
  - schema:
      fail:
        when required column missing: [customer_id, email, created_at]
        when wrong type:
          customer_id: integer
  - anomaly detection for row_count:
      warn: only
```

See [soda-checks.md](references/soda-checks.md) for:
- Freshness and schema checks in depth
- Anomaly detection configuration
- Cross-dataset reference checks
- Soda Cloud integration and alerting

## Schema Contracts and Evolution

Enforce schema contracts at pipeline boundaries to prevent breaking changes from propagating silently.

```python
from dataclasses import dataclass
from enum import Enum

class Compat(Enum):
    BACKWARD = "backward"   # New schema can read old data
    FORWARD = "forward"     # Old schema can read new data
    FULL = "full"           # Both directions

@dataclass
class SchemaContract:
    name: str
    version: int
    required_columns: dict[str, str]    # column_name -> data_type
    optional_columns: dict[str, str]
    compatibility: Compat

    def validate_dataframe(self, df) -> list[str]:
        violations = []
        for col, dtype in self.required_columns.items():
            if col not in df.columns:
                violations.append(f"Missing required column: {col}")
            elif str(df[col].dtype) != dtype:
                violations.append(f"Column {col}: expected {dtype}, got {df[col].dtype}")
        return violations

    def check_evolution(self, new_contract: "SchemaContract") -> list[str]:
        issues = []
        removed = set(self.required_columns) - set(new_contract.required_columns)
        if removed and self.compatibility in (Compat.FORWARD, Compat.FULL):
            issues.append(f"Removing columns breaks forward compat: {removed}")
        added = set(new_contract.required_columns) - set(self.required_columns)
        if added and self.compatibility in (Compat.BACKWARD, Compat.FULL):
            issues.append(f"Adding required columns breaks backward compat: {added}")
        return issues
```

See [schema-contracts.md](references/schema-contracts.md) for:
- Avro and Protobuf schema registry integration
- Automated migration generation
- Contract testing in CI/CD pipelines
- Handling nullable and default value evolution

## Anomaly Detection Patterns

Detect unexpected changes in data volume, distributions, and value ranges using statistical methods.

```python
import numpy as np

class VolumeAnomalyDetector:
    def __init__(self, z_threshold: float = 3.0):
        self.z_threshold = z_threshold

    def check(self, current: int, history: list[int]) -> dict:
        if len(history) < 7:
            return {"is_anomaly": False, "reason": "insufficient_history"}
        mean, std = np.mean(history), np.std(history)
        if std == 0:
            return {"is_anomaly": current != mean}
        z = (current - mean) / std
        return {"is_anomaly": abs(z) > self.z_threshold, "z_score": round(z, 3),
                "expected_range": (round(mean - self.z_threshold * std), round(mean + self.z_threshold * std))}
```

See [anomaly-detection.md](references/anomaly-detection.md) for:
- Distribution shift detection with KL divergence
- Seasonal adjustment for time-series metrics
- Multi-metric correlation analysis
- Alert fatigue reduction strategies

## Data Observability

Track freshness, volume, schema changes, and lineage across your entire data platform.

```python
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum

class Status(Enum):
    HEALTHY = "healthy"
    WARNING = "warning"
    CRITICAL = "critical"

@dataclass
class TableHealthCheck:
    table_name: str
    freshness_threshold: timedelta
    expected_schema: dict[str, str]

    def check_freshness(self, last_updated: datetime) -> Status:
        age = datetime.utcnow() - last_updated
        if age > self.freshness_threshold * 2:
            return Status.CRITICAL
        return Status.WARNING if age > self.freshness_threshold else Status.HEALTHY

    def check_schema(self, actual: dict[str, str]) -> tuple[Status, list[str]]:
        diffs = [f"Missing: {c}" for c in self.expected_schema if c not in actual]
        diffs += [f"{c}: expected {t}, got {actual[c]}"
                  for c, t in self.expected_schema.items()
                  if c in actual and actual[c] != t]
        status = Status.CRITICAL if any("Missing" in d for d in diffs) \
            else Status.WARNING if diffs else Status.HEALTHY
        return status, diffs
```

See [observability-patterns.md](references/observability-patterns.md) for:
- Lineage graph construction and querying
- Automated freshness SLA enforcement
- Incident response runbooks
- Integration with Monte Carlo, Elementary, and OpenLineage

## Quality Metrics and SLAs

Define measurable quality dimensions and enforce them through SLAs with automated scoring.

```python
@dataclass
class QualityDimension:
    name: str                       # "completeness", "accuracy", "timeliness"
    weight: float                   # weights must sum to 1.0
    threshold_warn: float
    threshold_fail: float
    current_score: float = 0.0

def composite_score(dims: list[QualityDimension]) -> dict:
    score = sum(d.current_score * d.weight for d in dims)
    fails = [d.name for d in dims if d.current_score < d.threshold_fail]
    warns = [d.name for d in dims if d.threshold_fail <= d.current_score < d.threshold_warn]
    return {"score": round(score, 4), "status": "fail" if fails else "warn" if warns else "pass"}
```

See [quality-metrics.md](references/quality-metrics.md) for:
- Six dimensions of data quality measurement
- SLA definition and enforcement patterns
- Quality dashboards and trend reporting
- Cost-of-poor-quality estimation

## Anti-Patterns

| Avoid | Use Instead |
|-------|-------------|
| Validating only at pipeline end | Quality gates at each stage (ingestion, transform, load) |
| Hardcoded thresholds without history | Adaptive thresholds from rolling statistics |
| Silent failures writing bad data downstream | Fail-fast with circuit breakers and dead-letter queues |
| Schema-on-read with no contracts | Explicit schema contracts between producers and consumers |
| Single global quality score | Per-dimension scores with independent thresholds |
| Manual checks after incidents | Automated continuous validation in pipelines |
| Alerting on every anomaly | Tiered alerting (info/warn/critical) with escalation policies |
| Testing quality only in production | Contract tests in CI/CD before deployment |

## Performance

- **Sample large datasets** -- Use `TABLESAMPLE` or partition-level checks on multi-billion row tables.
- **Parallelize checks** -- Run column-level expectations concurrently; Soda checks are independent by default.
- **Partition-aware validation** -- Only validate changed partitions, not the entire table.
- **Cache historical metrics** -- Store rolling statistics in a metrics table rather than recomputing each run.
- **Approximate aggregations** -- HyperLogLog for cardinality, t-digest for percentiles on terabyte tables.
- **Schedule strategically** -- Freshness/volume every 15 min; distribution checks daily off-peak.

source: Great Expectations docs, Soda Core docs, Data Quality Fundamentals (O'Reilly), Monte Carlo documentation
