# BigQuery Patterns Reference

Detailed patterns for Google BigQuery partitioning, clustering, nested/repeated fields, materialized views, BI Engine, and cost optimization.

---

## Partitioning Strategies

Partitioning divides a table into segments by a column value. BigQuery prunes partitions at query time, dramatically reducing bytes scanned and cost.

```sql
-- Time-unit partitioning on a TIMESTAMP column (daily granularity)
CREATE TABLE analytics.fct_transactions (
    transaction_id      STRING NOT NULL,
    user_id             STRING NOT NULL,
    merchant_id         STRING,
    amount_cents        INT64,
    currency            STRING,
    transaction_type    STRING,
    transaction_time    TIMESTAMP NOT NULL,
    _partition_date     DATE NOT NULL
)
PARTITION BY _partition_date
OPTIONS (
    partition_expiration_days = 730,
    require_partition_filter  = TRUE,
    description = 'Transaction fact table partitioned by date'
);

-- Integer range partitioning for non-date use cases
CREATE TABLE analytics.dim_products (
    product_id      INT64 NOT NULL,
    product_name    STRING,
    category        STRING,
    subcategory     STRING,
    price_cents     INT64,
    created_at      TIMESTAMP
)
PARTITION BY RANGE_BUCKET(product_id, GENERATE_ARRAY(0, 10000000, 100000));

-- Ingestion-time partitioning (automatic based on load time)
CREATE TABLE raw.api_responses (
    request_id      STRING,
    endpoint        STRING,
    status_code     INT64,
    response_body   JSON,
    response_time   FLOAT64
)
PARTITION BY _PARTITIONDATE
OPTIONS (
    require_partition_filter = TRUE
);
```

### Partition Type Comparison

| Type | Column Type | Granularity | Best For |
|---|---|---|---|
| Time-unit (HOUR) | TIMESTAMP/DATE | Hourly | High-volume streaming tables |
| Time-unit (DAY) | TIMESTAMP/DATE | Daily | Most fact tables |
| Time-unit (MONTH) | TIMESTAMP/DATE | Monthly | Slowly growing dimensions |
| Integer range | INT64 | Custom buckets | Non-date sharding (user_id ranges) |
| Ingestion time | Automatic | Daily/Hourly | When source has no reliable date column |

---

## Clustering

Clustering sorts data within each partition by up to four columns. It accelerates filter and join performance without manual index management.

```sql
-- Cluster on columns commonly used in WHERE and JOIN
CREATE TABLE analytics.fct_page_views (
    session_id      STRING NOT NULL,
    user_id         STRING,
    page_path       STRING,
    referrer        STRING,
    duration_ms     INT64,
    event_timestamp TIMESTAMP NOT NULL,
    _partition_date DATE NOT NULL
)
PARTITION BY _partition_date
CLUSTER BY user_id, page_path;

-- Recluster an existing table by replacing it
CREATE OR REPLACE TABLE analytics.fct_page_views
PARTITION BY _partition_date
CLUSTER BY user_id, page_path
AS SELECT * FROM analytics.fct_page_views;
```

### Clustering Column Selection

- Choose columns that appear in `WHERE`, `JOIN`, and `GROUP BY` clauses
- Order from lowest to highest cardinality (most selective first)
- Maximum 4 clustering columns
- Clustering is free and automatic — BigQuery re-clusters in the background
- Most effective on tables larger than 1 GB

---

## Nested and Repeated Fields (STRUCT and ARRAY)

BigQuery natively supports nested records and repeated fields, avoiding expensive JOINs by denormalizing related data.

```sql
-- Table with nested STRUCT and ARRAY fields
CREATE TABLE analytics.user_sessions (
    session_id      STRING NOT NULL,
    user_id         STRING,
    session_start   TIMESTAMP,
    session_end     TIMESTAMP,
    device          STRUCT<
        category    STRING,
        os          STRING,
        os_version  STRING,
        browser     STRING,
        screen_res  STRING
    >,
    geo             STRUCT<
        country     STRING,
        region      STRING,
        city        STRING,
        latitude    FLOAT64,
        longitude   FLOAT64
    >,
    events          ARRAY<STRUCT<
        event_name  STRING,
        event_time  TIMESTAMP,
        params      ARRAY<STRUCT<key STRING, value STRING>>
    >>,
    _partition_date DATE NOT NULL
)
PARTITION BY _partition_date
CLUSTER BY user_id;

-- Query nested fields directly
SELECT
    session_id,
    device.category     AS device_category,
    device.os           AS device_os,
    geo.country         AS country
FROM analytics.user_sessions
WHERE _partition_date = '2026-02-14'
  AND device.category = 'mobile';

-- Unnest repeated fields to flatten arrays
SELECT
    s.session_id,
    s.user_id,
    e.event_name,
    e.event_time,
    p.key             AS param_key,
    p.value           AS param_value
FROM analytics.user_sessions s,
    UNNEST(s.events) AS e,
    UNNEST(e.params) AS p
WHERE s._partition_date = '2026-02-14'
  AND e.event_name = 'purchase';
```

