output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "backend_irsa_role_arn" {
  value = module.irsa.role_arn
}
