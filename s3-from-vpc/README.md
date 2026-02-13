# S3 Access from VPC

## Overview

Amazon S3 (Simple Storage Service) is AWS's foundational object storage service, designed to store and retrieve any amount of data from anywhere on the internet. Unlike block storage or file systems, S3 organizes data as objects within buckets, each object consisting of the data itself, metadata, and a unique key. S3 offers eleven nines of durability (99.999999999%), making it one of the most resilient storage services available and the backbone of countless AWS architectures for backups, data lakes, static assets, and application state.

I built this project to understand how EC2 instances interact with S3 programmatically from within a VPC, a pattern that appears in virtually every real-world AWS architecture. Previous projects in this series focused on VPC construction, traffic control, connectivity testing, peering, and monitoring, all through the AWS Console. This project introduced a critical shift: the entire infrastructure is defined as code using Terraform and lives in the `terraform/` directory. That change alone makes this the most significant methodological step in the series so far, because Infrastructure as Code (IaC) is how production infrastructure is actually managed.

This project builds directly on the VPC knowledge accumulated across projects three through nine. I applied everything I learned about subnets, Internet Gateways, route tables, security groups, and Network ACLs, but this time expressed entirely in Terraform resources rather than console actions. Adding S3 to the architecture introduced object storage, versioning, encryption configuration, and AWS CLI usage from inside an EC2 instance.

## Architecture

![Architecture Diagram](assets/s3.png)

## Implementation Steps

### 1. VPC Infrastructure

I defined the VPC with a `10.0.0.0/16` CIDR block, a public subnet at `10.0.1.0/24`, an Internet Gateway, a route table with a default route (`0.0.0.0/0`) pointing to the IGW, and a route table association connecting the subnet to that route table. One decision I made deliberately was enabling both `enable_dns_hostnames` and `enable_dns_support` on the VPC. DNS hostname support is required for EC2 instances to receive public DNS names and for some AWS service integrations to work correctly, including certain S3 endpoint configurations. Enabling it from the start is a safe default and avoids subtle resolution failures later. Terraform's declarative model meant all six of these networking resources were defined in a single file (`network.tf`) and applied atomically.

### 2. Security Layer

I created a Security Group and a Network ACL together, applying both the stateful and stateless layers of defense in depth that I studied in earlier VPC projects. The Security Group restricts SSH (port 22) and ICMP to my current IP address only, while allowing HTTP (80) and HTTPS (443) from anywhere. The NACL mirrors these rules with an important addition: explicit inbound and outbound rules for ephemeral ports (1024-65535). NACLs are stateless, meaning return traffic is not automatically permitted the way it is with security groups. Without ephemeral port rules, outbound responses to inbound SSH or HTTP connections would be silently dropped at the subnet boundary. Writing these rules manually in Terraform forced me to internalize why stateless firewalls require bidirectional rules, a concept that is easy to miss when security groups handle everything automatically.

### 3. Dynamic IP Detection

Rather than hardcoding my IP address as a Terraform variable, I used a bash script (`scripts/my_ip_json.sh`) that queries a public IP API at plan time via Terraform's `external` data source. The script returns a JSON object with the detected IP, which Terraform then uses to populate the `/32` CIDR blocks in both the Security Group and NACL rules. This approach means the correct IP is always used without any manual lookup or variable update before each `terraform apply`. It also eliminated the risk of accidentally leaving a stale or overly broad CIDR in the SSH rule. Automating even this small operational detail reflects a core IaC principle: anything that can drift should be computed, not hardcoded.

### 4. EC2 Instance and Key Pair

I used Terraform's `tls_private_key` resource to generate a 4096-bit RSA key pair entirely within the Terraform run. The public key is registered with AWS as an EC2 Key Pair, and the private key is written to `terraform/.ssh/` as a local file with `0400` permissions. The reason for generating the key inside Terraform rather than creating it manually is consistency and reproducibility: the key is tied to the infrastructure definition and requires no out-of-band steps. I attached an Elastic IP to the instance using `depends_on = [aws_internet_gateway.test-igw]`, which is necessary because an EIP associated with an instance in a VPC without an IGW is unreachable. The `depends_on` makes Terraform's implicit dependency graph explicit for resources that don't reference each other directly, ensuring the IGW exists before the EIP is allocated. I chose an Elastic IP over relying on the instance's auto-assigned public IP because auto-assigned IPs change on every stop-start cycle, which would break SSH access and any scripts that reference the IP.

