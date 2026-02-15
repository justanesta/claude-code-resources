# Data Lake Patterns Reference

Detailed patterns for partitioning strategies, file formats, compaction, schema evolution, and modern table formats.

## Storage Layer Architecture

```
s3://acme-data-lake-{layer}-{env}/{domain}/{table_name}/{partition_key}={value}/

Layers:
    raw/        Immutable landing zone, original format
    cleaned/    Deduplicated, validated, standardized schema
    curated/    Business-ready aggregates and feature tables
    sandbox/    Ad-hoc analyst explorations (auto-expire 30 days)
```

## Partitioning Strategies

### Date-Based Partitioning

```python
from pyspark.sql import SparkSession, functions as F

spark = SparkSession.builder.appName("partition-events").getOrCreate()
events_df = spark.read.parquet("s3://acme-data-lake-raw-prod/events/")

# Single-level date partition (best for daily batch queries)
events_df.write.partitionBy("event_date").mode("overwrite") \
    .parquet("s3://acme-data-lake-cleaned-prod/events/")

# Multi-level partition for high-volume streaming
events_with_parts = events_df \
    .withColumn("year", F.year("event_timestamp")) \
    .withColumn("month", F.format_string("%02d", F.month("event_timestamp"))) \
    .withColumn("day", F.format_string("%02d", F.dayofmonth("event_timestamp"))) \
    .withColumn("hour", F.format_string("%02d", F.hour("event_timestamp")))

events_with_parts.write.partitionBy("year", "month", "day", "hour") \
    .mode("append").parquet("s3://acme-data-lake-cleaned-prod/events_hourly/")
```

### Partition Sizing Guidelines

```
Rule of thumb: Each partition should contain 128 MB - 1 GB of data.

Too many partitions (< 1 MB each):    Excessive LIST calls, task overhead
Too few partitions (> 10 GB each):    Limited parallelism, wasted scans

Daily events: 50 GB raw -> partition by date         -> ~50 GB/partition (ok)
Hourly events: 50 GB raw -> partition by date+hour   -> ~2 GB/partition (good)
```

### Bucketing for Join Optimization

```python
# Both tables bucketed on the same key avoids shuffle
orders_df.write.bucketBy(64, "customer_id").sortBy("order_timestamp") \
    .mode("overwrite").saveAsTable("cleaned.orders_bucketed")

customers_df.write.bucketBy(64, "customer_id").sortBy("customer_id") \
    .mode("overwrite").saveAsTable("cleaned.customers_bucketed")

# Join is now shuffle-free (sort-merge join on co-located buckets)
joined = spark.sql("""
    SELECT o.*, c.customer_segment
    FROM cleaned.orders_bucketed o
    JOIN cleaned.customers_bucketed c ON o.customer_id = c.customer_id
    WHERE o.order_date = '2025-01-15'
""")
```

## File Format Comparison

```
Format   | Compression | Read Speed | Schema Evolution | Best For
---------|-------------|------------|------------------|---------------------------
Parquet  | Excellent   | Fast       | Good             | Analytics, columnar queries
ORC      | Excellent   | Fast       | Good             | Hive ecosystem, ACID tables
Avro     | Good        | Medium     | Excellent        | Streaming, row-level access
CSV      | Poor        | Slow       | None             | Never use in data lake
```

### Parquet Configuration

```python
import pyarrow as pa
import pyarrow.parquet as pq

table = pa.Table.from_pandas(df)

# Optimal settings for analytics workloads
pq.write_table(
    table, "events.snappy.parquet",
    row_group_size=128 * 1024 * 1024,   # 128 MB row groups
    compression="snappy",                # Best speed/ratio balance
    write_statistics=True,               # Enable min/max for predicate pushdown
    use_dictionary=True,                 # Great for low-cardinality strings
)

# For archival / cold data, use zstd for maximum compression
pq.write_table(table, "events.zstd.parquet", compression="zstd", compression_level=9)
```

## Small File Compaction

