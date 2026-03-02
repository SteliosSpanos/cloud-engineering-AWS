# AWS Homelab Infrastructure with Terraform

## Overview

Secure, cost-optimized AWS environment built with Terraform. The architecture uses a bastion host for SSH access, a NAT instance instead of NAT Gateway for cost savings, defense-in-depth security, private S3 access via VPC endpoint, a web-facing application tier backed by a managed PostgreSQL database, and centralized log collection via CloudWatch Logs.

**Stack:** Terraform · VPC (1 public + 2 private subnets) · 4 EC2 instances (Amazon Linux 2023) · RDS PostgreSQL 15 · Security Groups + NACLs · IAM least-privilege roles · S3 with encryption and versioning · VPC Gateway Endpoint · CloudWatch Logs · SSH ProxyJump automation

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                      INTERNET                                        │
└────────────────────────────────────────┬─────────────────────────────────────────────┘
                                         │
                      SSH (Port 22), only from my IP
                      HTTP/HTTPS (80/443), web app only
                                         │
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                               VPC (10.0.0.0/16)                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         PUBLIC SUBNET (10.0.1.0/24)                            │  │
│  │                                                                                │  │
│  │  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────────────┐    │  │
│  │  │    JUMP BOX      │   │   NAT INSTANCE   │   │        WEB APP           │    │  │
│  │  │   (t3.micro)     │   │   (t3.micro)     │   │       (t3.micro)         │    │  │
│  │  │                  │   │                  │   │                          │    │  │
│  │  │ ┌──────────────┐ │   │ ┌──────────────┐ │   │ ┌──────────────────────┐ │    │  │
│  │  │ │Security Group│ │   │ │Security Group│ │   │ │    Security Group    │ │    │  │
│  │  │ │- SSH from IP │ │   │ │- HTTP/S from │ │   │ │ - SSH from jump box  │ │    │  │
│  │  │ └──────────────┘ │   │ │  private sub │ │   │ │ - HTTP/HTTPS 0.0.0.0 │ │    │  │
│  │  │                  │   │ │- SSH from JB │ │   │ │ - ICMP from jump box │ │    │  │
│  │  │ Elastic IP ──────┼──►│ └──────────────┘ │   │ └──────────────────────┘ │    │  │
│  │  │                  │   │                  │   │                          │    │  │
│  │  │ IAM Role:        │   │ Elastic IP ──────┼──►│ Elastic IP ─────────────┼──►  │  │
│  │  │ - CloudWatch     │   │                  │   │                          │    │  │
│  │  │ - SSM Access     │   │ IAM Role:        │   │ IAM Role:                │    │  │
│  │  └──────────────────┘   │ - CloudWatch     │   │ - CloudWatch             │    │  │
│  │           │             │ - SSM Access     │   │ - SSM Access             │    │  │
│  │           │ SSH         │                  │   └────────────┬─────────────┘    │  │
│  │           │ ProxyJump   │ IP Forwarding +  │                │                  │  │
│  │           │             │ iptables         │                │ Port 5432        │  │
│  │           │             │ MASQUERADE       │                │                  │  │
│  │           │             └────────┬─────────┘                │                  │  │
│  │           │                      │                          │                  │  │
│  └───────────┼──────────────────────┼──────────────────────────┼───────────────── ┘  │
│              │                      │ Outbound via NAT         │                     │
│              │       ┌──────────────┘                          │                     │
│              │       ▼                                         ▼                     │
│  ┌───────────┼───────────────────────────────────────────────────────────────┐       │
│  │           │       PRIVATE SUBNET 1 (10.0.2.0/24) - AZ 1                   |       │
│  │           │                                                               |       │
│  │           ▼                                ┌─────────────────────┐        |       │
│  │  ┌──────────────────────┐                  │    S3 BUCKET        │        |       │
│  │  │       MAIN VM        │  VPC Endpoint    │                     │        |       │
│  │  │      (t3.micro)      │◄────────────────►│  - Versioning       │        |       │
│  │  │                      │   (Gateway)      │  - AES256 Encrypted │        |       │
│  │  │ ┌──────────────────┐ │                  │  - Public Access    │        |       │
│  │  │ │  Security Group  │ │                  │    Blocked          │        |       │
│  │  │ │ - SSH from JB    │ │                  │  - Bucket Policy:   │        |       │
│  │  │ │ - ICMP from JB   │ │                  │    Main VM Role Only│        |       │
│  │  │ └──────────────────┘ │                  └─────────────────────┘        |       │
│  │  │  NO Public IP        │                                                 |       │
│  │  │  IAM Role:           │                                                 |       │
│  │  │  - CloudWatch        │                                                 |       │
│  │  │  - SSM Access        │                    ┌──────────────────────────────┐     │
│  │  │  - S3 Access         │                    │   RDS POSTGRESQL 15          │     │
│  │  └──────────────────────┘                    │   (db.t3.micro, 20 GB)       │     │
│  │                                              │                              │     │
│  │                                              │  ┌──────────────────────────┐│     │
│  │                                              │  │     Security Group       ││     │
│  └──────────────────────────────────────────────│  │  - Port 5432 from        ││     │
│                                                 │  │    web app SG only       ││     │
│  ┌──────────────────────────────────────────────│  └──────────────────────────┘│     │
│  │  PRIVATE SUBNET 2 (10.0.3.0/24) - AZ 2       │                              │     │
│  │  (RDS DB Subnet Group - no instances)        │  Storage encryption enabled  │     │
│  └──────────────────────────────────────────────│  DB Subnet Group: both AZs   │     │
│                                                 └──────────────────────────────┘     │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐    │
│  │                            SECURITY LAYERS                                   │    │
│  │  Layer 1: Security Groups (Stateful, Instance-level)                         │    │
│  │  Layer 2: Network ACLs (Stateless, Subnet-level)                             │    │
│  │  Layer 3: IAM Roles (API-level access control)                               │    │
│  └──────────────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

