# Quality Metrics and SLA Frameworks

## Six Dimensions of Data Quality

Measure data quality across standardized dimensions with quantifiable scores.

```python
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from typing import Optional, Callable
import pandas as pd
import numpy as np

class QualityDimension(Enum):
    COMPLETENESS = "completeness"    # Are all expected values present?
    ACCURACY = "accuracy"            # Do values reflect reality?
    CONSISTENCY = "consistency"      # Are values consistent across systems?
    TIMELINESS = "timeliness"        # Is data available when expected?
    UNIQUENESS = "uniqueness"        # Are there unwanted duplicates?
    VALIDITY = "validity"            # Do values conform to rules?


@dataclass
class DimensionScore:
    dimension: QualityDimension
    score: float                     # 0.0 to 1.0
    threshold_warn: float
    threshold_fail: float
    details: dict = field(default_factory=dict)

    @property
    def status(self) -> str:
        if self.score < self.threshold_fail:
            return "fail"
        elif self.score < self.threshold_warn:
            return "warn"
        return "pass"
```

## Completeness Measurement

```python
class CompletenessScorer:
    """Measure how complete a dataset is across its columns."""

    def score_column(self, series: pd.Series) -> float:
        """Fraction of non-null values in a column."""
        if len(series) == 0:
            return 0.0
        return 1.0 - (series.isna().sum() / len(series))

    def score_table(
        self,
        df: pd.DataFrame,
        required_columns: list[str],
        column_weights: dict[str, float] | None = None,
    ) -> DimensionScore:
        """Weighted completeness score across required columns."""
        if column_weights is None:
            column_weights = {col: 1.0 for col in required_columns}

        total_weight = sum(column_weights.get(c, 1.0) for c in required_columns)
        weighted_score = 0.0
        col_details = {}

        for col in required_columns:
            if col not in df.columns:
                col_score = 0.0
            else:
                col_score = self.score_column(df[col])
            weight = column_weights.get(col, 1.0)
            weighted_score += col_score * weight
            col_details[col] = round(col_score, 4)

        overall = weighted_score / total_weight if total_weight > 0 else 0.0

        return DimensionScore(
            dimension=QualityDimension.COMPLETENESS,
            score=round(overall, 4),
            threshold_warn=0.98,
            threshold_fail=0.95,
            details={"column_scores": col_details, "row_count": len(df)},
        )

    def score_row_completeness(
        self, df: pd.DataFrame, required_columns: list[str]
    ) -> float:
        """Fraction of rows where ALL required columns are non-null."""
        if len(df) == 0:
            return 0.0
        present_cols = [c for c in required_columns if c in df.columns]
        complete_rows = df[present_cols].dropna().shape[0]
        return complete_rows / len(df)
```

## Accuracy Measurement

```python
class AccuracyScorer:
    """Measure data accuracy using validation rules and reference data."""

    def score_against_rules(
        self,
        df: pd.DataFrame,
        rules: dict[str, Callable[[pd.Series], pd.Series]],
    ) -> DimensionScore:
        """Score accuracy based on column-level validation rules.

        Each rule is a function that returns a boolean Series
        (True = valid, False = invalid).
        """
        total_checks = 0
        total_valid = 0
        rule_details = {}

        for rule_name, rule_fn in rules.items():
            try:
                valid_mask = rule_fn(df)
                valid_count = valid_mask.sum()
                total_count = len(valid_mask)
                rule_details[rule_name] = {
                    "valid": int(valid_count),
                    "total": total_count,
                    "score": round(valid_count / total_count, 4) if total_count > 0 else 0.0,
                }
                total_checks += total_count
                total_valid += valid_count
            except Exception as e:
                rule_details[rule_name] = {"error": str(e), "score": 0.0}

        overall = total_valid / total_checks if total_checks > 0 else 0.0

        return DimensionScore(
            dimension=QualityDimension.ACCURACY,
            score=round(overall, 4),
            threshold_warn=0.99,
            threshold_fail=0.97,
            details={"rules": rule_details},
        )

    def score_against_reference(
        self,
        df: pd.DataFrame,
        reference_df: pd.DataFrame,
        join_key: str,
        compare_columns: list[str],
    ) -> DimensionScore:
        """Score accuracy by comparing to a trusted reference dataset."""
        merged = df.merge(
            reference_df, on=join_key, suffixes=("_actual", "_reference"),
            how="inner",
        )

        match_details = {}
        total_matches = 0
        total_compared = 0

        for col in compare_columns:
            actual_col = f"{col}_actual"
            ref_col = f"{col}_reference"
            if actual_col in merged.columns and ref_col in merged.columns:
                matches = (merged[actual_col] == merged[ref_col]).sum()
                count = len(merged)
                match_details[col] = round(matches / count, 4) if count > 0 else 0.0
                total_matches += matches
                total_compared += count

        overall = total_matches / total_compared if total_compared > 0 else 0.0

        return DimensionScore(
            dimension=QualityDimension.ACCURACY,
            score=round(overall, 4),
            threshold_warn=0.99,
            threshold_fail=0.95,
            details={
                "column_accuracy": match_details,
                "records_compared": len(merged),
            },
        )
```

