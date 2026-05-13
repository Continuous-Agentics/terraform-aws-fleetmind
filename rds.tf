# ── RDS Postgres 16 ───────────────────────────────────────────────────────────
#
# Placed in private subnets — not internet-accessible.
# Agent SG is the only allowed ingress source.
#
# Note: with DynamoDB as the primary ContextStore, RDS is optional.
# Set var.enable_rds = false to skip this entirely for simpler deployments.

resource "aws_db_subnet_group" "main" {
  count = var.enable_rds ? 1 : 0

  name       = "${var.fleet_name}-db-subnet-group"
  subnet_ids = module.networking.private_subnet_ids

  tags = { Name = "${var.fleet_name}-db-subnet-group" }
}

# Master password is generated, stored, and rotated by RDS itself via
# manage_master_user_password = true. The credentials live in a Secrets Manager
# secret AWS owns (name: rds!db-<random>); no password ever touches Terraform
# state. The secret ARN is exposed as the db_master_user_secret_arn output.
#
# Agents construct the DATABASE_URL at runtime by reading the AWS-managed
# secret (returns {username, password}) and combining with the db_endpoint
# output. See README.md "Database access".

resource "aws_db_instance" "main" {
  count = var.enable_rds ? 1 : 0

  identifier        = "${var.fleet_name}-postgres"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "fleetmind"
  username                    = "fleetmind"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]

  multi_az                  = var.rds_multi_az
  publicly_accessible       = false
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.fleet_name}-postgres-final"

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  deletion_protection = true

  tags = { Name = "${var.fleet_name}-postgres" }
}


