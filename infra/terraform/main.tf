module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  cidr_block   = "10.1.0.0/16"
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
  namespace                    = "demo-devops"
  service_account_name         = "backend-sa"
  secrets_manager_secret_arn   = module.rds.secret_arn
}

module "cloudwatch" {
  source       = "./modules/cloudwatch"
  project_name = var.project_name
  cluster_name = module.eks.cluster_name
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = "demo-namespace"
  }
}

resource "kubernetes_service" "frontend_lb" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }
  spec {
    selector = {
      app = "frontend"
    }
    port {
      port        = 80
      target_port = 3000
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_service" "backend_lb" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }
  spec {
    selector = {
      app = "backend"
    }
    port {
      port        = 8000
      target_port = 8000
    }
    type = "LoadBalancer"
  }
}