## Timeliness Measurement

```python
class TimelinessScorer:
    """Measure how timely data arrives and updates."""

    def score_freshness(
        self,
        last_updated: datetime,
        expected_frequency: timedelta,
        now: datetime | None = None,
    ) -> DimensionScore:
        """Score based on data freshness relative to expected update frequency."""
        now = now or datetime.utcnow()
        age = now - last_updated
        age_ratio = age / expected_frequency

        # Score: 1.0 if within expected frequency, degrades linearly
        score = max(0.0, 1.0 - max(0.0, age_ratio - 1.0))

        return DimensionScore(
            dimension=QualityDimension.TIMELINESS,
            score=round(score, 4),
            threshold_warn=0.80,
            threshold_fail=0.50,
            details={
                "age_seconds": age.total_seconds(),
                "expected_frequency_seconds": expected_frequency.total_seconds(),
                "age_ratio": round(age_ratio, 2),
                "last_updated": last_updated.isoformat(),
            },
        )

    def score_event_latency(
        self,
        df: pd.DataFrame,
        event_time_col: str,
        ingestion_time_col: str,
        max_acceptable_latency: timedelta,
    ) -> DimensionScore:
        """Score based on ingestion latency distribution."""
        latencies = (df[ingestion_time_col] - df[event_time_col]).dt.total_seconds()

        within_sla = (latencies <= max_acceptable_latency.total_seconds()).sum()
        score = within_sla / len(latencies) if len(latencies) > 0 else 0.0

        return DimensionScore(
            dimension=QualityDimension.TIMELINESS,
            score=round(score, 4),
            threshold_warn=0.95,
            threshold_fail=0.90,
            details={
                "median_latency_seconds": round(latencies.median(), 2),
                "p95_latency_seconds": round(latencies.quantile(0.95), 2),
                "p99_latency_seconds": round(latencies.quantile(0.99), 2),
                "max_latency_seconds": round(latencies.max(), 2),
                "within_sla_percent": round(score * 100, 2),
            },
        )
```

## Uniqueness and Consistency Scoring

