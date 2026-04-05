# Create an IAM role for each microservice
resource "aws_iam_role" "my-microservice" {
  name        = "my-microservice-iam-role"
  description = "IAM role for my-microservice"

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
