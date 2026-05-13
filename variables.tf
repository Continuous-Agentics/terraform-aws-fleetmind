variable "fleet_name" {
  description = "Name of the FleetMind fleet. Used to namespace all AWS resources and workspace paths."
  type        = string
  default     = "fleetmind"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type. t3.medium comfortably runs 3 OpenClaw agents. Scale up if adding more."
  type        = string
  default     = "t3.medium"
}

variable "agent_names" {
  description = "List of agent names. Each gets its own EC2 instance, IAM role, and per-agent secrets. Must be non-empty and unique."
  type        = list(string)
  default     = ["orchestrator", "pixel", "forge"]

  validation {
    condition     = length(var.agent_names) > 0
    error_message = "agent_names must not be empty — a fleet has at least one agent."
  }

  validation {
    condition     = length(var.agent_names) == length(toset(var.agent_names))
    error_message = "agent_names must be unique."
  }
}

variable "agent_ports" {
  description = "Map of agent name to OpenClaw port."
  type        = map(number)
  default = {
    orchestrator = 18789
    pixel        = 18790
    forge        = 18791
  }
}

variable "openclaw_version" {
  description = "OpenClaw npm package version to install. Use 'latest' or pin to a specific version."
  type        = string
  default     = "latest"
}

variable "node_version" {
  description = "Node.js major version to install via nvm."
  type        = string
  default     = "22"
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH to the fleet instance. Default empty — use SSM Session Manager instead."
  type        = list(string)
  default     = []
}

variable "ami_id" {
  description = "AMI ID override. Defaults to latest Amazon Linux 2023 if left empty."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the created VPC. Ignored when vpc_id is set (BYO VPC mode)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_id" {
  description = "ID of an existing VPC to deploy into. Leave empty to create a new VPC."
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "IDs of existing public subnets (2 required) when deploying into an existing VPC."
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "IDs of existing private subnets (2 required) when deploying into an existing VPC."
  type        = list(string)
  default     = []
}

variable "context_store_backend" {
  description = "Backend for the fleet ContextStore (cross-agent shared key-value state). Only \"dynamodb\" is supported today; the variable exists to set up the seam for future backends (e.g. \"rds\") without an interface break. When the runtime gains additional backends, valid values will be widened here."
  type        = string
  default     = "dynamodb"

  validation {
    condition     = contains(["dynamodb"], var.context_store_backend)
    error_message = "context_store_backend must be \"dynamodb\" (the only backend the agent runtime currently supports)."
  }
}

# ── Per-agent overrides (optional) ────────────────────────────────────────────
# All default to empty maps so existing deployments are unaffected.
# Use these in tfvars to give specific agents different sizing.

variable "agent_instance_types" {
  description = "Per-agent EC2 instance type overrides (map of agent_id → instance_type). Falls back to var.instance_type for any agent not listed."
  type        = map(string)
  default     = {}
}

variable "agent_orchestrators" {
  description = "Map of agent_id → bool indicating which agents are PM/orchestrator bots. Used by the task-ledger module to split IAM policy attachments: orchestrators get the pm policy; non-orchestrators get the worker policy."
  type        = map(bool)
  default     = {}
}

variable "delegation_enabled" {
  description = "Instantiate the task-ledger submodule (DynamoDB task table, S3 narratives bucket, EventBridge Pipe, DLQ infrastructure). Default true — the bot-delegation flow is a core Fleetmind feature. Set false only for fleets that explicitly do not use delegation (e.g. single-bot fleets) to skip the substrate."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "Provision VPC interface endpoints for SSM (ssm, ssmmessages, ec2messages) and Secrets Manager. Adds ~$80/mo (4 endpoints × ~$20/mo). Default false. Recommended for fleets in fully-private subnets without NAT, or operators who want SSM resilience independent of NAT health."
  type        = bool
  default     = false
}

variable "wake_target_session_key" {
  description = "OpenClaw session key used by the task-ledger EventBridge rule to wake the PM bot via SSM Run Command when a terminal task event fires. Format: agent:main:slack:channel:<channel_id>. Required (non-empty) when delegation_enabled = true."
  type        = string
  default     = ""
}

variable "fleetmind_version" {
  description = "Version of @continuous-agentics/fleetmind to install on each agent EC2."
  type        = string
  default     = "latest"
}

variable "secret_recovery_window_days" {
  description = "AWS Secrets Manager recovery window (days) after deletion. Applied to per-agent Slack and Anthropic secrets. Must be 0 (delete immediately, useful for ephemeral test fleets) or 7–30 (AWS-enforced range)."
  type        = number
  default     = 7

  validation {
    condition     = var.secret_recovery_window_days == 0 || (var.secret_recovery_window_days >= 7 && var.secret_recovery_window_days <= 30)
    error_message = "secret_recovery_window_days must be 0 or in the inclusive range 7\u201330 (AWS Secrets Manager constraint)."
  }
}
