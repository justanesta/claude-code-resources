# Data Observability Patterns

## Observability Pillars

Data observability tracks five pillars: freshness, volume, schema, lineage, and distribution. This reference covers implementation patterns for each.

## Freshness Monitoring

Track when tables were last updated and alert when data becomes stale.

```python
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from typing import Optional
import logging

logger = logging.getLogger(__name__)

class HealthStatus(Enum):
    HEALTHY = "healthy"
    WARNING = "warning"
    CRITICAL = "critical"
    UNKNOWN = "unknown"

@dataclass
class FreshnessConfig:
    table_name: str
    timestamp_column: str
    expected_frequency: timedelta
    warn_after: timedelta
    critical_after: timedelta
    owner_team: str = ""
    slack_channel: str = ""

@dataclass
class FreshnessResult:
    table_name: str
    status: HealthStatus
    last_updated: Optional[datetime]
    age: Optional[timedelta]
    message: str

class FreshnessMonitor:
    """Monitor data freshness across warehouse tables."""

    def __init__(self, db_connection):
        self.db = db_connection

    def check_table(self, config: FreshnessConfig) -> FreshnessResult:
        """Check freshness of a single table."""
        query = f"""
            SELECT MAX({config.timestamp_column}) as last_updated
            FROM {config.table_name}
        """
        result = self.db.execute(query).fetchone()

        if result is None or result["last_updated"] is None:
            return FreshnessResult(
                table_name=config.table_name,
                status=HealthStatus.CRITICAL,
                last_updated=None,
                age=None,
                message=f"No data found in {config.table_name}",
            )

        last_updated = result["last_updated"]
        age = datetime.utcnow() - last_updated

        if age > config.critical_after:
            status = HealthStatus.CRITICAL
        elif age > config.warn_after:
            status = HealthStatus.WARNING
        else:
            status = HealthStatus.HEALTHY

        return FreshnessResult(
            table_name=config.table_name,
            status=status,
            last_updated=last_updated,
            age=age,
            message=(
                f"{config.table_name}: last updated {age.total_seconds() / 3600:.1f}h ago "
                f"(threshold: {config.warn_after.total_seconds() / 3600:.1f}h warn, "
                f"{config.critical_after.total_seconds() / 3600:.1f}h critical)"
            ),
        )

    def check_all(
        self, configs: list[FreshnessConfig]
    ) -> list[FreshnessResult]:
        """Check freshness for all monitored tables."""
        results = []
        for config in configs:
            try:
                result = self.check_table(config)
                results.append(result)
            except Exception as e:
                logger.error(f"Freshness check failed for {config.table_name}: {e}")
                results.append(FreshnessResult(
                    table_name=config.table_name,
                    status=HealthStatus.UNKNOWN,
                    last_updated=None,
                    age=None,
                    message=f"Check failed: {e}",
                ))
        return results


# Example configuration for a data warehouse
FRESHNESS_CONFIGS = [
    FreshnessConfig(
        table_name="raw.customer_events",
        timestamp_column="event_timestamp",
        expected_frequency=timedelta(minutes=15),
        warn_after=timedelta(minutes=30),
        critical_after=timedelta(hours=1),
        owner_team="data-platform",
        slack_channel="#data-alerts-critical",
    ),
    FreshnessConfig(
        table_name="staging.orders",
        timestamp_column="loaded_at",
        expected_frequency=timedelta(hours=1),
        warn_after=timedelta(hours=2),
        critical_after=timedelta(hours=4),
        owner_team="data-engineering",
        slack_channel="#data-alerts",
    ),
    FreshnessConfig(
        table_name="marts.daily_revenue",
        timestamp_column="report_date",
        expected_frequency=timedelta(hours=24),
        warn_after=timedelta(hours=26),
        critical_after=timedelta(hours=30),
        owner_team="analytics-engineering",
        slack_channel="#data-alerts",
    ),
]
```

## Volume Monitoring

Track row counts over time and detect unexpected changes.