```python
from pyspark.sql import SparkSession
import datetime

spark = SparkSession.builder.appName("compact-small-files").getOrCreate()

def compact_partition(source_path, target_file_size_mb=128):
    """Compact small files into optimally-sized Parquet files."""
    df = spark.read.parquet(source_path)
    total_bytes = sum(f.length for f in
        spark._jvm.org.apache.hadoop.fs.Path(source_path)
        .getFileSystem(spark._jsc.hadoopConfiguration())
        .listStatus(spark._jvm.org.apache.hadoop.fs.Path(source_path)))
    num_files = max(1, int(total_bytes / (target_file_size_mb * 1024 * 1024)))
    df.coalesce(num_files).write.mode("overwrite").parquet(source_path)

# Compact recent partitions
base_path = "s3://acme-data-lake-cleaned-prod/events"
for day_offset in range(7):
    dt = datetime.date.today() - datetime.timedelta(days=day_offset + 1)
    compact_partition(f"{base_path}/event_date={dt.isoformat()}")
```

## Schema Evolution

```python
import pyarrow as pa
import pyarrow.parquet as pq

# Original schema
schema_v1 = pa.schema([
    pa.field("event_id", pa.string(), nullable=False),
    pa.field("user_id", pa.string(), nullable=False),
    pa.field("event_type", pa.string(), nullable=False),
    pa.field("event_timestamp", pa.timestamp("ms"), nullable=False),
])

# Evolved schema: adding nullable columns is backward compatible
schema_v2 = pa.schema([
    pa.field("event_id", pa.string(), nullable=False),
    pa.field("user_id", pa.string(), nullable=False),
    pa.field("event_type", pa.string(), nullable=False),
    pa.field("event_timestamp", pa.timestamp("ms"), nullable=False),
    pa.field("session_id", pa.string(), nullable=True),   # New
    pa.field("device_type", pa.string(), nullable=True),   # New
])

# Reading v1 data with v2 schema fills new columns with NULL
df = pq.read_table("old_data.parquet", schema=schema_v2)
```

## Delta Lake and Apache Iceberg

### Delta Lake

```python
from delta import DeltaTable

# Write as Delta table
events_df.write.format("delta").partitionBy("event_date") \
    .mode("overwrite").save("s3://acme-data-lake-curated-prod/delta/events/")

# MERGE for upsert (CDC pattern)
delta_table = DeltaTable.forPath(spark, "s3://acme-data-lake-curated-prod/delta/events/")
delta_table.alias("target").merge(
    new_events_df.alias("source"), "target.event_id = source.event_id"
).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()

# Time travel and maintenance
historical_df = spark.read.format("delta").option("versionAsOf", 5) \
    .load("s3://acme-data-lake-curated-prod/delta/events/")
delta_table.optimize().executeCompaction()
delta_table.optimize().executeZOrderBy("user_id", "event_type")
```

### Apache Iceberg

```sql
-- Create Iceberg table with hidden partitioning
CREATE TABLE lakehouse.analytics.events (
    event_id STRING, user_id STRING, event_type STRING,
    event_timestamp TIMESTAMP, event_payload STRING
) USING iceberg
PARTITIONED BY (days(event_timestamp))
TBLPROPERTIES (
    'write.target-file-size-bytes' = '134217728',
    'write.parquet.compression-codec' = 'snappy'
);

-- Partition evolution without rewriting data
ALTER TABLE lakehouse.analytics.events ADD PARTITION FIELD hours(event_timestamp);

-- Expire old snapshots to reclaim storage
CALL lakehouse.system.expire_snapshots(
    table => 'analytics.events',
    older_than => TIMESTAMP '2025-01-01 00:00:00',
    retain_last => 10
);
```

## Edge Cases and Gotchas

- **Partition column in data** — Hive-style partitioning removes the partition column from file data. Ensure your schema expects this when reading with non-Hive-aware tools.
- **Empty partitions** — A partition directory with no files confuses some crawlers. Always write at least one file or skip creating the directory.
- **Clock skew in streaming** — Late-arriving events may land in wrong partitions. Use processing time for partitioning and event time as a column for queries.
- **Parquet footer reads** — Each Parquet file requires a footer read. With 10,000 small files, that is 10,000 S3 GET requests before any data is read.
- **Schema mismatch across partitions** — Different column types in older partitions cause Athena and Spark failures. Use Iceberg for safe schema evolution.
- **Decimal precision** — Parquet decimal types must match exactly between writer and reader. DECIMAL(10,2) cannot be read as DECIMAL(12,4) without explicit casting.
