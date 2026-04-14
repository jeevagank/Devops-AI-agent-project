# Prerequisites: run terraform/bootstrap first to create this bucket and KMS key.
terraform {
  backend "s3" {
    bucket               = "telstra-tfstate-tools"
    key                  = "terraform.tfstate"
    region               = "ap-southeast-2"
    encrypt              = true
    kms_key_id           = "alias/telstra-tfstate-tools"
    use_lockfile         = true
  }
}
