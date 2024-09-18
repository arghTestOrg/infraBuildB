
variable "aws_eks_cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "aws_eks_cluster_ver" {
  description = "The version of the EKS cluster"
  type        = string
}

variable "aws_eks_cluster_max_capacity" {
  description = "The maximum capacity for the EKS cluster"
  type        = number
}

variable "aws_eks_min_capacity" {
  description = "The minimum capacity for the EKS cluster"
  type        = number
}

variable "aws_eks_desired_capacity" {
  description = "The desired capacity for the EKS cluster"
  type        = number
}

variable "aws_eks_node_instance_type" {
  description = "The instance type for EKS worker nodes"
  type        = string
}
