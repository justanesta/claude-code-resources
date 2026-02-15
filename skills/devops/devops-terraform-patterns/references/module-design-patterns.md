# Module Design Patterns

## Standard Module Structure

Follow the HashiCorp standard module structure for consistency and registry compatibility.

```
terraform-aws-vpc/
  main.tf          # Primary resource definitions
  variables.tf     # Input variable declarations
  outputs.tf       # Output value declarations
  versions.tf      # Required providers and Terraform version
  README.md        # Module documentation
  examples/
    simple/        # Minimal usage example
    complete/      # Full-featured example
  modules/
    subnets/       # Nested sub-module
    routes/        # Nested sub-module
  tests/
    vpc_test.go    # Terratest integration tests
```

Keep `main.tf` focused. For large modules, split resources into logically named files like `security_groups.tf`, `iam.tf`, and `dns.tf`.

---

## Input Variable Design

Define clear, typed inputs with descriptions and sensible defaults. Use object types for grouped configuration.

```hcl
variable "cluster_config" {
  description = "EKS cluster configuration"
  type = object({
    name               = string
    kubernetes_version = string
    node_groups = map(object({
      instance_types = list(string)
      min_size       = number
      max_size       = number
      desired_size   = number
      disk_size      = optional(number, 50)
      labels         = optional(map(string), {})
    }))
  })

  validation {
    condition     = can(regex("^1\\.(2[7-9]|3[0-9])$", var.cluster_config.kubernetes_version))
    error_message = "Kubernetes version must be 1.27 or higher."
  }

  validation {
    condition = alltrue([
      for ng in values(var.cluster_config.node_groups) :
      ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size
    ])
    error_message = "Node group sizing must satisfy: min_size <= desired_size <= max_size."
  }
}
```

Use `optional()` with defaults (Terraform 1.3+) to reduce boilerplate for callers while maintaining type safety.

---

## Output Design

Outputs should expose values that downstream consumers need. Group related outputs logically.

```hcl
output "cluster" {
  description = "EKS cluster attributes"
  value = {
    id                   = aws_eks_cluster.this.id
    arn                  = aws_eks_cluster.this.arn
    endpoint             = aws_eks_cluster.this.endpoint
    certificate_authority = aws_eks_cluster.this.certificate_authority[0].data
    security_group_id    = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  }
}

output "node_group_arns" {
  description = "Map of node group names to ARNs"
  value = {
    for k, ng in aws_eks_node_group.this : k => ng.arn
  }
}

output "kubeconfig_command" {
  description = "AWS CLI command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${var.region}"
}
```

Mark outputs as `sensitive = true` when they contain credentials, endpoints used for authentication, or private keys.

---

## Module Versioning

Pin module sources to specific versions. Use semantic versioning for internal modules.

```hcl
# Registry module with pessimistic version constraint
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "production-vpc"
  cidr = "10.0.0.0/16"
}

# Git source pinned to tag
module "custom_iam" {
  source = "git::https://github.com/myorg/terraform-modules.git//iam?ref=v3.2.1"

  role_name   = "app-service-role"
  policy_arns = var.policy_arns
}

# Local module for project-specific logic
module "app_config" {
  source = "./modules/app-config"

  app_name    = var.app_name
  environment = var.environment
}
```

Version pinning strategy:
- **Registry modules** — Use `~>` pessimistic constraint to allow patch updates.
- **Git modules** — Pin to a tag, never a branch. Branches can change unexpectedly.
- **Local modules** — No version pinning needed; they evolve with the root module.

---

## Module Composition

Compose smaller modules into larger stacks. Pass outputs from one module as inputs to another.

```hcl
# Root module composing infrastructure layers
module "networking" {
  source = "./modules/networking"

  vpc_cidr        = var.vpc_cidr
  environment     = var.environment
  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  vpc_id          = module.networking.vpc_id
  private_subnets = module.networking.private_subnet_ids
  environment     = var.environment
}

module "compute" {
  source = "./modules/compute"

  subnet_ids         = module.networking.private_subnet_ids
  security_group_ids = module.security.app_security_group_ids
  instance_type      = var.instance_type
  ami_id             = data.aws_ami.app.id
  iam_role_arn       = module.security.instance_role_arn
}

module "monitoring" {
  source = "./modules/monitoring"

  cluster_name   = module.compute.cluster_name
  vpc_id         = module.networking.vpc_id
  alarm_sns_topic = var.alarm_sns_topic_arn
}
```

---

## Provider Passthrough

Never declare providers inside child modules. Pass them from the root module.

```hcl
# Root module declares providers
provider "aws" {
  region = "us-east-1"
  alias  = "primary"
}

provider "aws" {
  region = "us-west-2"
  alias  = "secondary"
}

# Pass providers to module for multi-region deployment
module "dns" {
  source = "./modules/dns"

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  domain_name = var.domain_name
  records     = var.dns_records
}
```

In the child module, declare required providers:

```hcl
# modules/dns/versions.tf
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.0"
      configuration_aliases = [aws.primary, aws.secondary]
    }
  }
}
```

---

## Testing Modules

Use `terraform test` (Terraform 1.6+) for native testing or Terratest for integration tests.

```hcl
# tests/vpc.tftest.hcl
provider "aws" {
  region = "us-east-1"
}

variables {
  environment     = "test"
  vpc_cidr        = "10.99.0.0/16"
  private_subnets = { "a" = { cidr = "10.99.1.0/24", az = "us-east-1a" } }
}

run "creates_vpc_with_correct_cidr" {
  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == "10.99.0.0/16"
    error_message = "VPC CIDR block does not match expected value."
  }
}

run "tags_include_environment" {
  command = plan

  assert {
    condition     = aws_vpc.main.tags["Environment"] == "test"
    error_message = "VPC is missing the Environment tag."
  }
}
```

---

## Edge Cases

- **Circular dependencies** — If module A needs output from module B and vice versa, restructure so a third module handles the shared concern. Terraform cannot resolve circular references.
- **Module count/for_each** — Modules support `count` and `for_each` (Terraform 0.13+). Use `for_each` for multi-region or multi-environment deployments from a single root.
- **Moved blocks** — When refactoring module structure, use `moved` blocks to preserve state:

```hcl
moved {
  from = aws_instance.app
  to   = module.compute.aws_instance.app
}
```

- **Sensitive outputs** — If a module output is marked sensitive, any output referencing it in the root module must also be marked sensitive.
- **Empty modules** — A module with `count = 0` or `for_each = {}` creates no resources. All its outputs become null. Guard downstream references with `try()` or conditional logic.
