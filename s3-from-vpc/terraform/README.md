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
- **EC2 instance** (Ubuntu 24.04 LTS) with SSH access

## Project Structure

```
terraform/
├── versions.tf                 # Terraform and provider configuration
├── variables.tf                # Input variables
├── data.tf                     # Data sources (AZs, AMI, external IP)
├── network.tf                  # VPC, subnets, IGW, route tables
├── security.tf                 # Security groups and NACLs
├── compute.tf                  # EC2 instances and key pairs
├── outputs.tf                  # Output values
├── terraform.tfvars.example    # Example variable values
├── templates/                  # Template files
│   ├── userdata.tpl           # EC2 user data script
│   ├── linux-ssh-config.tpl   # Linux SSH config template
│   └── windows-ssh-config.tpl # Windows SSH config template
└── scripts/                    # Helper scripts
    └── my_ip_json.sh          # Script to get current public IP
```

## Prerequisites

1. **AWS CLI** configured with credentials
   ```bash
   aws configure --profile test-dev
   ```

2. **Terraform** installed (version >= 1.0)
   ```bash
   terraform version
   ```

3. **SSH key pair** generated
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/dev-key
   ```

4. **Operating System**: Linux or Windows with PowerShell

## Configuration

1. **Create your variables file**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars** if needed:
   ```hcl
   host_os = "linux"  # or "windows"
   ```

3. **Update versions.tf** with your AWS profile and region if different:
   ```hcl
   provider "aws" {
     profile = "test-dev"      # Your AWS CLI profile
     region  = "eu-west-3"     # Your preferred region
   }
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
terraform output dev_ip
```

### SSH into Instance
After apply, SSH is automatically configured. Connect with:
```bash
ssh ubuntu@<dev_ip>
```

Or if SSH config was generated:
```bash
ssh dev-node
```

### Destroy Infrastructure
```bash
terraform destroy
```

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

## Cost Considerations

- **VPC**: Free
- **Subnet**: Free
- **Internet Gateway**: Free
- **Route Table**: Free
- **Security Groups/NACLs**: Free
- **EC2 t3.micro**: ~$0.0104/hour (Free tier eligible: 750 hours/month for 12 months)
- **EBS Volume (10 GB gp2)**: ~$1.00/month (Free tier eligible: 30 GB/month for 12 months)

**Estimated monthly cost**: ~$0-8 (depending on free tier eligibility)

## Important Notes

1. **SSH Key**: Ensure `~/.ssh/dev-key.pub` exists before running `terraform apply`
2. **IP Changes**: If your public IP changes, run `terraform apply` again to update security rules
3. **State Files**: Never commit `terraform.tfstate` or `terraform.tfvars` to version control
4. **Region**: Default region is `eu-west-3` (Paris). Change in `versions.tf` if needed
5. **Cleanup**: Always run `terraform destroy` when done to avoid unnecessary charges

## Troubleshooting

### SSH Connection Issues
- Verify your public key exists: `ls -la ~/.ssh/dev-key.pub`
- Check security group rules: `terraform state show aws_security_group.test-public-sg`
- Verify your current IP matches the allowed CIDR: `curl ifconfig.me`

### Terraform Init Fails
- Check AWS credentials: `aws sts get-caller-identity --profile test-dev`
- Verify internet connectivity for provider downloads

### Instance Launch Fails
- Check AWS service limits: `aws service-quotas list-service-quotas --service-code ec2`
- Verify AMI availability in your region
- Ensure sufficient privileges on your AWS account

## Customization

### Change Instance Type
Edit `compute.tf`:
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
  values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-jammy-22.04-amd64-server-*"]
}
```

## License

This configuration is part of a learning portfolio project. Feel free to use and modify as needed.