```python
@dataclass
class VolumeConfig:
    table_name: str
    min_expected: int
    max_expected: int
    track_by_partition: bool = False
    partition_column: str = ""

class VolumeMonitor:
    """Monitor data volume changes across tables."""

    def __init__(self, db_connection, metrics_store):
        self.db = db_connection
        self.metrics = metrics_store

    def check_table_volume(self, config: VolumeConfig) -> dict:
        """Check current volume against expected bounds."""
        query = f"SELECT COUNT(*) as row_count FROM {config.table_name}"
        result = self.db.execute(query).fetchone()
        current_count = result["row_count"]

        # Store for historical tracking
        self.metrics.record(
            table=config.table_name,
            metric="row_count",
            value=current_count,
            timestamp=datetime.utcnow(),
        )

        # Check against static bounds
        if current_count < config.min_expected:
            status = HealthStatus.CRITICAL
            message = (
                f"{config.table_name}: {current_count:,} rows "
                f"below minimum {config.min_expected:,}"
            )
        elif current_count > config.max_expected:
            status = HealthStatus.WARNING
            message = (
                f"{config.table_name}: {current_count:,} rows "
                f"above maximum {config.max_expected:,}"
            )
        else:
            status = HealthStatus.HEALTHY
            message = f"{config.table_name}: {current_count:,} rows (within bounds)"

        return {
            "table": config.table_name,
            "status": status.value,
            "row_count": current_count,
            "message": message,
        }

    def check_partition_volume(self, config: VolumeConfig, date: str) -> dict:
        """Check volume for a specific partition."""
        query = f"""
            SELECT COUNT(*) as row_count
            FROM {config.table_name}
            WHERE {config.partition_column} = '{date}'
        """
        result = self.db.execute(query).fetchone()
        current_count = result["row_count"]

        # Get historical partition volumes for the same day-of-week
        history = self.metrics.get_partition_history(
            table=config.table_name,
            metric="partition_row_count",
            days=28,  # 4 weeks of same day-of-week data
        )

        # Simple anomaly check
        if history:
            import numpy as np
            mean = np.mean(history)
            std = np.std(history)
            z_score = (current_count - mean) / std if std > 0 else 0
            is_anomaly = abs(z_score) > 3.0
        else:
            z_score = 0
            is_anomaly = False

        return {
            "table": config.table_name,
            "partition": date,
            "row_count": current_count,
            "z_score": round(z_score, 2),
            "is_anomaly": is_anomaly,
        }
```

## Schema Change Detection

Detect and track schema changes automatically.

```python
@dataclass
class SchemaSnapshot:
    table_name: str
    columns: dict[str, str]   # column_name -> data_type
    captured_at: datetime

@dataclass
class SchemaDiff:
    table_name: str
    added_columns: dict[str, str]
    removed_columns: dict[str, str]
    type_changes: dict[str, tuple[str, str]]  # col -> (old_type, new_type)
    is_breaking: bool

class SchemaMonitor:
    """Detect schema drift across warehouse tables."""

    def __init__(self, db_connection, schema_store):
        self.db = db_connection
        self.store = schema_store

    def capture_snapshot(self, table_name: str) -> SchemaSnapshot:
        """Capture current schema of a table."""
        query = """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema || '.' || table_name = %s
            ORDER BY ordinal_position
        """
        rows = self.db.execute(query, (table_name,)).fetchall()
        columns = {row["column_name"]: row["data_type"] for row in rows}

        snapshot = SchemaSnapshot(
            table_name=table_name,
            columns=columns,
            captured_at=datetime.utcnow(),
        )
        self.store.save_snapshot(snapshot)
        return snapshot

    def detect_changes(self, table_name: str) -> Optional[SchemaDiff]:
        """Compare current schema against last known snapshot."""
        current = self.capture_snapshot(table_name)
        previous = self.store.get_latest_snapshot(table_name)

        if previous is None:
            return None  # First snapshot, nothing to compare

        added = {
            col: dtype for col, dtype in current.columns.items()
            if col not in previous.columns
        }
        removed = {
            col: dtype for col, dtype in previous.columns.items()
            if col not in current.columns
        }
        type_changes = {
            col: (previous.columns[col], current.columns[col])
            for col in set(current.columns) & set(previous.columns)
            if current.columns[col] != previous.columns[col]
        }

        # Removal or type narrowing is breaking
        is_breaking = bool(removed) or bool(type_changes)

        if not added and not removed and not type_changes:
            return None  # No changes

        return SchemaDiff(
            table_name=table_name,
            added_columns=added,
            removed_columns=removed,
            type_changes=type_changes,
            is_breaking=is_breaking,
        )
```

