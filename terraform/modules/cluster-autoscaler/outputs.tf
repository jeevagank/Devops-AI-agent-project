output "iam_role_arn" {
  description = "Cluster Autoscaler IRSA IAM role ARN"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "iam_role_name" {
  description = "Cluster Autoscaler IRSA IAM role name"
  value       = aws_iam_role.cluster_autoscaler.name
}
