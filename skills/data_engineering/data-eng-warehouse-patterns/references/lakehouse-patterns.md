# Lakehouse Architecture Patterns Reference

Detailed patterns for Apache Iceberg, Delta Lake, open table formats, time travel, schema evolution, and partition evolution.

---

## Apache Iceberg Overview

Iceberg is an open table format that brings ACID transactions, schema evolution, and time travel to data lakes. It works with Spark, Trino, Snowflake, and other engines.

```sql
-- Create an Iceberg table in Spark SQL
CREATE TABLE lakehouse.bronze.raw_orders (
    order_id        STRING      NOT NULL,
    customer_id     STRING      NOT NULL,
    product_id      STRING,
    quantity         INT,
    unit_price      DECIMAL(10,2),
    order_total     DECIMAL(12,2),
    order_status    STRING,
    order_timestamp TIMESTAMP,
    _loaded_at      TIMESTAMP
)
USING ICEBERG
PARTITIONED BY (days(order_timestamp))
TBLPROPERTIES (
    'format-version'    = '2',
    'write.format.default' = 'parquet',
    'write.parquet.compression-codec' = 'zstd',
    'write.metadata.delete-after-commit.enabled' = 'true',
    'write.metadata.previous-versions-max' = '100'
);
```

### Iceberg Architecture

Iceberg tables consist of three layers:

1. **Catalog** — Tracks the current metadata pointer (Hive Metastore, AWS Glue, Nessie, REST catalog)
2. **Metadata layer** — JSON metadata files, manifest lists, and manifest files that track data files and their statistics
3. **Data layer** — Parquet/ORC/Avro data files stored in object storage

---

## Delta Lake Overview

Delta Lake is an open-source storage layer that brings reliability to data lakes. Originally from Databricks, it uses a transaction log stored alongside data files.

```python
# Create a Delta table in PySpark
from delta.tables import DeltaTable
from pyspark.sql.types import StructType, StructField, StringType, TimestampType, DecimalType

schema = StructType([
    StructField("order_id", StringType(), False),
    StructField("customer_id", StringType(), False),
    StructField("product_id", StringType(), True),
    StructField("order_total", DecimalType(12, 2), True),
    StructField("order_status", StringType(), True),
    StructField("order_timestamp", TimestampType(), True),
])

# Create empty Delta table with partitioning
(spark.createDataFrame([], schema)
    .write
    .format("delta")
    .partitionBy("order_status")
    .option("delta.autoOptimize.optimizeWrite", "true")
    .option("delta.autoOptimize.autoCompact", "true")
    .saveAsTable("bronze.raw_orders"))
```

```sql
-- Create Delta table in Spark SQL
CREATE TABLE bronze.raw_events (
    event_id        STRING,
    user_id         STRING,
    event_name      STRING,
    event_params    MAP<STRING, STRING>,
    event_timestamp TIMESTAMP
)
USING DELTA
PARTITIONED BY (DATE(event_timestamp))
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true',
    'delta.logRetentionDuration' = 'interval 30 days',
    'delta.deletedFileRetentionDuration' = 'interval 7 days',
    'delta.autoOptimize.optimizeWrite' = 'true'
);
```

---

## Iceberg vs Delta Lake Comparison

| Feature | Apache Iceberg | Delta Lake |
|---|---|---|
| Transaction log | Metadata files + manifest lists | JSON transaction log (`_delta_log/`) |
| Format version | v1, v2 (row-level deletes) | Protocol versioned (reader/writer) |
| Engine support | Spark, Trino, Flink, Snowflake, BigQuery, Dremio | Spark, Trino, Flink, Databricks, Starburst |
| Schema evolution | Full (add, drop, rename, reorder columns) | Add columns, rename (with column mapping) |
| Partition evolution | Yes (change partitioning without rewriting) | No (must rewrite data) |
| Hidden partitioning | Yes (partition transforms are metadata-only) | No (explicit partition columns) |
| Time travel | Snapshot-based, configurable retention | Version-based, configurable retention |
| Row-level operations | Merge-on-read and copy-on-write | Merge-on-read (deletion vectors) and copy-on-write |
| Catalog requirement | Required (Hive, Glue, REST, Nessie) | Optional (self-describing via `_delta_log`) |

---

## Time Travel

Both formats support querying historical versions of data.

```sql
-- Iceberg: time travel by timestamp
SELECT * FROM lakehouse.bronze.raw_orders
FOR SYSTEM_TIME AS OF TIMESTAMP '2026-02-13 10:00:00';

-- Iceberg: time travel by snapshot ID
SELECT * FROM lakehouse.bronze.raw_orders
FOR SYSTEM_VERSION AS OF 7234891560348712;

-- Iceberg: list available snapshots
SELECT
    snapshot_id,
    committed_at,
    operation,
    summary['added-data-files']     AS files_added,
    summary['added-records']        AS records_added,
    summary['total-records']        AS total_records
FROM lakehouse.bronze.raw_orders.snapshots;

-- Delta Lake: time travel by version
SELECT * FROM bronze.raw_orders VERSION AS OF 42;

-- Delta Lake: time travel by timestamp
SELECT * FROM bronze.raw_orders TIMESTAMP AS OF '2026-02-13 10:00:00';

-- Delta Lake: view table history
DESCRIBE HISTORY bronze.raw_orders;
```

### Rollback Operations

