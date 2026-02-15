# Terraform for Data Infrastructure Reference

Detailed patterns for managing cloud data infrastructure with Terraform, including reusable modules, state management, and environment promotion.

## Project Structure

```
terraform/
    environments/
        dev/main.tf, variables.tf, terraform.tfvars, backend.tf
        staging/main.tf, variables.tf, terraform.tfvars, backend.tf
        prod/main.tf, variables.tf, terraform.tfvars, backend.tf
    modules/
        data-lake-bucket/main.tf, variables.tf, outputs.tf
        warehouse/main.tf, variables.tf, outputs.tf
        iam-roles/main.tf, variables.tf, outputs.tf
```

## Data Lake Bucket Module (AWS)

```hcl
# modules/data-lake-bucket/main.tf
resource "aws_s3_bucket" "data_lake" {
  bucket        = var.bucket_name
  force_destroy = var.environment != "prod"
  tags = merge(var.tags, { ManagedBy = "terraform", Environment = var.environment })
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration { status = var.versioning_enabled ? "Enabled" : "Suspended" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.encryption_kms_key_id
    }
    bucket_key_enabled = var.encryption_kms_key_id != null
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket                  = aws_s3_bucket.data_lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.data_lake.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"
      filter { prefix = rule.value.prefix }
      transition { days = rule.value.transition_days; storage_class = rule.value.transition_class }
      expiration { days = rule.value.expiration_days }
    }
  }
}
```

## GCS Data Lake Module

```hcl
resource "google_storage_bucket" "data_lake" {
  name          = var.bucket_name
  location      = var.location
  project       = var.project_id
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  versioning { enabled = var.versioning_enabled }
  encryption { default_kms_key_name = var.kms_key_name }

  dynamic "lifecycle_rule" {
    for_each = var.gcs_lifecycle_rules
    content {
      action { type = lifecycle_rule.value.action_type; storage_class = lookup(lifecycle_rule.value, "storage_class", null) }
      condition { age = lifecycle_rule.value.age_days }
    }
  }

  labels = merge(var.labels, { managed_by = "terraform", environment = var.environment })
}
```

## Warehouse Module

### Redshift Serverless

```hcl
resource "aws_redshiftserverless_namespace" "warehouse" {
  namespace_name      = "analytics-${var.environment}"
  db_name             = "analytics"
  admin_username      = "admin"
  admin_user_password = var.admin_password
  default_iam_role_arn = var.redshift_iam_role_arn
  kms_key_id          = var.kms_key_arn
  log_exports         = ["userlog", "connectionlog", "useractivitylog"]
  tags                = var.tags
}

resource "aws_redshiftserverless_workgroup" "warehouse" {
  workgroup_name      = "analytics-${var.environment}-wg"
  namespace_name      = aws_redshiftserverless_namespace.warehouse.namespace_name
  base_capacity       = var.base_rpu
  max_capacity        = var.max_rpu
  publicly_accessible = false
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids

  config_parameter { parameter_key = "max_query_execution_time"; parameter_value = tostring(var.max_query_time_seconds) }
  config_parameter { parameter_key = "enable_result_cache_for_session"; parameter_value = "true" }
  tags = var.tags
}
```

### BigQuery Dataset

```hcl
resource "google_bigquery_dataset" "warehouse" {
  dataset_id    = var.dataset_id
  project       = var.project_id
  location      = var.location
  friendly_name = var.friendly_name

  default_table_expiration_ms     = var.default_table_expiration_days != null ? var.default_table_expiration_days * 86400000 : null
  default_partition_expiration_ms  = var.default_partition_expiration_days != null ? var.default_partition_expiration_days * 86400000 : null
  default_encryption_configuration { kms_key_name = var.kms_key_name }
  labels = var.labels
}
```

## IAM Roles Module

```hcl
resource "aws_iam_role" "glue_etl" {
  name = "data-eng-glue-etl-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "glue.amazonaws.com" } }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "glue_s3_read" {
  name = "s3-read-raw"
  role = aws_iam_role.glue_etl.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject", "s3:ListBucket"], Resource = [var.raw_bucket_arn, "${var.raw_bucket_arn}/*"] },
      { Effect = "Allow", Action = ["s3:PutObject", "s3:DeleteObject"], Resource = "${var.cleaned_bucket_arn}/*" },
      { Effect = "Allow", Action = ["glue:GetTable", "glue:GetPartitions", "glue:UpdateTable"], Resource = "*" },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = var.kms_key_arn },
    ]
  })
}

resource "aws_iam_role" "redshift" {
  name = "data-eng-redshift-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "redshift.amazonaws.com" } }]
  })
}
```

## Remote State Management

```hcl
terraform {
  backend "s3" {
    bucket         = "acme-terraform-state-prod"
    key            = "data-infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/tf-state-key"
    dynamodb_table = "terraform-state-locks"
  }
}

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = { bucket = "acme-terraform-state-prod", key = "networking/terraform.tfstate", region = "us-east-1" }
}

locals {
  vpc_id             = data.terraform_remote_state.networking.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
}
```

## Environment Composition

```hcl
module "raw_bucket" {
  source      = "../../modules/data-lake-bucket"
  bucket_name = "acme-data-lake-raw-${var.environment}"
  environment = var.environment
  encryption_kms_key_id = module.kms.key_arn
  versioning_enabled    = true
  lifecycle_rules = [{
    id = "events-tiering", prefix = "events/",
    transition_days = 90, transition_class = "GLACIER", expiration_days = 2555
  }]
  tags = local.common_tags
}

module "warehouse" {
  source                 = "../../modules/warehouse"
  environment            = var.environment
  base_rpu               = 32
  max_rpu                = 256
  redshift_iam_role_arn  = module.iam_roles.redshift_role_arn
  kms_key_arn            = module.kms.key_arn
  subnet_ids             = local.private_subnet_ids
  security_group_ids     = local.security_group_ids
  tags                   = local.common_tags
}
```

## Edge Cases and Gotchas

- **State locking** — Always use DynamoDB (AWS) or GCS (GCP) for state locking. Without it, concurrent applies corrupt state.
- **Destroy protection** — Add `lifecycle { prevent_destroy = true }` to production databases and buckets.
- **Secret management** — Never store passwords in `.tfvars`. Use `aws_secretsmanager_secret` or `google_secret_manager_secret` data sources.
- **Module versioning** — Pin module versions with `?ref=v1.2.3` for git sources. Unpinned modules break on upstream changes.
- **Import existing resources** — Use `terraform import` before managing console-created resources to avoid duplicates.
- **Plan before apply** — Always run `terraform plan -out=plan.tfplan` and review before `terraform apply plan.tfplan`.
