output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "backend_irsa_role_arn" {
  value = module.irsa.role_arn
}

output "eks_kubeconfig_command" {
  description = "Command to join the EKS cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager database credentials"
  value       = module.rds.secret_arn
}
