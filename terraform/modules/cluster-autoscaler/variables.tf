variable "env" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the EKS cluster runs"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from EKS module (for IRSA)"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from EKS module (for IRSA trust policy)"
  type        = string
}
