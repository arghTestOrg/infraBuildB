terraform {
  required_version = ">= 1.9.5"

  backend "s3" {
    bucket = "oidc-tf-state-bucket"
    key    = "terraform/state"
    region = "ap-southeast-1"
    #dynamodb_table = "terraform-locks"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.65"
    }
  }
}
