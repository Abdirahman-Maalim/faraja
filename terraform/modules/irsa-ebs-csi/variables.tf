variable "cluster_name" {
  type = string
}
variable "oidc_provider_arn" {
  type = string
}
variable "oidc_provider_url" {
  type = string
}
variable "permissions_boundary_arn" {
  type        = string
  default     = null
  description = "Permission boundary attached to every IAM role this stack creates (required when the deployer uses terraform/iam-deployer)."
}