## Lineage Tracking

Track data flow from source to destination for impact analysis and root cause investigation.

```python
from dataclasses import dataclass, field

@dataclass
class LineageNode:
    name: str                   # e.g., "raw.customer_events"
    node_type: str              # "source", "transformation", "table", "report"
    owner: str = ""
    description: str = ""

@dataclass
class LineageEdge:
    source: str                 # node name
    target: str                 # node name
    transformation: str = ""    # e.g., "dbt model", "spark job"
    columns_mapped: dict[str, str] = field(default_factory=dict)

class LineageGraph:
    """In-memory lineage graph for impact analysis."""

    def __init__(self):
        self.nodes: dict[str, LineageNode] = {}
        self.edges: list[LineageEdge] = []

    def add_node(self, node: LineageNode):
        self.nodes[node.name] = node

    def add_edge(self, edge: LineageEdge):
        self.edges.append(edge)

    def get_upstream(self, node_name: str, depth: int = 10) -> list[str]:
        """Find all upstream dependencies of a node."""
        visited = set()
        queue = [node_name]
        upstream = []

        while queue and depth > 0:
            current = queue.pop(0)
            for edge in self.edges:
                if edge.target == current and edge.source not in visited:
                    visited.add(edge.source)
                    upstream.append(edge.source)
                    queue.append(edge.source)
            depth -= 1

        return upstream

    def get_downstream(self, node_name: str, depth: int = 10) -> list[str]:
        """Find all downstream consumers of a node."""
        visited = set()
        queue = [node_name]
        downstream = []

        while queue and depth > 0:
            current = queue.pop(0)
            for edge in self.edges:
                if edge.source == current and edge.target not in visited:
                    visited.add(edge.target)
                    downstream.append(edge.target)
                    queue.append(edge.target)
            depth -= 1

        return downstream

    def impact_analysis(self, failed_node: str) -> dict:
        """Analyze the blast radius of a failure at a given node."""
        downstream = self.get_downstream(failed_node)
        affected_reports = [
            n for n in downstream
            if self.nodes.get(n, LineageNode(n, "")).node_type == "report"
        ]
        affected_teams = set(
            self.nodes[n].owner for n in downstream
            if n in self.nodes and self.nodes[n].owner
        )
        return {
            "failed_node": failed_node,
            "downstream_affected": downstream,
            "affected_reports": affected_reports,
            "affected_teams": list(affected_teams),
            "blast_radius": len(downstream),
        }


# Build lineage graph from pipeline metadata
lineage = LineageGraph()

lineage.add_node(LineageNode("source.payment_api", "source", owner="payments-team"))
lineage.add_node(LineageNode("raw.transactions", "table", owner="data-platform"))
lineage.add_node(LineageNode("staging.transactions", "table", owner="data-engineering"))
lineage.add_node(LineageNode("marts.daily_revenue", "table", owner="analytics"))
lineage.add_node(LineageNode("reports.revenue_dashboard", "report", owner="finance"))

lineage.add_edge(LineageEdge("source.payment_api", "raw.transactions",
                              transformation="kafka_consumer"))
lineage.add_edge(LineageEdge("raw.transactions", "staging.transactions",
                              transformation="dbt_model:stg_transactions"))
lineage.add_edge(LineageEdge("staging.transactions", "marts.daily_revenue",
                              transformation="dbt_model:daily_revenue"))
lineage.add_edge(LineageEdge("marts.daily_revenue", "reports.revenue_dashboard",
                              transformation="looker_view"))

# If raw.transactions fails, what is affected?
impact = lineage.impact_analysis("raw.transactions")
# => downstream: staging.transactions, marts.daily_revenue, reports.revenue_dashboard
# => affected_teams: data-engineering, analytics, finance
```

