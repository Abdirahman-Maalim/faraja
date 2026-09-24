terraform {
  backend "s3" {
    bucket         = "faraja-terraform-state-342278407001"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
