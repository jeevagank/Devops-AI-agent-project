# Prerequisites: run terraform/bootstrap first to create this bucket and KMS key.
terraform {
  backend "s3" {
    bucket               = "telstra-tfstate-staging"
    key                  = "terraform.tfstate"
    region               = "ap-southeast-2"
    encrypt              = true
    kms_key_id           = "alias/telstra-tfstate-staging"
    use_lockfile         = true
  }
}
