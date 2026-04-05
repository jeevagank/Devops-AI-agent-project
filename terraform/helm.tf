# Create a Terraform module for the Helm charts
module "helm" {
  source = file("./modules/helm")
}
