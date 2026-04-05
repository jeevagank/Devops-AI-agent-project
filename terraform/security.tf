# Security best practices configuration
# IAM least privilege
resource "aws_iam_role" "this" {
  name        = "your-role"
  description = "Your role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

# S3 encryption
resource "aws_s3_bucket" "this" {
  bucket = "your-bucket"
  acl   = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Secrets manager integration
resource "aws_secretsmanager_secret" "this" {
  name = "your-secret"
}
