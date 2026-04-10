terraform {
  backend "s3" {
    bucket       = "telstra-tfstate-dr"
    key          = "terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
