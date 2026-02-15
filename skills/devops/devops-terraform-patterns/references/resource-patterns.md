# Resource Patterns

## Lifecycle Rules

Lifecycle meta-arguments control how Terraform manages resource creation, updates, and deletion.

```hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = var.instance_type

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [ami, user_data]
    prevent_destroy       = false
  }

  tags = {
    Name = "${var.project}-app"
  }
}
```

### create_before_destroy

Creates the replacement resource before destroying the old one. Essential for resources that cannot have downtime.

```hcl
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-app-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  lifecycle {
    create_before_destroy = true
  }
}
```

### ignore_changes

Prevents Terraform from reverting changes made outside of Terraform. Common for auto-scaling group sizes and tags managed by external systems.

```hcl
resource "aws_autoscaling_group" "app" {
  name                = "${var.project}-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  lifecycle {
    ignore_changes = [desired_capacity, target_group_arns]
  }
}
```

### prevent_destroy

Safeguards critical resources from accidental deletion. Terraform will error if a destroy is planned for this resource.

```hcl
resource "aws_rds_instance" "primary" {
  identifier     = "${var.project}-primary"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  lifecycle {
    prevent_destroy = true
  }
}
```

---

## depends_on

Use explicit `depends_on` only when Terraform cannot infer the dependency from resource references. Most dependencies are handled automatically.

```hcl
# IAM policy must exist before Lambda can assume the role
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "processor" {
  function_name = "${var.project}-processor"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = var.lambda_zip_path

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_vpc]
}
```

Overusing `depends_on` hides the real dependency graph and can slow down applies by preventing parallelism. Prefer implicit dependencies through references whenever possible.

---

## count vs for_each

### count

Use `count` for simple on/off toggles or creating N identical resources.

```hcl
variable "create_bastion" {
  description = "Whether to create a bastion host"
  type        = bool
  default     = false
}

resource "aws_instance" "bastion" {
  count = var.create_bastion ? 1 : 0

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = var.public_subnet_ids[0]

  tags = {
    Name = "${var.project}-bastion"
  }
}

# Reference with index
output "bastion_ip" {
  value = var.create_bastion ? aws_instance.bastion[0].public_ip : null
}
```

### for_each

Use `for_each` when each resource has a unique identity. Resources are keyed by the map key or set element, making additions and removals safe.

```hcl
variable "s3_buckets" {
  description = "Map of S3 buckets to create"
  type = map(object({
    versioning = bool
    lifecycle_days = number
  }))
}

resource "aws_s3_bucket" "this" {
  for_each = var.s3_buckets

  bucket = "${var.project}-${each.key}"

  tags = merge(var.common_tags, {
    Name = each.key
  })
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = {
    for k, v in var.s3_buckets : k => v if v.versioning
  }

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}
```

**Key difference:** Removing an item from the middle of a `count` list shifts all subsequent indices, causing unnecessary destroys and recreates. `for_each` uses stable keys, so only the removed resource is destroyed.

---

## Dynamic Blocks

Generate repeated nested blocks from collections. Useful for security group rules, IAM statements, and similar repetitive configurations.

```hcl
variable "ingress_rules" {
  description = "Security group ingress rules"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "Application security group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules

    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Avoid nesting dynamic blocks more than one level deep. Deeply nested dynamic blocks become very difficult to read and debug.

---

## Resource Replacement

Use `-replace` to force recreation of a specific resource without tainting.

```bash
# Force replacement of a specific instance
terraform apply -replace="aws_instance.app[\"web-1\"]"

# Replace a module resource
terraform apply -replace="module.compute.aws_launch_template.app"
```

---

## Timeouts

Set custom timeouts for resources that take a long time to provision. Provisioners (`remote-exec`, `local-exec`) are a last resort -- prefer cloud-init or user data instead.

```hcl
resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.project}-aurora"
  engine             = "aurora-postgresql"
  engine_version     = "15.4"
  master_username    = var.db_username
  master_password    = var.db_password

  timeouts {
    create = "45m"
    update = "30m"
    delete = "30m"
  }
}

```

---

## Edge Cases

- **Resource drift** — When infrastructure is modified outside Terraform, `terraform plan` detects the drift. Use `terraform apply` to reconcile. If the external change is desired, update the code to match and use `ignore_changes` if needed.
- **Destroy-time provisioners** — These run before a resource is destroyed. They fail silently if the resource is already gone. Use `when = destroy` and handle errors with `on_failure = continue`.
- **Sensitive attributes** — Some resource attributes (e.g., RDS passwords) are marked sensitive by providers. They appear as `(sensitive value)` in plan output. Use `nonsensitive()` only when you explicitly need to expose them.
- **Resource targeting** — `terraform apply -target=RESOURCE` applies only that resource and its dependencies. Never use in production workflows as it can leave state inconsistent.
- **Orphaned resources** — If you remove a resource block without first running `terraform destroy` on it, the resource is removed from state but continues to exist in the cloud. Use `terraform state rm` only when you intentionally want to stop managing a resource.
