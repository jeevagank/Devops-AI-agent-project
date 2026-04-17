provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Environment = "prod"
      Project     = "jeevagan"
      ManagedBy   = "terraform"
    }
  }
}

# ── Security Groups ────────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "prod-jeevagan-rds-sg"
  description = "Aurora RDS security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "redis" {
  name        = "prod-jeevagan-redis-sg"
  description = "ElastiCache Redis security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "msk" {
  name        = "prod-jeevagan-msk-sg"
  description = "MSK Kafka security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
  name        = "prod-jeevagan-alb-sg"
  description = "ALB security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── VPC ────────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  env                  = "prod"
  vpc_cidr             = "10.2.0.0/16"
  availability_zones   = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
  public_subnet_cidrs  = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]
}

# ── EKS ────────────────────────────────────────────────────────────────────────

module "eks" {
  source = "../../modules/eks"

  env                  = "prod"
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnets
  cluster_version      = "1.29"
  node_instance_types  = ["m5.xlarge"]
  node_min_size        = 3
  node_max_size        = 10
  node_desired_size    = 5
}

# ── RDS Aurora ─────────────────────────────────────────────────────────────────

module "rds" {
  source = "../../modules/rds"

  env                     = "prod"
  subnet_ids              = module.vpc.private_subnets
  security_group_ids      = [aws_security_group.rds.id]
  instance_class          = "db.r6g.2xlarge"
  instance_count          = 3
  backup_retention_period = 14
}

# ── Redis ──────────────────────────────────────────────────────────────────────

module "redis" {
  source = "../../modules/redis"

  env                = "prod"
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.redis.id]
  node_type          = "cache.r6g.xlarge"
  num_cache_clusters = 3
}

# ── MSK ────────────────────────────────────────────────────────────────────────

module "msk" {
  source = "../../modules/msk"

  env                    = "prod"
  subnet_ids             = module.vpc.private_subnets
  security_group_ids     = [aws_security_group.msk.id]
  broker_instance_type   = "kafka.m5.2xlarge"
  number_of_broker_nodes = 3
  broker_volume_size     = 500
}

# ── ALB ────────────────────────────────────────────────────────────────────────

module "alb" {
  source = "../../modules/alb"

  env                 = "prod"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnets
  security_group_ids  = [aws_security_group.alb.id]
  acm_certificate_arn = var.acm_certificate_arn
}

# ── Jenkins IRSA Role ─────────────────────────────────────────────────────────

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
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "prod-jeevagan-jenkins"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume.json
  tags = { Environment = "prod", Project = "jeevagan", ManagedBy = "terraform" }
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

output "jenkins_irsa_role_arn" { value = aws_iam_role.jenkins.arn }

# ── Variables ──────────────────────────────────────────────────────────────────

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS listener"
  type        = string
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "vpc_id"                { value = module.vpc.vpc_id }
output "eks_cluster_name"      { value = module.eks.cluster_name }
output "eks_cluster_endpoint"  { value = module.eks.cluster_endpoint }
output "rds_endpoint"          { value = module.rds.cluster_endpoint }
output "rds_reader_endpoint"   { value = module.rds.cluster_reader_endpoint }
output "redis_endpoint"        { value = module.redis.primary_endpoint }
output "msk_brokers"           { value = module.msk.bootstrap_brokers_tls }
output "alb_dns_name"          { value = module.alb.alb_dns_name }
