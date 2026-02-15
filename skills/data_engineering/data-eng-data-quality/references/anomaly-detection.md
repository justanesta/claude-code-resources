# Anomaly Detection for Data Quality

## Z-Score Based Volume Monitoring

The simplest and most common approach for detecting row count and metric anomalies.

```python
import numpy as np
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional

@dataclass
class AnomalyResult:
    metric_name: str
    current_value: float
    expected_mean: float
    expected_std: float
    z_score: float
    is_anomaly: bool
    severity: str       # "info", "warning", "critical"
    message: str

class ZScoreDetector:
    """Detect anomalies using z-score with configurable thresholds."""

    def __init__(
        self,
        warn_threshold: float = 2.5,
        critical_threshold: float = 3.5,
        min_history: int = 14,
    ):
        self.warn_threshold = warn_threshold
        self.critical_threshold = critical_threshold
        self.min_history = min_history

    def evaluate(
        self, metric_name: str, current: float, history: list[float]
    ) -> AnomalyResult:
        if len(history) < self.min_history:
            return AnomalyResult(
                metric_name=metric_name,
                current_value=current,
                expected_mean=0,
                expected_std=0,
                z_score=0,
                is_anomaly=False,
                severity="info",
                message=f"Insufficient history ({len(history)}/{self.min_history})",
            )

        mean = np.mean(history)
        std = np.std(history, ddof=1)

        if std < 1e-10:
            is_anomaly = abs(current - mean) > 1e-10
            z_score = float("inf") if is_anomaly else 0.0
        else:
            z_score = (current - mean) / std
            is_anomaly = abs(z_score) > self.warn_threshold

        if abs(z_score) > self.critical_threshold:
            severity = "critical"
        elif abs(z_score) > self.warn_threshold:
            severity = "warning"
        else:
            severity = "info"

        direction = "above" if z_score > 0 else "below"
        return AnomalyResult(
            metric_name=metric_name,
            current_value=current,
            expected_mean=round(mean, 2),
            expected_std=round(std, 2),
            z_score=round(z_score, 3),
            is_anomaly=is_anomaly,
            severity=severity,
            message=(
                f"{metric_name}: {current} is {abs(z_score):.1f} std devs "
                f"{direction} mean ({mean:.1f} +/- {std:.1f})"
            ),
        )
```

## Modified Z-Score with Median Absolute Deviation

More robust against outliers in the historical data than standard z-score.

```python
class MADDetector:
    """Use Median Absolute Deviation for outlier-robust anomaly detection."""

    def __init__(self, threshold: float = 3.5, min_history: int = 14):
        self.threshold = threshold
        self.min_history = min_history
        # 0.6745 is the 0.75th quantile of the standard normal distribution
        self.consistency_constant = 0.6745

    def evaluate(
        self, metric_name: str, current: float, history: list[float]
    ) -> AnomalyResult:
        if len(history) < self.min_history:
            return AnomalyResult(
                metric_name=metric_name,
                current_value=current,
                expected_mean=0, expected_std=0, z_score=0,
                is_anomaly=False, severity="info",
                message="Insufficient history",
            )

        median = np.median(history)
        mad = np.median(np.abs(np.array(history) - median))

        if mad < 1e-10:
            modified_z = 0.0 if abs(current - median) < 1e-10 else float("inf")
        else:
            modified_z = self.consistency_constant * (current - median) / mad

        is_anomaly = abs(modified_z) > self.threshold
        severity = "critical" if abs(modified_z) > self.threshold * 1.5 \
            else "warning" if is_anomaly else "info"

        return AnomalyResult(
            metric_name=metric_name,
            current_value=current,
            expected_mean=round(median, 2),
            expected_std=round(mad, 2),
            z_score=round(modified_z, 3),
            is_anomaly=is_anomaly,
            severity=severity,
            message=f"{metric_name}: modified z-score = {modified_z:.2f}",
        )
```

## Distribution Shift Detection

Detect when the distribution of column values changes significantly between batches.

