###############################################################################
# Fleet S3 bucket — always created, regardless of delegation_enabled.
#
# This bucket serves two purposes:
#   1. deploy-staging/  — used by `fleetmind push fleet` for all fleets
#   2. v0/projects/...  — narrative content (only written when delegation_enabled)
#
# Separating bucket creation from the task-ledger module means single-bot
# fleets (delegation_enabled = false) still have the bucket that push fleet
# requires, without provisioning the full delegation substrate.
###############################################################################

locals {
  ledger_bucket_name = "${var.fleet_name}-ledger"
}

resource "aws_s3_bucket" "ledger" {
  bucket = local.ledger_bucket_name
  tags   = { Name = local.ledger_bucket_name }
}

resource "aws_s3_bucket_public_access_block" "ledger" {
  bucket                  = aws_s3_bucket.ledger.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "ledger" {
  bucket = aws_s3_bucket.ledger.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "ledger" {
  bucket = aws_s3_bucket.ledger.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ledger" {
  bucket = aws_s3_bucket.ledger.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ledger" {
  bucket = aws_s3_bucket.ledger.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "ledger_bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.ledger.arn,
      "${aws_s3_bucket.ledger.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "ledger" {
  bucket     = aws_s3_bucket.ledger.id
  policy     = data.aws_iam_policy_document.ledger_bucket_policy.json
  depends_on = [aws_s3_bucket_public_access_block.ledger]
}
