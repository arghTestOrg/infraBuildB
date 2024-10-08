aws_s3_tf_state_bucket_name  = "oidc-tf-state-bucket"
aws_region                   = "ap-southeast-1"
aws_vpc_name                 = "prod_vpc"
aws_vpc_cidr                 = "10.1.0.0/16"
aws_ec2_linux_ami_id         = "ami-01811d4912b4ccb26"
aws_ec2_instance_type        = "t2.micro"
aws_db_security_group_name   = "prod_db_sg"
aws_mongodb_ver              = "7.0"
aws_s3_db_backup_bucket_name = "mongodb-bkup-cron"
aws_eks_cluster_name         = "prod_eks"
aws_eks_cluster_ver          = "1.3"
aws_eks_cluster_max_capacity = 3
aws_eks_min_capacity         = 1
aws_eks_desired_capacity     = 2
aws_eks_node_instance_type   = "t2.micro"
aws_eks_ami_type             = "AL2_x86_64"
tf_eks_module_ver            = "20.24.0"

