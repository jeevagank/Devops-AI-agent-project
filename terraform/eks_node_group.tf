# Configure the EKS node group
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = [aws_subnet.private.id, aws_subnet.public.id]

  # Use a GPU-enabled instance type
  instance_types = ["p3.2xlarge"]
}
