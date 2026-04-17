# Bootstrap: run this ONCE before any environment terraform apply.
# It creates the S3 state buckets and KMS keys used in each env's backend.tf.
#
# Usage:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply -var="aws_account_id=<YOUR_ACCOUNT_ID>"

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

variable "aws_account_id" {
  description = "AWS account ID — used to restrict bucket policy to this account only"
  type        = string
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "jeevagan"
}

locals {
  envs = ["dev", "staging", "prod", "dr", "tools"]
}

# ── KMS key per environment (dedicated key per env, not a shared key) ──────────

resource "aws_kms_key" "tfstate" {
  for_each = toset(local.envs)

  description             = "${var.project}-${each.key} Terraform state encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project}-tfstate-${each.key}-kms"
    Environment = each.key
    Project     = var.project
    ManagedBy   = "terraform-bootstrap"
  }
}

resource "aws_kms_alias" "tfstate" {
  for_each = toset(local.envs)

  name          = "alias/${var.project}-tfstate-${each.key}"
  target_key_id = aws_kms_key.tfstate[each.key].key_id
}

# ── S3 state buckets ───────────────────────────────────────────────────────────

resource "aws_s3_bucket" "tfstate" {
  for_each = toset(local.envs)

  bucket        = "${var.project}-tfstate-${each.key}"
  force_destroy = false

  tags = {
    Name        = "${var.project}-tfstate-${each.key}"
    Environment = each.key
    Project     = var.project
    ManagedBy   = "terraform-bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  for_each = toset(local.envs)

  bucket = aws_s3_bucket.tfstate[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  for_each = toset(local.envs)

  bucket = aws_s3_bucket.tfstate[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate[each.key].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  for_each = toset(local.envs)

  bucket                  = aws_s3_bucket.tfstate[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "tfstate" {
  for_each = toset(local.envs)

  bucket        = aws_s3_bucket.tfstate[each.key].id
  target_bucket = aws_s3_bucket.tfstate[each.key].id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_policy" "tfstate" {
  for_each = toset(local.envs)

  bucket = aws_s3_bucket.tfstate[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "${aws_s3_bucket.tfstate[each.key].arn}",
          "${aws_s3_bucket.tfstate[each.key].arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid    = "RestrictToAccount"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          "${aws_s3_bucket.tfstate[each.key].arn}",
          "${aws_s3_bucket.tfstate[each.key].arn}/*"
        ]
        Condition = {
          StringNotEquals = { "aws:PrincipalAccount" = var.aws_account_id }
        }
      }
    ]
  })
}

# ── DynamoDB lock tables ───────────────────────────────────────────────────────
# Note: Terraform >= 1.10 uses S3 native locking (use_lockfile = true in backend.tf).
# DynamoDB tables are kept here for teams on older Terraform versions.

resource "aws_dynamodb_table" "tfstate_lock" {
  for_each = toset(local.envs)

  name         = "${var.project}-tfstate-lock-${each.key}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tfstate[each.key].arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.project}-tfstate-lock-${each.key}"
    Environment = each.key
    Project     = var.project
    ManagedBy   = "terraform-bootstrap"
  }
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "state_bucket_names" {
  description = "Terraform state S3 bucket names per environment"
  value       = { for env, bucket in aws_s3_bucket.tfstate : env => bucket.id }
}

output "kms_key_arns" {
  description = "KMS key ARNs for state bucket encryption per environment"
  value       = { for env, key in aws_kms_key.tfstate : env => key.arn }
}

output "dynamodb_lock_tables" {
  description = "DynamoDB lock table names per environment"
  value       = { for env, table in aws_dynamodb_table.tfstate_lock : env => table.name }
}
