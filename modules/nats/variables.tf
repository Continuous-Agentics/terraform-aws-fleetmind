variable "fleet_name" {
  description = "Fleet name — used to namespace resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "vpc_id" {
  description = "VPC to deploy the NATS instance into."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for the NATS instance."
  type        = string
}

variable "fleet_sg_id" {
  description = "Security group ID of the fleet agent instances. NATS allows inbound 4222 from this SG."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the NATS server. t4g.small handles thousands of msg/s with ease."
  type        = string
  default     = "t4g.small"
}

variable "architecture" {
  description = "CPU architecture — must match instance_type. 'arm64' for t4g.*, 'x86_64' for t3.*."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "architecture must be 'arm64' or 'x86_64'."
  }
}

variable "ami_id" {
  description = "AMI override. Defaults to latest Amazon Linux 2023 for the given architecture."
  type        = string
  default     = ""
}

variable "nats_version" {
  description = "NATS server version to install (from GitHub releases). Pin for reproducibility."
  type        = string
  default     = "2.10.18"
}

variable "cloud_map_namespace_id" {
  description = "Cloud Map private DNS namespace ID. The NATS instance is registered as 'nats.<fleet_name>.internal' within this namespace."
  type        = string
}

variable "cloud_map_namespace_name" {
  description = "Cloud Map namespace DNS name (e.g. 'fleetmind.internal'). Used to construct the full NATS DNS name."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
