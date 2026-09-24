variable "cluster_name" {
  type = string
}
variable "node_role_arn" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "instance_type" {
  type = string
}
variable "desired_capacity" {
  type = number
}
variable "min_size" {
  type = number
}
variable "max_size" {
  type = number
}
variable "volume_size" {
  type = number
}
