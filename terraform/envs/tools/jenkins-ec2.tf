# Jenkins Controller — EC2 in tools account
# Run ONCE by a platform engineer after EKS is up.
# Jenkins agents still run as pods on tools EKS (configured via Ansible JCasC).

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_caller_identity" "tools" {}

# ── Security Groups ────────────────────────────────────────────────────────────

resource "aws_security_group" "jenkins_alb" {
  name        = "tools-jenkins-alb-sg"
  description = "ALB for Jenkins — HTTPS from internal VPN only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from internal VPN/corporate network"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpn_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "tools-jenkins-alb-sg", Project = "jeevagan", ManagedBy = "terraform" }
}

resource "aws_security_group" "jenkins_ec2" {
  name        = "tools-jenkins-ec2-sg"
  description = "Jenkins EC2 — only ALB and SSM access, no direct SSH"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_alb.id]
  }

  egress {
    description = "Allow all outbound — Jenkins agents, ECR, AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "tools-jenkins-ec2-sg", Project = "jeevagan", ManagedBy = "terraform" }
}

# ── KMS key for EBS encryption ─────────────────────────────────────────────────

resource "aws_kms_key" "jenkins_ebs" {
  description             = "Jenkins EBS volume encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = { Name = "tools-jenkins-ebs-kms", Project = "jeevagan" }
}

# ── EC2 Instance ───────────────────────────────────────────────────────────────

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "m5.xlarge"
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.jenkins_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  # No SSH key — access via AWS Systems Manager Session Manager only
  key_name = null

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    kms_key_id            = aws_kms_key.jenkins_ebs.arn
    delete_on_termination = true
  }

  # SSM agent is pre-installed on AL2023
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    dnf update -y
    dnf install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF
  )

  tags = {
    Name        = "tools-jenkins-controller"
    Project     = "jeevagan"
    Environment = "tools"
    ManagedBy   = "terraform"
  }
}

# ── EBS Volume for Jenkins home (/var/lib/jenkins) ────────────────────────────

resource "aws_ebs_volume" "jenkins_home" {
  availability_zone = aws_instance.jenkins.availability_zone
  size              = 100
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true
  kms_key_id        = aws_kms_key.jenkins_ebs.arn

  tags = {
    Name        = "tools-jenkins-home"
    Project     = "jeevagan"
    ManagedBy   = "terraform"
  }
}

resource "aws_volume_attachment" "jenkins_home" {
  device_name  = "/dev/xvdf"
  volume_id    = aws_ebs_volume.jenkins_home.id
  instance_id  = aws_instance.jenkins.id
  force_detach = false
}

# ── IAM Role for Jenkins EC2 ──────────────────────────────────────────────────

resource "aws_iam_role" "jenkins_ec2" {
  name = "tools-jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Project = "jeevagan", ManagedBy = "terraform" }
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "tools-jenkins-ec2-profile"
  role = aws_iam_role.jenkins_ec2.name
}

# SSM Session Manager — replaces SSH
resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "jenkins_ec2_policy" {
  name        = "tools-jenkins-ec2-policy"
  description = "Jenkins EC2: ECR push, Secrets Manager read, cross-account assume role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
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
        Resource = "arn:aws:ecr:ap-southeast-2:${data.aws_caller_identity.tools.account_id}:repository/*"
      },
      {
        Sid    = "AssumeDeployRoles"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::${var.dev_account_id}:role/dev-jeevagan-jenkins-deploy",
          "arn:aws:iam::${var.staging_account_id}:role/staging-jeevagan-jenkins-deploy",
          "arn:aws:iam::${var.prod_account_id}:role/prod-jeevagan-jenkins-deploy"
        ]
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:ap-southeast-2:${data.aws_caller_identity.tools.account_id}:secret:jenkins/*"
      },
      {
        Sid    = "EKSDescribeTools"
        Effect = "Allow"
        Action = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:ap-southeast-2:${data.aws_caller_identity.tools.account_id}:cluster/tools-jeevagan-eks"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_ec2_policy" {
  role       = aws_iam_role.jenkins_ec2.name
  policy_arn = aws_iam_policy.jenkins_ec2_policy.arn
}

# ── ALB ───────────────────────────────────────────────────────────────────────

resource "aws_lb" "jenkins" {
  name               = "tools-jenkins-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jenkins_alb.id]
  subnets            = module.vpc.private_subnets

  tags = { Name = "tools-jenkins-alb", Project = "jeevagan", ManagedBy = "terraform" }
}

resource "aws_lb_target_group" "jenkins" {
  name     = "tools-jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/login"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
  }
}

resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = aws_instance.jenkins.id
  port             = 8080
}

resource "aws_lb_listener" "jenkins_https" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}

# ── Route53 ───────────────────────────────────────────────────────────────────

data "aws_route53_zone" "internal" {
  name         = var.internal_hosted_zone
  private_zone = true
}

resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "jenkins.${var.internal_hosted_zone}"
  type    = "A"

  alias {
    name                   = aws_lb.jenkins.dns_name
    zone_id                = aws_lb.jenkins.zone_id
    evaluate_target_health = true
  }
}

# ── Variables ──────────────────────────────────────────────────────────────────

variable "vpn_cidr" {
  description = "Corporate VPN CIDR — only this range can reach the Jenkins ALB"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for jenkins.internal.jeevagan.com"
  type        = string
}

variable "internal_hosted_zone" {
  description = "Route53 private hosted zone (e.g. internal.jeevagan.com)"
  type        = string
  default     = "internal.jeevagan.com"
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "jenkins_url"          { value = "https://jenkins.${var.internal_hosted_zone}" }
output "jenkins_instance_id"  { value = aws_instance.jenkins.id }
output "jenkins_alb_dns"      { value = aws_lb.jenkins.dns_name }
output "jenkins_ec2_role_arn" { value = aws_iam_role.jenkins_ec2.arn }