**VPC:** 10.0.0.0/16 with three subnets — public (10.0.1.0/24), private AZ1 (10.0.2.0/24), private AZ2 (10.0.3.0/24, RDS only).

**Compute:** Four t3.micro instances. The jump box is the sole SSH entry point via Elastic IP. The NAT instance routes private subnet outbound traffic using iptables masquerade. The main VM has no public IP and is accessed only via ProxyJump through the jump box. The web app serves HTTP/HTTPS publicly and connects to RDS on port 5432.

**Database:** RDS PostgreSQL 15 in a subnet group spanning both AZs. Reachable only from the web app security group on port 5432. Storage encrypted at rest.

**Security:** Three-layer defense — security groups (stateful, instance-level), NACLs (stateless, subnet-level), and IAM roles (per-instance, least-privilege). The main VM is the only instance with S3 access. Each instance has a dedicated CloudWatch IAM policy scoped to its own log group ARN, rather than a shared wildcard policy.

**Storage:** S3 bucket with versioning, AES256 encryption, public access blocked, and a bucket policy whitelisting only the main VM's IAM role. A VPC Gateway Endpoint routes S3 traffic privately, avoiding NAT bandwidth.

## Project Structure

```
homelab/
├── README.md
├── .gitignore
└── terraform/
    ├── providers.tf
    ├── variables.tf
    ├── outputs.tf
    ├── network.tf         (VPC, 3 subnets, IGW, route tables)
    ├── security.tf        (Security Groups incl. PostgreSQL SG)
    ├── nacls.tf           (Public and Private NACLs)
    ├── compute.tf         (EC2: jump box, NAT, main VM, web app)
    ├── database.tf        (RDS PostgreSQL instance + subnet group)
    ├── iam.tf             (IAM roles for all 4 instances)
    ├── s3.tf              (S3 bucket + VPC gateway endpoint)
    ├── cloudwatch.tf      (CloudWatch log groups, one per instance)
    ├── data.tf            (data sources)
    ├── templates/
    │   ├── userdata.tpl           (NAT instance init script + CloudWatch Agent)
    │   ├── userdata-db.tpl        (Web app init script + CloudWatch Agent)
    │   ├── userdata-jump-box.tpl  (Jump box init script + CloudWatch Agent)
    │   └── userdata-main-vm.tpl   (Main VM init script + CloudWatch Agent)
    └── scripts/
        └── my_ip_json.sh
```

## Implementation Notes

### Network Architecture

Three subnets serve distinct roles. The public subnet hosts internet-facing resources. Private subnet 1 (AZ1) hosts the main workload VM. Private subnet 2 (AZ2) exists solely to satisfy the RDS requirement that a DB subnet group spans at least two availability zones.

The public route table points to the Internet Gateway. The private route table points to the NAT instance's network interface. Both private subnets share the private route table.

### NAT Instance

Uses a t3.micro with source/destination checks disabled. A user data script enables IP forwarding, configures iptables MASQUERADE rules, and creates a systemd service to persist rules across reboots. This saves ~$25-30/month vs. NAT Gateway.

### SSH Access

Terraform generates a 4096-bit RSA key pair, writes the private key locally with 0400 permissions, and produces an SSH config with ProxyJump entries for all instances. Access to private instances is transparent:

```bash
ssh -F terraform/.ssh/config main-vm
ssh -F terraform/.ssh/config web-app
```

The jump box is the single SSH entry point even for instances with public IPs.

### Dynamic IP Whitelisting

