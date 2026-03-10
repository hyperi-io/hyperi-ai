---
name: terraform-standards
description: Terraform standards for infrastructure as code, state management, and module patterns. Use when writing Terraform, reviewing IaC, or provisioning cloud infrastructure.
rule_paths:
  - "**/*.tf"
  - "**/*.tfvars"
detect_markers:
  - "glob:*.tf"
  - "deep_glob:*.tf"
---

# Terraform Standards for HyperI Projects

**Infrastructure provisioning: HCL, EKS, on-prem (Rancher), state management**

---

## Quick Reference

```bash
terraform init                  # Initialize
terraform plan                  # Preview changes
terraform apply                 # Apply changes
terraform destroy               # Destroy resources
terraform fmt                   # Format code
terraform validate              # Validate syntax
```

---

## Project Structure

```text
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── prod/
├── modules/
│   ├── eks-cluster/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── vpc/
│   └── rds/
└── shared/
    └── backend.tf
```

---

## Provider Configuration

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "env/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}
```

---

## Variables

### Variable Definitions

```hcl
# variables.tf
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_config" {
  description = "EKS cluster configuration"
  type = object({
    name            = string
    version         = string
    node_groups     = map(object({
      instance_types = list(string)
      min_size       = number
      max_size       = number
      desired_size   = number
    }))
  })
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
```

### terraform.tfvars

```hcl
# environments/prod/terraform.tfvars
environment = "prod"
region      = "us-east-1"
vpc_cidr    = "10.0.0.0/16"

cluster_config = {
  name    = "prod-cluster"
  version = "1.28"
  node_groups = {
    general = {
      instance_types = ["m5.large"]
      min_size       = 2
      max_size       = 10
      desired_size   = 3
    }
    compute = {
      instance_types = ["c5.xlarge"]
      min_size       = 0
      max_size       = 20
      desired_size   = 0
    }
  }
}

tags = {
  Project = "myproject"
  Team    = "platform"
}
```

---

## Local Values

```hcl
locals {
  name_prefix = "${var.environment}-${var.project_name}"

  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
  })

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 4)]
}
```

---

## Module Pattern

### Module Definition

```hcl
# modules/eks-cluster/main.tf
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.public_access
    security_group_ids      = [aws_security_group.cluster.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]

  tags = var.tags
}

# modules/eks-cluster/variables.tf
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "subnet_ids" {
  description = "Subnet IDs for the cluster"
  type        = list(string)
}

variable "public_access" {
  description = "Enable public API endpoint"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

# modules/eks-cluster/outputs.tf
output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.this.id
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Cluster CA certificate"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}
```

### Module Usage

```hcl
# environments/prod/main.tf
module "eks" {
  source = "../../modules/eks-cluster"

  cluster_name    = local.name_prefix
  cluster_version = var.cluster_config.version
  subnet_ids      = module.vpc.private_subnet_ids
  public_access   = false

  tags = local.common_tags
}
```

---

## State Management

### Remote Backend (S3)

```hcl
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "env/${var.environment}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Terraform Cloud

```hcl
terraform {
  cloud {
    organization = "myorg"

    workspaces {
      tags = ["app:myapp"]
    }
  }
}
```

### State Locking

Always use state locking to prevent concurrent modifications:

```hcl
# DynamoDB table for locking
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

## Data Sources

```hcl
# Get current AWS account
data "aws_caller_identity" "current" {}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Get latest EKS AMI
data "aws_ami" "eks_node" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster_version}-*"]
  }
}

# Get existing VPC
data "aws_vpc" "existing" {
  tags = {
    Name = "main-vpc"
  }
}
```

---

## Outputs

```hcl
# outputs.tf
output "cluster_endpoint" {
  description = "EKS cluster endpoint URL"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_id
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ${var.region}"
}

output "database_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}
```

---

## Sensitive Data

### Never Commit Secrets

```hcl
# ❌ Bad - hardcoded secret
resource "aws_db_instance" "main" {
  password = "mysecretpassword"  # NEVER!
}

# ✅ Good - use variables
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

resource "aws_db_instance" "main" {
  password = var.db_password
}

# ✅ Good - use Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "myapp/db-password"
}

resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

---

## Naming Conventions

```hcl
# Resource naming pattern
locals {
  name = "${var.environment}-${var.project}-${var.component}"
}

# Examples:
# prod-myapp-eks
# dev-myapp-rds
# staging-myapp-vpc
```

| Resource Type | Convention |
|---------------|------------|
| Variables | snake_case |
| Resources | snake_case |
| Modules | kebab-case |
| Outputs | snake_case |

---

## Best Practices

### Always Do

- Pin provider versions (`~> 5.0` not `>= 5.0`)
- Use remote state with locking
- Tag all resources
- Use modules for reusable components
- Validate variables with conditions
- Mark sensitive outputs

### Never Do

- Hardcode secrets
- Use `terraform apply -auto-approve` in production
- Skip `terraform plan` review
- Commit `.tfvars` with secrets
- Use `count` when `for_each` is clearer

### Lifecycle Rules

```hcl
resource "aws_instance" "web" {
  # ...

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true  # Production safety
    ignore_changes        = [tags["LastModified"]]
  }
}
```

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Terraform Plan
  run: |
    terraform init
    terraform plan -out=tfplan

- name: Terraform Apply
  if: github.ref == 'refs/heads/main'
  run: terraform apply -auto-approve tfplan
```

### Atlantis Comments

```hcl
# atlantis.yaml
version: 3
projects:
  - name: prod
    dir: environments/prod
    workflow: default
    autoplan:
      when_modified: ["*.tf", "../../modules/**/*.tf"]
```

---

## Resources

- Terraform Documentation: <https://developer.hashicorp.com/terraform/docs>
- AWS Provider: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs>
- Terraform Best Practices: <https://www.terraform-best-practices.com/>
