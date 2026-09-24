module "vpc" {
  source                = "./modules/vpc"
  cluster_name          = var.cluster_name
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
}

module "iam" {
  source       = "./modules/iam"
  cluster_name = var.cluster_name
}

module "eks_cluster" {
  source               = "./modules/eks-cluster"
  cluster_name         = var.cluster_name
  cluster_version      = var.cluster_version
  cluster_role_arn     = module.iam.cluster_role_arn
  subnet_ids           = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  public_access_cidrs  = var.cluster_endpoint_public_access_cidrs
}

module "eks_nodegroup" {
  source           = "./modules/eks-nodegroup"
  cluster_name     = module.eks_cluster.cluster_name
  node_role_arn    = module.iam.node_role_arn
  subnet_ids       = module.vpc.private_subnet_ids
  instance_type    = var.node_instance_type
  desired_capacity = var.node_desired_capacity
  min_size         = var.node_min_size
  max_size         = var.node_max_size
  volume_size      = var.node_volume_size
  depends_on       = [module.iam, module.eks_cluster]
}

module "irsa_ebs_csi" {
  source            = "./modules/irsa-ebs-csi"
  cluster_name      = module.eks_cluster.cluster_name
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  oidc_provider_url = module.eks_cluster.oidc_provider_url
  depends_on        = [module.eks_nodegroup]
}

module "ecr" {
  source              = "./modules/ecr"
  backend_repo_name   = var.ecr_backend_repo_name
  frontend_repo_name  = var.ecr_frontend_repo_name
}
