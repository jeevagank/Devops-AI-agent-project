# Create a Terraform module for the ElastiCache Redis cluster
module "redis" {
  source = file("./modules/redis")
}
