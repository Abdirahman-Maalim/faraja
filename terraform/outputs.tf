output "cluster_name" {
  value = module.eks_cluster.cluster_name
}
output "cluster_endpoint" {
  value = module.eks_cluster.cluster_endpoint
}
output "backend_ecr_url" {
  value = module.ecr.backend_repository_url
}
output "frontend_ecr_url" {
  value = module.ecr.frontend_repository_url
}
