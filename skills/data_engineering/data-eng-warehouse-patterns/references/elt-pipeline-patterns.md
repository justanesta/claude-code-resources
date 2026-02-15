# ELT Pipeline Patterns Reference

Detailed patterns for staging layers, medallion architecture (bronze/silver/gold), incremental loading, idempotent transforms, and pipeline orchestration.

---

## Medallion Architecture

The medallion (or multi-hop) architecture organizes data into three layers: bronze (raw), silver (cleaned), and gold (business-ready). Each layer adds quality and structure.

```
Data Sources -> Bronze (Raw) -> Silver (Cleaned) -> Gold (Aggregated)
                  |                 |                    |
              Append-only      Deduplicated         Business metrics
              Schema-on-read   Typed & validated    Star schema / OBT
              Full fidelity    Conformed keys       Dashboard-ready
```

### Bronze Layer (Raw/Staging)

Bronze stores raw data exactly as received from source systems. No transformations, no filtering, no deduplication.

```sql
-- Bronze table: raw events from Kafka/S3
CREATE TABLE bronze.raw_clickstream (
    _raw_payload        VARIANT,            -- full raw JSON
    _source_file        VARCHAR(512),       -- file path or Kafka topic
    _source_offset      BIGINT,             -- Kafka offset or file row
    _loaded_at          TIMESTAMP_NTZ       DEFAULT CURRENT_TIMESTAMP(),
    _load_batch_id      VARCHAR(64)         -- batch identifier for lineage
);

-- Load from external stage (Snowflake example)
COPY INTO bronze.raw_clickstream (_raw_payload, _source_file, _source_offset, _loaded_at, _load_batch_id)
FROM (
    SELECT
        $1,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'batch_20260214_001'
    FROM @data_lake_stage/clickstream/dt=2026-02-14/
)
FILE_FORMAT = (TYPE = JSON)
ON_ERROR = 'CONTINUE';
```

### Silver Layer (Cleaned/Conformed)

Silver applies data quality rules: deduplication, type casting, null handling, and business key conforming.

```sql
-- Silver table: cleaned and typed clickstream
CREATE TABLE silver.clickstream (
    click_id            VARCHAR(64)     NOT NULL,
    session_id          VARCHAR(64)     NOT NULL,
    user_id             VARCHAR(64),
    page_url            VARCHAR(2048),
    referrer_url        VARCHAR(2048),
    event_name          VARCHAR(128),
    device_category     VARCHAR(32),
    device_os           VARCHAR(64),
    browser             VARCHAR(64),
    country_code        VARCHAR(2),
    region              VARCHAR(128),
    click_timestamp     TIMESTAMP_NTZ   NOT NULL,
    _loaded_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    _source_batch_id    VARCHAR(64)
);

-- Transform bronze -> silver with deduplication and typing
INSERT INTO silver.clickstream
WITH ranked AS (
    SELECT
        _raw_payload:click_id::VARCHAR(64)      AS click_id,
        _raw_payload:session_id::VARCHAR(64)    AS session_id,
        _raw_payload:user_id::VARCHAR(64)       AS user_id,
        _raw_payload:page_url::VARCHAR(2048)    AS page_url,
        _raw_payload:referrer::VARCHAR(2048)    AS referrer_url,
        _raw_payload:event::VARCHAR(128)        AS event_name,
        _raw_payload:device:category::VARCHAR   AS device_category,
        _raw_payload:device:os::VARCHAR         AS device_os,
        _raw_payload:device:browser::VARCHAR    AS browser,
        _raw_payload:geo:country::VARCHAR(2)    AS country_code,
        _raw_payload:geo:region::VARCHAR        AS region,
        _raw_payload:timestamp::TIMESTAMP_NTZ   AS click_timestamp,
        _load_batch_id                          AS _source_batch_id,
        ROW_NUMBER() OVER (
            PARTITION BY _raw_payload:click_id::VARCHAR
            ORDER BY _loaded_at DESC
        ) AS _row_num
    FROM bronze.raw_clickstream
    WHERE _load_batch_id = 'batch_20260214_001'
)
SELECT
    click_id, session_id, user_id, page_url, referrer_url,
    event_name, device_category, device_os, browser,
    country_code, region, click_timestamp,
    CURRENT_TIMESTAMP(), _source_batch_id
FROM ranked
WHERE _row_num = 1
  AND click_id IS NOT NULL
  AND click_timestamp IS NOT NULL;
```

### Gold Layer (Business-Ready)

Gold contains aggregated, denormalized tables optimized for specific business use cases: dashboards, reports, ML features.

