# AWS Cloud Projects

A collection of hands-on AWS projects documenting my learning journey in cloud computing and security.

## About

I'm a Computer Science student gaining practical experience with AWS services. This repository showcases projects that demonstrate cloud architecture, security best practices, and real-world problem-solving.

Each project includes:
- Architecture diagrams and design decisions
- Implementation details and thought process
- Security considerations
- Cost analysis and optimization
- Key learnings

## Projects

### 1. [Static Website Hosting on S3](./static-website-s3/)
Hosting a static website using AWS S3 with proper bucket policies and public access configuration.

**Technologies:** AWS S3, Static Web Hosting

### 2. [Cloud Security with IAM](./IAM-cloud-security/)
Implementing identity and access management with tag-based access control for EC2 instances. Created IAM policies, user groups, and users to enforce the principle of least privilege.

**Technologies:** AWS IAM, EC2, Tag-Based Access Control, JSON Policies

### 3. [Build your own Virtual Private Cloud](./virtual-private-cloud/)
Building foundational AWS networking infrastructure. Created an isolated VPC with public subnets, configured Internet Gateway, and learned Availability Zones.

**Technologies:** AWS VPC, Subnets, Internet Gateway, CIDR, Availability Zones

### 4. [VPC Traffic Flow and Security](./vpc-traffic-flow-security/)
Advanced VPC networking concepts including security groups, Network ACLs, and traffic flow control. Building on the foundational VPC project to implement granular security controls.

**Technologies:** AWS VPC, Security Groups, Network ACLs, Route Tables, Traffic Control

### 5. [VPC Private Subnets](./vpc-private-subnet/)
Implementing network isolation through private subnets. Created private subnet with dedicated route table (no internet gateway route) and Network ACL for hosting databases and application servers securely.

**Technologies:** AWS VPC, Private Subnets, Route Tables, Network ACLs, CIDR, Network Isolation

### 6. [Launching VPC Resources](./vpc-launching-resources/)
Deploying actual resources in VPC infrastructure. Launched public and private EC2 instances, configured security groups, and explored the 'VPC and More' option for visualizing network architecture.

**Technologies:** AWS VPC, EC2, Security Groups, Public/Private Subnets, VPC Resource Map

### 7. [Testing VPC Connectivity](./vpc-testing-connectivity/)
Validating network architecture through practical testing. Used EC2 Instance Connect, SSH, ping (ICMP), and curl to test connectivity between public and private instances and verify security group and NACL configurations.

**Technologies:** AWS EC2, EC2 Instance Connect, SSH, ICMP/Ping, Curl, Security Groups, Network Testing

### 8. [VPC Peering](./vpc-peering/)
Connecting isolated VPCs through peering connections. Created two VPCs with public subnets, launched EC2 instances, configured VPC peering, and updated route tables to enable private cross-VPC communication.

**Technologies:** AWS VPC, VPC Peering, Route Tables, Security Groups, EC2, Cross-VPC Networking

### 9. [VPC Monitoring with Flow Logs](./vpc-monitoring/)
Implementing network monitoring and visibility. Set up VPC Flow Logs to capture network traffic metadata, configured CloudWatch log groups, created IAM roles with trust policies, and used CloudWatch Logs Insights to analyze traffic patterns.

**Technologies:** AWS VPC Flow Logs, CloudWatch, CloudWatch Logs Insights, IAM Roles, Trust Policies, Network Monitoring

### 10. [S3 Access from VPC](./s3-from-vpc/)
First project using Terraform (IaC) instead of the AWS Console. Provisioned a full VPC environment with EC2, dynamic IP-restricted security rules, and an S3 bucket with versioning and encryption. SSH'd into the instance and accessed S3 using AWS CLI commands.

**Technologies:** Terraform, AWS VPC, EC2, S3, Security Groups, Network ACLs, Amazon Linux 2023, AWS CLI, IAM

### 11. [VPC Endpoints](./vpc-endpoints/)
Extended S3 access to use private VPC Gateway Endpoints instead of routing traffic through the internet. Modified route tables automatically, enforced S3 bucket policies restricting access to traffic originating from the designated endpoint, and explored Interface Endpoints (PrivateLink) for other AWS services.

**Technologies:** Terraform, AWS VPC, VPC Gateway Endpoints, S3, Bucket Policies, PrivateLink, NACLs, Security Groups

### 12. [EC2 Web App with Aurora DB](./aurora-db-ec2/)
Three-tier web architecture using Terraform. Deployed a publicly accessible EC2 instance running Apache and PHP in a public subnet, connected to a managed RDS PostgreSQL database isolated in private subnets. Implemented security group references for database access and used Secrets Manager for credentials management.

**Technologies:** Terraform, EC2, RDS PostgreSQL, Security Groups, NACLs, Elastic IP, PHP, Amazon Linux 2023, AWS Secrets Manager

### 13. [Homelab](./homelab/)
Production-like AWS homelab environment built entirely with Terraform. Features a bastion host for SSH access, a NAT instance for cost-efficient outbound routing, a web application tier backed by RDS PostgreSQL, and S3 with a VPC Gateway Endpoint for private access. Implements multi-layer security across security groups, NACLs, and IAM least-privilege roles.

**Technologies:** Terraform, VPC, EC2, RDS PostgreSQL 15, Security Groups, NACLs, IAM, S3, VPC Gateway Endpoint, SSH ProxyJump

### 14. [Data in DynamoDB](./dynamo-db-data/)
Exploring AWS DynamoDB as a fully managed NoSQL database service. Covers DynamoDB data modeling, table creation, and integrating a schemaless database into cloud infrastructure as an alternative to traditional relational databases.

**Technologies:** AWS DynamoDB, Terraform

---

## Goals

- Gain hands-on experience with core AWS services
- Develop security-focused cloud solutions
- Document technical decision-making and problem-solving
- Build a portfolio demonstrating cloud competency