```sql
-- Iceberg: rollback to a previous snapshot
CALL lakehouse.system.rollback_to_snapshot('bronze.raw_orders', 7234891560348712);

-- Iceberg: rollback to a timestamp
CALL lakehouse.system.rollback_to_timestamp('bronze.raw_orders', TIMESTAMP '2026-02-13 10:00:00');

-- Delta Lake: restore to a previous version
RESTORE TABLE bronze.raw_orders TO VERSION AS OF 42;

-- Delta Lake: restore to a timestamp
RESTORE TABLE bronze.raw_orders TO TIMESTAMP AS OF '2026-02-13 10:00:00';
```

---

## Schema Evolution

Modifying table structure without rewriting existing data files.

```sql
-- Iceberg: add columns
ALTER TABLE lakehouse.bronze.raw_orders
    ADD COLUMNS (
        shipping_address STRING AFTER order_status,
        discount_cents   BIGINT
    );

-- Iceberg: rename a column
ALTER TABLE lakehouse.bronze.raw_orders
    RENAME COLUMN order_total TO order_total_amount;

-- Iceberg: change column type (widening only)
ALTER TABLE lakehouse.bronze.raw_orders
    ALTER COLUMN quantity TYPE BIGINT;

-- Iceberg: reorder columns
ALTER TABLE lakehouse.bronze.raw_orders
    ALTER COLUMN discount_cents AFTER order_total_amount;

-- Delta Lake: add columns
ALTER TABLE bronze.raw_orders ADD COLUMNS (
    shipping_address STRING AFTER order_status,
    discount_cents   BIGINT
);

-- Delta Lake: rename columns (requires column mapping)
ALTER TABLE bronze.raw_orders SET TBLPROPERTIES (
    'delta.minReaderVersion' = '2',
    'delta.minWriterVersion' = '5',
    'delta.columnMapping.mode' = 'name'
);
ALTER TABLE bronze.raw_orders RENAME COLUMN order_total TO order_total_amount;
```

---

## Partition Evolution (Iceberg)

Iceberg supports changing partition schemes without rewriting data. Old data retains the old partitioning; new data uses the new scheme.

```sql
-- Start with daily partitioning
CREATE TABLE lakehouse.silver.user_activity (
    user_id         STRING,
    activity_type   STRING,
    activity_time   TIMESTAMP,
    details         STRING
)
USING ICEBERG
PARTITIONED BY (days(activity_time));

-- Data grows; switch to hourly partitioning for recent data
ALTER TABLE lakehouse.silver.user_activity
    ADD PARTITION FIELD hours(activity_time);

-- Drop the old daily partition spec (old data files remain as-is)
ALTER TABLE lakehouse.silver.user_activity
    DROP PARTITION FIELD days(activity_time);

-- Add a secondary partition on activity_type
ALTER TABLE lakehouse.silver.user_activity
    ADD PARTITION FIELD activity_type;
```

---

## Table Maintenance

Both formats require periodic maintenance for optimal performance.

```sql
-- Iceberg: compact small files into larger ones
CALL lakehouse.system.rewrite_data_files(
    table => 'bronze.raw_orders',
    options => map('target-file-size-bytes', '134217728')  -- 128 MB
);

-- Iceberg: expire old snapshots to reclaim storage
CALL lakehouse.system.expire_snapshots(
    table => 'bronze.raw_orders',
    older_than => TIMESTAMP '2026-02-07 00:00:00',
    retain_last => 10
);

-- Iceberg: remove orphan files not referenced by any snapshot
CALL lakehouse.system.remove_orphan_files(
    table => 'bronze.raw_orders',
    older_than => TIMESTAMP '2026-02-10 00:00:00'
);

-- Delta Lake: optimize (compact small files)
OPTIMIZE bronze.raw_orders
    WHERE order_timestamp >= '2026-02-01';

-- Delta Lake: Z-ORDER for multi-dimensional clustering
OPTIMIZE bronze.raw_orders
    ZORDER BY (customer_id, order_status);

-- Delta Lake: vacuum old files
VACUUM bronze.raw_orders RETAIN 168 HOURS;
```

---

## Merge (Upsert) Patterns

```sql
-- Iceberg: MERGE INTO for upserts
MERGE INTO lakehouse.silver.dim_customers t
USING lakehouse.bronze.raw_customers s
    ON t.customer_id = s.customer_id
WHEN MATCHED AND s.updated_at > t.updated_at THEN
    UPDATE SET
        t.customer_name  = s.customer_name,
        t.email          = s.email,
        t.phone          = s.phone,
        t.updated_at     = s.updated_at
WHEN NOT MATCHED THEN
    INSERT (customer_id, customer_name, email, phone, created_at, updated_at)
    VALUES (s.customer_id, s.customer_name, s.email, s.phone, s.created_at, s.updated_at);
```

```python
# Delta Lake: MERGE with Python DeltaTable API
from delta.tables import DeltaTable

target = DeltaTable.forName(spark, "silver.dim_customers")
source = spark.table("bronze.raw_customers")

(target.alias("t")
    .merge(source.alias("s"), "t.customer_id = s.customer_id")
    .whenMatchedUpdate(
        condition="s.updated_at > t.updated_at",
        set={
            "customer_name": "s.customer_name",
            "email": "s.email",
            "phone": "s.phone",
            "updated_at": "s.updated_at"
        }
    )
    .whenNotMatchedInsertAll()
    .execute())
```
