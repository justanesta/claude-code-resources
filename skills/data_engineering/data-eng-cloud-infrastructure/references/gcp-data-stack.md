# GCP Data Stack Reference

Detailed patterns for building data infrastructure on Google Cloud using BigQuery, GCS, Dataflow, Pub/Sub, and Cloud Composer.

## Google Cloud Storage (GCS)

```python
from google.cloud import storage

client = storage.Client()
bucket = client.create_bucket("acme-data-lake-raw-prod", location="US", storage_class="STANDARD")

# Enable uniform bucket-level access (recommended over ACLs)
bucket.iam_configuration.uniform_bucket_level_access_enabled = True
bucket.patch()

# Add lifecycle rules for cost management
bucket.add_lifecycle_delete_rule(age=2555)  # 7 years
bucket.add_lifecycle_set_storage_class_rule("NEARLINE", age=30)
bucket.add_lifecycle_set_storage_class_rule("COLDLINE", age=90)
bucket.add_lifecycle_set_storage_class_rule("ARCHIVE", age=365)
bucket.patch()

# Configure Pub/Sub notification for new objects
notification = bucket.notification(
    topic_name="projects/acme-analytics/topics/raw-data-landing",
    payload_format="JSON_API_V1",
    event_types=["OBJECT_FINALIZE"],
    blob_name_prefix="events/",
)
notification.create()
```

## BigQuery

### Dataset and Table Management

```sql
CREATE SCHEMA IF NOT EXISTS `acme-analytics.warehouse`
OPTIONS (
    location = 'US',
    default_partition_expiration_days = 365,
    default_kms_key_name = 'projects/acme-analytics/locations/us/keyRings/bq-ring/cryptoKeys/bq-key',
    description = 'Core analytics warehouse tables'
);

CREATE TABLE IF NOT EXISTS `acme-analytics.warehouse.orders`
(
    order_id STRING NOT NULL,
    customer_id STRING NOT NULL,
    product_category STRING NOT NULL,
    order_status STRING NOT NULL,
    order_total NUMERIC(12, 2),
    item_count INT64,
    order_timestamp TIMESTAMP NOT NULL
)
PARTITION BY DATE(order_timestamp)
CLUSTER BY customer_id, product_category
OPTIONS (
    partition_expiration_days = 730,
    require_partition_filter = TRUE,
    labels = [("team", "data-engineering"), ("pii", "false")]
);
```

### BigQuery Slots and Reservations

```python
from google.cloud import bigquery_reservation_v1

client = bigquery_reservation_v1.ReservationServiceClient()

# Create reservation with autoscaling
reservation = client.create_reservation(
    parent="projects/acme-analytics/locations/US",
    reservation_id="analytics-prod",
    reservation=bigquery_reservation_v1.Reservation(
        slot_capacity=400,
        autoscale=bigquery_reservation_v1.Reservation.Autoscale(max_slots=200),
        ignore_idle_slots=False,
    ),
)

# Assign the reservation to a project
client.create_assignment(
    parent=reservation.name,
    assignment=bigquery_reservation_v1.Assignment(
        assignee="projects/acme-analytics",
        job_type=bigquery_reservation_v1.Assignment.JobType.QUERY,
    ),
)
```

### Scheduled Query for Daily Aggregations

```sql
DECLARE run_date DATE DEFAULT @run_date;

CREATE OR REPLACE TABLE `acme-analytics.warehouse.daily_order_metrics`
PARTITION BY metric_date
CLUSTER BY shipping_region
AS
SELECT
    DATE(order_timestamp) AS metric_date,
    shipping_region,
    COUNT(*) AS order_count,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(order_total) AS gross_revenue,
    AVG(order_total) AS avg_order_value,
    COUNTIF(order_status = 'returned') AS return_count
FROM `acme-analytics.warehouse.orders`
WHERE DATE(order_timestamp) = run_date
GROUP BY metric_date, shipping_region;
```

## Dataflow (Apache Beam)

### Streaming Pipeline with Dead Letter Queue

