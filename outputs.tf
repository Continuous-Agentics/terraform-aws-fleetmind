# ── Per-agent outputs (sourced from module.agent[*]) ─────────────────────────

output "instance_ids" {
  description = "EC2 instance ID per agent."
  value       = { for k, m in module.agent : k => m.instance_id }
}

output "private_ips" {
  description = "Private IP per agent."
  value       = { for k, m in module.agent : k => m.private_ip }
}

output "ssm_connect" {
  description = "SSM Session Manager connect commands, one per agent."
  value       = { for k, m in module.agent : k => "aws ssm start-session --target ${m.instance_id} --region ${var.aws_region}" }
}

output "agent_workspace_paths" {
  description = "Workspace directory path on each agent's instance."
  value       = { for k, m in module.agent : k => m.workspace_path }
}

output "agent_service_names" {
  description = "systemd service name per agent."
  value       = { for k, m in module.agent : k => m.service_name }
}

output "agent_iam_role_names" {
  description = "IAM role name per agent. Useful for consumers that want to attach additional policies to per-agent roles after terraform apply (e.g. project-specific access grants)."
  value       = { for k, m in module.agent : k => m.iam_role_name }
}

output "secrets_arns" {
  description = "Secrets Manager ARNs — slack and anthropic keys per agent."
  value = merge(
    { for k, m in module.agent : "${k}_slack" => m.slack_secret_arn },
    { for k, m in module.agent : "${k}_anthropic" => m.anthropic_secret_arn },
  )
}

# ── Shared fleet infrastructure outputs ──────────────────────────────────────

output "vpc_id" {
  description = "VPC ID (created or adopted by modules/networking)."
  value       = module.networking.vpc_id
}

output "rds_endpoint" {
  description = "RDS Postgres endpoint (host:port). Empty string when enable_rds = false."
  value       = var.enable_rds ? aws_db_instance.main[0].endpoint : ""
}

output "db_name" {
  description = "Postgres database name created on the RDS instance. Empty string when enable_rds = false."
  value       = var.enable_rds ? aws_db_instance.main[0].db_name : ""
}

output "db_master_user_secret_arn" {
  description = "ARN of the AWS-managed Secrets Manager secret holding the RDS master user credentials (managed by RDS via manage_master_user_password). Agents read this at runtime to construct the DATABASE_URL. Empty string when enable_rds = false."
  value       = var.enable_rds ? aws_db_instance.main[0].master_user_secret[0].secret_arn : ""
}

# ── Task-ledger outputs (populated when delegation_enabled = true) ───────────

output "task_ledger_table_name" {
  description = "DynamoDB task-ledger table name. Used by 'fleetmind task ack/ship' and the bot-delegation/bot-reception skills. Empty string when delegation_enabled = false."
  value       = var.delegation_enabled ? module.task_ledger[0].table_name : ""
}

output "task_ledger_s3_bucket" {
  description = "S3 bucket name for task narrative content. Empty string when delegation_enabled = false."
  value       = var.delegation_enabled ? module.task_ledger[0].s3_bucket_name : ""
}

output "task_ledger_pm_policy_arn" {
  description = "ARN of the bot-ledger-pm IAM policy. Empty string when delegation_enabled = false."
  value       = var.delegation_enabled ? module.task_ledger[0].pm_policy_arn : ""
}

output "task_ledger_worker_policy_arn" {
  description = "ARN of the bot-ledger-worker IAM policy. Empty string when delegation_enabled = false."
  value       = var.delegation_enabled ? module.task_ledger[0].worker_policy_arn : ""
}
