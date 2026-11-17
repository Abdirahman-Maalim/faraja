variable "cluster_name" {
  type = string
}

variable "ecr_repository_arns" {
  type        = list(string)
  description = "ECR repositories the worker nodes may pull from."
}
variable "cni_via_irsa" {
  type        = bool
  default     = true
  description = "True: AmazonEKS_CNI_Policy is attached to an IRSA role for aws-node, not to the node role."
}
variable "permissions_boundary_arn" {
  type        = string
  default     = null
  description = "Permission boundary attached to every IAM role this stack creates (required when the deployer uses terraform/iam-deployer)."
}
