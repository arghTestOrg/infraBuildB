provider "aws" {
  region = var.aws_region
}

# Create VPC and Subnets

# get the available AZs
data "aws_availability_zones" "available" {}

resource "aws_vpc" "prod_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    name = var.aws_vpc_name
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.prod_vpc.id
  cidr_block              = "10.1.${1 + count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "PublicSubnet_${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
    "KubernetesCluster"      = "prod_eks"
  }
}

resource "aws_subnet" "private_subnets" {
  count      = length(data.aws_availability_zones.available.names)
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = "10.1.${10 + count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  #private_dns_hostname_type_on_launch = aws_instance.ip-name
  tags = {
    Name = "PrivateSubnet_${10 + count.index}"
    "kubernetes.io/cluster/prod_eks"  = "shared"
  }
}

# older working code below
/*resource "aws_subnet" "private_subnets" {
  count      = length(var.aws_private_subnet_cidrs)
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = element(var.aws_private_subnet_cidrs, count.index)

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}
*/

# Internet Gateway for Public Subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "igw" #should change to vari
  }
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route_table_association" "public_rt_association" {
  count          = length(var.aws_public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_rt.id

}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw.id
  }


  tags = {
    Name = "private_rt"
  }
}

resource "aws_route_table_association" "private_rt_association" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.private_rt.id
}

# Security Group for DB
resource "aws_security_group" "db_sg" {
  name        = var.aws_db_security_group_name
  vpc_id      = aws_vpc.prod_vpc.id
  description = "Security group for MongoDB instance"

  # Allow DB traffic to orginate only from local VPC 
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.prod_vpc.cidr_block]
  }
  # Allow SSH from public internet
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow outgoing connections anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.aws_db_security_group_name
  }
}

# Key-pair
resource "aws_key_pair" "aws_keyname" {
  key_name   = "aws_my_edkey"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFGh4PcfUYC7aL57bM4IUC33/j8hayD8HRKDpZOeRTVl kishor@osboxes"

}

variable "exclude_ec2_instance" {}

# EC2 Instance
resource "aws_instance" "db_instance" {
  #for cases where we don;t want to deploy this instance in terraform apply
  # terraform apply -var='exclude_ec2_instance=true'
  count         = var.exclude_ec2_instance ? 0 : 1
  ami           = var.aws_ec2_linux_ami_id
  instance_type = var.aws_ec2_instance_type
  #count                       = length(var.aws_private_subnet_cidrs)
  subnet_id                   = aws_subnet.public_subnets[0].id # taken shortcut here by using index 0 as its just one instance
  vpc_security_group_ids      = [aws_security_group.db_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = aws_key_pair.aws_keyname.key_name
  tags = {
    Name = "db_instance"
  }
  # added this depends-on block as sometimes the AWS Secrets Manager is slow to respond, but the secrets should be available for
  # the EC2 instance to configure Mongodb

  depends_on = [
    aws_secretsmanager_secret.mongodb_admin_secret,
    aws_secretsmanager_secret_version.mongodb_admin_secret_version,
    aws_secretsmanager_secret.mongodb_app_secret,
    aws_secretsmanager_secret_version.mongodb_app_secret_version,
    aws_s3_bucket.dbbackup_bucket,
    aws_s3_bucket_policy.dbbackup_bucket_policy,
  aws_s3_bucket_public_access_block.dbbackup_bucket_access_block]

  user_data = file("scripts/mongodb-init.sh")

}

# IAM Role and Instance Profile for EC2
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ec2_policy" {
  name        = "ec2_policy"
  description = "Custom policy for EC2"

  policy = <<EOF
{
	"Statement": [
		{
			"Action": "ec2:*",
			"Effect": "Allow",
			"Resource": "*"
		},
		{
			"Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListAllBuckets",
        "s3:GetBucketObjectLockConfiguration"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.dbbackup_bucket.id}",
        "arn:aws:s3:::${aws_s3_bucket.dbbackup_bucket.id}/*"
      ]
		}
	],
	"Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy_attachment" "ec2_policy_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}

# S3 Bucket for Backups
resource "aws_s3_bucket" "dbbackup_bucket" {
  bucket        = var.aws_s3_db_backup_bucket_name
  force_destroy = true
  tags = {
    Name = var.aws_s3_db_backup_bucket_name
  }
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.dbbackup_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_public_access_block" "dbbackup_bucket_access_block" {
  bucket = aws_s3_bucket.dbbackup_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "dbbackup_bucket_policy" {
  bucket = aws_s3_bucket.dbbackup_bucket.id
  depends_on = [
    aws_s3_bucket.dbbackup_bucket,
    aws_s3_bucket_public_access_block.dbbackup_bucket_access_block
  ]

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
      "s3:GetObject",
      "s3:ListBucket"
    ],
      "Resource": [
      "arn:aws:s3:::${aws_s3_bucket.dbbackup_bucket.id}",
      "arn:aws:s3:::${aws_s3_bucket.dbbackup_bucket.id}/*"
      ]
    }
  ]
}
EOF
}


# S3 VPC Endpoint [need this ?]
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.prod_vpc.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids   = [aws_route_table.public_rt.id]

  tags = {
    Name = "s3_endpoint"
  }
}

