# Create a Terraform module for the ELK stack
module "elk" {
  source = file("./modules/elk")
}
