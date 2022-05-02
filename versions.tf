terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.11.0"
    }
  }
  required_version = "~> 1.1"

  backend "s3" {
    bucket         = "kiririmode-tfbackend"
    key            = "gitlab"
    encrypt        = true
    dynamodb_table = "terraform_state"
    region         = "ap-northeast-1"
  }
}
