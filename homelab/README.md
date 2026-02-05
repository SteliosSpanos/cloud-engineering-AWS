# AWS Homelab Infrastructure with Terraform

## Overview

Infrastructure as Code (IaC) represents a fundamental shift in how cloud infrastructure is managed, moving from manual console clicking to declarative configuration files that can be versioned, reviewed, and reproducibly deployed. Terraform, HashiCorp's open-source IaC tool, enables you to define AWS resources in human-readable configuration files and manage their entire lifecycle through code. This approach brings software engineering practices like version control, code review, and automated testing to infrastructure management.

I built this homelab project to synthesize everything I learned from my previous VPC projects into a complete, production-ready infrastructure managed entirely through Terraform. Rather than manually creating resources through the AWS Console, I defined a three-tier architecture in code that includes networking, compute, security, storage, and identity management. This project represents the natural evolution from learning individual AWS services to architecting complete systems with industry-standard tooling.

The homelab creates a secure, cost-optimized AWS environment suitable for hosting private workloads, development environments, or experimental projects. The architecture implements the bastion host pattern for secure access, uses a NAT instance instead of AWS's managed NAT Gateway for cost savings, enforces defense-in-depth security with multiple layers of access controls, and provides private S3 access through VPC endpoints. All infrastructure is defined in modular Terraform files, making it easy to modify, extend, or tear down.

The technologies involved include Terraform for infrastructure as code, VPC networking with public and private subnets, EC2 instances running Amazon Linux 2023, security groups and network ACLs for traffic control, IAM roles with least-privilege policies, S3 with encryption and versioning, VPC endpoints for AWS service access, and automated SSH configuration with ProxyJump. This project taught me that real cloud engineering isn't about knowing how to create resources, it's about architecting systems that are secure, maintainable, and cost-effective from day one.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                    INTERNET                                      │
└─────────────────────────────────────┬───────────────────────────────────────────┘
                                      │
                                      │ SSH (Port 22) - Only from My IP
                                      ▼
