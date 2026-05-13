###############################################################################
# Networking — VPC create-or-adopt
#
# Two modes:
#   - Create new VPC (default): leave var.vpc_id empty. Module creates
#     a /16 VPC with 2 public + 2 private subnets across 2 AZs,
#     an IGW, single NAT gateway, and route tables.
#   - Adopt existing VPC: set var.vpc_id and provide
#     existing_public_subnet_ids (2) + existing_private_subnet_ids (2).
#     No new VPC, subnets, IGW, NAT, or route tables are created.
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  create_vpc = var.vpc_id == ""

  azs = local.create_vpc ? slice(data.aws_availability_zones.available.names, 0, 2) : []

  vpc_id          = local.create_vpc ? aws_vpc.main[0].id : var.vpc_id
  public_subnets  = local.create_vpc ? aws_subnet.public[*].id : var.existing_public_subnet_ids
  private_subnets = local.create_vpc ? aws_subnet.private[*].id : var.existing_private_subnet_ids
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ── New VPC (only created when vpc_id is not provided) ────────────────────────

resource "aws_vpc" "main" {
  count = local.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name_prefix}vpc" }
}

resource "aws_subnet" "public" {
  count = local.create_vpc ? 2 : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = local.azs[count.index]

  map_public_ip_on_launch = true
  tags                    = { Name = "${var.name_prefix}public-${count.index}" }
}

resource "aws_subnet" "private" {
  count = local.create_vpc ? 2 : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = { Name = "${var.name_prefix}private-${count.index}" }
}

resource "aws_internet_gateway" "main" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id
  tags   = { Name = "${var.name_prefix}igw" }
}

resource "aws_route_table" "public" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = { Name = "${var.name_prefix}public-rt" }
}

resource "aws_route_table_association" "public" {
  count = local.create_vpc ? 2 : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  count  = local.create_vpc ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.name_prefix}nat-eip" }
}

resource "aws_nat_gateway" "main" {
  count = local.create_vpc ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.name_prefix}nat" }
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = { Name = "${var.name_prefix}private-rt" }
}

resource "aws_route_table_association" "private" {
  count = local.create_vpc ? 2 : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}
