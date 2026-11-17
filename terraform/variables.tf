variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "cluster_name" {
  type    = string
  default = "faraja-cluster"
}
variable "cluster_version" {
  type    = string
  default = "1.35" # standard support; 1.31 is extended-support ($0.60/hr vs $0.10/hr)
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}
variable "node_instance_type" {
  type    = string
  default = "t3.small"
}
variable "node_desired_capacity" {
  type    = number
  default = 5
}
variable "node_min_size" {
  type    = number
  default = 5
}
variable "node_max_size" {
  type    = number
  default = 5
}
variable "node_volume_size" {
  type    = number
  default = 20
}
variable "ecr_backend_repo_name" {
  type    = string
  default = "faraja-backend"
}
variable "ecr_frontend_repo_name" {
  type    = string
  default = "faraja-frontend"
}
variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the EKS API. Set to your current public IP/32."
}
variable "aws_account_id" {
  type        = string
  description = "Account this configuration may be applied to (guard rail in the provider block)."
}
variable "cni_via_irsa" {
  type        = bool
  default     = true
  description = "Deliver VPC CNI permissions through IRSA instead of the node role. Set false to fall back."
}
variable "jenkins_allowed_source_cidrs" {
  type        = list(string)
  default     = []
  description = "Public IP/CIDR of the Jenkins host; restricts the jenkins-ci user to calls from there. Empty = unrestricted."
}
variable "permissions_boundary_arn" {
  type        = string
  default     = null
  description = "Permission boundary attached to every IAM role this stack creates (required when the deployer uses terraform/iam-deployer)."
}
