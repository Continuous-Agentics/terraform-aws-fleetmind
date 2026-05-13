output "vpc_id" {
  description = "VPC ID — either the newly created VPC or the adopted var.vpc_id."
  value       = local.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (2)."
  value       = local.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnet IDs (2)."
  value       = local.private_subnets
}

output "vpc_cidr_block" {
  description = "VPC CIDR block. Empty string when adopting an existing VPC (caller already knows it)."
  value       = local.create_vpc ? aws_vpc.main[0].cidr_block : ""
}

output "created_vpc" {
  description = "True if this module created the VPC, false if adopting an existing one."
  value       = local.create_vpc
}
