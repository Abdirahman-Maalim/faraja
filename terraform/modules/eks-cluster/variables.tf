variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "cluster_role_arn" { type = string }
variable "subnet_ids" { type = list(string) }
variable "public_access_cidrs" { type = list(string) }
