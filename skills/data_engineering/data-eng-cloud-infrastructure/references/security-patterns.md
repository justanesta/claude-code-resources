# Security Patterns Reference

Detailed patterns for securing cloud data infrastructure with IAM, encryption, network isolation, column-level security, and audit logging.

## IAM Roles and Policies

### Least-Privilege for AWS Data Pipelines

```hcl
resource "aws_iam_role" "glue_events_etl" {
  name = "glue-events-etl-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow", Action = "sts:AssumeRole",
      Principal = { Service = "glue.amazonaws.com" },
      Condition = { StringEquals = { "aws:SourceAccount" = var.account_id } }
    }]
  })
  max_session_duration = 14400
}

resource "aws_iam_role_policy" "glue_events_s3" {
  name = "s3-scoped-access"
  role = aws_iam_role.glue_events_etl.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "ReadRawEvents", Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::${var.raw_bucket}/events/*" },
      { Sid = "ListRawBucket", Effect = "Allow", Action = ["s3:ListBucket"], Resource = "arn:aws:s3:::${var.raw_bucket}",
        Condition = { StringLike = { "s3:prefix" = ["events/*"] } } },
      { Sid = "WriteCleanedEvents", Effect = "Allow", Action = ["s3:PutObject", "s3:DeleteObject"],
        Resource = "arn:aws:s3:::${var.cleaned_bucket}/events/*",
        Condition = { StringEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" } } },
    ]
  })
}
```

### GCP Service Account with Scoped Permissions

```hcl
resource "google_service_account" "dataflow_pipeline" {
  account_id   = "dataflow-events-pipeline"
  display_name = "Dataflow Events Pipeline"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "raw_reader" {
  bucket = google_storage_bucket.raw.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.dataflow_pipeline.email}"
}

resource "google_bigquery_table_iam_member" "events_writer" {
  project    = var.project_id
  dataset_id = "warehouse"
  table_id   = "user_events"
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.dataflow_pipeline.email}"
}
```

### Cross-Account Access (AWS)

```hcl
resource "aws_s3_bucket_policy" "cross_account_read" {
  bucket = aws_s3_bucket.curated.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.analytics_account_id}:role/redshift-query-role" }
      Action    = ["s3:GetObject", "s3:ListBucket"]
      Resource  = ["arn:aws:s3:::${aws_s3_bucket.curated.id}", "arn:aws:s3:::${aws_s3_bucket.curated.id}/analytics/*"]
      Condition = { Bool = { "aws:SecureTransport" = "true" } }
    }]
  })
}
```

## Encryption

### AWS KMS and S3 Encryption

```hcl
resource "aws_kms_key" "data_lake" {
  description             = "Data lake encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "RootAccess", Effect = "Allow", Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }, Action = "kms:*", Resource = "*" },
      { Sid = "GlueAccess", Effect = "Allow", Principal = { AWS = aws_iam_role.glue_events_etl.arn },
        Action = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"], Resource = "*" },
    ]
  })
}

# Enforce encryption on all S3 writes
resource "aws_s3_bucket_policy" "require_encryption" {
  bucket = aws_s3_bucket.data_lake.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "DenyUnencryptedTransport", Effect = "Deny", Principal = "*", Action = "s3:*",
        Resource = ["arn:aws:s3:::${aws_s3_bucket.data_lake.id}", "arn:aws:s3:::${aws_s3_bucket.data_lake.id}/*"],
        Condition = { Bool = { "aws:SecureTransport" = "false" } } },
      { Sid = "DenyNoKMS", Effect = "Deny", Principal = "*", Action = "s3:PutObject",
        Resource = "arn:aws:s3:::${aws_s3_bucket.data_lake.id}/*",
        Condition = { StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" } } },
    ]
  })
}
```

### GCP Customer-Managed Encryption Keys

```hcl
resource "google_kms_key_ring" "data_lake" {
  name = "data-lake-keyring"; location = "us"; project = var.project_id
}

resource "google_kms_crypto_key" "data_lake" {
  name            = "data-lake-key"
  key_ring        = google_kms_key_ring.data_lake.id
  rotation_period = "7776000s"  # 90 days
  purpose         = "ENCRYPT_DECRYPT"
}

resource "google_kms_crypto_key_iam_member" "gcs_encrypt" {
  crypto_key_id = google_kms_crypto_key.data_lake.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com"
}
```

