# Snowflake Patterns Reference

Detailed patterns for Snowflake architecture, warehouse management, data loading, clustering, and time travel.

---

## Warehouse Sizing and Management

Virtual warehouses are independent compute clusters. Size them by workload type — not by team name.

```sql
-- Lightweight warehouse for BI dashboards and ad-hoc queries
CREATE WAREHOUSE bi_query_wh
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'ECONOMY'
    COMMENT = 'Dashboard and ad-hoc analytics queries';

-- Heavy-duty warehouse for dbt transformations
CREATE WAREHOUSE dbt_transform_wh
    WAREHOUSE_SIZE = 'X-LARGE'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    COMMENT = 'Scheduled dbt model builds';

-- Resource monitor to cap monthly spend
CREATE RESOURCE MONITOR transform_budget
    WITH CREDIT_QUOTA = 500
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE dbt_transform_wh
    SET RESOURCE_MONITOR = transform_budget;
```

### Sizing Guidelines

| Warehouse Size | Nodes | Credits/Hour | Best For |
|---|---|---|---|
| X-Small | 1 | 1 | Development, testing |
| Small | 2 | 2 | Light BI queries |
| Medium | 4 | 4 | Standard BI, moderate transforms |
| Large | 8 | 8 | Complex joins, medium batch loads |
| X-Large | 16 | 16 | Heavy dbt runs, large data loads |
| 2X-Large | 32 | 32 | Very large table scans, backfills |

---

## External Stages and File Formats

Stages define where external data lives. File formats define how to parse it.

```sql
-- Create a storage integration for S3 access
CREATE STORAGE INTEGRATION s3_integration
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/snowflake-access'
    STORAGE_ALLOWED_LOCATIONS = ('s3://company-data-lake/');

-- Named file format for Parquet ingestion
CREATE FILE FORMAT parquet_format
    TYPE = PARQUET
    COMPRESSION = SNAPPY
    BINARY_AS_TEXT = FALSE;

-- Named file format for JSON with error handling
CREATE FILE FORMAT json_tolerant
    TYPE = JSON
    STRIP_OUTER_ARRAY = TRUE
    ALLOW_DUPLICATE = TRUE
    IGNORE_UTF8_ERRORS = TRUE;

-- External stage pointing to S3 prefix
CREATE STAGE raw_events_stage
    STORAGE_INTEGRATION = s3_integration
    URL = 's3://company-data-lake/events/'
    FILE_FORMAT = parquet_format;

-- List files in stage to verify connectivity
LIST @raw_events_stage;
```

---

## COPY INTO Patterns

COPY INTO is the primary bulk loading mechanism. Use it with error handling and metadata columns.

```sql
-- Basic COPY with metadata columns
COPY INTO raw.web_events
FROM (
    SELECT
        $1:event_id::STRING             AS event_id,
        $1:user_id::STRING              AS user_id,
        $1:event_name::STRING           AS event_name,
        $1:properties::VARIANT          AS properties,
        $1:timestamp::TIMESTAMP_NTZ     AS event_timestamp,
        METADATA$FILENAME               AS _source_file,
        METADATA$FILE_ROW_NUMBER        AS _source_row,
        CURRENT_TIMESTAMP()             AS _loaded_at
    FROM @raw_events_stage
)
FILE_FORMAT = parquet_format
PATTERN = '.*events.*[.]parquet'
ON_ERROR = 'CONTINUE'
FORCE = FALSE;

-- Check load history for errors
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'raw.web_events',
    START_TIME => DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
))
WHERE STATUS = 'LOAD_FAILED'
ORDER BY LAST_LOAD_TIME DESC;

-- Snowpipe for continuous micro-batch loading
CREATE PIPE raw.web_events_pipe
    AUTO_INGEST = TRUE
AS
COPY INTO raw.web_events
FROM @raw_events_stage
FILE_FORMAT = parquet_format
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;
```

---

## Clustering Keys

Clustering physically reorders micro-partitions to co-locate similar values. It improves pruning for large tables (typically > 1 TB).

