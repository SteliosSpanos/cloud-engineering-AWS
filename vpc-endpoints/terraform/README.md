# VPC Endpoints — Terraform Configuration

This directory contains the Terraform configuration that provisions the full infrastructure for the VPC Endpoints project. It builds a VPC with a public subnet and an EC2 instance, an S3 bucket with versioning and encryption, a **VPC Gateway Endpoint** that routes S3 traffic through the AWS private network, and a **bucket policy** that enforces VPC endpoint-only access.

---

## Directory Structure

```
terraform/
├── providers.tf                # Terraform and provider configuration (aws, tls, local, external)
├── variables.tf                # Input variables
├── data.tf                     # Data sources (AZs, AMI, external IP, caller identity)
├── network.tf                  # VPC, subnet, IGW, route tables
├── security.tf                 # Security groups and NACLs
├── compute.tf                  # EC2 instances and key pairs
├── s3.tf                       # S3 bucket, VPC endpoint, and bucket policy
├── outputs.tf                  # Output values
├── terraform.tfvars.example    # Example variable values
└── scripts/
    └── my_ip_json.sh           # Script to retrieve current public IP
```

---

## What This Configuration Provisions

| Resource | Details |
|---|---|
| VPC | Custom CIDR, DNS hostnames and DNS support enabled |
| Public Subnet | Single AZ, auto-assigns public IPs on launch |
| Internet Gateway | Attached to VPC for internet connectivity |
| Route Table | Default route (`0.0.0.0/0`) to IGW; VPC endpoint adds its own prefix-list route automatically |
| Security Group | SSH and ICMP restricted to your IP only; HTTP/HTTPS open to all |
| Network ACL | Stateless rules covering SSH, HTTP, HTTPS, ICMP, and ephemeral ports |
| EC2 Instance | Amazon Linux 2023, `t3.micro`, placed in the public subnet |
| Key Pair | Auto-generated 4096-bit RSA key; private key saved locally |
| Elastic IP | Stable public address attached to the EC2 instance |
| S3 Bucket | Versioning enabled, AES256 encryption, all public access blocked |
| VPC Gateway Endpoint | Free; routes S3 traffic through the AWS private network |
| Bucket Policy | Denies all S3 operations not originating from the VPC endpoint |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- AWS CLI configured with a named profile
- `bash` and `curl` available locally (required by `scripts/my_ip_json.sh`)

---

## Quick Start

### 1. Copy and populate the variables file

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set at minimum:

```hcl
profile = "your-aws-profile"
region  = "eu-west-3"
```

### 2. Initialise Terraform

```bash
terraform init
```

### 3. Review the execution plan

```bash
terraform plan
```

### 4. Apply

```bash
terraform apply
```

Terraform will display all outputs (VPC ID, bucket name, SSH command, etc.) after a successful apply.

### 5. Connect to the instance

```bash
# Using the output directly
$(terraform output -raw ssh_command)

# Or manually
ssh -i $(terraform output -raw ssh_key_path) ec2-user@$(terraform output -raw instance_public_ip)
```

### 6. Tear down

```bash
terraform destroy
```

---

## Variables

### Required (no defaults — must be set in `terraform.tfvars`)

| Variable | Description |
|---|---|
| `profile` | AWS CLI named profile to use for authentication |
| `region` | AWS region in which to deploy all resources |

### Optional (defaults provided)

| Variable | Default | Description |
|---|---|---|
| `project_name` | `"s3-gateway"` | Prefix used for naming all resources |
| `vpc_cidr` | `"10.0.0.0/16"` | CIDR block assigned to the VPC |
| `public_subnet_cidr` | `"10.0.1.0/24"` | CIDR block assigned to the public subnet |
| `instance_type` | `"t3.micro"` | EC2 instance type |

---

## Outputs

| Output | Description |
|---|---|
| `vpc_id` | ID of the created VPC |
| `public_subnet_id` | ID of the public subnet |
| `instance_public_ip` | Elastic IP address of the EC2 instance |
| `s3_bucket_name` | Name of the created S3 bucket |
| `ssh_key_path` | Local path to the generated private key file |
| `ssh_command` | Complete SSH command to connect to the instance |

---

## Resource Details

### Network (`network.tf`)

A single public subnet is created inside the VPC, associated with a route table that sends all traffic (`0.0.0.0/0`) to the Internet Gateway. When the VPC Gateway Endpoint for S3 is created, AWS automatically inserts a managed prefix-list route into this same route table, directing S3-bound traffic through the endpoint rather than the IGW.

### Security (`security.tf`)

**Security Group** — stateful, applied at the instance level:

| Direction | Port / Protocol | Source |
|---|---|---|
| Inbound | 22 (SSH) | Your IP only |
| Inbound | 80 (HTTP) | `0.0.0.0/0` |
| Inbound | 443 (HTTPS) | `0.0.0.0/0` |
| Inbound | ICMP | Your IP only |
| Outbound | All | `0.0.0.0/0` |

**Network ACL** — stateless, applied at the subnet level. Mirrors the security group rules and additionally allows inbound and outbound ephemeral ports (1024–65535) to support return traffic for outbound connections.

### Compute (`compute.tf`)

A 4096-bit RSA key pair is generated by Terraform at apply time. The public key is registered with AWS; the private key is written to `.ssh/<project_name>-key.pem` with `0400` permissions. An Elastic IP is allocated and associated with the instance, providing a stable address that survives instance stops.

### S3 Resources (`s3.tf`)

The S3 bucket is named `<project_name>-storage-<account_id>` and is configured with three layers of protection:

**Versioning**
All object versions are retained, enabling recovery from accidental deletion or overwrite.

**Server-Side Encryption**
AES256 (SSE-S3) is applied by default to every object written to the bucket.

**Public Access Block**
All four public-access block settings are enabled:
- `block_public_acls`
- `block_public_policy`
- `ignore_public_acls`
- `restrict_public_buckets`

This prevents any ACL or policy from inadvertently exposing bucket contents to the public internet.

**VPC Gateway Endpoint**
```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.test-vpc.id
  service_name    = "com.amazonaws.${var.region}.s3"
  route_table_ids = [aws_route_table.test-route-table.id]
}
```
The Gateway Endpoint is free of charge and requires no changes to application code. AWS updates the specified route table automatically with a managed prefix-list entry that captures all S3 IP ranges for the region.

**Bucket Policy (Data Perimeter)**
```hcl
{
  Sid       = "DenyIfNotFromVPCEndpoint"
  Effect    = "Deny"
  Principal = "*"
  Action    = "s3:*"
  Resource  = [bucket_arn, "${bucket_arn}/*"]
  Condition = {
    StringNotEqualsIfExists = {
      "aws:sourceVpce" = <endpoint_id>
    }
    ArnNotLike = {
      "aws:PrincipalArn" = <caller_identity_arn>
    }
  }
}
```
Any S3 request that does not originate from the VPC endpoint is denied — unless the caller's ARN matches the account's own principal ARN. The `ArnNotLike` exception allows Terraform itself (running locally under the same IAM identity) to manage the bucket without needing to route through the endpoint.

---

## Security Features

- **Least-privilege network access**: SSH and ICMP are restricted to your detected public IP, resolved at plan time by `scripts/my_ip_json.sh`.
- **Stateless NACL hardening**: NACLs provide a subnet-level backstop, explicitly allowing only the required inbound and outbound traffic categories.
- **Private network routing for S3**: The VPC Gateway Endpoint ensures that S3 traffic from the EC2 instance never leaves the AWS network and never traverses the public internet.
- **Data perimeter via bucket policy**: The `aws:sourceVpce` condition key enforces that the bucket can only be accessed through the designated VPC endpoint, preventing exfiltration through compromised credentials used from outside the VPC.
- **Public access block**: All four settings eliminate the risk of misconfigured ACLs or policies accidentally making bucket contents public.
- **Auto-generated SSH keys**: Terraform generates keys at apply time; no pre-existing key material needs to be managed or stored outside the working directory.

---

## Cost Considerations

All resources are in the AWS Free Tier where eligible (t3.micro under EC2 free tier, S3 storage within free tier limits). Charges that apply outside the free tier:

| Resource | Cost |
|---|---|
| EC2 t3.micro | ~$0.0116/hour (on-demand, eu-west-3) |
| Elastic IP | Free while attached to a running instance; ~$0.005/hour when unattached |
| S3 storage | $0.024/GB/month (eu-west-3), plus request fees |
| VPC Gateway Endpoint | **Free** — no hourly charge, no data processing fee |
| Data transfer | Standard EC2 data transfer rates apply for internet-bound traffic |

> **VPC Gateway vs. Interface Endpoints**: Gateway Endpoints (available only for S3 and DynamoDB) are free. Interface Endpoints use an ENI and cost approximately $0.01/hour per Availability Zone plus data processing fees. Using a Gateway Endpoint here provides private S3 routing at zero additional cost.

Run `terraform destroy` immediately after testing to avoid ongoing EC2 and Elastic IP charges.

---

## Important Notes

- **`terraform.tfvars` is gitignored.** Use `terraform.tfvars.example` as a reference and never commit your actual profile name or region if they are sensitive.
- **The generated private key** is written to `.ssh/` inside the Terraform directory and is also gitignored. Do not commit it.
- **Bucket policy and local access**: After `terraform apply`, any S3 request to this bucket from outside the VPC (including your local AWS CLI) will be denied — unless you are authenticated as the exact IAM principal that ran Terraform. The `ArnNotLike` condition in the bucket policy preserves management access for that principal only.
- **Route table modification**: The VPC Gateway Endpoint modifies the associated route table by inserting a prefix-list route. This is managed by AWS and will be removed automatically when the endpoint is destroyed.
- **Single-AZ design**: This configuration uses one subnet in one Availability Zone. It is suitable for development and testing, not for production workloads that require high availability.
- **IP detection**: `scripts/my_ip_json.sh` calls an external service to resolve your current public IP. If your IP changes between plan and apply, re-run `terraform plan` to refresh the detected value before applying.

---

## Troubleshooting

### SSH Connection Issues
- Confirm the private key path: `terraform output ssh_key_path`
- Ensure the key file has correct permissions: `chmod 400 <key_path>`
- Check security group rules: `terraform state show aws_security_group.test-public-sg`
- Verify your current IP matches the allowed CIDR: `curl ifconfig.me`

### S3 Access Denied from Local Machine
- This is expected behaviour. The bucket policy denies requests not coming through the VPC endpoint.
- Access from outside the VPC is only permitted for the IAM principal that ran `terraform apply` (the `ArnNotLike` exception).
- To access the bucket from the EC2 instance: SSH in, configure AWS CLI credentials, then use `aws s3 ls` or `aws s3 cp`.

### Terraform Init Fails
- Check AWS credentials: `aws sts get-caller-identity --profile your-profile`
- Verify internet connectivity for provider downloads.

### Instance Launch Fails
- Check AWS service limits for EC2 in your region.
- Verify AMI availability: the configuration uses the latest Amazon Linux 2023 x86_64 HVM AMI.