## Alerting and Escalation

```python
from dataclasses import dataclass
from datetime import datetime

@dataclass
class AlertRule:
    name: str
    condition: str          # "freshness_critical", "volume_anomaly", "schema_breaking"
    severity: str           # "info", "warning", "critical"
    channels: list[str]     # ["#data-alerts", "oncall@company.com"]
    escalation_after: timedelta = timedelta(hours=1)
    escalation_channels: list[str] = field(default_factory=list)

class AlertRouter:
    """Route observability alerts to the right channels."""

    def __init__(self, notification_client):
        self.client = notification_client
        self.active_alerts: dict[str, dict] = {}

    def process_freshness_results(
        self, results: list[FreshnessResult], rules: list[AlertRule]
    ):
        """Process freshness check results and route alerts."""
        for result in results:
            if result.status == HealthStatus.HEALTHY:
                self._auto_resolve(result.table_name)
                continue

            alert_key = f"freshness:{result.table_name}"
            matching_rules = [
                r for r in rules
                if r.condition == f"freshness_{result.status.value}"
            ]

            for rule in matching_rules:
                if alert_key in self.active_alerts:
                    # Check for escalation
                    first_seen = self.active_alerts[alert_key]["first_seen"]
                    if (
                        datetime.utcnow() - first_seen > rule.escalation_after
                        and not self.active_alerts[alert_key].get("escalated")
                    ):
                        self._send_alert(
                            rule.escalation_channels,
                            f"ESCALATION: {result.message}",
                            "critical",
                        )
                        self.active_alerts[alert_key]["escalated"] = True
                else:
                    # New alert
                    self._send_alert(rule.channels, result.message, rule.severity)
                    self.active_alerts[alert_key] = {
                        "first_seen": datetime.utcnow(),
                        "severity": rule.severity,
                        "escalated": False,
                    }

    def _send_alert(self, channels: list[str], message: str, severity: str):
        for channel in channels:
            if channel.startswith("#"):
                self.client.send_slack(channel, message, severity)
            elif "@" in channel:
                self.client.send_email(channel, f"Data Alert: {severity}", message)
            else:
                self.client.send_pagerduty(channel, message, severity)

    def _auto_resolve(self, table_name: str):
        """Clear alerts when the issue resolves itself."""
        keys_to_remove = [
            k for k in self.active_alerts if table_name in k
        ]
        for key in keys_to_remove:
            del self.active_alerts[key]
```

## Incident Response Runbook Pattern

```python
@dataclass
class IncidentRunbook:
    """Structured incident response for data quality issues."""

    incident_type: str
    severity: str
    affected_table: str
    detected_at: datetime
    steps: list[str] = field(default_factory=list)

    def generate(self, lineage: LineageGraph) -> dict:
        """Generate a runbook based on incident type and lineage."""
        impact = lineage.impact_analysis(self.affected_table)

        if self.incident_type == "freshness_critical":
            self.steps = [
                f"1. Check upstream source: {lineage.get_upstream(self.affected_table, depth=1)}",
                "2. Verify the ingestion job is running: check Airflow/Prefect UI",
                "3. Check source system status page for outages",
                "4. If source is down: update status page, notify downstream teams",
                f"5. Downstream impact: {impact['downstream_affected']}",
                f"6. Notify affected teams: {impact['affected_teams']}",
                "7. If not resolved in 30 min: escalate to data platform on-call",
            ]
        elif self.incident_type == "schema_breaking":
            self.steps = [
                "1. Identify the schema change (check schema diff)",
                "2. Determine if change was planned (check change management)",
                f"3. Downstream impact: {impact['blast_radius']} tables affected",
                "4. If unplanned: revert source schema or add compatibility layer",
                "5. If planned: update downstream schemas and redeploy pipelines",
                "6. Run full validation suite after fix",
            ]
        elif self.incident_type == "volume_anomaly":
            self.steps = [
                "1. Check if volume drop corresponds to source system change",
                "2. Compare with same day-of-week last 4 weeks",
                "3. Check for upstream pipeline failures",
                "4. Verify no filter or partition changes in ingestion logic",
                "5. If legitimate: update volume thresholds",
                "6. If data loss: trigger backfill from source",
            ]

        return {
            "incident_type": self.incident_type,
            "severity": self.severity,
            "affected_table": self.affected_table,
            "detected_at": self.detected_at.isoformat(),
            "blast_radius": impact["blast_radius"],
            "affected_teams": impact["affected_teams"],
            "affected_reports": impact["affected_reports"],
            "runbook_steps": self.steps,
        }
```

