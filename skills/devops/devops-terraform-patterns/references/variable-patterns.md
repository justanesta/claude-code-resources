# Variable Patterns

## Primitive Types

Define variables with explicit types for clarity and early error detection.

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "instance_count" {
  description = "Number of application instances"
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 20
    error_message = "Instance count must be between 1 and 20."
  }
}

variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}
```

---

## Complex Types

Use `object`, `map`, `list`, `set`, and `tuple` for structured configuration. The `optional()` modifier (Terraform 1.3+) allows omitting fields with defaults.

```hcl
variable "database_config" {
  description = "RDS database configuration"
  type = object({
    engine             = string
    engine_version     = string
    instance_class     = string
    allocated_storage  = number
    multi_az           = optional(bool, false)
    backup_retention   = optional(number, 7)
    deletion_protection = optional(bool, true)
    parameters = optional(list(object({
      name         = string
      value        = string
      apply_method = optional(string, "pending-reboot")
    })), [])
  })
}

variable "dns_records" {
  description = "Map of DNS records to create"
  type = map(object({
    type    = string
    ttl     = optional(number, 300)
    records = list(string)
  }))

  default = {}
}
```

Calling the module:

```hcl
module "database" {
  source = "./modules/rds"

  database_config = {
    engine            = "postgres"
    engine_version    = "15.4"
    instance_class    = "db.r6g.large"
    allocated_storage = 100
    multi_az          = true

    parameters = [
      { name = "log_statement", value = "all" },
      { name = "log_min_duration_statement", value = "1000" },
    ]
  }
}
```

---

## Validation Rules

Multiple validation blocks can be applied to a single variable. All conditions must pass.

```hcl
variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }

  validation {
    condition     = tonumber(split("/", var.cidr_block)[1]) >= 16 && tonumber(split("/", var.cidr_block)[1]) <= 24
    error_message = "CIDR prefix must be between /16 and /24."
  }
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "Project name must be 3-21 characters, lowercase alphanumeric and hyphens, starting with a letter."
  }
}

variable "allowed_ports" {
  description = "List of ports to allow inbound"
  type        = list(number)

  validation {
    condition     = alltrue([for p in var.allowed_ports : p > 0 && p <= 65535])
    error_message = "All ports must be between 1 and 65535."
  }

  validation {
    condition     = length(var.allowed_ports) == length(toset(var.allowed_ports))
    error_message = "Port list must not contain duplicates."
  }
}
```

---

## Locals

Locals compute derived values, reducing repetition and centralizing logic. They are evaluated once and cached.

```hcl
locals {
  # Naming convention
  name_prefix = "${var.project}-${var.environment}"

  # Common tags applied to all resources
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Team        = var.team
    CostCenter  = var.cost_center
  }

  # Derived configuration
  is_production = var.environment == "prod"

  instance_type = local.is_production ? "m6i.xlarge" : "t3.medium"

  # Flatten nested structures for for_each
  subnet_routes = flatten([
    for subnet_key, subnet in var.subnets : [
      for route_key, route in subnet.routes : {
        subnet_key  = subnet_key
        route_key   = route_key
        cidr        = route.cidr
        gateway_id  = route.gateway_id
      }
    ]
  ])

  # Convert list to map for for_each
  subnet_route_map = {
    for sr in local.subnet_routes :
    "${sr.subnet_key}-${sr.route_key}" => sr
  }
}
```

Use the flattened locals with `for_each`:

```hcl
resource "aws_route" "this" {
  for_each = local.subnet_route_map

  route_table_id         = aws_route_table.this[each.value.subnet_key].id
  destination_cidr_block = each.value.cidr
  gateway_id             = each.value.gateway_id
}
```

---

## Conditional Resource Creation

Use `count` with a boolean variable to conditionally create resources.

```hcl
variable "create_nat_gateway" {
  description = "Whether to create NAT gateways for private subnets"
  type        = bool
  default     = true
}

resource "aws_eip" "nat" {
  count  = var.create_nat_gateway ? length(var.availability_zones) : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${var.availability_zones[count.index]}"
  })
}

resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? length(var.availability_zones) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${var.availability_zones[count.index]}"
  })
}
```

For more complex conditionals, use `for_each` with a filtered map:

```hcl
variable "services" {
  type = map(object({
    enabled   = bool
    port      = number
    replicas  = number
  }))
}

resource "aws_ecs_service" "this" {
  for_each = {
    for k, v in var.services : k => v if v.enabled
  }

  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.this[each.key].arn
  desired_count   = each.value.replicas
}
```

---

## tfvars File Organization

Organize variable values by environment using `.tfvars` files.

```
environments/
  dev.tfvars
  staging.tfvars
  prod.tfvars
  common.tfvars
```

Apply with `-var-file` flags. Later files override earlier ones:

```bash
terraform plan \
  -var-file="environments/common.tfvars" \
  -var-file="environments/prod.tfvars"
```

Mark sensitive variables with `sensitive = true`. Pass values via `TF_VAR_*` environment variables to avoid storing secrets in `.tfvars` files.

---

## Edge Cases

- **Variable precedence** — Environment variables (`TF_VAR_*`) are overridden by `-var-file`, which is overridden by `-var` flags. Last definition wins for `-var` and `-var-file`.
- **Null defaults** — Setting `default = null` makes a variable optional but with no value. Use `coalesce()` or conditionals to handle null downstream.
- **Type coercion** — Terraform auto-converts between compatible types (string to number, list to set). Explicit types prevent unexpected coercion.
- **Recursive validation** — Validation blocks cannot reference other variables. Each validation only sees its own variable's value.
- **Empty collections** — `for_each = {}` or `for_each = toset([])` creates zero resource instances. This is valid and commonly used for conditional creation.
- **Locals referencing locals** — Locals can reference other locals within the same `locals` block. Terraform resolves the dependency order automatically. Circular references cause an error.
