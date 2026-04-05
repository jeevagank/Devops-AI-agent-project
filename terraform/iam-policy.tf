# Create an IAM policy for each microservice
resource "aws_iam_policy" "my-microservice" {
  name        = "my-microservice-iam-policy"
  description = "IAM policy for my-microservice"

  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "logs:CreateLogGroup"
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
