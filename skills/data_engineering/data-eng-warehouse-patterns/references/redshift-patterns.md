# Redshift Patterns Reference

Detailed patterns for Amazon Redshift distribution styles, sort keys, COPY command, workload management (WLM), and Redshift Spectrum.

---

## Distribution Styles

Distribution style determines how table rows are spread across compute nodes. The right choice minimizes data movement during JOINs.

```sql
-- KEY distribution: co-locate rows with the same key on the same node
-- Use when this table is frequently joined on user_id
CREATE TABLE analytics.fct_orders (
    order_id        BIGINT          IDENTITY(1,1),
    user_id         BIGINT          NOT NULL DISTKEY,
    product_id      BIGINT          NOT NULL,
    order_total     DECIMAL(12,2),
    order_status    VARCHAR(32),
    order_timestamp TIMESTAMP       NOT NULL,
    region          VARCHAR(64)
)
DISTSTYLE KEY;

-- ALL distribution: replicate small dimension tables to every node
-- Eliminates data redistribution for joins with fact tables
CREATE TABLE analytics.dim_regions (
    region_id       INTEGER         NOT NULL,
    region_name     VARCHAR(128),
    country_code    VARCHAR(2),
    timezone        VARCHAR(64),
    currency_code   VARCHAR(3)
)
DISTSTYLE ALL;

-- EVEN distribution: round-robin when no good join key exists
CREATE TABLE staging.raw_events (
    event_id        VARCHAR(64),
    event_payload   VARCHAR(65535),
    received_at     TIMESTAMP
)
DISTSTYLE EVEN;

-- AUTO distribution: let Redshift decide (good default for new tables)
CREATE TABLE analytics.dim_products (
    product_id      BIGINT          NOT NULL,
    product_name    VARCHAR(256),
    category        VARCHAR(128),
    subcategory     VARCHAR(128),
    price_cents     BIGINT
)
DISTSTYLE AUTO;
```

### Distribution Style Decision Guide

| Style | When to Use | Trade-off |
|---|---|---|
| KEY | Large fact tables joined frequently on a specific column | Skew risk if key has uneven distribution |
| ALL | Small dimension tables (< 3M rows) joined with many fact tables | Storage cost multiplied by node count |
| EVEN | Staging/temp tables with no clear join key | No co-location benefit for JOINs |
| AUTO | New tables where query patterns are unknown | Redshift may not choose optimally |

---

## Sort Keys

Sort keys define the physical order of rows on disk. They enable zone map pruning, where Redshift skips blocks that cannot contain matching rows.

```sql
-- Compound sort key: most effective when queries filter left-to-right
CREATE TABLE analytics.fct_page_views (
    page_view_id    BIGINT          IDENTITY(1,1),
    user_id         BIGINT          NOT NULL DISTKEY,
    page_url        VARCHAR(2048),
    view_timestamp  TIMESTAMP       NOT NULL,
    device_type     VARCHAR(32)
)
COMPOUND SORTKEY (view_timestamp, user_id);

-- Interleaved sort key: equal weight to each column
-- Better when queries filter on different column combinations
CREATE TABLE analytics.fct_search_events (
    search_id       BIGINT          IDENTITY(1,1),
    user_id         BIGINT          NOT NULL,
    search_query    VARCHAR(512),
    result_count    INTEGER,
    clicked_result  BOOLEAN,
    search_date     DATE            NOT NULL,
    category        VARCHAR(64),
    region          VARCHAR(64)
)
INTERLEAVED SORTKEY (search_date, category, region);
```

### Sort Key Selection

- **Compound**: Queries consistently filter on the same leading columns (e.g., date range)
- **Interleaved**: Queries filter on varying column combinations with roughly equal frequency
- Check sort key effectiveness with `SVV_TABLE_INFO`:

```sql
-- Monitor table health: sort key effectiveness, skew, compression
SELECT
    "table"         AS table_name,
    diststyle,
    sortkey1,
    sortkey_num,
    unsorted        AS pct_unsorted,
    stats_off       AS stats_staleness,
    tbl_rows,
    skew_rows       AS row_skew_ratio,
    encoded         AS compression_encoded
FROM SVV_TABLE_INFO
WHERE schema = 'analytics'
ORDER BY tbl_rows DESC;
```

---

## COPY Command

COPY is the fastest way to load data from S3 into Redshift. It parallelizes reads across slices and applies automatic compression.

```sql
-- Load Parquet files from S3 with IAM role
COPY analytics.fct_orders
FROM 's3://data-lake-prod/orders/dt=2026-02-14/'
IAM_ROLE 'arn:aws:iam::123456789012:role/redshift-loader'
FORMAT AS PARQUET;

-- Load CSV with explicit options and error handling
COPY staging.raw_customers
FROM 's3://data-lake-prod/customers/'
IAM_ROLE 'arn:aws:iam::123456789012:role/redshift-loader'
FORMAT AS CSV
DELIMITER ','
IGNOREHEADER 1
DATEFORMAT 'auto'
TIMEFORMAT 'auto'
NULL AS ''
MAXERROR 100
REGION 'us-east-1'
COMPUPDATE ON
STATUPDATE ON;

-- Load gzipped JSON
COPY staging.raw_events
FROM 's3://data-lake-prod/events/2026/02/14/'
IAM_ROLE 'arn:aws:iam::123456789012:role/redshift-loader'
FORMAT AS JSON 'auto'
GZIP
MAXERROR 50
TRUNCATECOLUMNS;

-- Check load errors
SELECT
    starttime,
    filename,
    line_number,
    colname,
    type,
    col_length,
    raw_field_value,
    err_reason
FROM STL_LOAD_ERRORS
WHERE starttime > DATEADD(HOUR, -6, GETDATE())
ORDER BY starttime DESC
LIMIT 50;

-- Manifest-based loading for exact file control
COPY analytics.fct_orders
FROM 's3://data-lake-prod/manifests/orders_20260214.manifest'
IAM_ROLE 'arn:aws:iam::123456789012:role/redshift-loader'
FORMAT AS PARQUET
MANIFEST;
```

