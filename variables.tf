variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
}

variable "aws_vpc_name" {
  description = "The name of the VPC."
  type        = string
}

variable "aws_vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "aws_ec2_linux_ami_id" {
  description = "The AMI ID for the EC2 instance."
  type        = string
}

variable "aws_ec2_instance_type" {
  description = "The instance type for the 13.212.81.250EC2 instance."
  type        = string
}

variable "aws_s3_tf_state_bucket_name" {
  description = "The name of the S3 bucket to store Terraform state."
  type        = string
}

variable "aws_db_security_group_name" {
  description = "The name of the security group for the database."
  type        = string
}

variable "aws_s3_db_backup_bucket_name" {
  description = "The name of the S3 bucket for database backups."
  type        = string
}


variable "aws_mongodb_ver" {
  description = "The MongoDB version to install."
  type        = string
}

variable "aws_eks_cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "aws_eks_cluster_ver" {
  description = "The version of the EKS cluster."
  type        = string
}

variable "aws_eks_cluster_max_capacity" {
  description = "The maximum capacity for the EKS cluster."
  type        = number
}

variable "aws_eks_min_capacity" {
  description = "The minimum capacity for the EKS cluster."
  type        = number
}

variable "aws_eks_desired_capacity" {
  description = "The desired capacity for the EKS cluster."
  type        = number
}

variable "aws_eks_node_instance_type" {
  description = "The instance type for EKS worker nodes."
  type        = string
}

variable "tf_eks_module_ver" {
  description = "The version of the EKS Terraform module."
  type        = string
}

variable "aws_eks_ami_type" {
  description = "The version of EKS Managed Node Group AMI"
  type        = string
}