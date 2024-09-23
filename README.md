# infraBuildB
B version

This is a Terraform based IaC project to build out the following resources in AWS in support of an app
to be deployed in an EKS Cluster. This IaC include intentional security vulnerabilities - DO NOT USE THIS
CODE FOR LIVE DEPLOYMENTS!
1. 10.1.0.0/16 VPC with an Internet Gateway, 
2. 'n' Public subnets and n Private subnets with /24 CIDRs, where 'n' is the number of AZs in the region you specify
3. An EKS Cluster with its control plane in the private subnets
4. An EC2 instance in the public subnet
5. MongoB Community Edition installed in that EC2 instance
6. Security Groups
7. S3 Endpoint - Gateway type, to access the mondb-backup bucket. Backups are mongodump at midnight, copied to a very insecure S3 bucket.
8. Secrets Manager Endpoint
9. Access Entries and Policies for some users
10.A service Account in K8S to assume an IAM using the new Pod Identity Agent add-on.
11. All the setup is done through a Deploy to AWS workflow in Github Actions
12. All of the setup can be cleaned up with the Destroy workflow in Github Actions.

This repo provides the setup for the application repo to deploy a dockerized application on EKS.
