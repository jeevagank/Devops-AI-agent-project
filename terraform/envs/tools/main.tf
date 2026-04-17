provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Environment = "tools"
      Project     = "jeevagan"
      ManagedBy   = "terraform"
    }
  }
}

# ── VPC ────────────────────────────────────────────────────────────────────────
# Tools VPC is small — only Jenkins and internal tooling run here.
# No RDS, Redis, or MSK needed.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "tools-jeevagan-vpc"
  cidr = "10.4.0.0/16"

  azs             = ["ap-southeast-2a", "ap-southeast-2b"]
  private_subnets = ["10.4.1.0/24", "10.4.2.0/24"]
  public_subnets  = ["10.4.101.0/24", "10.4.102.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"          = "1"
    "kubernetes.io/cluster/tools-jeevagan-eks"  = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                   = "1"
    "kubernetes.io/cluster/tools-jeevagan-eks"  = "shared"
  }
}

# ── EKS ────────────────────────────────────────────────────────────────────────
# Small cluster — only runs Jenkins and supporting tooling.
# No microservice workloads here.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.0.0"

  cluster_name    = "tools-jeevagan-eks"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    tools = {
      instance_types = ["m5.large"]
      min_size       = 2
      max_size       = 5
      desired_size   = 2

      tags = {
        "k8s.io/cluster-autoscaler/enabled"               = "true"
        "k8s.io/cluster-autoscaler/tools-jeevagan-eks"     = "owned"
      }

      labels = {
        Environment = "tools"
        Project     = "jeevagan"
      }
    }
  }

  tags = {
    Environment = "tools"
    Project     = "jeevagan"
    ManagedBy   = "terraform"
  }
}

# ── Jenkins IRSA Role ──────────────────────────────────────────────────────────
# Jenkins pods assume this role.
# This role can then assume cross-account roles in dev/staging/prod.

data "aws_iam_policy_document" "jenkins_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:jenkins:jenkins"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "tools-jeevagan-jenkins"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume.json

  tags = {
    Environment = "tools"
    Project     = "jeevagan"
    ManagedBy   = "terraform"
  }
}

# ── Jenkins IAM Policy ─────────────────────────────────────────────────────────
# Allows Jenkins to:
# 1. Push/pull ECR images in the tools account
# 2. Assume cross-account roles in dev/staging/prod for deployments

resource "aws_iam_policy" "jenkins" {
  name        = "tools-jeevagan-jenkins-policy"
  description = "Jenkins IRSA policy — ECR access + cross-account assume role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:CreateRepository"
        ]
        Resource = "*"
      },
      {
        Sid    = "AssumeRoleDev"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.dev_account_id}:role/dev-jeevagan-jenkins-deploy"
      },
      {
        Sid    = "AssumeRoleStaging"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.staging_account_id}:role/staging-jeevagan-jenkins-deploy"
      },
      {
        Sid    = "AssumeRoleProd"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.prod_account_id}:role/prod-jeevagan-jenkins-deploy"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.jenkins.arn
}

# ── Cross-account deploy roles (created in each target account) ────────────────
# These roles live in dev/staging/prod accounts and trust the tools Jenkins role.
# Each allows Jenkins to update EKS deployments in that account only.

resource "aws_iam_role" "jenkins_deploy_dev" {
  provider = aws.dev
  name     = "dev-jeevagan-jenkins-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = aws_iam_role.jenkins.arn }
    }]
  })

  tags = { Environment = "dev", Project = "jeevagan", ManagedBy = "terraform" }
}

# Minimal policy: only DescribeCluster to generate kubeconfig.
# Actual deploy permissions are controlled by Kubernetes RBAC in each target cluster.
resource "aws_iam_policy" "jenkins_deploy_dev" {
  provider    = aws.dev
  name        = "dev-jeevagan-jenkins-deploy-policy"
  description = "Allows Jenkins to fetch EKS kubeconfig for dev cluster only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "EKSDescribeOnly"
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = "arn:aws:eks:ap-southeast-2:${var.dev_account_id}:cluster/dev-jeevagan-eks"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_deploy_dev_eks" {
  provider   = aws.dev
  role       = aws_iam_role.jenkins_deploy_dev.name
  policy_arn = aws_iam_policy.jenkins_deploy_dev.arn
}

resource "aws_iam_role" "jenkins_deploy_staging" {
  provider = aws.staging
  name     = "staging-jeevagan-jenkins-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = aws_iam_role.jenkins.arn }
    }]
  })

  tags = { Environment = "staging", Project = "jeevagan", ManagedBy = "terraform" }
}

resource "aws_iam_policy" "jenkins_deploy_staging" {
  provider    = aws.staging
  name        = "staging-jeevagan-jenkins-deploy-policy"
  description = "Allows Jenkins to fetch EKS kubeconfig for staging cluster only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "EKSDescribeOnly"
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = "arn:aws:eks:ap-southeast-2:${var.staging_account_id}:cluster/staging-jeevagan-eks"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_deploy_staging_eks" {
  provider   = aws.staging
  role       = aws_iam_role.jenkins_deploy_staging.name
  policy_arn = aws_iam_policy.jenkins_deploy_staging.arn
}

resource "aws_iam_role" "jenkins_deploy_prod" {
  provider = aws.prod
  name     = "prod-jeevagan-jenkins-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = aws_iam_role.jenkins.arn }
    }]
  })

  tags = { Environment = "prod", Project = "jeevagan", ManagedBy = "terraform" }
}

resource "aws_iam_policy" "jenkins_deploy_prod" {
  provider    = aws.prod
  name        = "prod-jeevagan-jenkins-deploy-policy"
  description = "Allows Jenkins to fetch EKS kubeconfig for prod cluster only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "EKSDescribeOnly"
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = "arn:aws:eks:ap-southeast-2:${var.prod_account_id}:cluster/prod-jeevagan-eks"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_deploy_prod_eks" {
  provider   = aws.prod
  role       = aws_iam_role.jenkins_deploy_prod.name
  policy_arn = aws_iam_policy.jenkins_deploy_prod.arn
}

# ── Additional providers for cross-account resources ──────────────────────────

provider "aws" {
  alias  = "dev"
  region = "ap-southeast-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.dev_account_id}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "staging"
  region = "ap-southeast-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.staging_account_id}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "prod"
  region = "ap-southeast-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.prod_account_id}:role/OrganizationAccountAccessRole"
  }
}

# ── Cluster Autoscaler ─────────────────────────────────────────────────────────

module "cluster_autoscaler" {
  source = "../../modules/cluster-autoscaler"

  env               = "tools"
  cluster_name      = module.eks.cluster_name
  aws_region        = "ap-southeast-2"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
}

# ── Variables ──────────────────────────────────────────────────────────────────

variable "dev_account_id" {
  description = "AWS account ID for dev environment"
  type        = string
}

variable "staging_account_id" {
  description = "AWS account ID for staging environment"
  type        = string
}

variable "prod_account_id" {
  description = "AWS account ID for prod environment"
  type        = string
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "tools_vpc_id"              { value = module.vpc.vpc_id }
output "tools_eks_cluster_name"    { value = module.eks.cluster_name }
output "tools_eks_cluster_endpoint" { value = module.eks.cluster_endpoint }
output "jenkins_irsa_role_arn"     { value = aws_iam_role.jenkins.arn }
output "jenkins_deploy_role_dev"   { value = aws_iam_role.jenkins_deploy_dev.arn }
output "jenkins_deploy_role_staging" { value = aws_iam_role.jenkins_deploy_staging.arn }
output "jenkins_deploy_role_prod"  { value = aws_iam_role.jenkins_deploy_prod.arn }
