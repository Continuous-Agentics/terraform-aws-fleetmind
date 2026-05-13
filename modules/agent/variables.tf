variable "name" {
  description = "Agent name within the fleet (e.g. \"pm\", \"forge\"). Used for resource naming and secret namespace."
  type        = string

  validation {
    condition     = length(var.name) > 0
    error_message = "name must not be empty."
  }
}

variable "fleet_name" {
  description = "Fleet name. Combined with var.name to form resource names ($${fleet_name}-$${name}-*) and secret namespace ($${fleet_name}/agents/$${name}/*)."
  type        = string
}

variable "aws_region" {
  description = "AWS region. Used to construct ARNs for IAM policy resource scoping."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the agent instance. Typically derived once at the root from data.aws_ami and passed into every agent."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for this agent."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance into. Should be a private subnet — agents only need egress."
  type        = string
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to attach to the instance."
  type        = list(string)
}

variable "agent_port" {
  description = "TCP port the agent's OpenClaw gateway listens on."
  type        = number
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 50
}

# ── User-data bootstrap inputs ───────────────────────────────────────────────

variable "openclaw_version" {
  description = "OpenClaw npm package version pin for the bootstrap script."
  type        = string
}

variable "node_version" {
  description = "Node.js major version for the bootstrap script (nvm install)."
  type        = string
}

variable "fleetmind_version" {
  description = "Fleetmind CLI npm package version pin for the bootstrap script."
  type        = string
}

# ── IAM policy inputs ────────────────────────────────────────────────────────

variable "context_store_table_arn" {
  description = "ARN of the DynamoDB ContextStore table. When non-empty, the agent role gets read/write on this table. Pass an empty string when the fleet uses a non-DDB context-store backend (e.g. RDS)."
  type        = string
  default     = ""
}

variable "shared_secret_arns" {
  description = "Additional Secrets Manager ARNs (outside the $${fleet_name}/agents/$${name}/* and $${fleet_name}/shared/* namespaces) that the agent role must be able to read. Typically used to grant access to the RDS-managed master-user secret (name: rds!db-<random>) which AWS owns and names."
  type        = list(string)
  default     = []
}

variable "secret_recovery_window_days" {
  description = "recovery_window_in_days for the per-agent Slack + Anthropic secrets."
  type        = number
  default     = 7
}
