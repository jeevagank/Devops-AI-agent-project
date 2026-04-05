# Create an EKS node group
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "my-eks-node-group"
  node_role_arn   = aws_iam_role.eks-node.arn
  subnet_ids      = [aws_subnet.private.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t2.medium"]
}
