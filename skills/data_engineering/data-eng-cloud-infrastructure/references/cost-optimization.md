# Cost Optimization Reference

Detailed patterns for minimizing cloud data infrastructure costs across storage, compute, data transfer, and query engines.

## Storage Tiering

### AWS S3 Storage Classes

```
Storage Class       | Cost/GB/month | Retrieval Cost | Use Case
--------------------|---------------|----------------|----------------------------
S3 Standard         | $0.023        | None           | Active data, frequent access
S3 Standard-IA      | $0.0125       | $0.01/GB       | Monthly reports, backups
S3 Glacier IR       | $0.004        | $0.03/GB       | Quarterly compliance data
S3 Deep Archive     | $0.00099      | $0.02/GB       | 7-year retention compliance
```

### Automated Tiering

```python
import boto3

s3 = boto3.client("s3")

s3.put_bucket_intelligent_tiering_configuration(
    Bucket="acme-data-lake-raw-prod",
    Id="events-tiering",
    IntelligentTieringConfiguration={
        "Id": "events-tiering",
        "Status": "Enabled",
        "Filter": {"Prefix": "events/"},
        "Tierings": [
            {"AccessTier": "ARCHIVE_ACCESS", "Days": 90},
            {"AccessTier": "DEEP_ARCHIVE_ACCESS", "Days": 180},
        ],
    },
)
```

### GCS Storage Class Transitions

```hcl
resource "google_storage_bucket" "data_lake" {
  name          = "acme-data-lake-raw-prod"
  location      = "US"
  storage_class = "STANDARD"

  lifecycle_rule { condition { age = 30 };  action { type = "SetStorageClass"; storage_class = "NEARLINE" } }
  lifecycle_rule { condition { age = 90 };  action { type = "SetStorageClass"; storage_class = "COLDLINE" } }
  lifecycle_rule { condition { age = 365 }; action { type = "SetStorageClass"; storage_class = "ARCHIVE" } }
  lifecycle_rule { condition { age = 2555 }; action { type = "Delete" } }
}
```

## Compute Autoscaling

### EMR Managed Scaling

```hcl
resource "aws_emr_cluster" "spark" {
  name          = "data-pipeline-${var.environment}"
  release_label = "emr-7.0.0"
  applications  = ["Spark", "Hive"]

  master_instance_group { instance_type = "m6g.xlarge"; instance_count = 1 }
  core_instance_group   { instance_type = "m6g.2xlarge"; instance_count = 2 }

  managed_scaling_policy {
    compute_limits {
      unit_type                       = "InstanceFleetUnits"
      minimum_capacity_units          = 2
      maximum_capacity_units          = 50
      maximum_on_demand_capacity_units = 10  # Rest uses spot
    }
  }
}
```

### Redshift Serverless Scheduled Scaling

```python
import boto3

redshift = boto3.client("redshift-serverless")
events = boto3.client("events")

# Scale up during business hours, minimum at night
events.put_rule(Name="redshift-scale-up", ScheduleExpression="cron(0 8 ? * MON-FRI *)", State="ENABLED")
events.put_rule(Name="redshift-scale-down", ScheduleExpression="cron(0 20 ? * MON-FRI *)", State="ENABLED")

def scale_workgroup(event, context):
    rule_name = event["resources"][0].split("/")[-1]
    base = 128 if "scale-up" in rule_name else 32
    max_cap = 512 if "scale-up" in rule_name else 64
    redshift.update_workgroup(workgroupName="analytics-prod-wg", baseCapacity=base, maxCapacity=max_cap)
```

## Reserved and Spot Capacity

### BigQuery Reservations vs On-Demand

```python
"""
Break-even analysis:
    On-demand: $6.25 per TB scanned
    Standard Edition slots: $0.04 per slot-hour (autoscale, no commitment)

    At 100 slots running 24/7: 100 * 730 * $0.04 = $2,920/month
    On-demand equivalent: $2,920 / $6.25 = 467 TB/month
    If you scan > 467 TB/month, slots are cheaper.
"""
from google.cloud import bigquery_reservation_v1

client = bigquery_reservation_v1.ReservationServiceClient()
reservation = client.create_reservation(
    parent="projects/acme-analytics/locations/US",
    reservation_id="analytics-autoscale",
    reservation=bigquery_reservation_v1.Reservation(
        slot_capacity=0,
        edition=bigquery_reservation_v1.Edition.STANDARD,
        autoscale=bigquery_reservation_v1.Reservation.Autoscale(max_slots=500),
    ),
)
```

### EC2 Spot Instances for Spark

```hcl
resource "aws_emr_instance_fleet" "task" {
  cluster_id                    = aws_emr_cluster.spark.id
  name                          = "task-fleet"
  target_on_demand_capacity     = 0
  target_spot_capacity          = 20

  launch_specifications {
    spot_specification {
      allocation_strategy      = "capacity-optimized"
      timeout_action           = "SWITCH_TO_ON_DEMAND"
      timeout_duration_minutes = 10
    }
  }

  # Diversify instance types to reduce spot interruption risk
  instance_type_configs { instance_type = "m6g.2xlarge"; weighted_capacity = 4; bid_price_as_percentage_of_on_demand_price = 60 }
  instance_type_configs { instance_type = "m6g.4xlarge"; weighted_capacity = 8; bid_price_as_percentage_of_on_demand_price = 60 }
  instance_type_configs { instance_type = "r6g.2xlarge"; weighted_capacity = 4; bid_price_as_percentage_of_on_demand_price = 60 }
}
```

