variable "name_prefix" {
  description = "Prefix applied to all resource names. Include a trailing separator (e.g. \"my-fleet-\"). Matches the convention used by the task-ledger submodule."
  type        = string

  validation {
    condition     = length(var.name_prefix) > 0
    error_message = "name_prefix must not be empty."
  }
}

variable "aws_region" {
  description = "AWS region. Used to construct VPC endpoint service names (e.g. com.amazonaws.<region>.s3)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the created VPC. Ignored when vpc_id is set (BYO VPC mode)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_id" {
  description = "ID of an existing VPC to deploy into. Leave empty (default) to create a new VPC managed by this module."
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "Public subnet IDs (2 required) when deploying into an existing VPC. Ignored when vpc_id is empty."
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "Private subnet IDs (2 required) when deploying into an existing VPC. Ignored when vpc_id is empty."
  type        = list(string)
  default     = []
}

variable "enable_interface_endpoints" {
  description = "Provision VPC interface endpoints for SSM (ssm, ssmmessages, ec2messages) and Secrets Manager. Adds ~$80/mo (4 endpoints * ~$20/mo). Only created when this module manages the VPC (vpc_id is empty). When bringing your own VPC, wire endpoints in your own infrastructure."
  type        = bool
  default     = false
}
