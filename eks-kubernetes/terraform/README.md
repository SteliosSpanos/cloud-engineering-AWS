# Terraform — EKS Kubernetes Cluster

## Overview

This directory contains the Terraform configuration that provisions the full EKS cluster environment. It creates the VPC and subnets, the bastion EC2 instance, the EKS control plane, the managed worker node group, all IAM roles and policies, the EKS Access Entry that grants the bastion read-only kubectl access, and a private ECR repository for application images.

The configuration is split across logical files(`network.tf`, `compute.tf`, `eks.tf`) so each file corresponds to a distinct infrastructure layer. State is stored locally (no remote backend). The SSH key pair and your current public IP are both sourced outside of Terraform at plan time.

---

## Prerequisites

**SSH Key Pair**

Generate the bastion key pair before running `terraform apply`. The private key must never be committed to version control.

```bash
ssh-keygen -t rsa -b 4096 -f terraform/.ssh/bastion
```

Terraform reads `terraform/.ssh/bastion.pub` and registers the public key as an `aws_key_pair`. The `.ssh/` directory is gitignored.

**AWS CLI Profile**

The configured AWS profile must have permissions to create and manage:

- VPC, subnets, route tables, IGW, NAT Gateway, EIP
- EC2 instances, security groups, IAM roles and policies, key pairs
- EKS clusters, node groups, access entries, and access policy associations
- ECR repositories and lifecycle policies
- CloudWatch log groups (created automatically by EKS for control plane logs)

**Tools**

| Tool             | Purpose                                                      |
| ---------------- | ------------------------------------------------------------ |
| Terraform >= 1.6 | Infrastructure provisioning                                  |
| AWS CLI >= 2.x   | Profile authentication, kubeconfig generation                |
| `curl` / `jq`    | Used by `scripts/my_ip_json.sh` to resolve current public IP |

---

## File Structure

```
terraform/
├── providers.tf          # AWS provider ~> 5.0, required Terraform version >= 1.6
├── variables.tf          # All input variables with types, defaults, and descriptions
├── data.tf               # AMI lookup, AZ enumeration, dynamic IP, IAM assume role docs
├── network.tf            # VPC, public/private subnets (2 AZs), IGW, NAT, route tables
├── compute.tf            # Bastion EC2, IAM role + policy, security group, key pair
├── eks.tf                # EKS cluster, node group, IAM roles, access entry + association
├── ecr.tf                # ECR repository with image scanning and lifecycle policy
├── outputs.tf            # Cluster name, endpoint, bastion IP, kubeconfig command, ECR URL + push commands
├── templates/
│   └── userdata.tpl      # Bastion bootstrap script (kubectl + eksctl, SHA-256 verified)
└── scripts/
    └── my_ip_json.sh     # Resolves current public IP and returns JSON for external data source
```

| File           | Key Resources                                                                                                                                                                 |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `providers.tf` | `terraform` block, `required_providers`, AWS provider configuration                                                                                                           |
| `variables.tf` | Declares all 7 input variables                                                                                                                                                |
| `data.tf`      | `aws_caller_identity`, `aws_availability_zones`, `external` (my IP), `aws_ami`, `aws_iam_policy_document` (EC2 + EKS assume role)                                             |
| `network.tf`   | `aws_vpc`, `aws_subnet` ×4, `aws_internet_gateway`, `aws_eip`, `aws_nat_gateway`, `aws_route_table` ×2, `aws_route_table_association` ×4                                      |
| `compute.tf`   | `aws_key_pair`, `aws_iam_policy`, `aws_iam_role`, `aws_iam_instance_profile`, `aws_security_group`, `aws_instance` (bastion)                                                  |
| `eks.tf`       | `aws_iam_role` ×2 (cluster + node), `aws_iam_role_policy_attachment` ×4, `aws_eks_cluster`, `aws_eks_node_group`, `aws_eks_access_entry`, `aws_eks_access_policy_association` |
| `ecr.tf`       | `aws_ecr_repository` (scan on push, AES256 encryption), `aws_ecr_lifecycle_policy` (retain last 10 images)                                                                    |
| `outputs.tf`   | `cluster_name`, `cluster_endpoint`, `bastion_public_ip`, `kubeconfig_command`, `ecr_repository_url`, `docker_push_commands`                                                   |

---

## Variables

| Name                 | Type     | Default         | Description                                                      |
| -------------------- | -------- | --------------- | ---------------------------------------------------------------- |
| `profile`            | `string` | —               | AWS CLI named profile to use for authentication                  |
| `region`             | `string` | —               | AWS region to deploy into (e.g. `eu-west-3`)                     |
| `project_name`       | `string` | `"eks-cluster"` | Used as the EKS cluster name and as a prefix for named resources |
| `vpc_cidr`           | `string` | `"10.0.0.0/16"` | CIDR block for the VPC                                           |
| `kubernetes_version` | `string` | `"1.31"`        | Kubernetes version for the EKS cluster and node group            |
| `instance_type`      | `string` | `"t3.micro"`    | EC2 instance type for the bastion host                           |
| `node_instance_type` | `string` | `"t3.medium"`   | EC2 instance type for the managed worker node group              |

