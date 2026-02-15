# AWS Data Stack Reference

Detailed patterns for building data infrastructure on AWS using S3, Glue, Athena, Redshift Serverless, and Step Functions.

## S3 Data Lake Patterns

### Bucket Structure

```
s3://acme-data-lake-raw-prod/
    events/event_date=2025-01-15/part-00001.snappy.parquet
    clickstream/year=2025/month=01/day=15/clickstream-001.snappy.parquet
s3://acme-data-lake-cleaned-prod/
    events/event_date=2025-01-15/events-cleaned-00001.snappy.parquet
s3://acme-data-lake-curated-prod/
    analytics/daily_user_metrics/metric_date=2025-01-15/daily_metrics.snappy.parquet
```

### S3 Lifecycle Policies

```python
import boto3

s3_client = boto3.client("s3")

lifecycle_config = {
    "Rules": [
        {
            "ID": "raw-data-tiering",
            "Status": "Enabled",
            "Filter": {"Prefix": "events/"},
            "Transitions": [
                {"Days": 30, "StorageClass": "STANDARD_IA"},
                {"Days": 90, "StorageClass": "GLACIER"},
                {"Days": 365, "StorageClass": "DEEP_ARCHIVE"},
            ],
            "Expiration": {"Days": 2555},  # 7 years for compliance
        },
        {
            "ID": "cleanup-incomplete-uploads",
            "Status": "Enabled",
            "Filter": {"Prefix": ""},
            "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7},
        },
    ]
}

s3_client.put_bucket_lifecycle_configuration(
    Bucket="acme-data-lake-raw-prod",
    LifecycleConfiguration=lifecycle_config,
)
```

### S3 Event Notifications for Pipeline Triggers

```python
import boto3

glue_client = boto3.client("glue")

def handler(event, context):
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        if not key.startswith("events/event_date="):
            continue
        partition_value = key.split("event_date=")[1].split("/")[0]
        glue_client.start_job_run(
            JobName="events-raw-to-cleaned",
            Arguments={
                "--source_path": f"s3://{bucket}/events/event_date={partition_value}/",
                "--target_path": f"s3://acme-data-lake-cleaned-prod/events/event_date={partition_value}/",
            },
        )
```

## AWS Glue ETL

### Glue Job with Bookmarks

```python
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F

args = getResolvedOptions(sys.argv, ["JOB_NAME"])
sc = SparkContext()
glue_context = GlueContext(sc)
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

raw_dyf = glue_context.create_dynamic_frame.from_catalog(
    database="raw_data",
    table_name="events",
    transformation_ctx="raw_events",  # Required for bookmarks
    additional_options={"boundedFiles": 1000},
)

cleaned_df = (
    raw_dyf.toDF()
    .dropDuplicates(["event_id"])
    .withColumn("processed_at", F.current_timestamp())
    .filter(F.col("event_type").isNotNull())
)

cleaned_dyf = DynamicFrame.fromDF(cleaned_df, glue_context, "cleaned_events")
glue_context.write_dynamic_frame.from_options(
    frame=cleaned_dyf,
    connection_type="s3",
    connection_options={"path": "s3://acme-data-lake-cleaned-prod/events/", "partitionKeys": ["event_date"]},
    format="glueparquet",
    format_options={"compression": "snappy"},
    transformation_ctx="write_cleaned",
)
job.commit()
```

## Athena Query Optimization

```sql
-- Always include partition column to avoid full scans ($5 per TB scanned)
SELECT
    event_type,
    COUNT(*) AS event_count,
    COUNT(DISTINCT user_id) AS unique_users,
    AVG(CAST(JSON_EXTRACT_SCALAR(event_payload, '$.duration_ms') AS DOUBLE)) AS avg_duration
FROM cleaned_data.events
WHERE event_date BETWEEN DATE '2025-01-01' AND DATE '2025-01-31'
  AND event_type IN ('page_view', 'click', 'purchase')
GROUP BY event_type
ORDER BY event_count DESC;

-- CTAS to materialize expensive queries as Parquet
CREATE TABLE curated_data.daily_user_metrics
WITH (
    format = 'PARQUET',
    parquet_compression = 'SNAPPY',
    partitioned_by = ARRAY['metric_date'],
    external_location = 's3://acme-data-lake-curated-prod/analytics/daily_user_metrics/',
    bucketed_by = ARRAY['user_id'],
    bucket_count = 32
) AS
SELECT
    user_id,
    COUNT(*) AS total_events,
    COUNT_IF(event_type = 'purchase') AS purchases,
    SUM(CAST(JSON_EXTRACT_SCALAR(event_payload, '$.amount') AS DECIMAL(10,2))) AS total_spend,
    event_date AS metric_date
FROM cleaned_data.events
WHERE event_date = DATE '2025-01-15'
GROUP BY user_id, event_date;
```

