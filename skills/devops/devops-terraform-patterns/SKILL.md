---
name: devops-terraform-patterns
description: Terraform infrastructure-as-code patterns covering module design, state management, resource lifecycle, variables, CI/CD integration, and migration strategies for AWS and GCP.
---

# Terraform Patterns

## Core Principles

1. **Infrastructure as Code** — All infrastructure is declared in version-controlled `.tf` files. Manual changes are prohibited; every resource has a single source of truth in code.
2. **State Is Sacred** — Remote state with locking prevents corruption. Never edit state files by hand. Use `terraform state` commands for manipulation and always back up before operations.
3. **Modular Design** — Reusable modules encapsulate logical groupings of resources. Root modules compose child modules. Pin module versions to avoid surprises.
4. **Immutable Infrastructure** — Prefer replacing resources over mutating them. Use `create_before_destroy` lifecycle rules for zero-downtime deployments.
5. **Least Privilege Plans** — CI pipelines run `plan` on every PR and `apply` only on merge to main. Human review of plan output is mandatory before any production apply.

---

## Resource and Data Source Patterns

Use `for_each` over `count` when resources need stable identity. Data sources fetch existing infrastructure without managing it.

```hcl
# Fetch existing VPC, create subnets with for_each for stable keys
data "aws_vpc" "main" {
  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = data.aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.common_tags, {
    Name = "${var.project}-private-${each.key}"
    Tier = "private"
  })
}
```

See [resource-patterns](references/resource-patterns.md) for: lifecycle rules, depends_on usage, count vs for_each trade-offs, dynamic blocks, and provisioner patterns.

---

## Module Design

Modules accept typed inputs, expose outputs, and compose into larger stacks. Keep modules focused on a single concern.

```hcl
# Root module composing child modules
module "networking" {
  source  = "git::https://github.com/org/terraform-modules.git//networking?ref=v2.3.1"

  environment    = var.environment
  vpc_cidr       = var.vpc_cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
}

module "database" {
  source = "./modules/rds"

  subnet_ids         = module.networking.private_subnet_ids
  security_group_ids = [module.networking.db_security_group_id]
  instance_class     = var.db_instance_class
  engine_version     = var.db_engine_version
}

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.endpoint
  sensitive   = true
}
```

See [module-design-patterns](references/module-design-patterns.md) for: module structure conventions, input validation, output design, versioning strategies, and registry publishing.

---

## State Management

Store state remotely with locking. Use workspaces or directory-based separation for environments.

```hcl
# S3 backend with DynamoDB locking
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "prod/networking/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
    kms_key_id     = "alias/terraform-state"
  }
}
```

See [state-management](references/state-management.md) for: remote backend configuration (S3, GCS), locking mechanisms, workspace strategies, state migration, and disaster recovery.

---

## Variables and Locals

Use typed variables with validation blocks. Locals reduce repetition and compute derived values.

```hcl
variable "instance_type" {
  description = "EC2 instance type for the application tier"
  type        = string
  default     = "t3.medium"

  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Only t3 instance types are allowed in this environment."
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = var.cost_center
  }
}
```

See [variable-patterns](references/variable-patterns.md) for: complex type constraints, validation rules, locals patterns, conditional resource creation, and tfvars file organization.

---

## Plan/Apply Workflow

Separate plan and apply stages. Save plan files for deterministic applies. Integrate with CI pipelines for automated review.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Plan stage: generate and save binary plan
terraform init -backend-config="env/${ENVIRONMENT}.hcl"
terraform plan \
  -var-file="env/${ENVIRONMENT}.tfvars" \
  -out="tfplan-${ENVIRONMENT}-$(date +%s)" \
  -detailed-exitcode

# Exit code 2 means changes detected
# Apply stage: use saved plan for deterministic apply
terraform apply "tfplan-${ENVIRONMENT}-${PLAN_TIMESTAMP}"
```

See [ci-integration](references/ci-integration.md) for: GitHub Actions workflows, GitLab CI pipelines, plan artifact storage, auto-apply strategies, and Atlantis configuration.

---

## Import and Migration Patterns

Import existing resources into Terraform management. Use `import` blocks (Terraform 1.5+) for declarative imports.

```hcl
# Declarative import (Terraform 1.5+)
import {
  to = aws_s3_bucket.legacy_data
  id = "my-legacy-bucket-name"
}

resource "aws_s3_bucket" "legacy_data" {
  bucket = "my-legacy-bucket-name"

  tags = {
    ManagedBy = "terraform"
    Imported  = "true"
  }
}
```

After import, run `terraform plan` to verify no diff. Adjust the resource configuration until the plan shows no changes. For bulk imports, generate configuration with `terraform plan -generate-config-out=generated.tf`.

---

## Anti-Patterns

| Avoid | Use Instead |
|---|---|
| `count` with maps or objects that may reorder | `for_each` with a stable map key |
| Hardcoded provider credentials in `.tf` files | Environment variables or IAM roles |
| Monolithic root module with hundreds of resources | Smaller modules composed in a root module |
| `terraform apply -auto-approve` in production | Saved plan file reviewed then applied |
| Storing state locally or in version control | Remote backend with encryption and locking |
| Using `terraform taint` (deprecated) | `terraform apply -replace=RESOURCE` |
| Wildcard provider version constraints | Pinned versions with pessimistic constraint `~>` |
| Nested provider blocks inside modules | Pass providers from root module via `providers` argument |
| Running `terraform destroy` without targeted plan | `terraform plan -destroy` reviewed first |
| String interpolation for simple references | Direct reference `var.name` instead of `"${var.name}"` |

---

## Performance

- **Parallelism** — Increase with `terraform apply -parallelism=20` for large stacks. Default is 10. Monitor API rate limits.
- **Targeted applies** — Use `-target=module.networking` during development to reduce plan/apply time. Never rely on targets in production.
- **State splitting** — Break monolithic state into smaller states per service or layer (networking, compute, data). Use `terraform_remote_state` data source for cross-stack references.
- **Provider caching** — Configure `plugin_cache_dir` in `~/.terraformrc` to avoid re-downloading providers across workspaces.
- **Plan file caching** — In CI, cache `.terraform` directory between runs. Use `terraform providers lock` to generate lock files for consistent installs.
- **Refresh skipping** — Use `terraform plan -refresh=false` when you know infrastructure has not changed externally. Reduces API calls significantly on large stacks.
- **Data source minimization** — Avoid unnecessary data source lookups in tight loops. Cache results in locals when the same data source is referenced multiple times.

---

source: Terraform documentation, HashiCorp best practices, AWS/GCP provider guides
