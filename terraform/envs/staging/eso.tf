variable "staging_account_id" {
  description = "AWS account ID for staging environment"
  type        = string
}

# ── ESO IAM Policy ─────────────────────────────────────────────────────────────

resource "aws_iam_policy" "eso" {
  name        = "staging-jeevagan-eso-policy"
  description = "ESO IRSA policy — read Secrets Manager secrets for staging"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SecretsManagerRead"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:ap-southeast-2:${var.staging_account_id}:secret:staging/*"
    }]
  })
}

# ── ESO IRSA Role ──────────────────────────────────────────────────────────────

module "eso_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.0.0"

  role_name = "staging-jeevagan-eso"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  role_policy_arns = {
    eso = aws_iam_policy.eso.arn
  }

  tags = {
    Environment = "staging"
    Project     = "jeevagan"
    ManagedBy   = "terraform"
  }
}

output "eso_irsa_role_arn" {
  value = module.eso_irsa.iam_role_arn
}
