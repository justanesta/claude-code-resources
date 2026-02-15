---
name: data-eng-warehouse-patterns
description: Patterns and best practices for cloud data warehouses (Snowflake, BigQuery, Redshift), lakehouse architectures, Data Vault 2.0, and ELT pipeline design
---

# Data Warehouse Patterns

## Core Principles

1. **ELT over ETL** — Load raw data into the warehouse first, then transform using SQL. Modern warehouses have the compute power to handle transformations at scale, eliminating fragile middleware.
2. **Layered architecture** — Organize data into staging (raw), transformation (cleaned/conformed), and presentation (business-ready) layers. Each layer has clear ownership and SLAs.
3. **Immutable raw data** — Never modify source data after landing. Treat the raw layer as an append-only audit log. All transformations produce new tables or views downstream.
4. **Schema-on-read flexibility** — Semi-structured data (JSON, Avro, Parquet) can be loaded without predefined schemas, then parsed and typed during transformation.
5. **Cost-aware design** — Warehouse compute is elastic but not free. Partition, cluster, and materialize strategically to minimize scan volume and compute spend.

---

## ELT vs ETL Architecture

Modern cloud warehouses favor ELT because transformations run inside the warehouse engine, leveraging massive parallel processing. External ETL tools add latency, maintenance burden, and failure points.

```sql
-- ELT pattern: land raw JSON, then transform in-warehouse
-- Step 1: Load raw data into staging
COPY INTO raw.stripe_events
FROM @s3_stage/stripe/
FILE_FORMAT = (TYPE = JSON);

-- Step 2: Transform with SQL into clean layer
CREATE OR REPLACE TABLE cleaned.payments AS
SELECT
    raw:id::STRING                          AS event_id,
    raw:data:object:amount::NUMBER / 100    AS amount_dollars,
    raw:data:object:currency::STRING        AS currency,
    raw:created::TIMESTAMP_NTZ              AS event_timestamp,
    CURRENT_TIMESTAMP()                     AS _loaded_at
FROM raw.stripe_events
WHERE raw:type::STRING = 'charge.succeeded';
```

See [elt-pipeline-patterns](references/elt-pipeline-patterns.md) for: medallion architecture, incremental loading strategies, staging layer design.

---

## Snowflake Patterns

Snowflake separates storage and compute with virtual warehouses. Use multi-cluster warehouses for concurrency, and leverage time travel and zero-copy clones for development.

```sql
-- Create a warehouse sized for heavy transformation workloads
CREATE WAREHOUSE transform_wh
    WAREHOUSE_SIZE = 'X-LARGE'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 4
    SCALING_POLICY = 'STANDARD';

-- Cluster a large fact table on commonly filtered columns
ALTER TABLE analytics.fct_orders
    CLUSTER BY (order_date, region_id);

-- Use time travel to recover from bad writes
SELECT * FROM analytics.fct_orders
    AT(OFFSET => -3600);  -- state from 1 hour ago
```

See [snowflake-patterns](references/snowflake-patterns.md) for: warehouse sizing guidelines, external stages, COPY INTO options, clustering key selection, time travel and cloning.

---

## BigQuery Patterns

BigQuery is serverless — there are no clusters to manage. Optimize cost by partitioning tables, clustering on high-cardinality filter columns, and using materialized views to accelerate repeated queries.

```sql
-- Partitioned and clustered table for event analytics
CREATE TABLE analytics.user_events (
    event_id        STRING NOT NULL,
    user_id         STRING NOT NULL,
    event_name      STRING,
    event_params    ARRAY<STRUCT<key STRING, value STRING>>,
    device          STRUCT<category STRING, os STRING, browser STRING>,
    event_timestamp TIMESTAMP NOT NULL,
    _partition_date DATE NOT NULL
)
PARTITION BY _partition_date
CLUSTER BY user_id, event_name
OPTIONS (
    partition_expiration_days = 365,
    require_partition_filter  = TRUE
);
```

See [bigquery-patterns](references/bigquery-patterns.md) for: partition strategies, nested/repeated fields, materialized views, BI Engine reservations, slot management.

---

## Redshift Patterns

Redshift uses a shared-nothing MPP architecture. Distribution keys control how data is spread across nodes, and sort keys define on-disk ordering for range-restricted scans.

```sql
-- Fact table with optimized distribution and sort keys
CREATE TABLE analytics.fct_page_views (
    page_view_id    BIGINT IDENTITY(1,1),
    session_id      VARCHAR(64)     NOT NULL,
    user_id         BIGINT          DISTKEY,
    page_url        VARCHAR(2048),
    referrer_url    VARCHAR(2048),
    view_duration   INTEGER,
    view_timestamp  TIMESTAMP       SORTKEY,
    device_type     VARCHAR(32),
    country_code    VARCHAR(2)
)
DISTSTYLE KEY
COMPOUND SORTKEY (view_timestamp, user_id);
```

See [redshift-patterns](references/redshift-patterns.md) for: distribution styles (KEY, ALL, EVEN, AUTO), sort key types, COPY from S3, WLM configuration, Redshift Spectrum.

