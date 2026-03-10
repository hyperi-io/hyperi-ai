---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
detect_markers:
  - "glob:*.tf"
  - "deep_glob:*.tf"
source: infrastructure/TERRAFORM.md
---

<!-- override: manual -->
## Project Structure

- Use `environments/{dev,staging,prod}/` with `main.tf`, `variables.tf`, `terraform.tfvars` each
- Use `modules/{component}/` with `main.tf`, `variables.tf`, `outputs.tf` each
- Use `shared/backend.tf` for backend configuration

## Provider Configuration

- Pin `required_version = ">= 1.5.0"`
- Pin provider versions with pessimistic constraint (`~> 5.0`, not `>= 5.0`)
- Use S3 backend with `encrypt = true` and `dynamodb_table` for locking
- Set `default_tags` on the provider using `local.common_tags`

## Variables

- Every variable MUST have `description` and `type`
- Use `validation` blocks for constrained inputs (e.g., environment must be dev/staging/prod)
- Use structured types (`object`, `map(object(...))`) for complex config — avoid loose maps
- Mark secrets `sensitive = true`
- Provide `default` only when a sensible universal default exists

## Local Values

- Compute `name_prefix = "${var.environment}-${var.project_name}"` in locals
- Build `common_tags` by merging `var.tags` with Environment, ManagedBy, Project
- Derive AZs and subnets via expressions in locals, not hardcoded

## Module Pattern

- Name the primary resource `this` inside modules
- Module variables: same rules as root (description, type, validation)
- Module outputs: always include `description`; mark sensitive outputs with `sensitive = true`
- Reference modules with relative `source` paths (`../../modules/eks-cluster`)
- Use explicit `depends_on` only when implicit dependency graph is insufficient

## State Management

- ALWAYS use remote state with locking (S3+DynamoDB or Terraform Cloud)
- State key should encode environment: `env/{environment}/terraform.tfstate`
- Create DynamoDB lock table with `LockID` string hash key, `PAY_PER_REQUEST` billing

## Sensitive Data

- NEVER hardcode secrets in `.tf` or `.tfvars`

```hcl
# ❌ Bad
resource "aws_db_instance" "main" { password = "mysecretpassword" }
# ✅ Good — use sensitive variable or aws_secretsmanager_secret_version data source
resource "aws_db_instance" "main" { password = var.db_password }
```

- Prefer Secrets Manager/SSM Parameter Store data sources over variable injection
- Never commit `.tfvars` files containing secrets

## Naming Conventions

- Variables, resources, outputs: `snake_case`
- Modules (directory names): `kebab-case`
- Resource naming pattern: `${environment}-${project}-${component}`

## Outputs

- Every output MUST have `description`
- Mark sensitive outputs `sensitive = true`
- Provide actionable outputs (e.g., CLI commands to configure kubeconfig)

## Best Practices

- Run `terraform fmt` before every commit
- Run `terraform validate` in CI
- ALWAYS review `terraform plan` output before apply
- NEVER use `terraform apply -auto-approve` in production (only on saved plan files in CI)
- Use `for_each` over `count` when iterating named items
- Tag ALL resources via `local.common_tags`
- Use `create_before_destroy = true` for zero-downtime replacements
- Use `prevent_destroy = true` on production stateful resources (RDS, S3, etc.)
- Use `ignore_changes` sparingly and only for externally-managed attributes
- Use data sources (`aws_caller_identity`, `aws_availability_zones`, `aws_ami`) instead of hardcoding account IDs, AZs, or AMI IDs

## CI/CD Integration

- CI runs `terraform init` → `terraform plan -out=tfplan`
- Apply step uses saved plan file: `terraform apply tfplan`
- Autoplan triggers should include module paths: `["*.tf", "../../modules/**/*.tf"]`
