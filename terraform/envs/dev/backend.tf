# Prerequisites: run terraform/bootstrap first to create this bucket and KMS key.
terraform {
  backend "s3" {
    bucket               = "jeevagan-tfstate-dev"
    key                  = "terraform.tfstate"
    region               = "ap-southeast-2"
    encrypt              = true
    kms_key_id           = "alias/jeevagan-tfstate-dev"
    use_lockfile         = true
  }
}
