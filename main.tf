# Module declares only required providers; consumer configures `provider "aws"`
# and the Terraform backend in their root module. See README.md "Consumer setup"
# for an example root configuration.
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── Networking (VPC + subnets + endpoints) ────────────────────────────────────
module "networking" {
  source = "./modules/networking"

  name_prefix = "${var.fleet_name}-"
  aws_region  = var.aws_region
  vpc_cidr    = var.vpc_cidr

  vpc_id                      = var.vpc_id
  existing_public_subnet_ids  = var.existing_public_subnet_ids
  existing_private_subnet_ids = var.existing_private_subnet_ids

  enable_interface_endpoints = var.enable_interface_endpoints
}

# ── Latest Amazon Linux 2023 AMI ──────────────────────────────────────────────
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    # Excludes the "minimal" AMI variant (al2023-ami-minimal-*) which does NOT
    # include amazon-ssm-agent. The standard AMI name begins with the year:
    # al2023-ami-2023.X.YYYYMMDD.N-kernel-*-x86_64
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023.id

  # Derive the EC2 Name tag value for the primary PM bot so the task-ledger
  # EventBridge rule can target it via SSM Run Command.
  # Falls back to the first agent if no orchestrators are declared.
  pm_agent_names     = [for name in var.agent_names : name if lookup(var.agent_orchestrators, name, false)]
  wake_instance_name = length(local.pm_agent_names) > 0 ? "${var.fleet_name}-${local.pm_agent_names[0]}" : (length(var.agent_names) > 0 ? "${var.fleet_name}-${var.agent_names[0]}" : "${var.fleet_name}-agent")
}

# ── One agent submodule per declared agent ────────────────────────────────────
# Each call produces the full per-bot AWS footprint: EC2 instance, IAM role +
# instance profile + policies, and per-agent Slack + Anthropic secrets.
#
# Cross-cutting policies (task-ledger PM/worker grants) are attached separately
# by the task-ledger submodule below using module.agent[*].iam_role_name.
module "agent" {
  for_each = toset(var.agent_names)
  source   = "./modules/agent"

  name       = each.key
  fleet_name = var.fleet_name
  aws_region = var.aws_region

  ami_id        = local.ami_id
  instance_type = lookup(var.agent_instance_types, each.key, var.instance_type)
  # Round-robin agents across the 2 private subnets for AZ spread.
  subnet_id              = module.networking.private_subnet_ids[index(var.agent_names, each.key) % 2]
  vpc_security_group_ids = [aws_security_group.fleet.id]
  agent_port             = var.agent_ports[each.key]

  openclaw_version  = var.openclaw_version
  node_version      = var.node_version
  fleetmind_version = var.fleetmind_version

  context_store_table_arn     = var.context_store_backend == "dynamodb" ? aws_dynamodb_table.context_store[0].arn : ""
  secret_recovery_window_days = var.secret_recovery_window_days
}

# ── Task-ledger module ────────────────────────────────────────────────────────
# Creates the DynamoDB task table, S3 narratives bucket, EventBridge Pipe,
# and IAM policy attachments for PM and worker bots.
#
# Gated behind var.delegation_enabled (default false) so fleets that don't use
# the delegation substrate skip it entirely.
#
# Required tfvars when enabling:
#   delegation_enabled      = true
#   agent_orchestrators     = { conductor = true, forge = false }  # example
#   wake_target_session_key = "agent:main:slack:channel:<channel_id>"

module "task_ledger" {
  count  = var.delegation_enabled ? 1 : 0
  source = "./modules/task-ledger"

  name_prefix = "${var.fleet_name}-"
  aws_region  = var.aws_region

  # PM bots get the bot-ledger-pm policy (create/update tasks, write narratives)
  pm_role_names = [
    for name in var.agent_names :
    module.agent[name].iam_role_name
    if lookup(var.agent_orchestrators, name, false)
  ]

  # Worker bots get the bot-ledger-worker policy (update task status, write task .md)
  worker_role_names = [
    for name in var.agent_names :
    module.agent[name].iam_role_name
    if !lookup(var.agent_orchestrators, name, false)
  ]

  # EventBridge rule targets the primary PM bot's EC2 instance by Name tag.
  # The Name tag is set inside modules/agent/main.tf: "${fleet_name}-${name}".
  wake_target_instance_tag_key   = "Name"
  wake_target_instance_tag_value = local.wake_instance_name

  # OpenClaw session key to wake when a terminal task event fires.
  # Format: agent:main:slack:channel:<channel_id>
  wake_target_session_key = var.wake_target_session_key

  tags = {
    Project   = var.fleet_name
    ManagedBy = "terraform"
  }
}
