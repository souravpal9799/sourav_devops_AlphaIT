output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "backend_irsa_role_arn" {
  value = module.irsa.role_arn
}

output "eks_kubeconfig_command" {
  description = "Command to join the EKS cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "alb_public_dns" {
  description = "The public DNS name of the Application Load Balancer"
  value       = try(data.kubernetes_ingress_v1.main.status[0].load_balancer[0].ingress[0].hostname, "Waiting for ALB...")
}

output "frontend_url" {
  description = "URL for the frontend application"
  value       = try("http://${data.kubernetes_ingress_v1.main.status[0].load_balancer[0].ingress[0].hostname}", "Waiting for ALB...")
}

output "backend_url" {
  description = "URL for the backend API"
  value       = try("http://${data.kubernetes_ingress_v1.main.status[0].load_balancer[0].ingress[0].hostname}/api", "Waiting for ALB...")
}

output "vpc_id" {
  description = "The ID of the VPC created for this project"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "rds_secret_name" {
  description = "The name of the RDS secret in AWS Secrets Manager"
  value       = module.rds.secret_name
}
