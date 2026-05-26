###############################################################################
# Fleetmind agent — single bot
#
# Provisions one Fleetmind agent's complete AWS footprint:
#   - EC2 instance (Amazon Linux 2023, private subnet, SSM-managed)
#   - IAM role + instance profile with least-privilege scoping
#   - Per-agent Secrets Manager secrets for Slack tokens + Anthropic API key
#
# Intended to be invoked from the root module via for_each over agent names.
# Cross-cutting policies (task-ledger PM/worker grants) are attached by the
# task-ledger submodule using the iam_role_name output from this module.
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

# ── IAM role + instance profile ──────────────────────────────────────────────

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "agent" {
  name               = "${var.fleet_name}-${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    "fleetmind:agent_id"   = var.name
    "fleetmind:fleet_name" = var.fleet_name
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "secrets" {
  name = "${var.fleet_name}-${var.name}-secrets-read"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        # Agent reads its own per-agent secrets + the fleet's shared/* namespace
        # + any caller-supplied ARNs from var.shared_secret_arns (intended for
        # AWS-managed secrets whose names the caller can't fully predict).
        Resource = concat(
          [
            "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.fleet_name}/agents/${var.name}/*",
            "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.fleet_name}/shared/*",
          ],
          var.shared_secret_arns,
        )
      },
      {
        Sid    = "SecretsWrite"
        Effect = "Allow"
        Action = [
          "secretsmanager:PutSecretValue",
          "secretsmanager:CreateSecret",
        ]
        # Agent writes only its own per-agent secrets (e.g. gateway auth token
        # generated at bootstrap).
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.fleet_name}/agents/${var.name}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "dynamodb" {
  count = var.context_store_enabled ? 1 : 0

  name = "${var.fleet_name}-${var.name}-dynamodb"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBContextStore"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
        ]
        Resource = var.context_store_table_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_app" {
  name = "${var.fleet_name}-${var.name}-github-app"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubAppSSMRead"
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/fleetmind/${var.fleet_name}/agents/${var.name}/github-app/*",
        ]
      },
      {
        Sid      = "GitHubAppKMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = ["arn:aws:kms:${var.aws_region}:*:key/aws/ssm"]
      },
    ]
  })
}

# GitHub Packages auth: shared PAT in SSM. All agents read the same SecureString
# param. Single point of revocation. The path is fleet-agnostic on purpose.
resource "aws_iam_role_policy" "github_packages" {
  name = "${var.fleet_name}-${var.name}-github-packages"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubPackagesSSMRead"
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/fleetmind/shared/github-packages-token",
        ]
      },
      {
        Sid      = "GitHubPackagesKMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = ["arn:aws:kms:${var.aws_region}:*:key/aws/ssm"]
      },
    ]
  })
}

resource "aws_iam_instance_profile" "agent" {
  name = "${var.fleet_name}-${var.name}-profile"
  role = aws_iam_role.agent.name
}

# ── Per-agent Secrets Manager secrets ────────────────────────────────────────
# Placeholders; operator populates real values out-of-band after apply
# (lifecycle.ignore_changes on secret_string preserves operator-set values).

locals {
  slack_placeholder = <<-JSON
    {
      "SLACK_BOT_TOKEN": "REPLACE_ME_xoxb-...",
      "SLACK_SIGNING_SECRET": "REPLACE_ME",
      "SLACK_APP_TOKEN": "REPLACE_ME_xapp-..."
    }
  JSON

  anthropic_placeholder = <<-JSON
    {
      "ANTHROPIC_API_KEY": "REPLACE_ME_sk-ant-..."
    }
  JSON

  # Placeholder only — the real token is generated at bootstrap time by
  # agent_bootstrap.sh.tpl (STAGE 7c) and written directly to Secrets Manager
  # via `aws secretsmanager put-secret-value`. ignore_changes preserves that
  # bootstrap-generated value across subsequent `terraform apply` runs.
  hooks_placeholder = <<-JSON
    {
      "HOOKS_TOKEN": "PENDING_BOOTSTRAP"
    }
  JSON
}

resource "aws_secretsmanager_secret" "slack" {
  name                    = "${var.fleet_name}/agents/${var.name}/slack"
  description             = "Slack tokens for ${var.fleet_name} agent: ${var.name}"
  recovery_window_in_days = var.secret_recovery_window_days

  tags = { Agent = var.name }
}

resource "aws_secretsmanager_secret_version" "slack_placeholder" {
  secret_id     = aws_secretsmanager_secret.slack.id
  secret_string = local.slack_placeholder

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "anthropic" {
  name                    = "${var.fleet_name}/agents/${var.name}/anthropic"
  description             = "Anthropic API key for ${var.fleet_name} agent: ${var.name}"
  recovery_window_in_days = var.secret_recovery_window_days

  tags = { Agent = var.name }
}

resource "aws_secretsmanager_secret_version" "anthropic_placeholder" {
  secret_id     = aws_secretsmanager_secret.anthropic.id
  secret_string = local.anthropic_placeholder

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Hooks token secret.
# The placeholder value is overwritten by the bootstrap script on first start
# (STAGE 7c in agent_bootstrap.sh.tpl). ignore_changes preserves the
# bootstrap-generated token on all subsequent applies.
resource "aws_secretsmanager_secret" "hooks" {
  name                    = "${var.fleet_name}/agents/${var.name}/hooks"
  description             = "OpenClaw hooks endpoint token for ${var.fleet_name} agent: ${var.name}"
  recovery_window_in_days = var.secret_recovery_window_days

  tags = { Agent = var.name }
}

resource "aws_secretsmanager_secret_version" "hooks_placeholder" {
  secret_id     = aws_secretsmanager_secret.hooks.id
  secret_string = local.hooks_placeholder

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ── EC2 instance ─────────────────────────────────────────────────────────────

resource "aws_instance" "agent" {
  ami           = var.ami_id
  instance_type = var.instance_type

  # Agents go in private subnets — they only need outbound access (Slack Socket
  # Mode + AWS API via NAT). No public IP required.
  subnet_id                   = var.subnet_id
  associate_public_ip_address = false
  vpc_security_group_ids      = var.vpc_security_group_ids
  iam_instance_profile        = aws_iam_instance_profile.agent.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  # user_data_base64 + base64gzip keeps the rendered script under EC2's 16 KB
  # user_data limit while remaining fully transparent to the instance at boot.
  # user_data changes are ignored in lifecycle (see below) so bootstrap updates
  # do not trigger instance replacement. Reprovisioning is done by tainting the
  # resource explicitly when a bootstrap change must be applied to existing hosts.
  user_data_base64 = base64gzip(templatefile("${path.module}/user_data/agent_bootstrap.sh.tpl", {
    fleet_name        = var.fleet_name
    agent_id          = var.name
    openclaw_version  = var.openclaw_version
    node_version      = var.node_version
    aws_region        = var.aws_region
    fleetmind_version = var.fleetmind_version
    fleetmind_package = var.fleetmind_package
    is_orchestrator   = var.is_orchestrator
    gateway_port      = var.gateway_port
  }))

  tags = {
    Name                   = "${var.fleet_name}-${var.name}"
    "fleetmind:agent_id"   = var.name
    "fleetmind:fleet_name" = var.fleet_name
  }

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }
}
