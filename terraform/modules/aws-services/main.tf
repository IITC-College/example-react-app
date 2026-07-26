data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  securityhub_standards_arn = coalesce(
    var.securityhub_standards_arn,
    "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  )
}

# --- CloudTrail --------------------------------------------------------------

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.name}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

resource "aws_cloudtrail" "this" {
  name                          = "${var.name}-trail"
  s3_bucket_name                 = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail          = true
  include_global_service_events = true
  enable_log_file_validation    = true
  is_organization_trail          = false

  tags = var.tags

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# --- GuardDuty -----------------------------------------------------------------

resource "aws_guardduty_detector" "this" {
  enable = true

  tags = var.tags
}

# --- Security Hub -----------------------------------------------------------------

resource "aws_securityhub_account" "this" {}

resource "aws_securityhub_standards_subscription" "this" {
  standards_arn = local.securityhub_standards_arn

  depends_on = [aws_securityhub_account.this]
}

# --- AWS Backup -----------------------------------------------------------------

resource "aws_backup_vault" "this" {
  name = "${var.name}-backup-vault"
  tags = var.tags
}

data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restores" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_plan" "this" {
  name = "${var.name}-backup-plan"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.this.name
    schedule           = var.backup_schedule

    lifecycle {
      cold_storage_after = var.backup_cold_storage_after_days
      delete_after         = var.backup_delete_after_days
    }
  }

  tags = var.tags
}

resource "aws_backup_selection" "this" {
  name         = "${var.name}-backup-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id       = aws_backup_plan.this.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = var.backup_tag_key
    value = var.backup_tag_value
  }
}