```sql
-- Check current clustering depth before adding keys
SELECT SYSTEM$CLUSTERING_INFORMATION('analytics.fct_orders', '(order_date, customer_id)');

-- Cluster on most selective filter columns
ALTER TABLE analytics.fct_orders
    CLUSTER BY (order_date, region_id);

-- For high-cardinality string columns, cluster on expressions
ALTER TABLE analytics.fct_events
    CLUSTER BY (TO_DATE(event_timestamp), SUBSTRING(event_name, 1, 32));

-- Monitor clustering health over time
SELECT
    TABLE_NAME,
    CLUSTERING_KEY,
    AVERAGE_DEPTH,
    AVERAGE_OVERLAPS,
    TOTAL_CONSTANT_PARTITION_COUNT,
    TOTAL_PARTITION_COUNT
FROM TABLE(INFORMATION_SCHEMA.AUTOMATIC_CLUSTERING_HISTORY(
    DATE_RANGE_START => DATEADD(DAY, -7, CURRENT_DATE()),
    TABLE_NAME => 'analytics.fct_orders'
));
```

### When to Cluster

- Table is larger than 1 TB
- Queries consistently filter on the same 2-3 columns
- Clustering depth is consistently above 4-5
- Do NOT cluster tables that are mostly appended and rarely queried with filters

---

## Time Travel and Cloning

Time travel allows querying historical table states. Zero-copy clones create instant copies without duplicating storage.

```sql
-- Query table state at a specific timestamp
SELECT COUNT(*) FROM analytics.fct_orders
    AT(TIMESTAMP => '2026-02-13 08:00:00'::TIMESTAMP_NTZ);

-- Query table state before a specific query (useful for debugging)
SELECT * FROM analytics.fct_orders
    BEFORE(STATEMENT => '01b2c3d4-0001-a234-0000-00012345abcd');

-- Recover from a bad UPDATE
CREATE TABLE analytics.fct_orders_recovered
    CLONE analytics.fct_orders
    AT(OFFSET => -7200);  -- 2 hours ago

-- Zero-copy clone for development environment
CREATE DATABASE dev_analytics
    CLONE prod_analytics;

-- Clone a specific schema for testing
CREATE SCHEMA test_staging
    CLONE prod_staging;

-- Set time travel retention per table
ALTER TABLE analytics.fct_orders
    SET DATA_RETENTION_TIME_IN_DAYS = 14;
```

### Time Travel Retention

| Edition | Default Retention | Max Retention |
|---|---|---|
| Standard | 1 day | 1 day |
| Enterprise | 1 day | 90 days |
| Business Critical | 1 day | 90 days |

---

## Streams and Tasks for CDC

Streams capture change data on tables. Tasks schedule SQL execution.

```sql
-- Create a stream on the raw orders table
CREATE STREAM raw.orders_stream
    ON TABLE raw.orders
    APPEND_ONLY = FALSE
    SHOW_INITIAL_ROWS = FALSE;

-- Task to process stream data every 5 minutes
CREATE TASK transform.process_orders
    WAREHOUSE = dbt_transform_wh
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('raw.orders_stream')
AS
MERGE INTO cleaned.orders t
USING (
    SELECT
        order_id,
        customer_id,
        order_total,
        order_status,
        METADATA$ACTION   AS _action,
        METADATA$ISUPDATE AS _is_update
    FROM raw.orders_stream
) s
ON t.order_id = s.order_id
WHEN MATCHED AND s._action = 'INSERT' THEN
    UPDATE SET
        order_total  = s.order_total,
        order_status = s.order_status,
        _updated_at  = CURRENT_TIMESTAMP()
WHEN NOT MATCHED AND s._action = 'INSERT' THEN
    INSERT (order_id, customer_id, order_total, order_status, _loaded_at)
    VALUES (s.order_id, s.customer_id, s.order_total, s.order_status, CURRENT_TIMESTAMP());

-- Resume the task (tasks are created suspended)
ALTER TASK transform.process_orders RESUME;
```

---

## Dynamic Tables

Dynamic tables are Snowflake's declarative approach to data pipelines. Define the target state; Snowflake manages incremental refresh.

```sql
-- Dynamic table that automatically refreshes from raw data
CREATE DYNAMIC TABLE cleaned.daily_revenue
    TARGET_LAG = '30 minutes'
    WAREHOUSE = dbt_transform_wh
AS
SELECT
    DATE_TRUNC('day', order_timestamp)  AS order_date,
    region_id,
    COUNT(DISTINCT order_id)            AS order_count,
    SUM(order_total)                    AS total_revenue,
    AVG(order_total)                    AS avg_order_value
FROM raw.orders
WHERE order_status NOT IN ('cancelled', 'refunded')
GROUP BY 1, 2;
```
