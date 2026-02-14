# Terraform Infrastructure for S3 Access from VPC

This Terraform configuration creates a complete AWS VPC environment with an EC2 instance configured for secure S3 access.

## Architecture Overview

This infrastructure provisions:
- **VPC** with DNS support and hostnames enabled
- **Public subnet** with automatic public IP assignment
- **Internet Gateway** for internet connectivity
- **Route table** with default route to IGW
- **Security Group** with restricted SSH/ICMP access
- **Network ACL** for additional subnet-level security
- **EC2 instance** (Amazon Linux 2023) with SSH access
- **S3 bucket** with versioning and AES256 server-side encryption

## Project Structure

```
terraform/
├── providers.tf                # Terraform and provider configuration
├── variables.tf                # Input variables
├── data.tf                     # Data sources (AZs, AMI, external IP)
├── network.tf                  # VPC, subnets, IGW, route tables
├── security.tf                 # Security groups and NACLs
├── compute.tf                  # EC2 instances and key pairs
├── s3.tf                       # S3 bucket, versioning, and encryption
├── outputs.tf                  # Output values
├── terraform.tfvars.example    # Example variable values
└── scripts/                    # Helper scripts
    └── my_ip_json.sh           # Script to get current public IP
```

## Prerequisites

1. **AWS CLI** configured with credentials
   ```bash
   aws configure --profile your-profile
   ```

2. **Terraform** installed (version >= 1.0)
   ```bash
   terraform version
   ```

## Configuration

1. **Create your variables file**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** and set the two required values:
   ```hcl
   profile = "your-profile"  # Your AWS CLI profile name
   region  = "eu-west-3"     # Your preferred AWS region
   ```

   Optional variables (defaults shown) that can be added to `terraform.tfvars`:
   ```hcl
   project_name       = "s3-gateway"    # Used for resource naming
   vpc_cidr           = "10.0.0.0/16"
   public_subnet_cidr = "10.0.1.0/24"
   instance_type      = "t3.micro"
   ```

## Usage

### Initialize Terraform
```bash
terraform init
```

### Preview Changes
```bash
terraform plan
```

### Apply Configuration
```bash
terraform apply
```

### Get Outputs
```bash
terraform output instance_public_ip
terraform output ssh_key_path
terraform output s3_bucket_name
```

### SSH into Instance

Terraform generates the SSH key pair automatically. After `apply` completes, retrieve the private key path from the output and connect:

```bash
ssh -i $(terraform output -raw ssh_key_path) ec2-user@$(terraform output -raw instance_public_ip)
```

### Destroy Infrastructure
```bash
terraform destroy
```

## Outputs

| Output | Description |
|---|---|
| `vpc_id` | ID of the created VPC |
| `public_subnet_id` | ID of the public subnet |
| `instance_public_ip` | Elastic IP address of the EC2 instance |
| `s3_bucket_name` | Name of the created S3 bucket |
| `ssh_key_path` | Local path to the generated private key file |

## S3 Resources

The S3 bucket is named `<project_name>-storage-<account_id>` and is configured with:
- **Versioning**: Enabled to protect against accidental deletion or overwrites
- **Encryption**: AES256 server-side encryption applied to all objects at rest

## Security Features

### Security Group (Stateful)
- **SSH (22)**: Restricted to your current public IP
- **HTTP (80)**: Open to all (for web services)
- **HTTPS (443)**: Open to all (for web services)
- **ICMP**: Restricted to your current public IP
- **Egress**: All traffic allowed

### Network ACL (Stateless)
- **SSH (22)**: Restricted to your current IP
- **HTTP (80)**: Open to all
- **HTTPS (443)**: Open to all
- **Ephemeral Ports (1024-65535)**: Required for return traffic
- **ICMP**: Open to all
- **Egress**: All traffic allowed

### Dynamic IP Detection
The configuration automatically detects your current public IP using the `scripts/my_ip_json.sh` script and restricts SSH/ICMP access accordingly.

### SSH Key Management
Terraform generates the RSA key pair via the `tls_private_key` resource. The private key is saved to `terraform/.ssh/<project_name>-key.pem` automatically — no manual key generation is required.

## Cost Considerations

- **VPC**: Free
- **Subnet**: Free
- **Internet Gateway**: Free
- **Route Table**: Free
- **Security Groups/NACLs**: Free
- **EC2 t3.micro**: ~$0.0104/hour (Free tier eligible: 750 hours/month for 12 months)
- **EBS Volume (10 GB gp2)**: ~$1.00/month (Free tier eligible: 30 GB/month for 12 months)
- **S3 bucket**: Free tier includes 5 GB storage, 20,000 GET requests, and 2,000 PUT requests per month for 12 months

**Estimated monthly cost**: ~$0-8 (depending on free tier eligibility)

## Important Notes

1. **SSH Key**: Terraform generates the key pair automatically. Do not generate or provide your own key.
2. **IP Changes**: If your public IP changes, run `terraform apply` again to update security rules.
3. **State Files**: Never commit `terraform.tfstate` or `terraform.tfvars` to version control.
4. **Region**: Default region is `eu-west-3` (Paris). Change via `terraform.tfvars` if needed.
5. **Cleanup**: Always run `terraform destroy` when done to avoid unnecessary charges.

## Troubleshooting

### SSH Connection Issues
- Confirm the private key path: `terraform output ssh_key_path`
- Ensure the key file has correct permissions: `chmod 400 <key_path>`
- Check security group rules: `terraform state show aws_security_group.test-public-sg`
- Verify your current IP matches the allowed CIDR: `curl ifconfig.me`

### Terraform Init Fails
- Check AWS credentials: `aws sts get-caller-identity --profile your-profile`
- Verify internet connectivity for provider downloads

### Instance Launch Fails
- Check AWS service limits: `aws service-quotas list-service-quotas --service-code ec2`
- Verify AMI availability in your region
- Ensure sufficient privileges on your AWS account

## Customization

### Change Instance Type
Edit `variables.tf` or add to `terraform.tfvars`:
```hcl
instance_type = "t3.small"  # or t3.medium, etc.
```

### Add Additional Ports
Edit `security.tf` and add new ingress rules:
```hcl
ingress {
  description = "Custom port"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

### Use Different AMI
Edit `data.tf` to change the filter:
```hcl
filter {
  name   = "name"
  values = ["al2023-ami-*-x86_64"]
}
```

## License

This configuration is part of a learning portfolio project. Feel free to use and modify as needed.
