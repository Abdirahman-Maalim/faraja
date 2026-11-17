variable "repository_arns" { type = list(string) }
variable "allowed_source_cidrs" {
  type        = list(string)
  default     = []
  description = "Public IP CIDRs of the Jenkins host. Empty = no source-IP restriction."
}