# VPC Endpoint for Secrets Manager
resource "aws_vpc_endpoint" "secretsmanager_endpoint" {
  vpc_id            = aws_vpc.prod_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type = "Interface"
  #subnet_ids        = module.vpc.private_subnets
  #security_group_ids = [aws_security_group.db_sg.id]

  tags = {
    Name = "secretsmanager-vpc-endpoint"
  }
}
/*----------Below is AWS Config piece-----
# AWS Config
resource "aws_config_configuration_recorder" "main" {
  name     = "config"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported = true
    include_global_resource_types = true
  }
}

resource "aws_iam_role" "config_role" {
  name = "config_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "config_role_attachment" {
  name       = "config_role_attachment"
  roles      = [aws_iam_role.config_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}
*/


/* # Security Group for EKS to communicate with MongoDB
resource "aws_security_group" "eks_sg" {
  name   = "eks_security_group"
  vpc_id = aws_vpc.prod_vpc.id

  egress {
    from_port   = 0subnet_ids 
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.db_sg.id]
  }

  tags = {
    Name = "eks_security_group"
  }
} */

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

}

/* to use this code for eip and nat gw if it doesn't work */

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# Null resource to fetch MongoDB credentials and create Kubernetes secret
resource "null_resource" "create_mongo_k8s_secret" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = <<EOT
      # Configure kubectl to connect to the EKS cluster
      aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_name}

      # Fetch MongoDB credentials from AWS Secrets Manager
      MONGO_USERNAME=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mongodb_app_secret.id} --query SecretString --output text | jq -r .username)
      MONGO_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mongodb_app_secret.id} --query SecretString --output text | jq -r .password)

      # Create Kubernetes secret
      kubectl create secret generic mongo-secret --from-literal=username=$MONGO_USERNAME --from-literal=password=$MONGO_PASSWORD --namespace default
    EOT

    environment = {
      AWS_REGION = var.aws_region
    }
  }
}
# ***************************EKS CONFIG******************************
# EKS cluster module setup
module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "20.24.1"
  cluster_name = var.aws_eks_cluster_name
  subnet_ids   = aws_subnet.private_subnets[*].id
  #control_plane_subnet_ids                 = aws_subnet.private_subnets[*].id
  vpc_id                                   = aws_vpc.prod_vpc.id
  create_iam_role                          = false
  iam_role_arn                             = aws_iam_role.eks_cluster_role.arn
  iam_role_name                            = "tf_specified_eks_cluster_role"
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true

  eks_managed_node_groups = {
    eks_nodes = {
      desired_capacity = var.aws_eks_desired_capacity
      max_capacity     = var.aws_eks_cluster_max_capacity
      min_capacity     = var.aws_eks_min_capacity
      instance_type    = var.aws_eks_node_instance_type
    }
  }
  cluster_addons = {
    eks-pod-identity-agent = {}
  }

  #Need this dependency as the nodes need connectivity
  depends_on = [
    aws_eip.nat_eip,
    aws_nat_gateway.nat_gw,
    aws_route_table.private_rt,
    aws_route_table.public_rt,
    aws_iam_role.eks_cluster_role,
    aws_iam_role_policy_attachment.eks_cluster_policy_attachment,
    aws_iam_role_policy_attachment.eks_service_role_policy_attachment
  ]

  tags = {
    Environment = "production"
    Terraform   = "true"
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

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role" "githuboidcrole" {
  name = "githuboidcroleassume"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          "AWS" = "arn:aws:iam::209479268294:role/GithubOIDCRole",
          "AWS" = "arn:aws:sts::209479268294:assumed-role/GithubOIDCRole/GitHubActions"
        },
        Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_eks_access_entry" "rootadmin_access" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::209479268294:root"
  #kubernetes_groups = ["system:masters", "system:bootstrappers"]
  type      = "STANDARD"
  user_name = "root-admin"
}

resource "aws_eks_access_policy_association" "rootadmin_policy" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::209479268294:root"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "terraadmin_access" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::209479268294:user/terraleaner"
  #kubernetes_groups = ["system:masters", "system:bootstrappers"]
  type      = "STANDARD"
  user_name = "terra-admin"
}

resource "aws_eks_access_policy_association" "terraadmin_policy" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::209479268294:user/terraleaner"

  access_scope {
    type = "cluster"
  }
}
resource "aws_iam_role" "terraleanerrole" {
  name = "terraleanerroleassume"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          "AWS" = "arn:aws:iam::209479268294:user/terraleaner"
        },
        Action = "sts:AssumeRole"
    }]
  })
}

# Following section is for providing cluster-admin privilege to pods

# This is for authorization assuming role
data "aws_iam_policy_document" "podisadmin_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# This is to give podmin permission to assume the role
resource "aws_iam_role" "podisadmin" {
  name               = "pod-is-eks-admin"
  assume_role_policy = data.aws_iam_policy_document.podisadmin_assume_role.json
}


# EKS uses access entries
resource "aws_eks_access_entry" "podisadmin_access" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.podisadmin.arn
  type          = "STANDARD"
}

# This the association of the IAM role with Cluster Admin Policy 
resource "aws_eks_access_policy_association" "podisadmin_policy" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.podisadmin.arn

  access_scope {
    type = "cluster"
  }
}

# this is to associate the K8s service account with the IAM role
resource "aws_eks_pod_identity_association" "podisadmin-id-assoc" {
  cluster_name    = module.eks.cluster_name
  namespace       = "default"
  service_account = "techxeksadmin"
  role_arn        = aws_iam_role.podisadmin.arn
}

/* tried this first instead of creating access entry, but got error 400 validation error invalid arn
resource "aws_iam_role_policy_attachment" "podisadmin-policy-attach" {
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  role       = aws_iam_role.podisadmin.name
}

*/