---

## Materialized Views

Materialized views pre-compute query results and refresh incrementally. BigQuery automatically rewrites queries to use materialized views when beneficial.

```sql
-- Materialized view for daily revenue aggregation
CREATE MATERIALIZED VIEW analytics.mv_daily_revenue
PARTITION BY order_date
CLUSTER BY region
OPTIONS (
    enable_refresh = TRUE,
    refresh_interval_minutes = 30
)
AS
SELECT
    DATE(order_timestamp)   AS order_date,
    region,
    COUNT(*)                AS order_count,
    SUM(order_total)        AS total_revenue,
    AVG(order_total)        AS avg_order_value,
    APPROX_COUNT_DISTINCT(customer_id) AS unique_customers
FROM analytics.fct_orders
GROUP BY 1, 2;

-- Materialized view with filters (reduces refresh cost)
CREATE MATERIALIZED VIEW analytics.mv_active_subscriptions
AS
SELECT
    plan_type,
    billing_interval,
    COUNT(*)            AS subscriber_count,
    SUM(mrr_cents)      AS total_mrr_cents
FROM analytics.dim_subscriptions
WHERE status = 'active'
  AND cancelled_at IS NULL
GROUP BY 1, 2;
```

### Materialized View Limitations

- Must have at least one aggregate function
- Cannot use JOINs (except in BigQuery ML or with authorized views)
- Base table and materialized view must be in the same dataset
- Refresh cost is charged as bytes processed

---

## BI Engine Reservations

BI Engine is an in-memory analysis service that accelerates SQL queries from BI tools like Looker, Data Studio, and Tableau.

```sql
-- BI Engine reservation is configured via API or console, not SQL
-- But you can verify acceleration in query metadata:
SELECT
    job_id,
    query,
    total_bytes_processed,
    bi_engine_statistics.bi_engine_mode,
    bi_engine_statistics.acceleration_mode
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND bi_engine_statistics.bi_engine_mode IS NOT NULL
ORDER BY creation_time DESC;
```

```yaml
# Terraform: create BI Engine reservation
resource "google_bigquery_bi_reservation" "default" {
  location = "US"
  size     = "5368709120"  # 5 GB in bytes
  project  = "my-analytics-project"
}
```

---

## Scheduled Queries and Transfers

```sql
-- Scheduled query using BigQuery's built-in scheduler
-- Configured via console or API; the SQL itself is standard
-- This example runs daily at 06:00 UTC
DECLARE run_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

CREATE OR REPLACE TABLE analytics.daily_user_metrics AS
SELECT
    run_date                        AS metric_date,
    user_id,
    COUNT(DISTINCT session_id)      AS sessions,
    SUM(page_views)                 AS total_page_views,
    SUM(revenue_cents) / 100.0      AS revenue_dollars,
    MAX(last_active_at)             AS last_active_at
FROM analytics.fct_user_activity
WHERE activity_date = run_date
GROUP BY 1, 2;
```

---

## Cost Optimization

```sql
-- Estimate query cost before running (dry run via bq CLI)
-- bq query --dry_run --use_legacy_sql=false 'SELECT ...'

-- Check bytes billed for recent queries
SELECT
    user_email,
    job_id,
    query,
    total_bytes_billed,
    ROUND(total_bytes_billed / POW(1024, 4), 4) AS tb_billed,
    ROUND(total_bytes_billed / POW(1024, 4) * 6.25, 2) AS estimated_cost_usd
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND job_type = 'QUERY'
  AND state = 'DONE'
ORDER BY total_bytes_billed DESC
LIMIT 20;

-- Use table metadata to understand storage costs
SELECT
    table_name,
    ROUND(total_logical_bytes / POW(1024, 3), 2)   AS logical_gb,
    ROUND(total_physical_bytes / POW(1024, 3), 2)   AS physical_gb,
    ROUND(active_logical_bytes / POW(1024, 3), 2)   AS active_gb,
    ROUND(long_term_logical_bytes / POW(1024, 3), 2) AS long_term_gb,
    row_count
FROM `analytics`.INFORMATION_SCHEMA.TABLE_STORAGE
ORDER BY total_logical_bytes DESC;
```

### Cost Control Checklist

- Enable `require_partition_filter` on all partitioned tables
- Set `partition_expiration_days` to auto-drop old data
- Use clustering on top filter columns (free, automatic)
- Prefer `COUNT(DISTINCT)` approximations (`APPROX_COUNT_DISTINCT`) for dashboards
- Use materialized views for repeated aggregations
- Monitor per-user and per-project bytes billed via INFORMATION_SCHEMA
- Consider flat-rate pricing (slots) if on-demand spend exceeds $10K/month
