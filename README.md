# terraform-aws-fleetmind

Terraform module for [Fleetmind](https://github.com/Continuous-Agentics/fleetmind) — multi-bot fleet infrastructure on AWS.

Provisions a fleet of OpenClaw agent EC2 instances with shared task-ledger primitives (DynamoDB single-table, S3 narratives bucket, EventBridge Pipe), per-agent IAM roles, RDS, VPC + endpoints, and security groups.

## Status

🚧 *Pre-release.* Extracted from `fleetmind/infra/terraform/` to support module consumption from the upcoming [`fleetmind-template`](https://github.com/Continuous-Agentics/fleetmind/issues/26) repo. First tagged release will be `v0.1.0`.

Existing fleets (gg-sandbox, fleet-test-2) remain on the legacy direct-apply pattern at `Continuous-Agentics/fleetmind/infra/terraform/` until tear-down.

## Consumer setup

Consumers configure their own `provider "aws"`, Terraform backend, and `default_tags` in their root module. Example:

```hcl
terraform {
  required_version = ">= 1.5"

  backend "s3" {
    bucket         = "my-fleet-tfstate"
    region         = "us-west-2"
    dynamodb_table = "my-fleet-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.fleet_name
      ManagedBy   = "terraform"
      Environment = "production"
    }
  }
}

module "fleetmind" {
  source = "github.com/Continuous-Agentics/terraform-aws-fleetmind?ref=v0.1.0"

  fleet_name              = "my-fleet"
  aws_region              = "us-west-2"
  agent_names             = ["pm", "fe"]
  agent_orchestrators     = { pm = true, fe = false }
  wake_target_session_key = "agent:main:slack:channel:C0123456789"
  delegation_enabled      = true
  # ...see variables.tf for the full input surface
}
```

*Important:* `default_tags` no longer applies automatically — the module's previous provider config set `Project`/`ManagedBy`/`Environment` tags on every resource. Consumers must configure `default_tags` themselves (as shown above) to keep equivalent tagging behavior.

Use Terraform workspaces (`terraform workspace new <fleet-name>`) to isolate state per fleet — the backend `key` is intentionally not set so workspaces auto-prefix state files with `env:/<workspace>/`.

## What this module manages

- VPC + subnets + endpoints
- Security groups
- Per-agent EC2 instances (Amazon Linux 2023, SSM-managed)
- Per-agent IAM roles + instance profiles
- RDS Postgres (shared fleet datastore)
- AWS Secrets Manager secrets for per-agent + RDS credentials
- *Optional* task-ledger submodule (`var.delegation_enabled = true`): DynamoDB single-table, S3 narratives bucket, EventBridge Pipe + rule for terminal-state agent wake-ups

## Inputs and outputs

See [`variables.tf`](variables.tf) (23 inputs) and [`outputs.tf`](outputs.tf) (9 outputs incl. `agent_iam_role_names` for attaching consumer-side policies post-apply).

## License

Apache 2.0 — see [LICENSE](LICENSE).
