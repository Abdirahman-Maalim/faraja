resource "aws_eks_node_group" "main" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = [var.instance_type]
  disk_size      = var.volume_size

  scaling_config {
    desired_size = var.desired_capacity
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    max_unavailable = 1
  }
}
