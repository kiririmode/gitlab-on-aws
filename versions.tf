terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.11"
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

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      # 何のためのリソースか
      Target     = "Gitlab"
      Managed-By = "Terraform"
    }
  }
}