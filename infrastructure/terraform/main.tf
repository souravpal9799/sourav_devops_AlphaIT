module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  cidr_block   = "10.0.0.0/16"
}

module "security_group" {
  source       = "./modules/security-group"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

module "eks" {
  source             = "./modules/eks"
  project_name       = var.project_name
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_group.eks_sg_id]
}

module "rds" {
  source             = "./modules/rds"
  project_name       = var.project_name
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_group.rds_sg_id]
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}

module "irsa" {
  source                       = "./modules/irsa"
  project_name                 = var.project_name
  oidc_provider_arn            = module.eks.oidc_provider_arn
  oidc_provider_url            = module.eks.oidc_provider_url
  namespace                    = "mvp-namespace"
  service_account_name         = "backend-sa"
  secrets_manager_secret_arn   = module.rds.secret_arn
}

module "cloudwatch" {
  source       = "./modules/cloudwatch"
  project_name = var.project_name
  cluster_name = module.eks.cluster_name
}