|────────────────────────────────────────────────────────────────────────────────|
│                              VPC (10.0.0.0/16)                                 │
│  ┌───────────────────────────────────────────────────────────────────────────┐ │
│  │                        PUBLIC SUBNET (10.0.1.0/24)                        │ │
│  │                                                                           │ │
│  │   ┌─────────────────────┐              ┌─────────────────────┐            │ │
│  │   │     JUMP BOX        │              │    NAT INSTANCE     │            │ │
│  │   │    (t3.micro)       │              │     (t3.micro)      │            │ │
│  │   │                     │    SSH       │                     │            │ │
│  │   │  ┌───────────────┐  │◄────────────►│  ┌───────────────┐  │            │ │
│  │   │  │ Security Group│  │              │  │ Security Group│  │            │ │
│  │   │  │ - SSH from IP │  │              │  │ - HTTP/S from │  │            │ │
│  │   │  └───────────────┘  │              │  │   private sub │  │            │ │
│  │   │                     │              │  │ - SSH from JB │  │            │ │
│  │   │  Elastic IP ────────┼──► Internet  │  └───────────────┘  │            │ │
│  │   │                     │              │                     │            │ │
│  │   │  IAM Role:          │              │  Elastic IP ────────┼──► Internet│ │
│  │   │  - CloudWatch Logs  │              │                     │            │ │
│  │   │  - SSM Access       │              │  IAM Role:          │            │ │
│  │   └─────────────────────┘              │  - CloudWatch Logs  │            │ │
│  │            │                           │  - SSM Access       │            │ │
│  │            │ SSH ProxyJump             │                     │            │ │
│  │            │                           │  IP Forwarding +    │            │ │
│  │            │                           │  iptables MASQUERADE│            │ │
│  │            │                           └──────────┬──────────┘            │ │
│  │            │                                      │                       │ │
│  └────────────┼──────────────────────────────────────┼───────────────────────┘ │
│               │                                      │                         │
│               │         ┌────────────────────────────┘                         │
│               │         │  Outbound Traffic via NAT                            │
│               │         ▼                                                      │
│  ┌────────────┼─────────────────────────────────────────────────────────────┐  │
│  │            │         PRIVATE SUBNET (10.0.2.0/24)                        │  │
│  │            │                                                             │  │
│  │            ▼                                                             │  │
│  │   ┌─────────────────────┐                    ┌─────────────────────┐     │  │
│  │   │      MAIN VM        │                    │    S3 BUCKET        │     │  │
│  │   │     (t3.micro)      │    VPC Endpoint    │                     │     │  │
│  │   │                     │◄──────────────────►│  - Versioning       │     │  │
│  │   │  ┌───────────────┐  │   (Gateway)        │  - AES256 Encrypted │     │  │
│  │   │  │ Security Group│  │                    │  - Public Access    │     │  │
│  │   │  │ - SSH from JB │  │                    │    Blocked          │     │  │
│  │   │  │ - ICMP from JB│  │                    │  - Bucket Policy:   │     │  │
│  │   │  └───────────────┘  │                    │    Main VM Role Only│     │  │
│  │   │                     │                    └─────────────────────┘     │  │
│  │   │  NO Public IP       │                                                │  │
│  │   │                     │                                                │  │
│  │   │  IAM Role:          │                                                │  │
│  │   │  - CloudWatch Logs  │                                                │  │
│  │   │  - SSM Access       │                                                │  │
│  │   │  - S3 Access        │                                                │  │
│  │   └─────────────────────┘                                                │  │
│  │                                                                          │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                           SECURITY LAYERS                               │   │
│  │  Layer 1: Security Groups (Stateful, Instance-level)                    │   │
│  │  Layer 2: Network ACLs (Stateless, Subnet-level)                        │   │
│  │  Layer 3: IAM Roles (API-level access control)                          │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
|────────────────────────────────────────────────────────────────────────────────|
```

The homelab architecture implements a three-tier security model with clear separation between public-facing and private resources. The VPC uses the 10.0.0.0/16 CIDR block with DNS resolution enabled. Within this VPC, I created two subnets in the same availability zone: a public subnet (10.0.1.0/24) with direct internet access through an Internet Gateway, and a private subnet (10.0.2.0/24) that routes internet traffic through a NAT instance.

Three EC2 instances form the compute layer. The jump box (bastion) sits in the public subnet with an Elastic IP, serving as the single SSH entry point to the environment. The NAT instance also resides in the public subnet with source/destination checks disabled, routing outbound traffic from the private subnet to the internet using iptables masquerading. The main VM lives in the private subnet with no public IP address, accessible only through the jump box via SSH ProxyJump.

Security is enforced at three layers. Security groups provide stateful, instance-level firewall rules: the jump box accepts SSH only from my IP address, the NAT instance accepts HTTP/HTTPS from the private subnet, and the main VM accepts SSH only from the jump box. Network ACLs provide stateless, subnet-level controls with explicit allow rules for required traffic and implicit deny for everything else. IAM roles grant each instance least-privilege permissions: the jump box and NAT instance can write CloudWatch logs and use Systems Manager, while the main VM additionally has S3 access.

Storage and AWS service access are handled through S3 and VPC endpoints. The S3 bucket has versioning enabled, AES256 server-side encryption, public access completely blocked, and a bucket policy restricting access exclusively to the main VM's IAM role. A VPC Gateway Endpoint allows the private subnet to access S3 without traversing the public internet or consuming NAT bandwidth.

The Terraform automation generates RSA SSH keys, stores the private key locally with secure permissions, creates an SSH config file with ProxyJump configuration for transparent access to private instances, and outputs all connection commands and resource identifiers. This design balances security, cost optimization, and operational convenience.

## Implementation Steps

### 1. Structuring the Terraform Project

I organized my Terraform configuration into modular files based on resource types rather than creating a single monolithic configuration. This structure improves maintainability because changes to networking don't require touching compute or security configurations, and it makes code reviews more focused. I created separate files for providers.tf (AWS provider configuration), variables.tf (input variables), data.tf (data sources like AMIs and current IP), network.tf (VPC, subnets, route tables, gateways), security.tf (security groups), nacls.tf (network ACLs), compute.tf (EC2 instances and SSH keys), iam.tf (roles and policies), s3.tf (bucket and endpoint), and outputs.tf (output values). This modular approach is a best practice I learned from studying real-world Terraform projects. It makes the codebase navigable and encourages separation of concerns.

### 2. Learning Terraform Language Fundamentals

Terraform uses HashiCorp Configuration Language (HCL), a declarative language where you describe the desired end state rather than the steps to achieve it. I learned that Terraform resources are the fundamental building blocks, each representing an infrastructure component like aws_vpc or aws_instance. Resource blocks specify the resource type and local name, followed by configuration arguments. I also learned about variables for parameterization, data sources for querying existing resources or external information, and outputs for exposing values after deployment. Understanding the dependency graph was crucial: Terraform automatically determines resource creation order based on references, but you can use depends_on for explicit dependencies. This declarative model felt different from procedural scripting, but it's powerful because Terraform handles the complexity of ordering operations correctly.

### 3. Designing the Network Architecture

I designed a dual-subnet VPC architecture based on the principle of least privilege network access. The public subnet hosts resources that need direct internet access: the jump box for SSH entry and the NAT instance for routing private subnet traffic. The private subnet hosts the main workload VM, which has no direct internet route and can only be accessed through the bastion. This design minimizes the attack surface by keeping sensitive workloads isolated from direct internet exposure. I enabled DNS hostnames and DNS support on the VPC because many AWS services require DNS resolution to function properly. I learned that subnet IP addressing requires planning: 10.0.1.0/24 provides 251 usable IPs (AWS reserves 5 per subnet), which is sufficient for a homelab but would need careful planning in production. The key architectural decision was making the public and private subnets reside in the same availability zone, simplifying the setup and reducing cross-AZ data transfer costs.

### 4. Implementing Internet Gateway and Route Tables

I created an Internet Gateway and attached it to the VPC to enable internet connectivity for public subnet resources. The critical lesson was understanding that an IGW alone doesn't provide internet access; you must also configure route tables. I created separate route tables for public and private subnets, implementing the principle of explicit routing. The public route table contains a default route (0.0.0.0/0) pointing to the IGW, giving public subnet instances direct internet access. The private route table's default route points to the NAT instance's network interface, routing traffic through the NAT for outbound connectivity while preventing inbound internet access. Route table associations bind each subnet to its appropriate route table. This taught me that AWS networking requires explicit configuration at every layer—nothing is assumed or automatic. The separation of route tables provides clear traffic flow boundaries and makes the network design easier to understand and troubleshoot.

### 5. Configuring the NAT Instance

Rather than using AWS's managed NAT Gateway, which costs $0.045 per hour plus data transfer ($32/month minimum), I implemented a NAT instance using a t3.micro EC2 instance. This cost-saving approach is appropriate for homelab and development environments with low bandwidth requirements. The critical configuration for NAT functionality is disabling source/destination checks on the instance, which is normally enabled to prevent packet spoofing. With this check disabled, the instance can forward traffic for other instances, acting as a router. I wrote a user data script that runs at instance launch to configure the NAT functionality. The script enables IP forwarding in the kernel, installs iptables, configures MASQUERADE rules to rewrite source IP addresses on outbound packets, and creates a systemd service to restore iptables rules on reboot. This taught me about Linux networking fundamentals and how AWS security models assume instances won't route traffic unless explicitly configured. The NAT instance provides the same outbound internet access as NAT Gateway at a fraction of the cost, with the tradeoff of reduced bandwidth and lack of automatic failover.

### 6. Implementing Bastion/Jump Box Pattern

I created a jump box (bastion host) as the single point of entry for SSH access to the environment. This security pattern centralizes access control and audit logging. The jump box sits in the public subnet with an Elastic IP for a stable, reachable address. Security group rules restrict SSH access to my specific IP address, preventing unauthorized access attempts. From the jump box, I can SSH to other instances in both public and private subnets. For the private subnet main VM, which has no public IP, the jump box is the only possible access path. I automated the SSH workflow by generating an SSH config file that uses ProxyJump configuration. This allows transparent access: when I run `ssh main-vm`, SSH automatically connects to the jump box first, then establishes a second SSH connection to the main VM through that tunnel. The user never has to manually chain SSH commands. This taught me that security patterns can be user-friendly when properly automated. The bastion pattern is production-standard and appears in enterprise architectures specifically because it balances security control with operational convenience.

### 7. Automated SSH Key Management

I used Terraform's TLS provider to generate a 4096-bit RSA key pair automatically during deployment. The public key is uploaded to AWS as a key pair resource, while the private key is written to a local file with 0400 permissions (read-only for the owner). This automation eliminates the manual step of generating keys with ssh-keygen and uploading them to AWS. However, I learned an important security consideration: the private key is stored in Terraform state, which means the state file must be protected. In production environments, state files should be stored in encrypted S3 buckets with strict IAM policies, or better yet, use a dedicated secret management service and reference existing keys rather than generating them in Terraform. For a homelab project, the automation convenience outweighs this concern, but it's a pattern I wouldn't use for production systems handling sensitive workloads. This taught me that convenience features in IaC tools often come with security tradeoffs that must be evaluated based on the use case.

### 8. Defining Security Groups

I created three security groups implementing the principle of least privilege at the network level. The jump box security group allows inbound SSH only from my IP address, which I dynamically fetch using an external data source that calls a bash script. This ensures the security group always reflects my current IP without hardcoding values. The NAT instance security group allows HTTP and HTTPS from the private subnet CIDR and SSH from the jump box security group, demonstrating security group chaining where rules reference other security groups instead of IP ranges. The main VM security group allows SSH and ICMP only from the jump box security group, implementing the bastion pattern at the firewall level. All three security groups have unrestricted egress, following the AWS default of allowing all outbound traffic. I learned that security groups are stateful, meaning return traffic for allowed outbound connections is automatically permitted even without explicit inbound rules. This statefulness simplifies rule management compared to traditional firewalls.

### 9. Configuring Network ACLs

While security groups provide the primary security layer, I added network ACLs for defense in depth. NACLs are stateless, subnet-level firewalls that require explicit rules for both inbound and outbound traffic. I created separate NACLs for public and private subnets. The public NACL allows inbound SSH from my IP, HTTP/HTTPS from anywhere for internet-bound traffic, ephemeral ports (1024-65535) for return traffic, and ICMP for ping. Outbound rules mirror the inbound requirements plus SSH to the private subnet. The private NACL allows inbound SSH from the public subnet and ephemeral ports for return traffic from internet requests. Outbound rules allow HTTP/HTTPS for package downloads and updates. I learned that NACL rules require careful planning because they're evaluated in numerical order and the first match wins. Rule numbers 100, 110, 120 etc. leave room for inserting additional rules later without renumbering everything. NACLs feel redundant with security groups in simple architectures, but they provide a second layer of defense and can block traffic at the subnet level before it even reaches instances.

### 10. Implementing IAM Roles with Least Privilege

I created dedicated IAM roles for each EC2 instance type rather than sharing a common role. This follows the principle of least privilege: each instance receives only the permissions required for its specific function. All three roles share two common permissions: writing to CloudWatch Logs for centralized logging, and Systems Manager access for potential remote management without SSH. The main VM role uniquely has an S3 access policy granting GetObject, PutObject, ListBucket, and DeleteObject on the homelab bucket only. This demonstrates resource-based access control where permissions are scoped to specific S3 buckets rather than granting broad S3 access. I learned about IAM trust policies, which define which AWS services can assume a role. All three roles have trust policies allowing ec2.amazonaws.com to assume them, enabling EC2 instances to acquire the role's permissions. Instance profiles bind roles to EC2 instances, acting as a container for the role. This multi-layer approach—role definition, trust policy, permission policies, instance profile, and instance attachment—seems complex but provides granular security control and clear permission boundaries.

### 11. Configuring S3 Bucket with Security Best Practices

I created an S3 bucket implementing multiple layers of security and data protection. Versioning is enabled to maintain multiple versions of objects, providing protection against accidental deletion or modification. Server-side encryption with AES256 ensures data at rest is encrypted using AWS-managed keys. Public access block settings are enabled for all four options, preventing any form of public access regardless of bucket policies or ACLs. The bucket policy uses an explicit allow statement granting access only to the main VM's IAM role, implementing a whitelist approach. This combination of encryption, versioning, public access blocks, and role-based policies demonstrates S3 security best practices. I learned that S3 security is multi-layered by design: even if you accidentally create a public bucket policy, the public access block prevents it from taking effect. This defense-in-depth approach protects against configuration mistakes. The bucket naming includes the AWS account ID to ensure global uniqueness, a common pattern for avoiding naming conflicts.

### 12. Creating S3 VPC Gateway Endpoint

I created a VPC Gateway Endpoint for S3 to allow private subnet instances to access S3 without routing traffic through the NAT instance or over the public internet. VPC endpoints create a private connection between your VPC and AWS services. Gateway endpoints (for S3 and DynamoDB) work by modifying route tables to direct service traffic to the endpoint rather than the internet. This has two benefits: improved security because traffic never leaves the AWS network, and cost savings because traffic to S3 through a gateway endpoint doesn't consume NAT Gateway bandwidth or incur data transfer charges. I associated the endpoint with the private subnet route table, automatically adding routes for S3 prefix lists. I learned that gateway endpoints are free and provide better security and performance than accessing S3 over the internet, making them a no-brainer for VPC architectures with private subnets.

### 13. Data Sources for Dynamic Configuration

I used several Terraform data sources to fetch information dynamically rather than hardcoding values. The aws_availability_zones data source queries available AZs in the region, and I select the first one for subnet placement. The aws_ami data source queries the latest Amazon Linux 2023 AMI, ensuring instances always use recent images without manual updates. The data.external.my_ip data source executes a bash script that queries an IP API and returns my current public IP in JSON format. This enables dynamic security group rules that automatically reflect my IP without manual updates. The aws_caller_identity data source retrieves the AWS account ID for constructing unique S3 bucket names. Data sources taught me that Terraform isn't just for creating resources, it's a bridge between your code and the actual state of AWS, allowing configurations to adapt to real-world conditions. This makes infrastructure code more portable and less dependent on hardcoded environment-specific values.

### 14. Output Values for Operational Convenience

I defined Terraform outputs to expose important information after deployment. Outputs include all instance IP addresses, VPC and subnet IDs, S3 bucket name and ARN, and ready-to-use SSH connection commands. The ssh_commands output is particularly valuable: it shows exactly how to connect to each instance using the generated SSH config file. Users can copy-paste these commands without understanding the underlying ProxyJump configuration. Outputs serve as self-documenting infrastructure, showing operators how to interact with deployed resources. I learned that good IaC includes not just resource definitions but operational guidance. Outputs make infrastructure immediately usable without requiring users to dig through the AWS Console to find IP addresses or figure out connection methods. This attention to user experience is what differentiates production-quality infrastructure code from basic resource definitions.

### 15. Testing and Validation

After running terraform apply to create the infrastructure, I validated each layer of the architecture. I SSH'd to the jump box using the generated SSH config, then proxied through to the main VM and NAT instance, confirming the bastion pattern works. From the main VM, I tested internet connectivity with curl, ping, and package manager updates, validating that the NAT instance correctly routes traffic. I tested S3 access from the main VM using the AWS CLI to list buckets, upload files, and retrieve objects, confirming IAM role permissions work correctly. I also tested that the VPC endpoint routes S3 traffic by inspecting route tables and verifying that S3 requests don't appear in NAT instance logs. Finally, I intentionally violated security group rules by attempting SSH from unauthorized IPs or ports, confirming that security controls reject unauthorized access. This comprehensive testing taught me that infrastructure validation requires checking both positive cases (authorized actions work) and negative cases (unauthorized actions are blocked). Real infrastructure engineering includes systematic validation, not just deployment.

### 16. Terraform State Management

Throughout this project, I worked with Terraform state, the JSON file that maps your configuration to real infrastructure. State is how Terraform knows which resources exist, their current configuration, and what needs to change on subsequent applies. I learned that state files contain sensitive information like IP addresses, resource IDs, and in this project, the private SSH key. For solo learning projects, local state stored in terraform.tfstate is acceptable, but production environments must use remote state in S3 with encryption and state locking via DynamoDB to prevent concurrent modifications. I also learned about terraform plan, which compares desired state (configuration files) with actual state (AWS resources) and shows what changes will occur. This preview capability is essential for preventing destructive changes. Running terraform apply without reviewing the plan is dangerous in production. State management taught me that IaC isn't just about writing configuration—it's about maintaining the mapping between code and reality over time.

### 17. Cost Optimization Decisions

Several architectural decisions in this project prioritize cost optimization for a homelab environment. Using a NAT instance instead of NAT Gateway saves approximately $25-30 per month. Using t3.micro instances qualifies for AWS Free Tier (750 hours/month for 12 months), making compute costs zero or minimal. Creating resources in a single availability zone avoids cross-AZ data transfer charges. Using S3 Gateway Endpoints eliminates NAT bandwidth costs for S3 access. Implementing automated teardown with terraform destroy makes it easy to delete all resources when not in use, stopping all charges immediately. I learned that cloud cost optimization requires conscious architectural decisions, not just turning off unused resources. The choices I made reduce costs by 60-80% compared to using managed services like NAT Gateway and multi-AZ deployments, while providing functionally equivalent capabilities for a development environment. This taught me that "best practice" depends on context—what's right for production may be over-engineered for development or learning environments.

## Security Considerations

**Defense in Depth Architecture**

This homelab implements defense in depth, a security principle that layers multiple independent security controls so that if one fails, others continue protecting the system. Security groups provide the first layer at the instance level, NACLs provide a second layer at the subnet level, and IAM roles provide a third layer controlling service access. An attacker would need to bypass all three layers to compromise resources. I also implemented network segmentation, separating public and private subnets to minimize the blast radius of potential compromises. The bastion pattern adds another security layer by creating a single, heavily monitored access point rather than allowing direct SSH to all instances. This multi-layer approach taught me that real security isn't about perfect controls; it's about making attacks so difficult and detectable that attackers move on to easier targets.

**Bastion Host Security**

The jump box is the most critical security component because it's the entry point to the entire environment. I implemented several hardening measures. Security group rules restrict SSH access to my specific IP address, blocking all other sources. Elastic IP provides a stable address for monitoring and alerting. CloudWatch Logs integration enables audit logging of all SSH sessions. Systems Manager access provides an alternative access method if SSH is compromised or my IP changes unexpectedly. In production environments, I would add fail2ban to block brute force attempts, enforce SSH key authentication with password authentication disabled, implement session recording for compliance, and configure centralized log forwarding to a security information and event management (SIEM) system. The bastion host must be treated as a critical security boundary, not just a convenience feature.

**Least Privilege IAM Policies**

Every IAM role in this project grants only the minimum permissions required for functionality. The jump box and NAT instance have no S3 access because they don't need it. Only the main VM has S3 permissions, and only for a specific bucket, not all S3 buckets. CloudWatch permissions are scoped to log creation and writing, not reading or modifying logs. Systems Manager uses the AWS-managed policy AmazonSSMManagedInstanceCore rather than Administrator access. This granular permission model limits the damage from instance compromise. If the NAT instance is compromised, the attacker cannot access S3 data. If the main VM is compromised, the attacker cannot modify other VPC resources. I learned that least privilege requires thoughtful policy design—it's easier to grant broad permissions, but the security benefit of scoped policies is worth the additional effort.

**S3 Bucket Security**

The S3 bucket implements AWS's recommended security baseline. Server-side encryption ensures data at rest is protected even if someone gains access to physical storage systems. Versioning provides protection against accidental or malicious deletion by maintaining object history. Public access blocks prevent any form of public access, even if bucket policies are misconfigured. The bucket policy explicitly whitelists only the main VM's IAM role, implementing a zero-trust approach where access is denied by default and granted explicitly. I learned that S3 security requires multiple controls because buckets are a common target for data breaches. The combination of encryption, access controls, and public access blocks creates robust protection. In production, I would add S3 Object Lock for compliance requirements, enable access logging to track all bucket operations, and configure bucket notifications for security monitoring.

**Network Access Control Lists**

While security groups provide the primary firewall layer, NACLs add subnet-level protection and enable network-level blocking. NACLs are stateless, requiring explicit rules for both inbound and outbound traffic, which prevents certain attack patterns that exploit stateful firewall behavior. The public NACL restricts inbound SSH to my IP address at the subnet level, so even if a security group is misconfigured, unauthorized SSH is blocked. Ephemeral port rules allow return traffic for outbound connections while preventing arbitrary inbound connections. The private NACL enforces that only the public subnet can initiate SSH connections, implementing network segmentation at the NACL layer. I learned that NACLs feel redundant in simple architectures but provide valuable defense in depth, especially for blocking traffic before it reaches instances and enforcing subnet boundaries.

**Private Subnet Isolation**

The main VM in the private subnet has no direct internet access and no public IP address. All inbound access requires transiting through the bastion host, creating a controlled access path. Outbound internet access routes through the NAT instance, which provides a second layer of network address translation and logging. This isolation limits the attack surface: the main VM cannot be directly scanned or attacked from the internet. Even if a public-facing service is compromised, the attacker cannot pivot directly to the private subnet without first compromising the bastion or NAT instance. I learned that private subnets are essential for multi-tier architectures where application and database layers should never be directly internet-accessible. The tradeoff is operational complexity—access and troubleshooting require the bastion intermediary—but the security benefit justifies this overhead.

**SSH Key Security**

Terraform generates the SSH private key and stores it locally with restrictive file permissions (0400), preventing unauthorized users on the local system from reading it. However, the private key is also stored in Terraform state, which introduces a security consideration. If state is stored in unencrypted S3 or committed to version control, the key is exposed. For production environments, I would use an existing key pair created outside Terraform or use AWS Secrets Manager to store and retrieve keys. The SSH config file uses StrictHostKeyChecking=no for convenience, which is acceptable for a controlled homelab but should be disabled in production to prevent man-in-the-middle attacks. I learned that convenience features in IaC often trade security for ease of use, and the appropriate balance depends on the environment's security requirements.

**VPC Endpoint Security**

The S3 VPC Gateway Endpoint prevents S3 traffic from transiting the public internet, reducing exposure to network-based attacks. Traffic between instances and S3 remains within the AWS network, benefiting from AWS's internal security controls. Endpoint policies could further restrict access to specific S3 buckets, though I didn't implement that in this basic setup. Gateway endpoints also prevent DNS-based exfiltration attacks where an attacker redirects S3 DNS queries to malicious endpoints. I learned that VPC endpoints improve security by reducing the attack surface of the network boundary. Every service accessed over the internet is a potential point of compromise; endpoints eliminate that risk for supported AWS services.

**IP Whitelisting Limitations**

The security groups and NACLs whitelist my current public IP address for SSH access. This is effective for blocking unauthorized access but has operational challenges. If my IP address changes (common with residential ISPs), I lose SSH access until updating the security group. For production bastion hosts, more robust solutions include using a VPN to provide a stable source IP, implementing AWS Systems Manager Session Manager for browserless SSH without security group rules, or using AWS Client VPN for secure, managed access. I learned that IP whitelisting is simple and effective for controlled environments but doesn't scale for teams with remote workers or dynamic IP addresses. The homelab implementation prioritizes simplicity, but production scenarios require more flexible access controls.

## Cost Analysis

**EC2 Compute Costs**

The three t3.micro instances are the primary cost component. Without Free Tier, t3.micro costs $0.0104 per hour in us-east-1, which equals approximately $7.49 per month per instance or $22.47 per month for all three. AWS Free Tier provides 750 hours of t3.micro usage per month for the first 12 months of an account, which covers all three instances running 24/7 (3 instances × 730 hours = 2,190 hours, but Free Tier allows 750 total hours, covering one instance). After Free Tier expires, the full cost applies. For a homelab that doesn't run 24/7, hourly costs can be minimized by stopping instances when not in use. Stopped instances incur no compute charges, only minimal EBS storage costs. I learned that cloud cost optimization often involves operational discipline—remembering to stop resources when finished—rather than just architectural decisions.

**NAT Instance vs NAT Gateway**

This project uses a NAT instance instead of AWS's managed NAT Gateway specifically to reduce costs. NAT Gateway costs $0.045 per hour (approximately $32.85 per month) plus data transfer charges ($0.045 per GB processed). A t3.micro NAT instance costs $7.49 per month (or free within Free Tier) with no additional data transfer charges beyond standard internet egress. For the minimal bandwidth requirements of a homelab (software updates, package downloads), this saves $25-30 per month. The tradeoff is reduced bandwidth (t3.micro provides up to 5 Gbps burst, NAT Gateway provides 45 Gbps), manual management, and lack of high availability. For production environments with high bandwidth or uptime requirements, NAT Gateway is worth the cost. For development and learning, NAT instance is the cost-effective choice.

**Elastic IP Costs**

AWS charges for Elastic IPs when they're allocated but not associated with a running instance. The two EIPs in this project (jump box and NAT instance) are always associated, so they incur no charges. If instances are stopped, the EIPs remain attached to stopped instances, incurring $0.005 per hour ($3.65 per month) per EIP. To avoid these charges, you can release EIPs when stopping instances, though this means the public IPs change on restart. I learned that EIP pricing encourages efficient IP address usage and penalizes hoarding unused addresses. For a homelab that's frequently stopped, releasing EIPs and accepting changing public IPs is a cost-saving measure, though it requires updating SSH configurations after each restart.

**S3 Storage Costs**

S3 Standard storage costs $0.023 per GB per month for the first 50 TB. For a homelab with minimal storage (under 5 GB), this is less than $0.12 per month. Versioning increases storage costs because deleted or modified objects are retained as previous versions, but for low-change-rate homelab data, the impact is minimal. S3 requests cost $0.0004 per 1,000 PUT requests and $0.0004 per 1,000 GET requests. Typical homelab usage generates pennies in request costs. The S3 VPC Gateway Endpoint is free, eliminating data transfer costs that would apply if accessing S3 through a NAT Gateway. I learned that S3 is extremely cost-effective for small-scale storage, and versioning's cost impact is negligible until you have high change rates or large objects.

**Data Transfer Costs**

AWS charges for data transfer out to the internet at $0.09 per GB after the first 100 GB per month free tier. Inbound data transfer is free. For a homelab with modest internet usage (package updates, accessing websites), staying within the 100 GB free tier is realistic. Data transfer between EC2 and S3 in the same region is free, which is why the VPC endpoint provides cost savings—S3 traffic doesn't consume NAT bandwidth or count as internet egress. Cross-AZ data transfer costs $0.01 per GB, which is why this project places all resources in a single AZ. I learned that data transfer is a hidden cost that can surprise new AWS users. Architectural decisions like VPC endpoints, single-AZ deployment for non-HA workloads, and minimizing internet egress significantly reduce costs.

**CloudWatch Logs**

The IAM policies grant CloudWatch Logs permissions, but the project doesn't configure actual log shipping, so CloudWatch costs are zero. If log shipping were enabled, CloudWatch Logs costs $0.50 per GB ingested and $0.50 per GB per month storage. Logs Insights queries cost $0.005 per GB scanned. For a homelab with minimal activity, logs would likely stay within the Free Tier's 5 GB ingestion and 5 GB storage per month. I learned that monitoring and logging costs scale with infrastructure activity and retention policies. Production environments should use log filtering and short retention periods for verbose logs while retaining security and audit logs longer.

**Total Cost Estimate**

Within AWS Free Tier, the homelab costs approximately $0-5 per month (mainly minimal S3 and potential data transfer). After Free Tier expires, the cost is approximately $25-30 per month for 24/7 operation, or $5-10 per month if instances are stopped when not in use. This compares to $60-80 per month for an equivalent setup using NAT Gateway, demonstrating the cost impact of managed services versus self-managed alternatives. I learned that AWS Free Tier is genuinely valuable for learning projects, providing a year of experimentation with minimal costs. After Free Tier, disciplined resource management—stopping instances, releasing unused resources, and using Terraform destroy to tear down the environment—keeps costs manageable.

**Cost Management Best Practices**

I implemented several cost management practices in this project. Terraform's declarative model makes it trivial to destroy and recreate infrastructure, enabling the pattern of "spin up for use, tear down when done." I used AWS Cost Explorer to monitor actual spending and set billing alarms to alert if costs exceed thresholds. I tagged all resources with the project name for cost allocation reporting. I avoided expensive managed services like NAT Gateway where self-managed alternatives suffice for non-production use. I learned that cost management is an ongoing discipline, not a one-time decision. Regular review of Cost Explorer, cleaning up forgotten resources, and right-sizing instances prevents bill shock. Infrastructure as Code makes cost management easier because you can confidently destroy infrastructure knowing you can recreate it identically anytime.

## Key Takeaways

**Infrastructure as Code Fundamentals**

Terraform taught me that infrastructure should be treated like software: versioned, reviewed, tested, and reproducibly deployed. The declarative approach means I describe the desired end state and Terraform determines the steps to achieve it, handling dependency ordering and parallel resource creation. This is fundamentally different from imperative scripts that specify step-by-step procedures. Declarative IaC is resilient to interruptions, idempotent (running apply multiple times produces the same result), and self-documenting because the code describes the actual infrastructure. I learned that once you adopt IaC, returning to manual resource creation feels inefficient and error-prone. The ability to destroy and recreate entire environments in minutes changes how you think about infrastructure—it becomes ephemeral and disposable rather than precious and fragile.

**Modular Code Organization**

Breaking Terraform configuration into logical files improved maintainability dramatically compared to monolithic configurations. Networking changes don't affect security or compute files, reducing the risk of unintended changes. Code reviews become focused on specific domains. New team members can understand the architecture by reading relevant files without parsing thousands of lines. I learned that good code organization is just as important in infrastructure as in application development. The extra effort of creating and maintaining multiple files pays dividends in long-term maintainability, especially as projects grow beyond simple prototypes.

**Three-Tier Security Model**

Implementing security at multiple layers (security groups, NACLs, IAM) taught me that single points of failure extend beyond infrastructure availability to security controls. If a security group is misconfigured, NACLs provide backup protection. If an instance is compromised, IAM limits damage to that instance's specific permissions. This redundancy mirrors production security practices where defense in depth is standard. I learned that security isn't about perfect controls but about making successful attacks require multiple failures or breaches, increasing difficulty and detection likelihood.

**Cost Optimization Through Architecture**

The decision to use NAT instances instead of NAT Gateway demonstrates that cost optimization requires architectural choices, not just turning off idle resources. Choosing t3.micro over larger instance types, using gateway endpoints for S3, deploying in a single AZ, and implementing automated teardown all reduce costs. I learned that "best practice" recommendations often assume production requirements like high availability and managed services. For development and learning environments, self-managed alternatives and simplified architectures provide equivalent functionality at significantly lower cost. Understanding the tradeoffs enables informed decisions rather than blindly following recommendations.

**Bastion Host Pattern**

The jump box implements a security pattern used in real enterprise environments. Centralizing access through a single, hardened entry point simplifies security monitoring, access control, and audit logging. While it adds operational complexity (must proxy through the bastion), the security benefits justify this overhead. I learned that security patterns often prioritize protection over convenience, and good tooling (like SSH ProxyJump configuration) can minimize the operational burden. The bastion pattern is particularly valuable in cloud environments where network boundaries are less distinct than traditional data centers.

**IAM Role-Based Access Control**

Using IAM roles instead of access keys for EC2 instance permissions taught me about temporary credentials and automatic credential rotation. Roles eliminate the need to store long-term credentials on instances, reducing the risk of credential exposure. Instance profiles bind roles to instances, and the EC2 service automatically refreshes temporary credentials. This is more secure than embedding access keys in application configuration or environment variables. I learned that AWS services are designed to integrate with IAM roles, and using them is always preferable to managing access keys manually.

**VPC Endpoints for Service Access**

S3 VPC Gateway Endpoints provide private connectivity to AWS services without internet routing. This improves security by keeping traffic within the AWS network and reduces costs by avoiding NAT bandwidth charges. Gateway endpoints work by modifying route tables to direct service traffic to the endpoint prefix lists. I learned that VPC endpoints are a best practice for production VPCs with private subnets, improving both security and cost profiles. The fact that gateway endpoints are free makes them an obvious choice for S3 and DynamoDB access.

**Terraform State Management**

State files are critical infrastructure artifacts that map configuration to real resources. Losing state means Terraform can't manage resources or detect drift. State files contain sensitive data, requiring protection through encryption and access controls. I learned that local state is acceptable for solo learning but production environments require remote state in S3 with locking via DynamoDB. State management is often overlooked in Terraform tutorials but is essential for production use. Understanding state taught me that IaC isn't just about writing configuration—it's about maintaining the mapping between code and reality over the infrastructure lifecycle.

**Automation for Operational Excellence**

Automating SSH key generation, config file creation, and connection commands taught me that infrastructure automation should extend beyond resource creation to operational workflows. Users shouldn't need to manually construct ProxyJump commands or manage key files. Good infrastructure code includes convenience outputs and automation that make the system immediately usable. I learned that operational excellence includes reducing cognitive load on operators through automation, clear documentation, and self-service tooling. The difference between functional infrastructure and operationally excellent infrastructure is the attention to user experience.

**Network Segmentation Benefits**

Separating public and private subnets enforces the principle of least privilege at the network level. Resources that don't need direct internet access shouldn't have it, reducing attack surface and potential for misconfiguration. Private subnet instances can still access the internet through NAT for updates and external API calls, but inbound access is strictly controlled. I learned that network segmentation is a fundamental security control that limits blast radius and enforces architectural boundaries. The discipline of asking "does this resource need public access?" leads to more secure designs.

## Future Enhancements

**CloudWatch Monitoring and Alarms**

The infrastructure currently grants CloudWatch Logs permissions but doesn't actively ship logs or configure metrics. I plan to implement comprehensive CloudWatch monitoring including shipping system logs and application logs to CloudWatch Logs for centralized analysis, creating CloudWatch alarms for CPU utilization, disk space, and network anomalies, setting up SNS notifications for alarm states, and potentially integrating with CloudWatch Dashboards for visualization. This would teach me about operational observability and proactive monitoring rather than reactive troubleshooting.

**VPC Flow Logs Integration**

Building on my previous VPC Flow Logs project, I plan to enable Flow Logs on this VPC to monitor network traffic patterns and detect security anomalies. This would include capturing all traffic (accepted and rejected), analyzing rejected traffic to identify attack patterns or misconfigurations, and using CloudWatch Logs Insights to query traffic patterns. Flow Logs would provide network visibility essential for security monitoring and troubleshooting connectivity issues. This integration would demonstrate how security projects build on each other to create comprehensive monitoring.

**Automated Backup Strategy**

The S3 bucket has versioning but no formal backup strategy. I plan to implement automated backups including S3 lifecycle policies to transition old versions to cheaper storage classes, cross-region replication for disaster recovery, and potentially AMI backups of EC2 instances with automated lifecycle management. This would teach me about business continuity and disaster recovery planning in cloud environments, where data durability and recovery time objectives drive architectural decisions.

**CI/CD Pipeline for Terraform**

Currently, I run Terraform commands locally, but production environments use automated pipelines. I plan to create a GitHub Actions or GitLab CI pipeline that validates Terraform syntax, runs terraform plan on pull requests, automatically applies infrastructure changes after merge, and implements environment separation (dev/staging/prod). This would teach me about GitOps workflows where infrastructure changes go through code review and automated testing before deployment, improving reliability and auditability.

**Enhanced Security Hardening**

While the current implementation follows basic security best practices, several enhancements would improve security posture including implementing AWS Systems Manager Session Manager to eliminate SSH access entirely, adding fail2ban or GuardDuty for intrusion detection, enabling AWS Config for compliance monitoring and resource tracking, implementing AWS Secrets Manager for credential management, and adding CloudTrail for comprehensive API audit logging. These enhancements would demonstrate production-level security controls and compliance readiness.

**High Availability Architecture**

The current setup uses a single AZ and single NAT instance, creating single points of failure. For production-like learning, I plan to expand to a multi-AZ architecture with public and private subnets in two AZs, multiple NAT instances with health checks and failover, and load balancing across instances. This would significantly increase complexity and cost but would teach me about high availability design patterns and AWS fault tolerance capabilities. It would also introduce challenges like cross-AZ data transfer costs and state synchronization.

**Cost Monitoring and Optimization**

While I've implemented basic cost management, I plan to add automated cost controls including AWS Budgets for spending thresholds and automated alerts, tagging strategies for fine-grained cost allocation, automated instance scheduling to stop resources during off-hours, and Cost Explorer API integration for programmatic cost analysis. This would teach me about FinOps practices and the tools AWS provides for cost governance.

## Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) - Comprehensive reference for all AWS resources in Terraform