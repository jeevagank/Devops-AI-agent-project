# Create a Terraform module for the Aurora PostgreSQL database
module "aurora" {
  source = file("./modules/aurora")
}
