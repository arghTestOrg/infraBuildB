# VPC ID
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.prod_vpc.id
}

# Public Subnet ID
output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public_subnets[*].id
}

# Private Subnet ID
output "private_subnet_id" {
  description = "The ID of the private subnet"
  value       = aws_subnet.private_subnets[*].id
}

# EC2 Instance ID
output "ec2_instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.db_instance[*].id
}

# EC2 Instance Public IP
output "ec2_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.db_instance[*].public_ip
}

# S3 TF State Bucket Name and ID
output "tf_state_bucket_name" {
  description = "The name and ID of the S3 bucket for Terraform state"
  value       = var.aws_s3_tf_state_bucket_name
}

# S3 Backup Bucket Name and ID
output "backup_bucket_name" {
  description = "The name and ID of the S3 bucket for backups"
  value       = aws_s3_bucket.dbbackup_bucket.id
}

# MongoDB Connection String (Public DNS)
output "mongodb_connection_endpoint" {
  description = "The connection string for MongoDB (EC2 Private DNS)"
  value       = aws_instance.db_instance[*].private_dns
}


# EKS Cluster Name
output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

# EKS Cluster Endpoint
output "eks_cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_status" {
  description = "Status of the EKS cluster"
  value = module.eks.cluster_status
}

