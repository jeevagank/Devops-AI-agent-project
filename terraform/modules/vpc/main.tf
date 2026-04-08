module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.env}-telstra-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  tags = {
    Name        = "${var.env}-telstra-vpc"
    Environment = var.env
    Project     = "telstra"
    ManagedBy   = "terraform"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                        = "1"
    "kubernetes.io/cluster/${var.env}-telstra-eks"           = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                                 = "1"
    "kubernetes.io/cluster/${var.env}-telstra-eks"           = "shared"
  }
}