### 5. S3 Bucket

I created the S3 bucket in Terraform with three configuration blocks: the bucket resource itself, versioning configuration, and server-side encryption configuration. The bucket name follows the pattern `s3-gateway-storage-<account_id>`, where the account ID is fetched at runtime using Terraform's `aws_caller_identity` data source. S3 bucket names must be globally unique across all AWS accounts, and appending the account ID is a widely-used convention that achieves uniqueness without random suffixes. I enabled versioning so that overwritten or deleted objects are retained as previous versions, providing a safety net against accidental data loss. I chose AES256 (SSE-S3) for server-side encryption rather than KMS-managed keys (SSE-KMS) because for a learning project, SSE-S3 provides transparent encryption with no additional cost or configuration overhead. SSE-KMS would be appropriate in production for environments requiring key rotation audit trails or cross-account key sharing.

### 6. S3 Access from the EC2 Instance

With the instance running, I SSH'd in using the generated private key and the Elastic IP. I ran `aws configure` on the instance to supply IAM user credentials (access key ID and secret access key), which configured the AWS CLI to authenticate requests to S3. I then used `aws s3 ls` to list buckets and `aws s3 cp` to upload and download test files. Each command succeeded, confirming end-to-end connectivity: the EC2 instance inside the VPC could authenticate to AWS APIs and perform read and write operations against the S3 bucket over the public AWS service endpoint. This validated both the network path (IGW, route table, security group, NACL) and the IAM credentials.

## Security Considerations

**Infrastructure as Code reduces configuration drift.** Every security-relevant resource in this project (ecurity groups, NACL rules, encryption settings, bucket configurations) is expressed in Terraform and committed to version control. With Terraform, the configuration file is the authoritative description of what exists. Any change must go through the code, which means it can be reviewed, audited, and reverted. Running `terraform plan` before every apply also creates a diff of what will change, making it harder to accidentally modify production resources.

**Dynamic IP detection enforces the principle of least privilege at the network layer.** The `scripts/my_ip_json.sh` script detects my current public IP at plan time and writes it directly into the SSH and ICMP allow rules as a `/32` CIDR. Restricting SSH to a single IP address means that even if an attacker knows the instance's Elastic IP and has valid credentials, they cannot initiate a connection from any other network location. This is a network-layer control that complements the credential-layer control of the key pair. Hardcoding a broader CIDR like `0.0.0.0/0` for SSH convenience is one of the most common misconfigurations in cloud environments, and automating the IP detection removes the temptation to do so.

**S3 encryption at rest and versioning protect stored data.** AES256 server-side encryption ensures that objects are encrypted on disk inside AWS's infrastructure, protecting against physical media exposure. Versioning provides a temporal safety net: deleted or overwritten objects are not permanently removed but retained as noncurrent versions, allowing recovery from accidental deletion or bad writes. Together, these two settings address two distinct threat models, unauthorized physical access and human error. Both are trivial to enable in Terraform and represent a minimum baseline for any production S3 bucket.

**IAM credentials on EC2 via `aws configure` is a common but non-ideal pattern.** In this project I ran `aws configure` on the EC2 instance and supplied an IAM user's access key and secret key. This works, but it means long-lived credentials are stored in `~/.aws/credentials` on the instance. If the instance is compromised, those credentials can be exfiltrated and used from anywhere. The correct pattern for granting EC2 instances access to AWS services is an IAM Role attached as an instance profile. Instance profiles deliver temporary, automatically rotated credentials via the EC2 metadata service, eliminating static credentials entirely. Using `aws configure` was appropriate for a learning exercise, but I treat it as a lesson learned: in any real environment, I would attach an IAM Role with the minimum required S3 permissions to the instance instead.

**The Terraform state file contains the generated private key.** Because I used the `tls_private_key` resource, the RSA private key is stored in `terraform.tfstate` in plaintext. Anyone with read access to the state file can extract the private key and SSH into the instance. In a team environment, state files are typically stored in a remote backend (such as an S3 bucket with versioning and server-side encryption) with strict IAM access controls. For this project the state is local, but understanding this risk is important before adopting the same pattern in shared or production environments. Alternatively, generating the key pair outside of Terraform and passing only the public key in avoids storing the private key in state entirely.

## Cost Analysis

