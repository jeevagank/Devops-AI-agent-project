terraform {
  backend "s3" {
    bucket       = "telstra-tfstate-tools"
    key          = "terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
