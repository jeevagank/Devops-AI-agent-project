# Prerequisites: run terraform/bootstrap first to create this bucket and KMS key.
terraform {
  backend "s3" {
    bucket               = "jeevagan-tfstate-dr"
    key                  = "terraform.tfstate"
    region               = "ap-southeast-1"
    encrypt              = true
    kms_key_id           = "alias/jeevagan-tfstate-dr"
    use_lockfile         = true
  }
}