```sql
-- Gold table: daily session metrics for executive dashboard
CREATE OR REPLACE TABLE gold.daily_session_metrics AS
SELECT
    DATE(click_timestamp)               AS metric_date,
    country_code,
    device_category,
    COUNT(DISTINCT session_id)          AS total_sessions,
    COUNT(DISTINCT user_id)             AS unique_users,
    COUNT(*)                            AS total_clicks,
    ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT session_id), 0), 2)
                                        AS avg_clicks_per_session,
    COUNT(DISTINCT CASE
        WHEN event_name = 'purchase' THEN session_id
    END)                                AS converting_sessions,
    ROUND(
        COUNT(DISTINCT CASE WHEN event_name = 'purchase' THEN session_id END)
        / NULLIF(COUNT(DISTINCT session_id), 0) * 100, 2
    )                                   AS conversion_rate_pct
FROM silver.clickstream
WHERE click_timestamp >= DATEADD(DAY, -90, CURRENT_DATE())
GROUP BY 1, 2, 3;
```

---

## Incremental Loading Patterns

Incremental loads process only new or changed data, reducing compute cost and pipeline runtime.

### Watermark-Based Incremental

Track the maximum timestamp from the last successful load and only process records after that point.

```sql
-- Get high watermark from the target table
SET last_loaded = (
    SELECT COALESCE(MAX(_loaded_at), '1900-01-01'::TIMESTAMP_NTZ)
    FROM silver.orders
);

-- Load only new records from bronze
INSERT INTO silver.orders
SELECT
    order_id,
    customer_id,
    order_total,
    order_status,
    order_timestamp,
    CURRENT_TIMESTAMP() AS _loaded_at
FROM bronze.raw_orders
WHERE _loaded_at > $last_loaded;
```

### MERGE-Based Incremental (Upsert)

Use MERGE for dimensions and tables where records can be updated.

```sql
-- Incremental upsert for customer dimension
MERGE INTO silver.dim_customers t
USING (
    SELECT * FROM (
        SELECT
            customer_id,
            customer_name,
            email,
            phone,
            signup_date,
            _loaded_at,
            ROW_NUMBER() OVER (
                PARTITION BY customer_id
                ORDER BY _loaded_at DESC
            ) AS _rn
        FROM bronze.raw_customers
        WHERE _loaded_at > (SELECT MAX(_loaded_at) FROM silver.dim_customers)
    )
    WHERE _rn = 1
) s
ON t.customer_id = s.customer_id
WHEN MATCHED AND (
    t.customer_name != s.customer_name OR
    t.email != s.email OR
    t.phone != s.phone
) THEN UPDATE SET
    customer_name = s.customer_name,
    email         = s.email,
    phone         = s.phone,
    _updated_at   = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    customer_id, customer_name, email, phone, signup_date, _loaded_at
) VALUES (
    s.customer_id, s.customer_name, s.email, s.phone, s.signup_date, CURRENT_TIMESTAMP()
);
```

### Partition-Based Incremental

Replace entire partitions for date-partitioned fact tables. This is idempotent and handles late-arriving data.

```sql
-- Delete and reload a specific partition (idempotent)
DELETE FROM silver.fct_transactions
WHERE transaction_date = '2026-02-14';

INSERT INTO silver.fct_transactions
SELECT
    transaction_id,
    user_id,
    merchant_id,
    amount_cents,
    currency,
    transaction_type,
    transaction_timestamp,
    DATE(transaction_timestamp) AS transaction_date,
    CURRENT_TIMESTAMP()         AS _loaded_at
FROM bronze.raw_transactions
WHERE DATE(_raw_payload:timestamp::TIMESTAMP) = '2026-02-14';
```

---

## Idempotent Pipeline Design

Every pipeline step should produce the same result when run multiple times with the same input. This enables safe retries and backfills.

```sql
-- Pattern 1: CREATE OR REPLACE (full rebuild, always idempotent)
CREATE OR REPLACE TABLE gold.weekly_revenue AS
SELECT
    DATE_TRUNC('week', order_date)  AS week_start,
    region,
    SUM(order_total)                AS total_revenue,
    COUNT(DISTINCT order_id)        AS order_count
FROM silver.fct_orders
GROUP BY 1, 2;

-- Pattern 2: DELETE + INSERT for partition-level idempotency
BEGIN TRANSACTION;

DELETE FROM silver.fct_orders WHERE order_date = :target_date;

INSERT INTO silver.fct_orders
SELECT * FROM bronze.raw_orders WHERE DATE(order_timestamp) = :target_date;

COMMIT;

-- Pattern 3: MERGE for row-level idempotency (shown above)
```

---

## Staging Layer Design

The staging layer is a transient workspace between extraction and bronze. Data lives here only during a load cycle.

