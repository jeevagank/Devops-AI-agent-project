terraform {
  backend "s3" {
    bucket         = "telstra-tfstate-prod"
    key            = "global/terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
