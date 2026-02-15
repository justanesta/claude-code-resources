# State Management

## Remote Backend: AWS S3

The S3 backend is the standard choice for AWS-centric teams. Use DynamoDB for state locking and KMS for encryption.

```hcl
# Backend configuration
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "prod/networking/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
    kms_key_id     = "arn:aws:kms:us-east-1:123456789:alias/terraform-state"
  }
}
```

Bootstrap the backend infrastructure before using it. This is the one piece of infrastructure typically managed outside Terraform or with a separate local-state root module.

```hcl
# Bootstrap module for state infrastructure
resource "aws_s3_bucket" "terraform_state" {
  bucket = "myorg-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

---

## Remote Backend: GCS

For GCP-centric teams, use Google Cloud Storage with built-in locking.

```hcl
terraform {
  backend "gcs" {
    bucket = "myorg-terraform-state"
    prefix = "prod/networking"
  }
}
```

GCS backends have built-in locking via object generation numbers. No separate lock table is needed. Enable versioning on the bucket for state recovery.

```hcl
resource "google_storage_bucket" "terraform_state" {
  name     = "myorg-terraform-state"
  location = "US"

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 30
    }
  }
}
```

---

## State Locking

State locking prevents concurrent operations from corrupting state. It is automatic with most remote backends.

**Lock troubleshooting:**

```bash
# If a lock is stuck (e.g., CI pipeline crashed)
terraform force-unlock LOCK_ID

# Always verify who holds the lock first
terraform plan
# Error message will show lock holder info
```

Never force-unlock during an active apply. The lock ID is displayed in the error message when a lock collision occurs. Verify the lock holder's operation has truly failed before unlocking.

---

## Workspace Strategies

Terraform workspaces create separate state files within the same backend configuration.

```hcl
# Using workspace name to parameterize configuration
locals {
  environment = terraform.workspace

  instance_type_map = {
    dev     = "t3.small"
    staging = "t3.medium"
    prod    = "t3.large"
  }

  instance_type = local.instance_type_map[local.environment]
}

resource "aws_instance" "app" {
  instance_type = local.instance_type
  ami           = var.ami_id

  tags = {
    Environment = local.environment
  }
}
```

```bash
# Workspace commands
terraform workspace new staging
terraform workspace select prod
terraform workspace list
```

**When to use workspaces vs. directory separation:**

- **Workspaces** — Good for environments that differ only in variable values (instance size, count). Same code, different state.
- **Directory separation** — Better when environments have structural differences (production has WAF, staging does not). Each directory has its own backend config and can evolve independently.

The directory approach is more common in production because it provides stronger isolation and clearer audit trails.

---

## Cross-Stack State References

Use `terraform_remote_state` to read outputs from another state file.

```hcl
data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = "myorg-terraform-state"
    key    = "prod/networking/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.networking.outputs.private_subnet_ids[0]

  tags = {
    Name = "app-server"
  }
}
```

Alternative: Use SSM Parameter Store or Consul for cross-stack data sharing when you want to avoid tight state coupling.

```hcl
# Writing outputs to SSM (in the networking stack)
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/infrastructure/prod/vpc_id"
  type  = "String"
  value = aws_vpc.main.id
}

# Reading in another stack
data "aws_ssm_parameter" "vpc_id" {
  name = "/infrastructure/prod/vpc_id"
}
```

---

## State Manipulation

Use `terraform state` commands for refactoring and recovery. Always back up state first.

```bash
# Pull state for backup before manipulation
terraform state pull > state-backup-$(date +%Y%m%d-%H%M%S).json

# Move a resource to a different address (refactoring)
terraform state mv aws_instance.old_name aws_instance.new_name

# Move a resource into a module
terraform state mv aws_s3_bucket.data module.storage.aws_s3_bucket.data

# Remove a resource from state (stop managing it, do not destroy)
terraform state rm aws_iam_role.legacy_role

# List all resources in state
terraform state list

# Show details of a specific resource
terraform state show aws_instance.app
```

Prefer `moved` blocks over `terraform state mv` when possible. Moved blocks are declarative, version-controlled, and applied during `terraform apply`:

```hcl
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}

moved {
  from = aws_s3_bucket.data
  to   = module.storage.aws_s3_bucket.data
}
```

---

## State Migration

Migrate between backends by updating the backend configuration and running `terraform init -migrate-state`.

```bash
# Step 1: Update backend configuration in code
# Step 2: Run init to trigger migration
terraform init -migrate-state

# Terraform will prompt to confirm migration
# For CI automation, use:
terraform init -migrate-state -input=false
```

---

## Disaster Recovery

Recovering from state corruption or loss:

1. **S3 versioning recovery** — Restore a previous version of the state file from S3 bucket versioning.
2. **State push** — Push a backup state file to the remote backend.

```bash
# Push a backup state file
terraform state push state-backup-20250115-143022.json
```

3. **Full reimport** — As a last resort, import every resource. Use `terraform import` or import blocks to rebuild state from scratch.

---

## Edge Cases

- **State file size** — Large state files (over 50MB) slow down all operations. Split into smaller states by service boundary.
- **Concurrent workspaces** — Two CI jobs running against different workspaces in the same backend are safe. Same workspace will be blocked by locking.
- **Backend changes** — Changing any backend parameter (bucket name, key path, region) requires `terraform init -migrate-state` or `-reconfigure`.
- **Sensitive data in state** — State files contain all resource attributes in plaintext, including passwords and keys. Encrypt at rest and restrict access with IAM policies.
- **Terraform Cloud migration** — Moving from S3 to Terraform Cloud requires `terraform login` followed by backend reconfiguration and `terraform init -migrate-state`.