```python
from scipy import stats

class DistributionShiftDetector:
    """Detect distribution shifts using statistical tests."""

    def __init__(self, significance_level: float = 0.01):
        self.significance_level = significance_level

    def ks_test(
        self, baseline: np.ndarray, current: np.ndarray
    ) -> dict:
        """Kolmogorov-Smirnov test for continuous distributions."""
        statistic, p_value = stats.ks_2samp(baseline, current)
        return {
            "test": "kolmogorov_smirnov",
            "statistic": round(statistic, 4),
            "p_value": round(p_value, 6),
            "is_shifted": p_value < self.significance_level,
            "interpretation": (
                f"Distribution shift detected (p={p_value:.4f})"
                if p_value < self.significance_level
                else f"No significant shift (p={p_value:.4f})"
            ),
        }

    def chi_squared_test(
        self, baseline_counts: dict, current_counts: dict
    ) -> dict:
        """Chi-squared test for categorical distributions."""
        all_categories = sorted(set(baseline_counts) | set(current_counts))
        baseline_freq = [baseline_counts.get(c, 0) for c in all_categories]
        current_freq = [current_counts.get(c, 0) for c in all_categories]

        # Normalize to same total
        total_baseline = sum(baseline_freq)
        total_current = sum(current_freq)
        if total_baseline == 0 or total_current == 0:
            return {"test": "chi_squared", "error": "empty distribution"}

        expected = [b * total_current / total_baseline for b in baseline_freq]
        # Filter out zero-expected categories to avoid division by zero
        valid_pairs = [
            (o, e) for o, e in zip(current_freq, expected) if e > 0
        ]
        if not valid_pairs:
            return {"test": "chi_squared", "error": "no valid categories"}

        observed, expected_filtered = zip(*valid_pairs)
        statistic, p_value = stats.chisquare(observed, expected_filtered)

        return {
            "test": "chi_squared",
            "statistic": round(statistic, 4),
            "p_value": round(p_value, 6),
            "is_shifted": p_value < self.significance_level,
        }

    def kl_divergence(
        self, baseline: np.ndarray, current: np.ndarray, bins: int = 50
    ) -> dict:
        """KL divergence for measuring distribution distance."""
        # Create shared bins
        all_values = np.concatenate([baseline, current])
        bin_edges = np.histogram_bin_edges(all_values, bins=bins)

        baseline_hist, _ = np.histogram(baseline, bins=bin_edges, density=True)
        current_hist, _ = np.histogram(current, bins=bin_edges, density=True)

        # Add smoothing to avoid log(0)
        epsilon = 1e-10
        baseline_hist = baseline_hist + epsilon
        current_hist = current_hist + epsilon

        # Normalize
        baseline_hist = baseline_hist / baseline_hist.sum()
        current_hist = current_hist / current_hist.sum()

        kl_div = stats.entropy(current_hist, baseline_hist)

        return {
            "test": "kl_divergence",
            "divergence": round(kl_div, 6),
            "is_shifted": kl_div > 0.1,  # Configurable threshold
            "interpretation": (
                f"KL divergence = {kl_div:.4f}. "
                f"{'Significant shift' if kl_div > 0.1 else 'Within normal range'}"
            ),
        }
```

## Seasonal Adjustment

Account for day-of-week and time-of-day patterns when detecting anomalies.

