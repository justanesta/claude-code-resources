# Soda Core Checks

## Basic Check Configuration

Soda Core uses SodaCL (Soda Checks Language), a YAML-based DSL for defining data quality checks.

```yaml
# configuration.yml -- connection setup
data_source warehouse:
  type: postgres
  connection:
    host: ${POSTGRES_HOST}
    port: 5432
    username: ${POSTGRES_USER}
    password: ${POSTGRES_PASSWORD}
    database: analytics
  schema: public
```

```yaml
# checks/orders_checks.yml
checks for orders:
  # Row count bounds
  - row_count between 1000 and 5000000

  # Null checks on critical columns
  - missing_count(order_id) = 0
  - missing_count(customer_id) = 0
  - missing_count(order_total) = 0

  # Uniqueness
  - duplicate_count(order_id) = 0

  # Value range
  - min(order_total) >= 0
  - max(order_total) < 1000000

  # Value set membership
  - invalid_count(status) = 0:
      valid values: ["pending", "confirmed", "shipped", "delivered", "cancelled"]

  # Percentage-based thresholds
  - missing_percent(shipping_address) < 5%
```

## Running Checks Programmatically

```python
from soda.core.scan import Scan

def run_soda_checks(
    check_files: list[str],
    data_source: str = "warehouse",
    scan_name: str = "scheduled_scan",
) -> dict:
    """Run Soda checks and return structured results."""
    scan = Scan()
    scan.set_data_source_name(data_source)
    scan.set_scan_definition_name(scan_name)

    scan.add_configuration_yaml_file("configuration.yml")
    for check_file in check_files:
        scan.add_sodacl_yaml_file(check_file)

    scan.execute()

    results = {
        "has_failures": scan.has_check_fails(),
        "has_warnings": scan.has_check_warns(),
        "checks_passed": [],
        "checks_warned": [],
        "checks_failed": [],
    }

    for check in scan.get_checks_pass():
        results["checks_passed"].append({
            "name": check.name,
            "table": check.table_name,
        })

    for check in scan.get_checks_warn():
        results["checks_warned"].append({
            "name": check.name,
            "table": check.table_name,
            "reasons": check.outcome_reasons,
        })

    for check in scan.get_checks_fail():
        results["checks_failed"].append({
            "name": check.name,
            "table": check.table_name,
            "reasons": check.outcome_reasons,
        })

    return results
```

## Freshness Checks

Ensure data is being updated within expected time windows.

```yaml
# checks/freshness_checks.yml
checks for transactions:
  # Fail if no data in last 2 hours
  - freshness(processed_at) < 2h

  # Warn at 1 hour, fail at 4 hours
  - freshness(processed_at):
      warn: when > 1h
      fail: when > 4h

checks for daily_aggregates:
  # Daily tables should update within 26 hours of partition date
  - freshness(load_timestamp) < 26h

checks for event_stream:
  # Real-time event table should never be more than 15 minutes stale
  - freshness(event_timestamp) < 15m
```

## Schema Checks

Detect schema drift before it causes pipeline failures.

```yaml
# checks/schema_checks.yml
checks for customers:
  - schema:
      name: Customer schema contract v3
      fail:
        when required column missing:
          [customer_id, email, created_at, status, country_code]
        when wrong type:
          customer_id: integer
          email: character varying
          created_at: timestamp with time zone
          status: character varying
        when forbidden column present:
          [ssn, raw_password]
      warn:
        when extra column present

checks for transactions:
  - schema:
      name: Transaction schema contract v2
      fail:
        when required column missing:
          [transaction_id, account_id, amount, currency, timestamp]
        when wrong type:
          amount: numeric
          timestamp: timestamp with time zone
      warn:
        when extra column present
```

## Anomaly Detection

Soda Core provides built-in anomaly detection using historical measurements.

```yaml
# checks/anomaly_checks.yml
checks for orders:
  # Volume anomaly -- uses last 30 days of row counts
  - anomaly detection for row_count:
      name: Order volume anomaly
      warn:
        when anomaly score > 3.0
      fail:
        when anomaly score > 5.0

  # Metric anomaly detection
  - anomaly detection for avg(order_total):
      name: Average order value anomaly

  - anomaly detection for missing_percent(email):
      name: Email null rate anomaly
      warn: only

  # Freshness anomaly
  - anomaly detection for freshness(created_at):
      name: Data freshness anomaly

checks for events:
  # Detect sudden changes in event distribution
  - anomaly detection for row_count:
      name: Event volume anomaly
      fail:
        when anomaly score > 4.0

  - anomaly detection for duplicate_count(event_id):
      name: Duplicate event anomaly
```

## Cross-Dataset Reference Checks

Validate referential integrity across tables and data sources.

```yaml
# checks/reference_checks.yml
checks for orders:
  # Every order must reference a valid customer
  - values in (customer_id) must exist in customers (customer_id)

  # Every product in order_items must exist in product catalog
checks for order_items:
  - values in (product_id) must exist in products (product_id)

  # Price consistency: order item price should match catalog
  # (custom SQL check for complex cross-table validation)
  - failed rows:
      name: Price mismatch between order items and catalog
      fail query: |
        SELECT oi.order_id, oi.product_id, oi.unit_price, p.current_price
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        WHERE ABS(oi.unit_price - p.current_price) > 0.01
          AND oi.created_at > CURRENT_DATE - INTERVAL '1 day'
```

## Custom SQL Checks

Write arbitrary SQL for complex validation logic.