---

## Lakehouse Architecture

Lakehouse combines the low-cost storage of data lakes with the ACID transactions and performance of data warehouses. Open table formats like Apache Iceberg and Delta Lake enable this convergence.

```sql
-- Apache Iceberg table creation in Snowflake (external volume)
CREATE ICEBERG TABLE bronze.web_clickstream (
    click_id        STRING,
    session_id      STRING,
    url             STRING,
    referrer        STRING,
    user_agent      STRING,
    click_timestamp TIMESTAMP,
    _loaded_at      TIMESTAMP
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'iceberg_s3_vol'
BASE_LOCATION = 'clickstream/'
FILE_FORMAT = (TYPE = PARQUET);

-- Time travel with Iceberg snapshots
SELECT * FROM bronze.web_clickstream
    AT(TIMESTAMP => '2026-02-13 10:00:00'::TIMESTAMP);
```

See [lakehouse-patterns](references/lakehouse-patterns.md) for: Iceberg vs Delta Lake comparison, table format internals, schema evolution, partition evolution, time travel mechanics.

---

## Data Vault 2.0 Overview

Data Vault 2.0 is a modeling methodology for enterprise data warehouses. It separates structural data (hubs, links) from descriptive data (satellites), enabling parallel loading and full historical tracking.

```sql
-- Hub: business key registry for customers
CREATE TABLE raw_vault.hub_customer (
    hub_customer_hk     BINARY(32)      NOT NULL,  -- SHA-256 hash key
    customer_bk         VARCHAR(64)     NOT NULL,  -- business key
    load_timestamp      TIMESTAMP_NTZ   NOT NULL,
    record_source       VARCHAR(128)    NOT NULL,
    CONSTRAINT pk_hub_customer PRIMARY KEY (hub_customer_hk)
);

-- Satellite: descriptive attributes with full history
CREATE TABLE raw_vault.sat_customer_details (
    hub_customer_hk     BINARY(32)      NOT NULL,
    load_timestamp      TIMESTAMP_NTZ   NOT NULL,
    load_end_timestamp  TIMESTAMP_NTZ,
    hash_diff           BINARY(32)      NOT NULL,  -- change detection
    first_name          VARCHAR(128),
    last_name           VARCHAR(128),
    email               VARCHAR(256),
    phone               VARCHAR(32),
    record_source       VARCHAR(128)    NOT NULL,
    CONSTRAINT pk_sat_cust PRIMARY KEY (hub_customer_hk, load_timestamp)
);
```

See [data-vault-patterns](references/data-vault-patterns.md) for: hub/link/satellite design rules, hash key generation, point-in-time tables, bridge tables, business vault.

---

## Anti-Patterns

| Avoid | Use Instead |
|---|---|
| Transforming data outside the warehouse in Python/Spark when SQL suffices | ELT: load raw, transform with SQL inside the warehouse |
| Single monolithic warehouse/cluster for all workloads | Separate warehouses per workload (ETL, BI, ad-hoc) |
| No partitioning on large tables (full table scans) | Partition on date/time columns; require partition filters |
| Using `SELECT *` in production queries and views | Explicit column lists to reduce scan volume and breakage risk |
| Storing all history in slowly changing dimension type 1 (overwrite) | Use SCD type 2 or Data Vault satellites for full history |
| Hard-deleting rows from raw/staging layers | Soft-delete with `_deleted_at` flag; keep raw data immutable |
| Running large transforms during peak BI query hours | Schedule heavy transforms during off-peak windows |
| Skipping clustering/sort keys on frequently filtered columns | Profile query patterns and cluster on top 2-3 filter columns |
| Loading many small files (small file problem) | Batch files to 100-250 MB compressed before loading |
| Granting broad warehouse access without resource monitors | Use resource monitors and per-team warehouse isolation |

---

## Performance

- **Partition pruning** eliminates scanning irrelevant data segments. Always partition fact tables by date and enforce partition filters in BigQuery.
- **Clustering** physically co-locates related rows. Choose 2-4 high-cardinality columns that appear in WHERE and JOIN clauses.
- **Materialized views** pre-compute expensive aggregations. Use them for dashboards that hit the same GROUP BY patterns repeatedly.
- **Result caching** is automatic in most warehouses. Avoid unnecessary `CURRENT_TIMESTAMP()` or non-deterministic functions in cached queries.
- **Warehouse sizing** should match workload: upsize for large batch transforms, downsize for light interactive queries. Auto-suspend aggressively (60-300 seconds).
- **Compression** is automatic in columnar warehouses but file format matters at ingestion — prefer Parquet or ORC over CSV for bulk loads.
- **Concurrency scaling** (Snowflake) and flex slots (BigQuery) handle burst workloads without over-provisioning base capacity.
- **Query profiling** is essential. Use `EXPLAIN`, query history views, and warehouse utilization dashboards to find bottlenecks before optimizing blindly.

---

source: Cloud data warehouse documentation (Snowflake, BigQuery, Redshift), Data Vault 2.0 methodology, Apache Iceberg and Delta Lake specifications, dbt best practices
