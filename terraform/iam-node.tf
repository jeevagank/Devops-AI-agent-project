# Create an IAM role for the EKS node group
resource "aws_iam_role" "eks-node" {
  name        = "my-eks-node-role"
  description = "EKS node role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