## OpenLineage Integration

Integrate with OpenLineage for standardized, cross-platform lineage tracking.

```python
from openlineage.client import OpenLineageClient
from openlineage.client.run import Run, RunEvent, RunState, Job, Dataset
from openlineage.client.facet import (
    SchemaDatasetFacet,
    SchemaField,
    DataQualityMetricsInputDatasetFacet,
)
import uuid
from datetime import datetime

def emit_quality_lineage_event(
    job_name: str,
    input_table: str,
    output_table: str,
    quality_results: dict,
    openlineage_url: str = "http://marquez:5000",
):
    """Emit an OpenLineage event with data quality facets."""
    client = OpenLineageClient(url=openlineage_url)

    run_id = str(uuid.uuid4())
    job = Job(namespace="data-quality", name=job_name)
    run = Run(runId=run_id)

    # Build quality facet from results
    quality_facet = DataQualityMetricsInputDatasetFacet(
        rowCount=quality_results.get("row_count", 0),
        columnMetrics={
            col: {
                "nullCount": metrics.get("null_count", 0),
                "distinctCount": metrics.get("distinct_count", 0),
            }
            for col, metrics in quality_results.get("column_metrics", {}).items()
        },
    )

    input_dataset = Dataset(
        namespace="warehouse",
        name=input_table,
        facets={"dataQualityMetrics": quality_facet},
    )
    output_dataset = Dataset(namespace="warehouse", name=output_table)

    # Emit COMPLETE event with quality metadata
    event = RunEvent(
        eventType=RunState.COMPLETE,
        eventTime=datetime.utcnow().isoformat() + "Z",
        run=run,
        job=job,
        inputs=[input_dataset],
        outputs=[output_dataset],
    )

    client.emit(event)
    return {"run_id": run_id, "event_type": "COMPLETE"}
```

## Unified Observability Check Runner

```python
from prefect import task, flow

@flow(name="Data Observability Suite")
def run_observability_suite(
    freshness_configs: list[FreshnessConfig],
    volume_configs: list[VolumeConfig],
    schema_tables: list[str],
    lineage: LineageGraph,
    alert_rules: list[AlertRule],
):
    """Run all observability checks and route alerts."""
    db = get_db_connection()
    metrics_store = get_metrics_store()

    # Freshness checks
    freshness_monitor = FreshnessMonitor(db)
    freshness_results = freshness_monitor.check_all(freshness_configs)

    # Volume checks
    volume_monitor = VolumeMonitor(db, metrics_store)
    volume_results = [
        volume_monitor.check_table_volume(config) for config in volume_configs
    ]

    # Schema checks
    schema_monitor = SchemaMonitor(db, metrics_store)
    schema_diffs = [
        schema_monitor.detect_changes(table) for table in schema_tables
    ]
    schema_diffs = [d for d in schema_diffs if d is not None]

    # Route alerts
    alert_router = AlertRouter(get_notification_client())
    alert_router.process_freshness_results(freshness_results, alert_rules)

    # Generate incidents for breaking schema changes
    for diff in schema_diffs:
        if diff.is_breaking:
            runbook = IncidentRunbook(
                incident_type="schema_breaking",
                severity="critical",
                affected_table=diff.table_name,
                detected_at=datetime.utcnow(),
            )
            incident = runbook.generate(lineage)
            send_incident_report(incident)

    return {
        "freshness": [
            {"table": r.table_name, "status": r.status.value}
            for r in freshness_results
        ],
        "volume": volume_results,
        "schema_changes": [
            {"table": d.table_name, "breaking": d.is_breaking}
            for d in schema_diffs
        ],
    }
```
