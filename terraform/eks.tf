# Configure the EKS cluster
resource "aws_eks_cluster" "this" {
  name     = "my-cluster"
  role_arn = aws_iam_role.eks.arn

  # Use an existing VPC and subnets
  vpc_id  = aws_vpc.this.id
  subnets = [aws_subnet.private.id, aws_subnet.public.id]
}
