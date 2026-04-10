module "cluster_autoscaler" {
  source = "../../modules/cluster-autoscaler"

  env               = "staging"
  cluster_name      = module.eks.cluster_name
  aws_region        = "ap-southeast-2"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
}
