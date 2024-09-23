# infraBuildB
**Version B**

This repository provides Infrastructure as Code (IaC) using Terraform to build out AWS resources in support of an application that will be deployed in an EKS Cluster. 

**Note**: This IaC includes intentional security vulnerabilities. **DO NOT USE THIS CODE FOR LIVE DEPLOYMENTS!** It is intended for learning and development purposes only.

## Infrastructure Overview

The Terraform scripts in this repository will create the following AWS resources:

1. **VPC Configuration**: A VPC with a CIDR block of 10.1.0.0/16, which includes:
   - An Internet Gateway.
   - `n` Public subnets and `n` Private subnets, each with /24 CIDRs. The value of `n` corresponds to the number of Availability Zones (AZs) in the AWS region you specify.

2. **EKS Cluster**:
   - An Amazon EKS Cluster with the control plane hosted in the private subnets.
   - The cluster is pre-configured to use Kubernetes services and resources.

3. **EC2 Instance**:
   - A single EC2 instance deployed in one of the public subnets.
   - **MongoDB Community Edition** installed on the EC2 instance.
   - The instance serves as the backend database, although it is highly insecure.

4. **Security Groups**:
   - Security groups are configured for the EC2 instance, EKS cluster, and other resources.
   - **Warning**: These security groups are intentionally insecure, leaving several attack vectors open.

5. **S3 Endpoint**:
   - An S3 VPC Endpoint of **Gateway type** to provide secure access to the `mondb-backup` S3 bucket.
   - Backups of the MongoDB database (`mongodump`) are created nightly at midnight and stored in an **insecure S3 bucket**.

6. **Secrets Manager Endpoint**:
   - AWS Secrets Manager VPC Endpoint to securely retrieve secrets used by the application (e.g., database credentials).

7. **Access Entries and Policies**:
   - IAM roles, policies, and Access Entries are created for users and resources.
   - **Warning**: These policies may have overly broad permissions.

8. **Service Account for IAM Roles**:
   - A **Kubernetes Service Account** is set up to assume an IAM Role using the **Pod Identity Agent** add-on.
   - This allows Kubernetes pods to securely access AWS services using IAM roles.

9. **GitHub Actions for CI/CD**:
   - A **Deploy to AWS** GitHub Actions workflow automates the infrastructure setup and application deployment in the EKS cluster.
   - A **Destroy** workflow is also included to clean up all resources after testing or development.

## Application Integration

This repository provides the infrastructure required to support a Dockerized application that will be deployed on the EKS Cluster. The application deployment itself is handled by a separate repository.

## Disclaimer

This repository is intended for **development and learning** purposes only. The infrastructure created using this code contains known security vulnerabilities and should **NOT** be used for any live workloads - whether production or not.