## Query Cost Controls

### Athena Workgroup Limits

```hcl
resource "aws_athena_workgroup" "data_engineering" {
  name = "data-engineering"
  configuration {
    enforce_workgroup_configuration = true
    bytes_scanned_cutoff_per_query  = 10737418240  # 10 GB
    result_configuration {
      output_location = "s3://acme-athena-results-prod/data-engineering/"
      encryption_configuration { encryption_option = "SSE_KMS"; kms_key_arn = var.kms_key_arn }
    }
  }
}

resource "aws_athena_workgroup" "ad_hoc" {
  name = "ad-hoc-analysts"
  configuration {
    enforce_workgroup_configuration = true
    bytes_scanned_cutoff_per_query  = 1073741824  # 1 GB limit for analysts
    result_configuration { output_location = "s3://acme-athena-results-prod/ad-hoc/" }
  }
}
```

### BigQuery Cost Controls

```sql
-- Per-query cost limit
SELECT customer_id, SUM(order_total) AS total_spend
FROM `acme-analytics.warehouse.orders`
WHERE DATE(order_timestamp) BETWEEN '2025-01-01' AND '2025-01-31'
GROUP BY customer_id
OPTIONS (max_bytes_billed = 10737418240);  -- 10 GB limit
```

## Data Transfer Optimization

```python
"""
Data transfer costs:
    Same region:     Free (same AZ) or $0.01/GB (cross-AZ)
    Cross-region:    $0.02/GB
    Internet egress: $0.09/GB (first 10 TB)
    VPC endpoints:   $0.01/GB (saves NAT gateway $0.045/GB)

Strategies:
    1. Co-locate compute and storage in the same region
    2. Use VPC endpoints for S3/DynamoDB (saves $0.045/GB vs NAT gateway)
    3. Compress data before transfer (Parquet + Snappy = 10x smaller than CSV)
    4. Cache frequently accessed reference data locally
"""
```

## Cost Monitoring and Alerts

```python
import boto3
from datetime import datetime, timedelta

ce = boto3.client("ce")

def get_data_pipeline_costs(days=7):
    end = datetime.today().strftime("%Y-%m-%d")
    start = (datetime.today() - timedelta(days=days)).strftime("%Y-%m-%d")
    response = ce.get_cost_and_usage(
        TimePeriod={"Start": start, "End": end},
        Granularity="DAILY",
        Metrics=["UnblendedCost"],
        Filter={"And": [
            {"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Simple Storage Service", "Amazon Athena", "AWS Glue", "Amazon Redshift"]}},
            {"Tags": {"Key": "Team", "Values": ["data-engineering"]}},
        ]},
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )
    for result in response["ResultsByTime"]:
        for group in result["Groups"]:
            cost = float(group["Metrics"]["UnblendedCost"]["Amount"])
            if cost > 0:
                print(f"{result['TimePeriod']['Start']} | {group['Keys'][0]}: ${cost:.2f}")

# Set up budget alert at 80% of $15k monthly limit
budgets = boto3.client("budgets")
budgets.create_budget(
    AccountId="123456789012",
    Budget={
        "BudgetName": "data-engineering-monthly",
        "BudgetLimit": {"Amount": "15000", "Unit": "USD"},
        "TimeUnit": "MONTHLY",
        "BudgetType": "COST",
        "CostFilters": {"TagKeyValue": ["user:Team$data-engineering"]},
    },
    NotificationsWithSubscribers=[{
        "Notification": {"NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN", "Threshold": 80, "ThresholdType": "PERCENTAGE"},
        "Subscribers": [{"SubscriptionType": "SNS", "Address": "arn:aws:sns:us-east-1:123456789012:cost-alerts"}],
    }],
)
```

## Edge Cases and Gotchas

- **S3 request costs** — PUT requests cost $0.005 per 1,000. Writing 1M small files costs $5 in requests alone. Compact to reduce overhead.
- **Glacier retrieval surprises** — Deep Archive bulk retrieval takes 12-48 hours. Plan ahead for compliance audits.
- **BigQuery streaming costs** — Streaming inserts cost $0.05/GB, 5x more than batch loading (free). Use Storage Write API for batch.
- **NAT gateway costs** — $0.045/GB processed. A 10 TB/month pipeline through NAT costs $450/month. Use VPC endpoints for AWS services.
- **Idle Redshift Serverless** — Minimum 32 RPU idle workgroups cost ~$270/month. Delete dev workgroups when not in use.
- **Cross-AZ charges** — $0.01/GB each direction. Multi-AZ EMR with heavy shuffle incurs significant cross-AZ costs.