```python
class UniquenessScorer:
    """Measure uniqueness/deduplication quality."""

    def score(
        self,
        df: pd.DataFrame,
        key_columns: list[str],
    ) -> DimensionScore:
        """Score based on duplicate rate of key columns."""
        if len(df) == 0:
            return DimensionScore(
                dimension=QualityDimension.UNIQUENESS,
                score=1.0, threshold_warn=0.9999, threshold_fail=0.999,
                details={"total_rows": 0, "duplicate_rows": 0},
            )

        duplicated = df.duplicated(subset=key_columns, keep="first").sum()
        score = 1.0 - (duplicated / len(df))

        return DimensionScore(
            dimension=QualityDimension.UNIQUENESS,
            score=round(score, 6),
            threshold_warn=0.9999,
            threshold_fail=0.999,
            details={
                "total_rows": len(df),
                "duplicate_rows": int(duplicated),
                "duplicate_percent": round(duplicated / len(df) * 100, 4),
            },
        )


class ConsistencyScorer:
    """Measure cross-system and cross-table consistency."""

    def score_cross_system(
        self,
        source_count: int,
        target_count: int,
    ) -> DimensionScore:
        """Compare record counts between source and target."""
        if source_count == 0:
            score = 1.0 if target_count == 0 else 0.0
        else:
            score = 1.0 - abs(source_count - target_count) / source_count

        return DimensionScore(
            dimension=QualityDimension.CONSISTENCY,
            score=round(max(0.0, score), 4),
            threshold_warn=0.999,
            threshold_fail=0.99,
            details={
                "source_count": source_count,
                "target_count": target_count,
                "difference": abs(source_count - target_count),
            },
        )

    def score_referential_integrity(
        self,
        child_df: pd.DataFrame,
        parent_df: pd.DataFrame,
        child_fk: str,
        parent_pk: str,
    ) -> DimensionScore:
        """Score referential integrity between two tables."""
        child_keys = set(child_df[child_fk].dropna().unique())
        parent_keys = set(parent_df[parent_pk].dropna().unique())
        orphans = child_keys - parent_keys
        score = 1.0 - (len(orphans) / len(child_keys)) if child_keys else 1.0

        return DimensionScore(
            dimension=QualityDimension.CONSISTENCY,
            score=round(score, 4),
            threshold_warn=0.999,
            threshold_fail=0.99,
            details={
                "child_key_count": len(child_keys),
                "orphan_count": len(orphans),
                "sample_orphans": list(orphans)[:10],
            },
        )
```

## Composite Quality Score

```python
@dataclass
class QualitySLA:
    """Define and enforce quality SLAs for a dataset."""

    dataset_name: str
    dimensions: dict[QualityDimension, tuple[float, float, float]]
    # dimension -> (weight, warn_threshold, fail_threshold)

    def evaluate(self, scores: list[DimensionScore]) -> dict:
        """Evaluate all dimension scores against SLA."""
        score_map = {s.dimension: s for s in scores}

        weighted_sum = 0.0
        total_weight = 0.0
        failures = []
        warnings = []
        dimension_results = {}

        for dim, (weight, warn_thresh, fail_thresh) in self.dimensions.items():
            if dim in score_map:
                score = score_map[dim]
                actual = score.score
            else:
                actual = 0.0

            weighted_sum += actual * weight
            total_weight += weight

            status = "pass"
            if actual < fail_thresh:
                status = "fail"
                failures.append(dim.value)
            elif actual < warn_thresh:
                status = "warn"
                warnings.append(dim.value)

            dimension_results[dim.value] = {
                "score": round(actual, 4),
                "weight": weight,
                "warn_threshold": warn_thresh,
                "fail_threshold": fail_thresh,
                "status": status,
            }

        composite = weighted_sum / total_weight if total_weight > 0 else 0.0

        return {
            "dataset": self.dataset_name,
            "composite_score": round(composite, 4),
            "overall_status": "fail" if failures else "warn" if warnings else "pass",
            "failures": failures,
            "warnings": warnings,
            "dimensions": dimension_results,
            "evaluated_at": datetime.utcnow().isoformat(),
        }


# Example: SLA definition for customer data
customer_sla = QualitySLA(
    dataset_name="customers",
    dimensions={
        QualityDimension.COMPLETENESS: (0.25, 0.98, 0.95),
        QualityDimension.ACCURACY: (0.25, 0.99, 0.97),
        QualityDimension.TIMELINESS: (0.20, 0.90, 0.80),
        QualityDimension.UNIQUENESS: (0.15, 0.9999, 0.999),
        QualityDimension.CONSISTENCY: (0.10, 0.999, 0.99),
        QualityDimension.VALIDITY: (0.05, 0.98, 0.95),
    },
)
```

## Quality Dashboard Metrics

