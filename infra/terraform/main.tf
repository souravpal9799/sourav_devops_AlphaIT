# Create S3 bucket and DynamoDB table for Terraform state
module "tf_state" {
  source       = "./modules/tf-state"
  project_name = var.project_name
  environment  = var.environment
}

locals {
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]
}

module "vpc" {
  source             = "./modules/vpc"
  project_name       = var.project_name
  cidr_block         = "10.1.0.0/16"
  availability_zones = local.availability_zones
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
  subnet_ids         = module.vpc.public_subnet_ids
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
  namespace                    = kubernetes_namespace.app_namespace.metadata[0].name
  service_account_name         = "backend-sa"
  secrets_manager_secret_arn   = module.rds.secret_arn
}

resource "kubernetes_service_account" "backend_sa" {
  metadata {
    name      = "backend-sa"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = module.irsa.role_arn
    }
  }
}

module "cloudwatch" {
  source          = "./modules/cloudwatch"
  project_name    = var.project_name
  cluster_name    = module.eks.cluster_name
  rds_instance_id = module.rds.db_instance_id
}

module "alb_controller" {
  source            = "./modules/alb-controller"
  project_name      = var.project_name
  cluster_name      = module.eks.cluster_name
  vpc_id            = module.vpc.vpc_id
  region            = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = "demo-namespace"
  }
}