```sql
-- Transient staging table (Snowflake: no time travel or fail-safe)
CREATE TRANSIENT TABLE staging.stg_crm_contacts (
    contact_id      VARCHAR(64),
    first_name      VARCHAR(128),
    last_name       VARCHAR(128),
    email           VARCHAR(256),
    phone           VARCHAR(32),
    company_name    VARCHAR(256),
    _extracted_at   TIMESTAMP_NTZ,
    _batch_id       VARCHAR(64)
);

-- Truncate staging before each load (clean slate)
TRUNCATE TABLE staging.stg_crm_contacts;

-- Load from external source
COPY INTO staging.stg_crm_contacts
FROM @crm_stage/contacts/
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');

-- Validate staging data before promoting to bronze
SELECT
    COUNT(*)                                    AS total_rows,
    COUNT(DISTINCT contact_id)                  AS unique_contacts,
    SUM(CASE WHEN contact_id IS NULL THEN 1 ELSE 0 END) AS null_ids,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END)      AS null_emails,
    MIN(_extracted_at)                          AS earliest_extract,
    MAX(_extracted_at)                          AS latest_extract
FROM staging.stg_crm_contacts;
```

---

## Pipeline Orchestration with dbt

dbt is the standard tool for managing SQL-based ELT transforms within the warehouse.

```yaml
# dbt_project.yml — model configuration by layer
models:
  my_project:
    staging:
      +materialized: view
      +schema: staging
      +tags: ['staging']
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
      +schema: gold
      +tags: ['gold']
      finance:
        +schema: gold_finance
      marketing:
        +schema: gold_marketing
```

```sql
-- dbt model: staging/stg_orders.sql
WITH source AS (
    SELECT * FROM {{ source('raw', 'orders') }}
),

renamed AS (
    SELECT
        order_id::VARCHAR(64)                   AS order_id,
        customer_id::VARCHAR(64)                AS customer_id,
        order_total::DECIMAL(12,2)              AS order_total,
        order_status::VARCHAR(32)               AS order_status,
        order_timestamp::TIMESTAMP_NTZ          AS order_timestamp,
        _loaded_at
    FROM source
)

SELECT * FROM renamed
```

```sql
-- dbt model: marts/fct_orders.sql (incremental)
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        cluster_by=['order_date', 'customer_id']
    )
}}

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
    {% if is_incremental() %}
    WHERE _loaded_at > (SELECT MAX(_loaded_at) FROM {{ this }})
    {% endif %}
),

enriched AS (
    SELECT
        o.order_id,
        o.customer_id,
        c.customer_segment,
        o.order_total,
        o.order_status,
        o.order_timestamp,
        DATE(o.order_timestamp)         AS order_date,
        o._loaded_at
    FROM orders o
    LEFT JOIN {{ ref('dim_customers') }} c
        ON o.customer_id = c.customer_id
)

SELECT * FROM enriched
```

---

## Data Quality Checks

Build quality gates into the pipeline to catch issues before they reach the gold layer.

```sql
-- dbt test: unique order_id
-- tests/assert_unique_order_id.sql
SELECT order_id, COUNT(*) AS cnt
FROM {{ ref('fct_orders') }}
GROUP BY order_id
HAVING COUNT(*) > 1;

-- dbt test: no null customer_id on completed orders
SELECT *
FROM {{ ref('fct_orders') }}
WHERE customer_id IS NULL
  AND order_status = 'completed';
```

```yaml
# dbt schema.yml — declarative tests
models:
  - name: fct_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: customer_id
        tests:
          - not_null:
              where: "order_status = 'completed'"
          - relationships:
              to: ref('dim_customers')
              field: customer_id
      - name: order_total
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 1000000
      - name: order_date
        tests:
          - not_null
          - dbt_utils.not_accepted_values:
              values: ['1970-01-01']
```

---

## Late-Arriving Data

Handle records that arrive after their partition has already been processed.

```sql
-- Reprocess affected partitions when late data arrives
-- Step 1: Identify affected dates from new arrivals
CREATE TEMPORARY TABLE _late_dates AS
SELECT DISTINCT DATE(event_timestamp) AS affected_date
FROM bronze.raw_events
WHERE _loaded_at > (SELECT MAX(_loaded_at) FROM silver.events)
  AND DATE(event_timestamp) < CURRENT_DATE() - 1;

-- Step 2: Reprocess only those dates
DELETE FROM silver.events
WHERE event_date IN (SELECT affected_date FROM _late_dates);

INSERT INTO silver.events
SELECT
    event_id,
    user_id,
    event_name,
    event_timestamp,
    DATE(event_timestamp) AS event_date,
    CURRENT_TIMESTAMP()   AS _loaded_at
FROM bronze.raw_events
WHERE DATE(event_timestamp) IN (SELECT affected_date FROM _late_dates);
```
