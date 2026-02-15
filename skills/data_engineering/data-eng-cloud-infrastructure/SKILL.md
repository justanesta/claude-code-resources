---
name: Data Engineering Cloud Infrastructure
description: Patterns for building and managing cloud data infrastructure on AWS and GCP using Infrastructure as Code, data lake architectures, cost optimization, and security best practices.
---

# Data Engineering Cloud Infrastructure

## Core Principles

1. **Infrastructure as Code (IaC) First** — Every resource is defined in version-controlled Terraform or equivalent. No manual console changes. Reproducible environments across dev, staging, and production.

2. **Separation of Storage and Compute** — Store data in object storage (S3/GCS) and attach compute engines (Athena, BigQuery, Spark) independently. Scale each layer on its own schedule and budget.

3. **Layered Data Architecture** — Organize data into raw, cleaned, and curated layers with clear contracts between them. Each layer has its own schema validation, retention policy, and access controls.

4. **Cost-Aware Design from Day One** — Choose file formats, partitioning strategies, and compute tiers based on query patterns and budget. Monitor spend continuously with alerts and automated shutdowns.

5. **Least-Privilege Security** — Grant the minimum permissions necessary. Use service accounts with scoped IAM roles, encrypt data at rest and in transit, and isolate workloads with VPC boundaries.

## AWS Data Stack

AWS provides a mature ecosystem for data engineering: S3 for storage, Glue for cataloging and ETL, Athena for ad-hoc queries, and Redshift for warehousing.

```python
# Glue ETL job reading partitioned Parquet from S3
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from pyspark.context import SparkContext

args = getResolvedOptions(sys.argv, ["JOB_NAME", "source_path", "target_path"])
sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session

# Read from raw layer with push-down predicate
raw_df = spark.read.parquet(args["source_path"]).filter(
    "event_date >= '2025-01-01' AND event_date < '2025-02-01'"
)

# Deduplicate and write to cleaned layer
cleaned_df = raw_df.dropDuplicates(["event_id"]).repartition("event_date")
cleaned_df.write.partitionBy("event_date").mode("overwrite").parquet(args["target_path"])
```

See [aws-data-stack](references/aws-data-stack.md) for: S3 lifecycle policies, Glue crawlers, Athena optimization, Redshift Serverless configuration, and Step Functions orchestration.

## GCP Data Stack

GCP centers on BigQuery as an integrated storage-plus-compute warehouse, with GCS for staging, Dataflow for streaming, and Cloud Composer for orchestration.

```sql
-- BigQuery partitioned and clustered table for event analytics
CREATE TABLE IF NOT EXISTS `project.analytics.user_events`
(
    event_id STRING NOT NULL,
    user_id STRING NOT NULL,
    event_type STRING NOT NULL,
    event_payload JSON,
    event_timestamp TIMESTAMP NOT NULL,
    processing_date DATE NOT NULL
)
PARTITION BY processing_date
CLUSTER BY user_id, event_type
OPTIONS (
    partition_expiration_days = 365,
    require_partition_filter = TRUE,
    description = 'User events partitioned by date, clustered for fast user lookups'
);
```

See [gcp-data-stack](references/gcp-data-stack.md) for: BigQuery slots and reservations, Dataflow pipeline patterns, Pub/Sub exactly-once delivery, and Cloud Composer DAGs.

## Terraform for Data Infrastructure

Define all cloud resources declaratively. Use modules to encapsulate reusable patterns like data lake buckets, warehouse clusters, and IAM role bindings.

```hcl
# Terraform module for a data lake S3 bucket with lifecycle rules
module "data_lake_raw" {
  source      = "./modules/data-lake-bucket"
  bucket_name = "acme-data-lake-raw-${var.environment}"
  environment = var.environment

  lifecycle_rules = [
    {
      id                  = "archive-old-data"
      prefix              = "events/"
      transition_days     = 90
      transition_class    = "GLACIER"
      expiration_days     = 730
    }
  ]

  versioning_enabled    = true
  encryption_kms_key_id = var.kms_key_arn

  tags = {
    Team        = "data-engineering"
    CostCenter  = "analytics"
    DataLayer   = "raw"
  }
}
```

See [terraform-data-infra](references/terraform-data-infra.md) for: module patterns for S3/GCS, warehouse provisioning, IAM role definitions, remote state management, and environment promotion.

## Data Lake Architecture

Organize object storage into layers with strict naming conventions, partitioning by query-relevant columns, and optimized file formats.