```python
class QualityDashboard:
    """Generate metrics for quality monitoring dashboards."""

    def __init__(self, metrics_store):
        self.store = metrics_store

    def get_trend(
        self, dataset: str, dimension: str, days: int = 30
    ) -> list[dict]:
        """Get quality score trend for a dimension over time."""
        records = self.store.query(
            dataset=dataset, dimension=dimension, days=days
        )
        return [
            {
                "date": r["evaluated_at"].strftime("%Y-%m-%d"),
                "score": r["score"],
                "status": r["status"],
            }
            for r in records
        ]

    def get_fleet_health(self) -> dict:
        """Get quality summary across all monitored datasets."""
        datasets = self.store.get_all_datasets()
        fleet = {"total": len(datasets), "healthy": 0, "degraded": 0, "failing": 0}
        details = []

        for ds in datasets:
            latest = self.store.get_latest_evaluation(ds)
            if latest["overall_status"] == "pass":
                fleet["healthy"] += 1
            elif latest["overall_status"] == "warn":
                fleet["degraded"] += 1
            else:
                fleet["failing"] += 1
            details.append({
                "dataset": ds,
                "composite_score": latest["composite_score"],
                "status": latest["overall_status"],
                "failing_dimensions": latest.get("failures", []),
            })

        fleet["details"] = sorted(details, key=lambda d: d["composite_score"])
        return fleet

    def estimate_cost_of_poor_quality(
        self,
        dataset: str,
        records_affected: int,
        cost_per_incident: float,
        incidents_per_failure: float = 0.1,
    ) -> dict:
        """Estimate the business cost of data quality failures."""
        latest = self.store.get_latest_evaluation(dataset)
        failure_rate = 1.0 - latest["composite_score"]
        expected_failures = records_affected * failure_rate
        expected_incidents = expected_failures * incidents_per_failure
        estimated_cost = expected_incidents * cost_per_incident

        return {
            "dataset": dataset,
            "composite_score": latest["composite_score"],
            "failure_rate": round(failure_rate, 4),
            "records_at_risk": int(expected_failures),
            "estimated_incidents": round(expected_incidents, 1),
            "estimated_cost": round(estimated_cost, 2),
        }
```

## SLA Enforcement in Pipelines

```python
from prefect import task, flow

@task
def evaluate_quality_sla(
    df: pd.DataFrame,
    sla: QualitySLA,
    metrics_store,
) -> dict:
    """Evaluate all quality dimensions and store results."""
    scores = []

    # Completeness
    completeness = CompletenessScorer().score_table(
        df, required_columns=list(df.columns)
    )
    scores.append(completeness)

    # Uniqueness (assuming first column is the key)
    pk_col = list(sla.dimensions.keys())[0]  # configured per dataset
    uniqueness = UniquenessScorer().score(df, key_columns=[df.columns[0]])
    scores.append(uniqueness)

    # Evaluate against SLA
    result = sla.evaluate(scores)

    # Store for historical tracking
    metrics_store.record_evaluation(sla.dataset_name, result)

    return result


@flow(name="Quality-Gated Pipeline")
def quality_gated_pipeline(
    source_path: str,
    target_table: str,
    sla: QualitySLA,
):
    """Pipeline that enforces quality SLAs before loading data."""
    df = pd.read_parquet(source_path)

    result = evaluate_quality_sla(df, sla, metrics_store)

    if result["overall_status"] == "fail":
        send_alert(
            severity="critical",
            message=(
                f"Quality SLA FAILED for {sla.dataset_name}. "
                f"Score: {result['composite_score']:.2%}. "
                f"Failing: {result['failures']}"
            ),
        )
        quarantine_data(df, reason="sla_failure", details=result)
        raise RuntimeError(f"Quality SLA failed: {result['failures']}")

    if result["overall_status"] == "warn":
        send_alert(
            severity="warning",
            message=(
                f"Quality SLA WARNING for {sla.dataset_name}. "
                f"Score: {result['composite_score']:.2%}. "
                f"Degraded: {result['warnings']}"
            ),
        )

    # SLA passed or warned -- proceed with load
    load_to_warehouse(df, target_table)
    return result
```