```python
from collections import defaultdict

class SeasonalAnomalyDetector:
    """Detect anomalies with seasonal adjustment for periodic patterns."""

    def __init__(self, z_threshold: float = 3.0, min_periods: int = 4):
        self.z_threshold = z_threshold
        self.min_periods = min_periods

    def build_seasonal_baseline(
        self,
        timestamps: list[datetime],
        values: list[float],
        granularity: str = "day_of_week",
    ) -> dict[int, list[float]]:
        """Group historical values by seasonal period."""
        buckets = defaultdict(list)
        for ts, val in zip(timestamps, values):
            if granularity == "day_of_week":
                key = ts.weekday()  # 0=Monday, 6=Sunday
            elif granularity == "hour_of_day":
                key = ts.hour
            elif granularity == "day_of_month":
                key = ts.day
            else:
                raise ValueError(f"Unknown granularity: {granularity}")
            buckets[key].append(val)
        return dict(buckets)

    def evaluate_with_season(
        self,
        metric_name: str,
        current_value: float,
        current_timestamp: datetime,
        timestamps: list[datetime],
        values: list[float],
        granularity: str = "day_of_week",
    ) -> AnomalyResult:
        """Evaluate anomaly against same-period historical data."""
        baseline = self.build_seasonal_baseline(timestamps, values, granularity)

        if granularity == "day_of_week":
            period_key = current_timestamp.weekday()
            period_name = current_timestamp.strftime("%A")
        elif granularity == "hour_of_day":
            period_key = current_timestamp.hour
            period_name = f"hour {current_timestamp.hour}"
        else:
            period_key = current_timestamp.day
            period_name = f"day {current_timestamp.day}"

        period_history = baseline.get(period_key, [])

        if len(period_history) < self.min_periods:
            return AnomalyResult(
                metric_name=metric_name,
                current_value=current_value,
                expected_mean=0, expected_std=0, z_score=0,
                is_anomaly=False, severity="info",
                message=(
                    f"Insufficient history for {period_name} "
                    f"({len(period_history)}/{self.min_periods})"
                ),
            )

        mean = np.mean(period_history)
        std = np.std(period_history, ddof=1)

        if std < 1e-10:
            z_score = 0.0 if abs(current_value - mean) < 1e-10 else float("inf")
        else:
            z_score = (current_value - mean) / std

        is_anomaly = abs(z_score) > self.z_threshold
        severity = "critical" if abs(z_score) > self.z_threshold * 1.5 \
            else "warning" if is_anomaly else "info"

        return AnomalyResult(
            metric_name=metric_name,
            current_value=current_value,
            expected_mean=round(mean, 2),
            expected_std=round(std, 2),
            z_score=round(z_score, 3),
            is_anomaly=is_anomaly,
            severity=severity,
            message=(
                f"{metric_name} for {period_name}: {current_value} "
                f"(expected {mean:.1f} +/- {std:.1f}, z={z_score:.2f})"
            ),
        )
```

## Multi-Metric Correlation Analysis

Detect anomalies that only appear when examining relationships between metrics.

```python
class CorrelatedAnomalyDetector:
    """Detect anomalies in metric relationships."""

    def check_ratio_stability(
        self,
        metric_a: list[float],
        metric_b: list[float],
        current_a: float,
        current_b: float,
        z_threshold: float = 3.0,
    ) -> dict:
        """Check if the ratio between two metrics has changed."""
        # Historical ratios (avoid division by zero)
        ratios = [
            a / b for a, b in zip(metric_a, metric_b)
            if b != 0
        ]
        if len(ratios) < 7:
            return {"status": "insufficient_history", "is_anomaly": False}

        if current_b == 0:
            return {"status": "division_by_zero", "is_anomaly": True,
                    "message": "Denominator metric is zero"}

        current_ratio = current_a / current_b
        mean_ratio = np.mean(ratios)
        std_ratio = np.std(ratios, ddof=1)

        if std_ratio < 1e-10:
            z_score = 0.0
        else:
            z_score = (current_ratio - mean_ratio) / std_ratio

        return {
            "status": "evaluated",
            "current_ratio": round(current_ratio, 4),
            "expected_ratio": round(mean_ratio, 4),
            "z_score": round(z_score, 3),
            "is_anomaly": abs(z_score) > z_threshold,
            "message": (
                f"Ratio {current_ratio:.3f} vs expected {mean_ratio:.3f} "
                f"(z={z_score:.2f})"
            ),
        }

    def check_correlation_break(
        self,
        metric_a_history: list[float],
        metric_b_history: list[float],
        current_a: float,
        current_b: float,
        min_correlation: float = 0.7,
    ) -> dict:
        """Detect when historically correlated metrics diverge."""
        if len(metric_a_history) < 14:
            return {"status": "insufficient_history"}

        correlation = np.corrcoef(metric_a_history, metric_b_history)[0, 1]

        if abs(correlation) < min_correlation:
            return {
                "status": "low_baseline_correlation",
                "correlation": round(correlation, 3),
            }

        # Predict current_b from current_a using linear regression
        slope, intercept, _, _, _ = stats.linregress(
            metric_a_history, metric_b_history
        )
        predicted_b = slope * current_a + intercept
        residuals = [
            b - (slope * a + intercept)
            for a, b in zip(metric_a_history, metric_b_history)
        ]
        residual_std = np.std(residuals, ddof=2)
        actual_residual = current_b - predicted_b

        if residual_std < 1e-10:
            z_score = 0.0
        else:
            z_score = actual_residual / residual_std

        return {
            "status": "evaluated",
            "baseline_correlation": round(correlation, 3),
            "predicted_b": round(predicted_b, 2),
            "actual_b": current_b,
            "residual_z_score": round(z_score, 3),
            "is_anomaly": abs(z_score) > 3.0,
        }
```

