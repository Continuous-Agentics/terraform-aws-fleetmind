# networking submodule

VPC + subnets + endpoints for a Fleetmind fleet.

Two modes:

- *Create new VPC* (default): leave `var.vpc_id` empty. Module provisions a `/16` VPC (CIDR configurable via `vpc_cidr`) with 2 public + 2 private subnets across 2 AZs, an IGW, a single NAT gateway, route tables, and VPC endpoints (S3 + DynamoDB gateway endpoints free; SSM + Secrets Manager interface endpoints opt-in via `enable_interface_endpoints`).
- *Adopt existing VPC*: set `var.vpc_id` and supply `existing_public_subnet_ids` (2) + `existing_private_subnet_ids` (2). No VPC, subnets, IGW, NAT, route tables, or endpoints are created. Wire endpoints in your own infrastructure if needed.

Consumed by the root `terraform-aws-fleetmind` module. Not intended to be a public general-purpose VPC module — it is opinionated to Fleetmind's needs (2 AZs, single NAT, specific endpoint set).
