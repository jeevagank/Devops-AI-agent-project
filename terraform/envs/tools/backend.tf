# Prerequisites: run terraform/bootstrap first to create this bucket and KMS key.
terraform {
  backend "s3" {
    bucket               = "jeevagan-tfstate-tools"
    key                  = "terraform.tfstate"
    region               = "ap-southeast-2"
    encrypt              = true
    kms_key_id           = "alias/jeevagan-tfstate-tools"
    use_lockfile         = true
  }
}
