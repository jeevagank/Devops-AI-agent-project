# Terraform modules for environment separation
module "dev" {
  source = file("./modules/dev")
}

module "staging" {
  source = file("./modules/staging")
}

module "prod" {
  source = file("./modules/prod")
}
