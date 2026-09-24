terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Guard rail: refuses to apply if the active AWS profile isn't this
  # account — cheap insurance against a wrong-account mistake.
  allowed_account_ids = ["342278407001"]

  default_tags {
    tags = {
      Project     = "faraja"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}