## Redshift Serverless

```python
import boto3

redshift_serverless = boto3.client("redshift-serverless")

redshift_serverless.create_namespace(
    namespaceName="analytics-prod",
    dbName="analytics",
    adminUsername="admin",
    adminUserPassword="RETRIEVED_FROM_SECRETS_MANAGER",
    defaultIamRoleArn="arn:aws:iam::123456789012:role/RedshiftServerlessRole",
    kmsKeyId="arn:aws:kms:us-east-1:123456789012:key/abc-123",
    logExports=["userlog", "connectionlog", "useractivitylog"],
)

redshift_serverless.create_workgroup(
    workgroupName="analytics-prod-wg",
    namespaceName="analytics-prod",
    baseCapacity=32,   # RPUs: 32 to 512
    maxCapacity=128,
    publiclyAccessible=False,
    subnetIds=["subnet-abc123", "subnet-def456"],
    securityGroupIds=["sg-analytics-redshift"],
    configParameters=[
        {"parameterKey": "max_query_execution_time", "parameterValue": "600"},
        {"parameterKey": "enable_result_cache_for_session", "parameterValue": "true"},
    ],
)
```

## Step Functions Orchestration

```json
{
  "Comment": "Daily data pipeline: ingest, transform, validate, publish",
  "StartAt": "RunGlueCrawler",
  "States": {
    "RunGlueCrawler": {
      "Type": "Task",
      "Resource": "arn:aws:states:::glue:startCrawler.sync",
      "Parameters": { "Name": "raw-events-crawler" },
      "Next": "RunGlueETL",
      "Retry": [{ "ErrorEquals": ["States.ALL"], "MaxAttempts": 2, "BackoffRate": 2 }]
    },
    "RunGlueETL": {
      "Type": "Task",
      "Resource": "arn:aws:states:::glue:startJobRun.sync",
      "Parameters": {
        "JobName": "events-raw-to-cleaned",
        "Arguments": { "--partition_value.$": "$.partition_date" }
      },
      "Next": "RunDataQualityChecks",
      "Catch": [{ "ErrorEquals": ["States.ALL"], "Next": "PipelineFailed" }]
    },
    "RunDataQualityChecks": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:123456789012:function:data-quality-checks",
      "Next": "QualityGate"
    },
    "QualityGate": {
      "Type": "Choice",
      "Choices": [{ "Variable": "$.quality_passed", "BooleanEquals": true, "Next": "PipelineSucceeded" }],
      "Default": "PipelineFailed"
    },
    "PipelineSucceeded": { "Type": "Succeed" },
    "PipelineFailed": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:123456789012:function:alert-pipeline-failure",
      "Next": "FailState"
    },
    "FailState": { "Type": "Fail", "Cause": "Data pipeline failed" }
  }
}
```

## Edge Cases and Gotchas

- **Glue catalog lag** — S3 provides strong read-after-write consistency, but Glue catalog updates may lag. Always run `MSCK REPAIR TABLE` or `ALTER TABLE ADD PARTITION` after writing new partitions.
- **Athena query timeout** — Default 30-minute timeout. For large backfills, break queries into per-partition batches.
- **Glue job memory** — Default 10 workers with G.1X (16 GB each). For skewed data, increase to G.2X or add more workers. Monitor with CloudWatch `glue.driver.jvm.heap.usage`.
- **Redshift Serverless cold start** — Initial queries after idle timeout take 15-30 seconds. Keep a lightweight heartbeat query for latency-sensitive dashboards.
- **S3 request rate** — S3 supports 5,500 GET and 3,500 PUT requests per prefix per second. Distribute files across prefixes if you exceed these limits.
- **Cross-region transfer costs** — Data transfer between regions is $0.02/GB. Keep compute and storage in the same region.
