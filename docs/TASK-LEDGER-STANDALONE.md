# Standalone task-ledger consumption

The `modules/task-ledger/` submodule provisions the delegation substrate (DynamoDB table, S3 narratives bucket, IAM policies, EventBridge Pipe + rule for the wake pipeline). It's normally activated by the root `terraform-aws-fleetmind` module whenever `delegation_enabled = true` — that's the canonical path used by `fleetmind-template`.

This doc covers calling the submodule **directly** from your own Terraform root. Use this when:
- You're integrating delegation into a fleet that doesn't use `fleetmind-template` or the root module.
- You want delegation infra without the rest of the fleetmind EC2/VPC/SG stack (e.g. you already manage agent EC2s yourself).

If you're using `fleetmind-template`, skip this doc — set `delegation_enabled = true` in your tfvars and you're done.

---

## Consuming Terraform root

```hcl
# my-fleet-infra/main.tf

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket  = "my-terraform-state"
    key     = "my-fleet/task-ledger.tfstate"
    region  = "us-east-1"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "task_ledger" {
  source = "github.com/Continuous-Agentics/terraform-aws-fleetmind//modules/task-ledger?ref=v0.1.6"

  name_prefix = "my-fleet-"
  aws_region  = "us-east-1"

  # Existing IAM role names (created by your bot EC2 module).
  pm_role_names     = ["my-fleet-pm-bot-role"]
  worker_role_names = ["my-fleet-worker-bot-role"]

  # Wake signaling: SSM Run Command target.
  wake_target_instance_tag_key   = "Name"
  wake_target_instance_tag_value = "my-fleet-pm-bot"
  wake_target_session_key        = "agent:main:slack:channel:C123456789"

  # Optional: email for DLQ alarm notifications.
  alert_email = "oncall@my-org.example.com"

  tags = {
    product = "my-fleet"
    env     = "production"
  }
}

output "table_name"    { value = module.task_ledger.table_name }
output "s3_bucket"     { value = module.task_ledger.s3_bucket_name }
output "pm_policy"     { value = module.task_ledger.pm_policy_arn }
output "worker_policy" { value = module.task_ledger.worker_policy_arn }
```

Apply:

```bash
cd my-fleet-infra
terraform init
terraform plan
terraform apply
```

Note the `table_name` and `s3_bucket` outputs — they feed into the consuming fleet's `fleet.yaml` `delegation:` block (or equivalent agent runtime config).

---

## Inputs (selected)

| Input | Required | Default | Notes |
|---|---|---|---|
| `name_prefix` | yes | — | Prefix for all created resources; must end in `-`. Resources: `<prefix>tasks` (DDB), `<prefix>ledger` (S3), `<prefix>pm-task-ledger-readwrite` / `<prefix>worker-task-ledger-readwrite` (IAM policies), `<prefix>ledger-pipe-dlq` / `<prefix>ledger-wake-dlq` (DLQs). |
| `aws_region` | yes | — | Used for SSM target resolution. |
| `pm_role_names` | yes | — | IAM role names that should be granted PM-side ledger access (read+write all tasks, dispatch wake commands). |
| `worker_role_names` | yes | — | IAM role names that should be granted worker-side ledger access (read+write own tasks only). |
| `wake_target_instance_tag_key` | yes | — | Tag key for the EventBridge → SSM Run Command target (the PM EC2). |
| `wake_target_instance_tag_value` | yes | — | Tag value. |
| `wake_target_session_key` | yes | — | OpenClaw session key for the PM, e.g. `agent:main:slack:channel:C0123456789`. Used as the `SESSION_KEY` env var in the SSM-invoked `ddb-wake.sh`. |
| `alert_email` | no | `""` | If set, creates an SNS topic + subscription for DLQ alarms. |
| `tags` | no | `{}` | Applied to all module-created resources. |

See [`modules/task-ledger/variables.tf`](../modules/task-ledger/variables.tf) for the full input surface including knobs you usually don't touch (DDB billing mode, S3 lifecycle rules, EventBridge filter pattern).

---

## Outputs

| Output | Purpose |
|---|---|
| `table_name` | DynamoDB tasks table name. Feed into your agent runtime's `delegation.table_name`. |
| `s3_bucket_name` | S3 narratives bucket. Feed into your agent runtime's `delegation.s3_bucket`. |
| `pm_policy_arn` | Attach to PM bot's IAM role if you didn't pass it via `pm_role_names`. |
| `worker_policy_arn` | Same for workers. |
| `pipe_arn`, `rule_arn` | Diagnostic — referenced by the DLQ alarms and visible in EventBridge console. |

---

## Wake pipeline topology

The submodule wires this end-to-end:

```
Worker UpdateItem (terminal status: shipped|blocked|abandoned|merged)
  → DDB Stream record
  → EventBridge Pipe (filters on terminal statuses)
  → EventBridge rule
  → SSM Run Command on PM's EC2
  → /opt/openclaw/ddb-wake.sh
  → openclaw agent --message "DDB_TERMINAL_WAKE: TASK#<id>"
```

Failure modes are caught by two DLQs:
- `<prefix>ledger-pipe-dlq` — Pipe couldn't filter/transform the stream record (rare; usually IAM perms)
- `<prefix>ledger-wake-dlq` — SSM Run Command failed (instance offline, missing tag, missing SSM perms)

CloudWatch alarms on DLQ message-count fire when `alert_email` is set.

---

## Related

- Root module overview: [`README.md`](../README.md)
- Existing-VPC deployment: [`EXISTING-VPC.md`](./EXISTING-VPC.md)
- Module-level troubleshooting (state lock, taint, DLQ recovery): [`MODULE-TROUBLESHOOTING.md`](./MODULE-TROUBLESHOOTING.md)
- Agent-runtime side of delegation (fleet.yaml schema, protocol): see [fleetmind/docs/integration/delegation.md](https://github.com/Continuous-Agentics/fleetmind/blob/main/docs/integration/delegation.md) (private — requires Carpe access)