`scripts/my_ip_json.sh` queries the current public IP at plan time and injects it into security group and NACL rules, avoiding hardcoded IP values.

### RDS and Web App

The web app user data script (`userdata-db.tpl`) installs Apache, PHP, and the `php-pgsql` driver, then writes `dbinfo.inc` with database connection parameters injected by Terraform via `templatefile()`. A sample PHP application creates an EMPLOYEES table, accepts POST submissions, and displays records — validating end-to-end connectivity.

Credentials are injected through user data for simplicity. In production, use AWS Secrets Manager instead.

### CloudWatch Logging

All four instances ship logs to CloudWatch Logs via the CloudWatch Agent, installed through each instance's user data script. Log groups are created and managed by Terraform (`cloudwatch.tf`) with a 30-day retention period, configurable via `var.log_retention_days`. Terraform creates the groups before instance launch, so the `logs:CreateLogGroup` action is not granted to any instance role.

| Instance | Log Group | Logs Collected |
|---|---|---|
| Jump box | `/homelab/jump-box` | `/var/log/secure`, `/var/log/messages` |
| NAT instance | `/homelab/nat-instance` | `/var/log/nat-setup.log`, `/var/log/messages` |
| Main VM | `/homelab/main-vm` | `/var/log/secure`, `/var/log/messages` |
| Web app | `/homelab/web-app` | `/var/log/httpd/access_log`, `/var/log/httpd/error_log`, `/var/log/messages` |

Each instance's IAM policy is scoped to its own log group ARN. An instance cannot write to any other instance's log group.

### Terraform State

State is stored locally in `terraform.tfstate`. It contains sensitive values including the private SSH key and database password. For production, use remote state in S3 with DynamoDB locking.

## Security

| Control | Scope | Details |
|---|---|---|
| Security Groups | Instance-level (stateful) | Jump box: SSH from my IP only. NAT: HTTP/S from private subnet. Main VM: SSH/ICMP from jump box. Web app: HTTP/S public, SSH from jump box. PostgreSQL: port 5432 from web app SG only. |
| NACLs | Subnet-level (stateless) | Public NACL: SSH from my IP, HTTP/S, ephemeral ports, ICMP. Private NACL: SSH from public subnet, ephemeral return traffic. |
| IAM Roles | API-level | Main VM: S3 (specific bucket), CloudWatch (scoped to `/homelab/main-vm`), SSM. Each other instance has a dedicated CloudWatch policy scoped to its own log group only (`logs:CreateLogStream`, `logs:PutLogEvents`, `logs:DescribeLogStreams`). No instance can write to another instance's log group. |
| Bastion Pattern | Access control | Single SSH entry point. All other instances restrict SSH to jump box SG. |
| S3 | Data protection | Versioning, AES256 encryption, all public access blocked, bucket policy whitelists main VM role only. |
| VPC Endpoint | Network | S3 traffic stays within the AWS network; never transits the public internet. |

**Note on SSH key storage:** The private key is in Terraform state. Protect state files accordingly. For production, generate keys outside Terraform or use AWS Secrets Manager.

## Cost

| Resource | Cost (after Free Tier) |
|---|---|
| 4× t3.micro EC2 | ~$30/month |
| RDS db.t3.micro + 20GB storage | ~$18/month |
| 3× Elastic IPs (attached) | $0 while running |
| S3 (minimal data) | <$1/month |
| NAT Instance (vs. NAT Gateway) | Saves ~$25-30/month |
| VPC Gateway Endpoint | Free |
| **Total (24/7)** | **~$50-55/month** |

Within Free Tier: ~$0-5/month. Stopped when idle: ~$10-15/month (EBS + RDS storage).

## Deployment

```bash
# 1. Create terraform.tfvars with DB credentials
# 2. Initialize
terraform -chdir=terraform init

# 3. Preview
terraform -chdir=terraform plan

# 4. Deploy
terraform -chdir=terraform apply

# 5. Connect
ssh -F terraform/.ssh/config jump-box

# 6. Tear down
terraform -chdir=terraform destroy
```

Outputs after apply include all IP addresses, the RDS endpoint, S3 bucket name, and ready-to-use SSH commands.

## Future Enhancements

- **VPC Flow Logs:** Enable traffic capture for security analysis and connectivity troubleshooting
- **CI/CD pipeline:** GitHub Actions for `terraform plan` on PRs and `terraform apply` on merge
- **Secrets Manager:** Replace user data credential injection with runtime secret fetch
- **Systems Manager Session Manager:** Eliminate SSH access entirely
- **Multi-AZ HA:** RDS multi-AZ + ALB + redundant NAT instances for production-grade availability
- **AWS Budgets + instance scheduling:** Automated cost controls and off-hours shutdown
