
output "mongodb_instance_endpoint" {
  description = "The endpoint of the MongoDB instance"
  value       = aws_instance.db_instance.public_ip
}

# EKS Cluster outputs
output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}