```python
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions, StandardOptions
from apache_beam.io.gcp.pubsub import ReadFromPubSub
from apache_beam.io.gcp.bigquery import WriteToBigQuery, BigQueryDisposition
import json

class ParseEvent(beam.DoFn):
    def process(self, element):
        try:
            record = json.loads(element.decode("utf-8"))
            yield {
                "event_id": record["event_id"],
                "user_id": record["user_id"],
                "event_type": record["event_type"],
                "event_timestamp": record["timestamp"],
            }
        except (json.JSONDecodeError, KeyError) as e:
            yield beam.pvalue.TaggedOutput("dead_letter", {
                "raw_message": element.decode("utf-8", errors="replace"),
                "error": str(e),
            })

options = PipelineOptions([
    "--project=acme-analytics", "--region=us-central1",
    "--runner=DataflowRunner", "--streaming",
    "--autoscaling_algorithm=THROUGHPUT_BASED",
    "--max_num_workers=20", "--enable_streaming_engine",
])

with beam.Pipeline(options=options) as pipeline:
    events, dead_letters = (
        pipeline
        | "ReadPubSub" >> ReadFromPubSub(
            subscription="projects/acme-analytics/subscriptions/events-sub")
        | "ParseEvents" >> beam.ParDo(ParseEvent()).with_outputs("dead_letter", main="events")
    )
    events | "WriteBigQuery" >> WriteToBigQuery(
        table="acme-analytics:warehouse.user_events",
        write_disposition=BigQueryDisposition.WRITE_APPEND,
        method="STREAMING_INSERTS",
    )
    dead_letters | "WriteDeadLetters" >> WriteToBigQuery(
        table="acme-analytics:warehouse.dead_letter_events",
        write_disposition=BigQueryDisposition.WRITE_APPEND,
    )
```

## Pub/Sub Configuration

```python
from google.cloud import pubsub_v1
from google.protobuf.duration_pb2 import Duration

publisher = pubsub_v1.PublisherClient()
subscriber = pubsub_v1.SubscriberClient()

topic_path = publisher.topic_path("acme-analytics", "user-events")
publisher.create_topic(request={
    "name": topic_path,
    "schema_settings": {
        "schema": "projects/acme-analytics/schemas/user-event",
        "encoding": "JSON",
    },
    "message_retention_duration": Duration(seconds=604800),  # 7 days
})

subscription_path = subscriber.subscription_path("acme-analytics", "events-to-bq")
subscriber.create_subscription(request={
    "name": subscription_path,
    "topic": topic_path,
    "ack_deadline_seconds": 120,
    "enable_exactly_once_delivery": True,
    "retry_policy": {
        "minimum_backoff": Duration(seconds=10),
        "maximum_backoff": Duration(seconds=600),
    },
    "dead_letter_policy": {
        "dead_letter_topic": publisher.topic_path("acme-analytics", "events-dead-letter"),
        "max_delivery_attempts": 5,
    },
})
```

## Cloud Composer (Airflow)

```python
from airflow import DAG
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryInsertJobOperator, BigQueryCheckOperator,
)
from airflow.providers.google.cloud.sensors.gcs import GCSObjectsWithPrefixExistenceSensor
from datetime import datetime, timedelta

default_args = {
    "owner": "data-engineering",
    "depends_on_past": True,
    "email_on_failure": True,
    "email": ["data-alerts@acme.com"],
    "retries": 2,
    "retry_delay": timedelta(minutes=10),
}

with DAG(
    dag_id="daily_order_pipeline",
    default_args=default_args,
    schedule_interval="0 6 * * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["production", "orders"],
) as dag:

    wait_for_data = GCSObjectsWithPrefixExistenceSensor(
        task_id="wait_for_raw_data",
        bucket="acme-data-lake-raw-prod",
        prefix="orders/order_date={{ ds }}/",
        timeout=7200,
        poke_interval=300,
    )

    transform = BigQueryInsertJobOperator(
        task_id="transform_orders",
        configuration={
            "query": {
                "query": "{% include 'sql/transform_orders.sql' %}",
                "useLegacySql": False,
                "destinationTable": {
                    "projectId": "acme-analytics",
                    "datasetId": "warehouse",
                    "tableId": "orders${{ ds_nodash }}",
                },
                "writeDisposition": "WRITE_TRUNCATE",
                "timePartitioning": {"type": "DAY", "field": "order_timestamp"},
            }
        },
    )

    quality_check = BigQueryCheckOperator(
        task_id="check_order_counts",
        sql="SELECT COUNT(*) > 0 FROM `acme-analytics.warehouse.orders` WHERE DATE(order_timestamp) = '{{ ds }}'",
        use_legacy_sql=False,
    )

    wait_for_data >> transform >> quality_check
```

## Edge Cases and Gotchas

- **BigQuery slot contention** — On-demand queries share a 2,000-slot pool per project. Use reservations for production workloads.
- **Pub/Sub ordering** — Messages are unordered by default. Use ordering keys for per-entity ordering, but throughput is limited to 1 MB/s per key.
- **Dataflow autoscaling lag** — Autoscaling takes 2-5 minutes to respond. For bursty traffic, set a higher initial worker count.
- **BigQuery streaming buffer** — Data in the streaming buffer is not available for DML or COPY for ~15 minutes.
- **Cloud Composer sizing** — Start with at least a `medium` environment for production DAGs with 50+ tasks.