## Network Isolation

### VPC Endpoints for AWS Data Services

```hcl
# S3 gateway endpoint (free)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids
  tags = { Name = "s3-vpc-endpoint" }
}

# Glue interface endpoint
resource "aws_vpc_endpoint" "glue" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.glue"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "vpc-endpoints-"
  vpc_id      = var.vpc_id
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = [var.vpc_cidr] }
}
```

## Column-Level Security

### BigQuery Policy Tags

```sql
-- Apply policy tags to restrict PII column access
ALTER TABLE `acme-analytics.warehouse.customers`
ALTER COLUMN email SET OPTIONS (
    policy_tags = ['projects/acme-analytics/locations/us/taxonomies/pii/policyTags/pii_medium']
);

ALTER TABLE `acme-analytics.warehouse.customers`
ALTER COLUMN ssn_hash SET OPTIONS (
    policy_tags = ['projects/acme-analytics/locations/us/taxonomies/pii/policyTags/pii_high']
);
```

```hcl
resource "google_data_catalog_taxonomy" "pii" {
  display_name           = "PII Classification"
  region                 = "us"
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "pii_high" {
  taxonomy     = google_data_catalog_taxonomy.pii.id
  display_name = "PII High"
  description  = "SSN, credit card numbers"
}

resource "google_data_catalog_policy_tag_iam_member" "analysts_pii_medium" {
  policy_tag = google_data_catalog_policy_tag.pii_medium.name
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = "group:data-analysts@acme.com"
}
```

### Redshift Column-Level Security

```sql
CREATE GROUP pii_restricted;
GRANT SELECT ON warehouse.customers TO GROUP pii_restricted;
REVOKE SELECT (email, phone_number, ssn_hash) ON warehouse.customers FROM GROUP pii_restricted;

-- Masking view for analysts
CREATE VIEW analytics.customers_masked AS
SELECT
    customer_id, customer_segment, lifetime_value, signup_date,
    REGEXP_REPLACE(email, '(^[^@]{2})[^@]*', '\\1***') AS email_masked,
    'XXX-XXX-' || RIGHT(phone_number, 4) AS phone_masked
FROM warehouse.customers;

GRANT SELECT ON analytics.customers_masked TO GROUP data_analysts;
```

## Audit Logging

```hcl
resource "aws_cloudtrail" "data_lake_audit" {
  name                       = "data-lake-audit-trail"
  s3_bucket_name             = aws_s3_bucket.audit_logs.id
  enable_log_file_validation = true
  kms_key_id                 = aws_kms_key.audit.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
    data_resource {
      type   = "AWS::S3::Object"
      values = [
        "arn:aws:s3:::acme-data-lake-raw-prod/",
        "arn:aws:s3:::acme-data-lake-cleaned-prod/",
        "arn:aws:s3:::acme-data-lake-curated-prod/",
      ]
    }
  }
}
```

```sql
-- Query BigQuery audit logs for PII table access
SELECT
    protopayload_auditlog.authenticationInfo.principalEmail AS user_email,
    protopayload_auditlog.methodName AS method,
    protopayload_auditlog.resourceName AS resource,
    timestamp
FROM `acme-analytics.audit_logs.cloudaudit_googleapis_com_data_access_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY))
    AND protopayload_auditlog.resourceName LIKE '%warehouse.customers%'
ORDER BY timestamp DESC
LIMIT 100;
```

## Edge Cases and Gotchas

- **IAM propagation delay** — AWS IAM changes take up to 60 seconds to propagate. Don't test permissions immediately after granting in CI/CD.
- **KMS key deletion** — Makes all encrypted data permanently unreadable. Use 30-day deletion window and require MFA.
- **Service account key leakage** — Prefer Workload Identity Federation over exported JSON keys. Rotate keys every 90 days.
- **VPC endpoint costs** — Interface endpoints cost ~$7/month per AZ plus $0.01/GB. Still cheaper than NAT gateway at $0.045/GB.
- **Column-level security gaps** — BigQuery column-level security does not apply to exports. Users with `bigquery.tables.export` can bypass restrictions.
- **Cross-account IAM debugging** — Both resource policy (trust) and identity policy (permissions) must allow the action.