The EC2 t3.micro instance is the primary compute cost. On-demand pricing for t3.micro in us-east-1 is approximately $0.0104 per hour, or roughly $7.50 per month if left running continuously. The AWS Free Tier covers 750 hours per month of t3.micro (or t2.micro) usage for the first 12 months of a new account, so this instance would cost nothing within the free tier period.

Elastic IPs have an important pricing nuance: they are free while attached to a running instance, but AWS charges $0.005 per hour for EIPs that are allocated but not associated with a running instance. This means stopping the EC2 instance without releasing the EIP incurs a small but ongoing charge. I kept the EIP released after completing the project to avoid this cost. It is a common source of unexpected bills for developers who stop instances without deallocating associated EIPs.

S3 costs have three components: storage ($0.023 per GB per month in us-east-1 for Standard storage), PUT/COPY/POST/LIST requests ($0.005 per 1,000 requests), and GET/SELECT requests ($0.0004 per 1,000 requests). For this learning project, the test files I uploaded were small and the request volume was minimal, placing the cost well within the Free Tier's 5 GB of S3 storage and 20,000 GET and 2,000 PUT requests per month. Versioning multiplies storage costs because each version of an object is stored independently. In production, lifecycle policies that transition or expire noncurrent versions are essential for keeping S3 costs predictable.

Terraform itself has no cost. The only Terraform-related cost consideration is remote state storage if using S3 as a backend, which would add a small amount to the S3 bill. For this project with local state, there was no additional charge.

Teardown is straightforward with Terraform: `terraform destroy` removes all provisioned resources in the correct dependency order. This is one of Terraform's most practical advantages over console-built infrastructure, where teardown requires remembering every resource created and deleting them in the right sequence. I ran `terraform destroy` after completing the project to ensure no resources continued accumulating charges.

## Key Takeaways

- **Terraform's plan/apply workflow enforces intentionality.** Running `terraform plan` before every `terraform apply` produces an explicit diff of what will be created, modified, or destroyed. This prevents accidental changes and forces a review step that the console's immediate action model does not provide. The plan output also serves as documentation of what each apply did, which is valuable for understanding infrastructure history.

- **IaC makes infrastructure reproducible and auditable.** Defining the entire stack in Terraform means I can tear it down and recreate it identically with a single command. The configuration files are version-controlled, so every infrastructure state is traceable to a commit. This is the foundation of reliable cloud operations and is not achievable when infrastructure exists only as console state.

- **Terraform state is a critical artifact that requires protection.** The state file is Terraform's record of what exists in the real world. It can contain sensitive values like the private key generated in this project. Treating state files with the same security rigor as application secrets—encrypted storage, access controls, versioning—is essential in any shared environment.

- **Dynamic IP detection automates security hygiene.** Using a script to detect and inject the current IP into security rules removes a manual, error-prone step and prevents overly permissive SSH access rules from persisting. Automating security controls, rather than relying on humans to configure them correctly each time, is a core principle of secure infrastructure management.

- **Elastic IPs provide stable addressing for EC2 instances.** Unlike auto-assigned public IPs that change on every stop-start cycle, Elastic IPs remain constant. This stability is necessary for any workflow that references the instance by IP address, including SSH access, DNS records, and firewall allowlists. The EIP's dependency on the IGW is an important detail that `depends_on` makes explicit in Terraform.

- **S3 is durable, scalable object storage accessible from anywhere in AWS.** An EC2 instance inside a VPC can reach S3 over the public AWS service endpoint through the Internet Gateway, using AWS CLI commands like `aws s3 cp` and `aws s3 ls`. This pattern is foundational to most AWS application architectures and is worth understanding.

- **IAM roles and instance profiles are the correct way to grant EC2 access to AWS services.** Using `aws configure` with an IAM user's credentials on an EC2 instance works, but leaves long-lived credentials on the instance. IAM roles attached as instance profiles provide temporary credentials via the metadata service, rotate automatically, and leave no static secrets on disk. This is the most important lesson from the S3 access step, and it shapes how I will approach EC2-to-service authentication in every future project.

- **Defense in depth requires understanding each layer's semantics.** Security groups and NACLs both control traffic, but their stateful versus stateless behavior means they require different rule sets. Writing both layers in Terraform forced me to be explicit about every permitted flow, including ephemeral return traffic, which deepened my understanding of how TCP connections traverse layered network security controls.