```yaml
# checks/custom_sql_checks.yml
checks for transactions:
  # Reconciliation: sum of transactions should match settlement
  - failed rows:
      name: Settlement reconciliation
      fail query: |
        SELECT t.settlement_batch_id,
               SUM(t.amount) as transaction_sum,
               s.settled_amount,
               ABS(SUM(t.amount) - s.settled_amount) as difference
        FROM transactions t
        JOIN settlements s ON t.settlement_batch_id = s.batch_id
        WHERE t.settlement_date = CURRENT_DATE - INTERVAL '1 day'
        GROUP BY t.settlement_batch_id, s.settled_amount
        HAVING ABS(SUM(t.amount) - s.settled_amount) > 0.01

  # Business rule: no single transaction > 10% of daily volume
  - failed rows:
      name: Suspicious large transaction
      warn query: |
        WITH daily_stats AS (
          SELECT DATE(timestamp) as tx_date,
                 SUM(amount) as daily_total
          FROM transactions
          WHERE timestamp >= CURRENT_DATE - INTERVAL '1 day'
          GROUP BY DATE(timestamp)
        )
        SELECT t.transaction_id, t.amount, ds.daily_total,
               t.amount / ds.daily_total * 100 as pct_of_daily
        FROM transactions t
        JOIN daily_stats ds ON DATE(t.timestamp) = ds.tx_date
        WHERE t.amount / ds.daily_total > 0.10
```

## Soda Cloud Integration

Connect Soda Core to Soda Cloud for centralized monitoring, alerting, and historical tracking.

```python
from soda.core.scan import Scan

def run_cloud_connected_scan(check_files: list[str]) -> dict:
    """Run checks with Soda Cloud integration for history and alerting."""
    scan = Scan()
    scan.set_data_source_name("warehouse")
    scan.set_scan_definition_name("production_daily_scan")

    # Local configuration
    scan.add_configuration_yaml_file("configuration.yml")

    # Soda Cloud configuration (in configuration.yml):
    # soda_cloud:
    #   host: cloud.soda.io
    #   api_key_id: ${SODA_API_KEY_ID}
    #   api_key_secret: ${SODA_API_KEY_SECRET}

    for f in check_files:
        scan.add_sodacl_yaml_file(f)

    # Variables for dynamic checks
    scan.add_variables({
        "date": "2025-01-15",
        "min_expected_rows": "5000",
    })

    scan.execute()

    # Results are automatically pushed to Soda Cloud
    # Historical trends, anomaly baselines, and alerts are managed there
    return {
        "passed": len(scan.get_checks_pass()),
        "warned": len(scan.get_checks_warn()),
        "failed": len(scan.get_checks_fail()),
        "cloud_url": scan.get_cloud_url(),
    }
```

## Pipeline Integration with Prefect

```python
from prefect import task, flow
from soda.core.scan import Scan

@task(name="soda-quality-gate")
def soda_quality_gate(
    check_files: list[str],
    data_source: str,
    fail_on_warn: bool = False,
) -> dict:
    """Soda quality gate task for pipeline orchestration."""
    scan = Scan()
    scan.set_data_source_name(data_source)
    scan.add_configuration_yaml_file("configuration.yml")

    for f in check_files:
        scan.add_sodacl_yaml_file(f)

    scan.execute()

    if scan.has_check_fails():
        failed_names = [c.name for c in scan.get_checks_fail()]
        raise RuntimeError(f"Soda checks failed: {failed_names}")

    if fail_on_warn and scan.has_check_warns():
        warned_names = [c.name for c in scan.get_checks_warn()]
        raise RuntimeError(f"Soda checks warned (strict mode): {warned_names}")

    return {
        "status": "passed",
        "passed": len(scan.get_checks_pass()),
        "warned": len(scan.get_checks_warn()),
    }


@flow(name="Soda-Validated ETL")
def etl_with_soda_gates():
    """ETL pipeline with Soda quality gates at each stage."""
    # Stage 1: Validate raw source
    soda_quality_gate(
        check_files=["checks/raw_source_checks.yml"],
        data_source="source_db",
    )

    # Stage 2: Run transformation
    run_dbt_models()

    # Stage 3: Validate transformed output
    soda_quality_gate(
        check_files=[
            "checks/staging_checks.yml",
            "checks/freshness_checks.yml",
        ],
        data_source="warehouse",
        fail_on_warn=False,
    )

    # Stage 4: Validate final mart tables
    soda_quality_gate(
        check_files=["checks/mart_checks.yml"],
        data_source="warehouse",
        fail_on_warn=True,  # Strict for customer-facing data
    )
```

## Edge Cases

### Handling Timezone-Aware Freshness

```yaml
# Soda uses UTC by default for freshness calculations
# If your timestamps are in local time, account for offset
checks for events:
  # If data is in US/Eastern (UTC-5), add buffer
  - freshness(event_timestamp) < 7h  # 2h tolerance + 5h offset
```

### Empty Tables

```yaml
checks for staging_table:
  # Check row count first -- other checks may pass vacuously on empty tables
  - row_count > 0:
      name: Table is not empty (must pass before other checks)
```

### Variable Substitution for Environment-Specific Checks

```yaml
# checks/parameterized_checks.yml
checks for orders:
  - row_count > ${MIN_EXPECTED_ROWS}
  - freshness(created_at) < ${FRESHNESS_THRESHOLD}
  - missing_percent(email) < ${MAX_NULL_PERCENT}%
```

```python
scan.add_variables({
    "MIN_EXPECTED_ROWS": "10000" if env == "production" else "100",
    "FRESHNESS_THRESHOLD": "2h" if env == "production" else "24h",
    "MAX_NULL_PERCENT": "1" if env == "production" else "10",
})
```