### COPY Best Practices

- Split files so the number of files is a multiple of the number of slices
- Target file sizes of 1 MB to 1 GB compressed
- Use Parquet or ORC for best performance (columnar, compressed)
- Enable `COMPUPDATE ON` on initial load to auto-select compression encodings
- Use `STATUPDATE ON` to refresh table statistics after load
- Use manifests for idempotent, exactly-once loading

---

## Workload Management (WLM)

WLM controls how queries are queued and allocated memory. Use separate queues for different workload types.

```sql
-- Check current WLM configuration
SELECT
    service_class,
    name,
    num_query_tasks,
    query_working_mem,
    max_execution_time,
    user_group_wild_card,
    query_group_wild_card
FROM STV_WLM_SERVICE_CLASS_CONFIG
WHERE service_class > 5
ORDER BY service_class;

-- Set query group before running a heavy transform
SET query_group TO 'etl_transforms';

-- Run the heavy query (routed to ETL queue)
CREATE TABLE analytics.fct_orders_daily AS
SELECT
    DATE_TRUNC('day', order_timestamp) AS order_date,
    region,
    COUNT(*) AS order_count,
    SUM(order_total) AS revenue
FROM analytics.fct_orders
GROUP BY 1, 2;

RESET query_group;

-- Monitor queue wait times and execution
SELECT
    service_class,
    query,
    slot_count,
    total_queue_time / 1000000.0 AS queue_seconds,
    total_exec_time / 1000000.0  AS exec_seconds
FROM STL_WLM_QUERY
WHERE starttime > DATEADD(HOUR, -2, GETDATE())
ORDER BY total_queue_time DESC
LIMIT 20;
```

### WLM Queue Design

| Queue | Concurrency | Memory % | Timeout | User Groups |
|---|---|---|---|---|
| ETL | 3 | 40% | 3600s | etl_service |
| BI Dashboards | 10 | 30% | 120s | looker_svc, tableau_svc |
| Ad-hoc Analysts | 5 | 20% | 600s | analyst_group |
| Short Queries | 15 | 10% | 30s | Default |

---

## Redshift Spectrum

Spectrum queries data directly in S3 without loading it into Redshift. Use it for cold data, ad-hoc exploration, and data lakehouse patterns.

```sql
-- Create external schema pointing to Glue Data Catalog
CREATE EXTERNAL SCHEMA spectrum_events
FROM DATA CATALOG
DATABASE 'data_lake'
IAM_ROLE 'arn:aws:iam::123456789012:role/redshift-spectrum'
CREATE EXTERNAL DATABASE IF NOT EXISTS;

-- Create external table over Parquet files in S3
CREATE EXTERNAL TABLE spectrum_events.web_clicks (
    click_id        VARCHAR(64),
    session_id      VARCHAR(64),
    user_id         BIGINT,
    page_url        VARCHAR(2048),
    click_timestamp TIMESTAMP
)
PARTITIONED BY (dt VARCHAR(10))
STORED AS PARQUET
LOCATION 's3://data-lake-prod/web_clicks/';

-- Add partitions (or use ALTER TABLE ... ADD PARTITION)
ALTER TABLE spectrum_events.web_clicks ADD
PARTITION (dt = '2026-02-14')
LOCATION 's3://data-lake-prod/web_clicks/dt=2026-02-14/';

-- Join Spectrum external table with local Redshift table
SELECT
    c.click_id,
    c.page_url,
    u.user_name,
    u.account_type
FROM spectrum_events.web_clicks c
    JOIN analytics.dim_users u ON c.user_id = u.user_id
WHERE c.dt = '2026-02-14'
  AND u.account_type = 'premium';
```

---

## Table Maintenance

```sql
-- VACUUM: reclaim space and re-sort after updates/deletes
VACUUM FULL analytics.fct_orders;

-- VACUUM specific sort percentage threshold
VACUUM SORT ONLY analytics.fct_orders TO 95 PERCENT;

-- ANALYZE: update table statistics for query planner
ANALYZE analytics.fct_orders;

-- Deep copy to completely reorganize a table
CREATE TABLE analytics.fct_orders_new (LIKE analytics.fct_orders);
INSERT INTO analytics.fct_orders_new SELECT * FROM analytics.fct_orders;
DROP TABLE analytics.fct_orders;
ALTER TABLE analytics.fct_orders_new RENAME TO fct_orders;

-- Monitor table bloat and vacuum needs
SELECT
    "table"     AS table_name,
    unsorted    AS pct_unsorted,
    empty       AS pct_empty_blocks,
    tbl_rows
FROM SVV_TABLE_INFO
WHERE schema = 'analytics'
  AND (unsorted > 20 OR empty > 20)
ORDER BY tbl_rows DESC;
```
