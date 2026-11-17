variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "aws_account_id" {
  type = string
}
variable "cluster_name" {
  type    = string
  default = "faraja-cluster"
}
variable "deployer_user_name" {
  type        = string
  description = "Existing IAM user that will run the Faraja Terraform."
}