```python
# Write DataFrame to data lake with Hive-style partitioning and Parquet
from pyarrow import parquet as pq
import pyarrow as pa

# Target ~128 MB files for optimal Athena/BigQuery performance
TARGET_FILE_SIZE = 128 * 1024 * 1024  # 128 MB

def write_to_data_lake(df, base_path, partition_cols):
    """Write pandas DataFrame as partitioned Parquet to data lake."""
    table = pa.Table.from_pandas(df)
    pq.write_to_dataset(
        table,
        root_path=base_path,
        partition_cols=partition_cols,
        compression="snappy",
        max_rows_per_file=1_000_000,
        existing_data_behavior="overwrite_or_ignore",
    )

# Usage: s3://acme-data-lake-raw/events/event_date=2025-01-15/part-0001.parquet
write_to_data_lake(events_df, "s3://acme-data-lake-raw/events", ["event_date"])
```

See [data-lake-patterns](references/data-lake-patterns.md) for: partitioning strategies, Parquet vs ORC vs Avro trade-offs, small file compaction, schema evolution, and Delta Lake/Iceberg table formats.

## Cost Optimization Patterns

Cloud data costs accumulate in storage, compute, and data transfer. Target each category with specific strategies.

```yaml
# AWS cost monitoring with CloudWatch alarms
Resources:
  DataPipelineBudgetAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: data-pipeline-daily-spend
      AlarmDescription: Alert when daily data pipeline spend exceeds $500
      Namespace: AWS/Billing
      MetricName: EstimatedCharges
      Statistic: Maximum
      Period: 86400
      EvaluationPeriods: 1
      Threshold: 500
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref DataEngineeringSlackSNSTopic
      Dimensions:
        - Name: ServiceName
          Value: AmazonAthena
```

See [cost-optimization](references/cost-optimization.md) for: storage tiering strategies, compute autoscaling, reserved and spot capacity, query cost controls, and data transfer optimization.

## Security and Access Control

Protect data with layered defenses: IAM policies scoped to specific resources, encryption for data at rest and in transit, and network isolation.

```hcl
# IAM role for a Glue ETL job with least-privilege S3 access
resource "aws_iam_role" "glue_etl_role" {
  name = "glue-etl-pipeline-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "glue-s3-scoped-access"
  role = aws_iam_role.glue_etl_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::acme-data-lake-raw-${var.environment}",
          "arn:aws:s3:::acme-data-lake-raw-${var.environment}/events/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::acme-data-lake-cleaned-${var.environment}/events/*"
      }
    ]
  })
}
```

See [security-patterns](references/security-patterns.md) for: cross-account access, encryption key management, VPC endpoints, column-level security in BigQuery and Redshift, and audit logging.

## Anti-Patterns

| Avoid | Use Instead |
|---|---|
| Creating resources manually in the cloud console | Define everything in Terraform with code review and CI/CD |
| Storing data as uncompressed CSV in object storage | Use columnar formats (Parquet/ORC) with Snappy compression |
| Single large unpartitioned table in the data lake | Partition by date or high-cardinality query column |
| Granting `s3:*` or `bigquery.admin` to service accounts | Scope IAM policies to specific buckets, prefixes, and actions |
| Running full-table scans without partition pruning | Always include partition column in WHERE clauses |
| Leaving dev/test clusters running 24/7 | Auto-terminate non-production resources on schedule |
| Storing all data in one storage class forever | Apply lifecycle policies to transition to cold/archive tiers |
| Hardcoding credentials in ETL scripts | Use IAM roles, service accounts, and secrets managers |
| Writing thousands of small files to object storage | Compact small files into 128-256 MB Parquet files |
| Using a single AWS account for all environments | Separate accounts per environment with cross-account roles |

## Performance

- **File sizing** — Target 128-256 MB per Parquet file for optimal query engine performance. Too many small files cause excessive list/open overhead; too few large files limit parallelism.
- **Partition pruning** — Design partitions around the most common WHERE clause filters (usually date). Athena and BigQuery skip entire partitions, reducing scanned data by orders of magnitude.
- **Columnar compression** — Parquet with Snappy gives the best balance of compression ratio and decompression speed. Dictionary encoding is automatic for low-cardinality columns.
- **Predicate pushdown** — Store column statistics (min/max) in Parquet row groups. Query engines skip row groups that cannot contain matching rows.
- **Cluster/sort keys** — In BigQuery use CLUSTER BY; in Redshift use SORTKEY. Co-locate frequently joined or filtered columns for block-level pruning.
- **Caching layers** — Use Athena query result caching, BigQuery BI Engine, or Redshift result caching to avoid re-scanning unchanged data.
- **Compute right-sizing** — Start with serverless (Athena, BigQuery on-demand) for unpredictable workloads. Switch to provisioned capacity when steady-state patterns emerge and cost savings exceed 30%.

source: Cloud provider documentation (AWS, GCP), Terraform Registry, Apache Parquet specification, Delta Lake and Apache Iceberg documentation.
