# EKS Kubernetes Project

## Architecture

```
Your Machine (SSH)
      │
      ▼
EC2 Bastion (public subnet, kubectl + eksctl installed)
      │  IAM Access Entry
      ▼
EKS Cluster (control plane)
      │
      ├── Public Subnets  (AZ-1, AZ-2) — bastion + NAT gateways
      └── Private Subnets (AZ-1, AZ-2) — worker nodes (no public IPs)
                │
                └── NAT Gateway → internet (ECR, AWS APIs)
```

## Files

| File | Purpose |
|------|---------|
| `providers.tf` | AWS provider + Terraform version |
| `variables.tf` | All input variables |
| `data.tf` | AMI lookup, IAM assume role documents |
| `network.tf` | VPC, public/private subnets, IGW, NAT, route tables |
| `compute.tf` | Bastion EC2, IAM role, security group, key pair |
| `eks.tf` | EKS cluster, node group, IAM roles, access entry |
| `outputs.tf` | Cluster name, endpoint, bastion IP, kubeconfig command |

## Steps

1. **Generate SSH key pair locally**
   ```bash
   ssh-keygen -t rsa -b 4096 -f terraform/.ssh/bastion
   ```

2. **Deploy infrastructure**
   ```bash
   terraform init
   terraform plan -var="profile=<profile>" -var="region=<region>" -var="allowed_ssh_cidr=<your-ip>/32"
   terraform apply
   ```

3. **SSH into bastion**
   ```bash
   ssh -i terraform/.ssh/bastion ec2-user@<bastion_public_ip>
   ```

4. **Configure kubectl on the bastion**
   ```bash
   aws eks update-kubeconfig --name eks-cluster --region <region>
   ```

5. **Verify cluster access**
   ```bash
   kubectl get nodes
   ```

6. **Test resilience (Secret Mission)**
   ```bash
   # Drain a node and watch pods reschedule
   kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
   kubectl get pods -w

   # Restore the node
   kubectl uncordon <node-name>
   ```

## Security Decisions

- Bastion IAM role has only `eks:DescribeCluster` — nothing else
- Worker nodes in private subnets — no public IPs
- EKS API endpoint restricted to your IP only
- All 5 cluster log types enabled (audit, api, authenticator, etc.)
- SSH egress locked to HTTPS (443) only
- Binary installs pinned to specific versions with SHA-256 checksum verification
