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
  vpc_cidr     = module.vpc.vpc_cidr
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

# Wait for ALB controller webhooks to be ready
resource "time_sleep" "wait_for_alb_controller" {
  depends_on = [module.alb_controller]
  create_duration = "30s"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"
  
  depends_on = [time_sleep.wait_for_alb_controller]
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = "demo-namespace"
  }
}

data "kubernetes_ingress_v1" "main" {
  metadata {
    name      = "demo-ingress"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }
}

# Advanced Automatic ALB Cleanup
# This uses AWS CLI to find and delete any Load Balancers tagged for this cluster
# It runs BEFORE the EKS nodes are destroyed to ensure nothing blocks the VPC deletion
resource "null_resource" "cleanup_alb" {
  triggers = {
    cluster_name = module.eks.cluster_name
    region       = var.aws_region
    vpc_id       = module.vpc.vpc_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
      echo "Searching for orphaned Load Balancers for cluster ${self.triggers.cluster_name}..."
      
      # 1. Get ARNs of Load Balancers associated with this cluster
      ALB_ARNS=$(aws elbv2 describe-load-balancers --region ${self.triggers.region} --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-')].LoadBalancerArn" --output text)
      
      for ARN in $ALB_ARNS; do
        # Check if this ALB belongs to our cluster via tags
        IS_OURS=$(aws elbv2 describe-tags --resource-arns $ARN --region ${self.triggers.region} --query "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster' && Value=='${self.triggers.cluster_name}']" --output text)
        
        if [ ! -z "$IS_OURS" ]; then
          echo "Deleting orphaned ALB: $ARN"
          aws elbv2 delete-load-balancer --load-balancer-arn $ARN --region ${self.triggers.region}
          echo "Waiting for ALB deletion to propagate..."
          sleep 30
        fi
      done
      
      # 2. Also try to delete the ingress via K8s if the cluster is still reachable
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || true
      kubectl delete ingress demo-ingress -n demo-namespace --ignore-not-found --timeout=30s || true
    EOF
  }

  depends_on = [module.eks, module.alb_controller]
}

