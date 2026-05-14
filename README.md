# terraform-aws-fleetmind

Terraform module for [Fleetmind](https://github.com/Continuous-Agentics/fleetmind) — multi-bot fleet infrastructure on AWS.

Provisions a fleet of OpenClaw agent EC2 instances with a DynamoDB ContextStore, optional task-ledger primitives (DynamoDB single-table, S3 narratives bucket, EventBridge Pipe), per-agent IAM roles, VPC + endpoints, and security groups.

## Status

🚧 *Pre-release.* Extracted from `fleetmind/infra/terraform/` to support module consumption from the upcoming [`fleetmind-template`](https://github.com/Continuous-Agentics/fleetmind/issues/26) repo. First tagged release will be `v0.1.0`.

Existing fleets (gg-sandbox, fleet-test-2) remain on the legacy direct-apply pattern at `Continuous-Agentics/fleetmind/infra/terraform/` until tear-down.

## Module layout

```
terraform-aws-fleetmind/
├── main.tf, variables.tf, outputs.tf   # root: composition + cross-cutting locals
├── vpc.tf                              # VPC + endpoints via terraform-aws-modules/vpc/aws (BYO VPC supported)
├── dynamodb.tf                         # ContextStore table (gated on context_store_backend)
├── sg.tf                               # fleet security group
└── modules/
    ├── agent/                          # one bot: EC2 + IAM role + per-agent secrets
    └── task-ledger/                    # delegation substrate (DDB + S3 + Pipes + EventBridge)
```

Networking is built on upstream [`terraform-aws-modules/vpc/aws`](https://github.com/terraform-aws-modules/terraform-aws-vpc) (pinned `~> 5.0`). BYO VPC is supported via `var.vpc_id` + the `existing_*_subnet_ids` pair.

## Consumer setup

Consumers configure their own `provider "aws"`, Terraform backend, and `default_tags` in their root module:

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

Use Terraform workspaces (`terraform workspace new <fleet-name>`) to isolate state per fleet — the backend `key` is intentionally not set so workspaces auto-prefix state files with `env:/<workspace>/`.

## ContextStore backend

`var.context_store_backend` (default `"dynamodb"`) selects the storage backend for the fleet's shared cross-agent key-value state. Today only `"dynamodb"` is supported — the agent runtime (`src/runtime/context.ts`) only speaks DynamoDB. The variable exists to set up a clean seam for future backends (e.g. `"rds"`) without an interface break.

## What this module manages

- VPC + subnets + endpoints (via upstream `terraform-aws-modules/vpc/aws` and `//modules/vpc-endpoints`; BYO VPC via `var.vpc_id`)
- Fleet security group
- Per-agent EC2 instances, IAM roles, and Secrets Manager placeholders (via `modules/agent/`, one call per agent)
- DynamoDB ContextStore table (when `context_store_backend = "dynamodb"`)
- *Optional* task-ledger submodule (`var.delegation_enabled = true`): DynamoDB tasks table, S3 narratives bucket, EventBridge Pipe + rule for terminal-state agent wake-ups

## Inputs and outputs

Full surface in [`variables.tf`](variables.tf) and [`outputs.tf`](outputs.tf). Selected outputs:

- *Per-agent* (one entry each in the returned map, keyed by agent id):
  `instance_ids`, `private_ips`, `ssm_connect`, `agent_workspace_paths`, `agent_service_names`, `agent_iam_role_names`, `secrets_arns`
- *Networking:* `vpc_id`
- *ContextStore:* `context_store_backend`, `context_store_table_name`, `context_store_table_arn`
- *Deploy-staging bucket* (always created): `ledger_bucket_name`
- *Task-ledger* (empty/null when `delegation_enabled = false`):
  `task_ledger_table_name`, `task_ledger_s3_bucket`,
  `task_ledger_pm_policy_arn`, `task_ledger_worker_policy_arn`

> Note: `ledger_bucket_name` is the always-created deploy-staging bucket; `task_ledger_s3_bucket` is the same bucket *as exposed by the task-ledger submodule* and returns an empty string when delegation is disabled. Most consumers should use `ledger_bucket_name`.

## Docs

- [`docs/EXISTING-VPC.md`](docs/EXISTING-VPC.md) — deploying into an existing VPC (BYO VPC mode), requirements, current interface-endpoints limitation.
- [`docs/TASK-LEDGER-STANDALONE.md`](docs/TASK-LEDGER-STANDALONE.md) — calling `modules/task-ledger/` directly from your own Terraform root, for callers who don't want the full fleetmind EC2/VPC stack.
- [`docs/MODULE-TROUBLESHOOTING.md`](docs/MODULE-TROUBLESHOOTING.md) — IaC-side failures: state lock recovery, derived.tfvars propagation, per-agent taint/replace, DLQ inspection, `secret_recovery_window_days` gotchas.
- [`docs/MIGRATIONS.md`](docs/MIGRATIONS.md) — per-version upgrade notes (baseline: `v0.1.6`).

## License

Apache 2.0 — see [LICENSE](LICENSE).