`profile` and `region` have no defaults and must be supplied at plan/apply time either via `-var` flags or a `terraform.tfvars` file. All other variables have sensible defaults that can be left as-is.

---

## Usage

**Option A — inline variables**

```bash
# Initialize (downloads the AWS provider)
terraform init

# Preview changes
terraform plan \
  -var="profile=<your-aws-profile>" \
  -var="region=eu-west-3"

# Deploy
terraform apply \
  -var="profile=<your-aws-profile>" \
  -var="region=eu-west-3"

# Tear down
terraform destroy \
  -var="profile=<your-aws-profile>" \
  -var="region=eu-west-3"
```

**Option B — terraform.tfvars file**

Create `terraform/terraform.tfvars` (gitignored):

```hcl
profile = "your-aws-profile"
region  = "eu-west-3"
```

Then run without `-var` flags:

```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

**After apply — configure kubectl on the bastion**

The `kubeconfig_command` output prints the exact command to run on the bastion:

```bash
# SSH into the bastion
ssh -i .ssh/bastion ec2-user@<bastion_public_ip>

# On the bastion: generate kubeconfig
aws eks update-kubeconfig --name eks-cluster --region <region>

# Verify
kubectl get nodes
```

**After apply — push the Flask image to ECR**

The `docker_push_commands` output prints the exact commands (run locally, not on the bastion):

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --profile <profile> --region <region> | \
  docker login --username AWS --password-stdin <ecr_repository_url>

# Build and push
docker build -t <ecr_repository_url>:latest ../nextwork-flask-backend
docker push <ecr_repository_url>:latest
```

---

## Outputs

| Name                   | Description                                                        |
| ---------------------- | ------------------------------------------------------------------ |
| `cluster_name`         | The EKS cluster name (value of `var.project_name`)                 |
| `cluster_endpoint`     | HTTPS endpoint of the EKS API server                               |
| `bastion_public_ip`    | Public IP address of the bastion EC2 instance                      |
| `kubeconfig_command`   | Ready-to-paste `aws eks update-kubeconfig` command for the bastion |
| `ecr_repository_url`   | Full ECR repository URL for tagging and pushing images             |
| `docker_push_commands` | Ready-to-paste `docker login / build / push` sequence              |

---

## Notes

### State Management

State is stored locally in `terraform.tfstate`. There is no remote backend configured. This keeps the setup self-contained and avoids a bootstrapping dependency on an S3 bucket or DynamoDB table. The trade-off is that state is not shared or locked. For a team environment, configure an S3 backend with DynamoDB locking in `providers.tf`. The `terraform.tfstate` and `terraform.tfstate.backup` files are gitignored.

### SSH Key

The key pair is generated outside of Terraform deliberately. If Terraform managed the private key (via `tls_private_key`), the key material would be stored in plaintext in `terraform.tfstate`. Generating it locally and registering only the public key with `aws_key_pair` means the private key never touches Terraform state. Keep `terraform/.ssh/bastion` secure and never commit it.

### Dynamic IP Resolution

`scripts/my_ip_json.sh` is invoked by the `external` data source in `data.tf` at every `terraform plan` and `terraform apply`. It queries the current public IP and returns `{ "ip": "x.x.x.x" }`. This value is consumed in two places:

1. `compute.tf` — bastion security group SSH ingress rule (`var_ip/32`)
2. `eks.tf` — EKS cluster `public_access_cidrs` list (`var_ip/32`)

If your IP changes between deploys, the next `terraform apply` will detect the drift and update both resources automatically. No manual intervention is needed.

### ECR Repository

`ecr.tf` creates a single private ECR repository named `${var.project_name}-repo`. Two settings are enabled by default:

- **`scan_on_push = true`** — every pushed image is automatically scanned for CVEs. Results appear in the ECR console attached to the image digest.
- **Lifecycle policy** — retains only the 10 most recent images (by any tag status). Older images are expired automatically, keeping storage costs near zero.

The worker node IAM role already has `AmazonEC2ContainerRegistryReadOnly` attached (via `eks.tf`), so nodes can pull images from the repository at runtime without any additional credential configuration.

The `docker_push_commands` output prints the full `docker login / build / push` sequence with the correct registry URL and profile interpolated. Run these commands locally after `terraform apply` to publish the application image before deploying workloads to the cluster.

### EKS Cluster Provisioning Time

`terraform apply` takes approximately 12–15 minutes to complete. The EKS control plane creation (`aws_eks_cluster`) is the bottleneck, it typically takes 10–12 minutes on its own. The node group comes up in 2–3 minutes after the cluster is ready. This is normal and expected; there is no benefit to re-running `plan` or `apply` during this window.