## Alert Fatigue Reduction

Strategies to avoid overwhelming teams with low-signal anomaly alerts.

```python
from collections import deque

class AlertManager:
    """Manage anomaly alerts with deduplication and suppression."""

    def __init__(
        self,
        cooldown_minutes: int = 60,
        max_alerts_per_hour: int = 10,
        auto_resolve_after: int = 3,
    ):
        self.cooldown_minutes = cooldown_minutes
        self.max_alerts_per_hour = max_alerts_per_hour
        self.auto_resolve_after = auto_resolve_after
        self.active_alerts: dict[str, dict] = {}
        self.alert_history: deque = deque(maxlen=1000)
        self.consecutive_ok: dict[str, int] = {}

    def should_alert(self, result: AnomalyResult) -> bool:
        """Determine if an anomaly should trigger an alert."""
        key = result.metric_name

        # Auto-resolve: if metric returned to normal N times, clear state
        if not result.is_anomaly:
            self.consecutive_ok[key] = self.consecutive_ok.get(key, 0) + 1
            if key in self.active_alerts:
                if self.consecutive_ok[key] >= self.auto_resolve_after:
                    del self.active_alerts[key]
                    self.consecutive_ok[key] = 0
            return False

        self.consecutive_ok[key] = 0

        # Cooldown: do not re-alert for the same metric within cooldown window
        if key in self.active_alerts:
            last_alert = self.active_alerts[key]["timestamp"]
            if (datetime.utcnow() - last_alert).total_seconds() < self.cooldown_minutes * 60:
                # Update severity if it escalated
                if result.severity == "critical" and \
                   self.active_alerts[key]["severity"] != "critical":
                    self.active_alerts[key]["severity"] = "critical"
                    return True  # Escalation overrides cooldown
                return False

        # Rate limit: cap total alerts per hour
        recent = [
            a for a in self.alert_history
            if (datetime.utcnow() - a["timestamp"]).total_seconds() < 3600
        ]
        if len(recent) >= self.max_alerts_per_hour and result.severity != "critical":
            return False  # Critical alerts always get through

        # Record and allow alert
        self.active_alerts[key] = {
            "timestamp": datetime.utcnow(),
            "severity": result.severity,
            "result": result,
        }
        self.alert_history.append({
            "timestamp": datetime.utcnow(),
            "metric": key,
            "severity": result.severity,
        })
        return True

    def get_summary(self) -> dict:
        """Get current alert state summary for dashboards."""
        return {
            "active_alerts": len(self.active_alerts),
            "critical": sum(
                1 for a in self.active_alerts.values()
                if a["severity"] == "critical"
            ),
            "warnings": sum(
                1 for a in self.active_alerts.values()
                if a["severity"] == "warning"
            ),
            "alerts_last_hour": sum(
                1 for a in self.alert_history
                if (datetime.utcnow() - a["timestamp"]).total_seconds() < 3600
            ),
        }
```

## Pipeline Integration

```python
from prefect import task, flow

@task
def run_anomaly_checks(
    table_name: str,
    metrics_store,  # Your metrics storage backend
    detector: ZScoreDetector,
    alert_manager: AlertManager,
) -> list[AnomalyResult]:
    """Run anomaly detection on all tracked metrics for a table."""
    results = []
    metrics = metrics_store.get_current_metrics(table_name)
    history = metrics_store.get_metric_history(table_name, days=30)

    for metric_name, current_value in metrics.items():
        historical_values = history.get(metric_name, [])
        result = detector.evaluate(metric_name, current_value, historical_values)
        results.append(result)

        if alert_manager.should_alert(result):
            send_alert(
                channel="#data-quality-alerts",
                severity=result.severity,
                message=result.message,
            )

    # Store current metrics for future baseline
    metrics_store.record_metrics(table_name, metrics)
    return results
```
