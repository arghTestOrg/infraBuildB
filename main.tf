
provider "aws" {
  region = var.aws_region
}

# EKS cluster module setup
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.aws_eks_cluster_name
  cluster_version = var.aws_eks_cluster_ver
  subnets         = aws_subnet.private_subnets[*].id
  vpc_id          = aws_vpc.prod_vpc.id

  node_groups = {
    eks_nodes = {
      desired_capacity = var.aws_eks_desired_capacity
      max_capacity     = var.aws_eks_cluster_max_capacity
      min_capacity     = var.aws_eks_min_capacity
      instance_type    = var.aws_eks_node_instance_type
    }
  }

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}

# Security Group for EKS to communicate with MongoDB
resource "aws_security_group" "eks_security_group" {
  name   = "eks_security_group"
  vpc_id = aws_vpc.prod_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    security_groups = [aws_security_group.db_security_group.id]
  }

  tags = {
    Name = "eks_security_group"
  }
}

# IAM Roles and Policies for EKS
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy_attachment" "eks_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  roles      = [aws_iam_role.eks_cluster_role.name]
}

resource "aws_iam_policy_attachment" "eks_service_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  roles      = [aws_iam_role.eks_cluster_role.name]
}

# Null resource to fetch MongoDB credentials and create Kubernetes secret
resource "null_resource" "create_mongo_k8s_secret" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = <<EOT
      MONGO_USERNAME=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mongodb_app_secret.id} --query SecretString --output text | jq -r .username)
      MONGO_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mongodb_app_secret.id} --query SecretString --output text | jq -r .password)

      kubectl create secret generic mongo-secret --from-literal=username=$MONGO_USERNAME --from-literal=password=$MONGO_PASSWORD --namespace default
    EOT
  }
}
