provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Environment = "dr"
      Project     = "telstra"
      ManagedBy   = "terraform"
      Region      = "ap-southeast-1"
    }
  }
}

# Remote state of primary (prod) to read outputs
data "terraform_remote_state" "prod" {
  backend = "s3"
  config = {
    bucket = "telstra-tfstate-prod"
    key    = "terraform.tfstate"
    region = "ap-southeast-2"
  }
}

# ── VPC ────────────────────────────────────────────────────────────────────────

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "dr-telstra-vpc"
  cidr = "10.3.0.0/16"

  azs             = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  private_subnets = ["10.3.1.0/24", "10.3.2.0/24", "10.3.3.0/24"]
  public_subnets  = ["10.3.101.0/24", "10.3.102.0/24", "10.3.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"              = "1"
    "kubernetes.io/cluster/dr-telstra-eks"         = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                       = "1"
    "kubernetes.io/cluster/dr-telstra-eks"         = "shared"
  }
}

# ── EKS ────────────────────────────────────────────────────────────────────────
# DR EKS is kept warm at minimum nodes to reduce cost.
# Scale up node group during failover.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.0.0"

  cluster_name    = "dr-telstra-eks"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    dr = {
      instance_types = ["m5.large"]
      min_size       = 2
      max_size       = 10
      desired_size   = 2

      labels = {
        Environment = "dr"
        Project     = "telstra"
      }
    }
  }
}

# ── Cluster Autoscaler ────────────────────────────────────────────────────────

module "cluster_autoscaler" {
  source = "../../modules/cluster-autoscaler"

  env               = "dr"
  cluster_name      = module.eks.cluster_name
  aws_region        = "ap-southeast-1"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
}

# ── Security group for Aurora DR ───────────────────────────────────────────────

resource "aws_security_group" "aurora_dr" {
  name        = "dr-telstra-aurora-sg"
  description = "Aurora DR secondary cluster security group"
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

# ── Aurora DB subnet group ─────────────────────────────────────────────────────

resource "aws_db_subnet_group" "aurora_dr" {
  name       = "dr-telstra-aurora-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# ── Aurora Global DB secondary cluster (Singapore) ────────────────────────────
# This cluster is a read-only replica of the primary in ap-southeast-2 (Sydney).
# On failover, it is promoted to standalone via the Lambda handler.

resource "aws_rds_cluster" "dr_secondary" {
  cluster_identifier        = "dr-telstra-aurora"
  engine                    = "aurora-postgresql"
  engine_version            = "15.4"
  global_cluster_identifier = var.global_cluster_identifier

  db_subnet_group_name   = aws_db_subnet_group.aurora_dr.name
  vpc_security_group_ids = [aws_security_group.aurora_dr.id]

  # Secondary clusters must not set master credentials — inherited from primary
  skip_final_snapshot = true
  deletion_protection = true
  storage_encrypted   = true

  lifecycle {
    ignore_changes = [replication_source_identifier]
  }

  tags = {
    Environment = "dr"
    Project     = "telstra"
    Role        = "secondary"
    Primary     = "ap-southeast-2"
  }
}

resource "aws_rds_cluster_instance" "dr_secondary" {
  count              = 1
  identifier         = "dr-telstra-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.dr_secondary.id
  instance_class     = "db.r6g.large"
  engine             = aws_rds_cluster.dr_secondary.engine
  engine_version     = aws_rds_cluster.dr_secondary.engine_version

  tags = {
    Environment = "dr"
    Project     = "telstra"
  }
}

# ── Variables ──────────────────────────────────────────────────────────────────

variable "global_cluster_identifier" {
  description = "Aurora Global DB cluster identifier created in the primary (ap-southeast-2) account"
  type        = string
  default     = "telstra-aurora-global"
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "dr_eks_cluster_name" {
  value = module.eks.cluster_name
}

output "dr_eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "dr_aurora_cluster_endpoint" {
  value = aws_rds_cluster.dr_secondary.endpoint
}

output "dr_aurora_cluster_id" {
  value = aws_rds_cluster.dr_secondary.cluster_identifier
}

output "dr_vpc_id" {
  value = module.vpc.vpc_id
}
