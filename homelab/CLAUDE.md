# CLAUDE.md

## Before Replying

- Use agents when needed and the task is fitting.
- Always challenge my thinking for solutions and architecture decisions.
- Follow AWS and terraform best practices for everything.
- Keep in mind the cost of each plan.
- Never write the code unless explicity told to.

## Project

AWS homelab infrastructure managed with Terraform. All IaC lives in `terraform/`.

## Architecture

VPC (10.0.0.0/16) with 3 subnets and 3 security layers (SGs, NACLs, IAM):

```
Internet
  │
  ├── [Public Subnet 10.0.1.0/24]
  │     ├── Jump Box ──── sole SSH entry point, ProxyJump to all instances
  │     ├── NAT Instance ── iptables MASQUERADE, routes private subnet outbound
  │     └── Web App ──── Apache/PHP, public HTTP/S, connects to RDS on :5432
  │
  ├── [Private Subnet 1 10.0.2.0/24 - AZ1]
  │     └── Main VM ──── no public IP, SSH via jump box, sole S3 access via VPC endpoint
  │
  └── [Private Subnet 2 10.0.3.0/24 - AZ2]
        └── (RDS only — satisfies multi-AZ subnet group requirement)

  RDS PostgreSQL 15 ── spans both private subnets, reachable only from web app SG; postgres SG has explicit egress restricted to VPC CIDR
  S3 Bucket ── encrypted, versioned, accessed privately via VPC Gateway Endpoint; bucket policy denies all except main VM IAM role and account root
```

**How the pieces connect:**

- `network.tf` creates the VPC, subnets, IGW, and route tables. Private route table points to NAT instance ENI.
- `security.tf` defines SGs that reference each other (e.g., main VM allows SSH from jump box SG, RDS allows :5432 from web app SG). Postgres SG has explicit egress restricted to VPC CIDR only.
- `nacls.tf` adds stateless subnet-level rules on top of SGs (defense-in-depth).
- `iam.tf` creates per-instance roles. Each role gets CloudWatch scoped to its own log group + SSM. Main VM additionally gets S3 access.
- `compute.tf` wires it all together: instances reference their subnet, SG, IAM profile, and userdata template. NAT instance receives both private subnet CIDRs for iptables MASQUERADE rules.
- `database.tf` creates the RDS instance + DB subnet group spanning both private subnets.
- `s3.tf` creates the bucket + VPC Gateway Endpoint. Bucket policy has two statements: `DenyNonSSLTransport` and `AllowOnlyMainVMRole` (denies all principals except main VM role ARN and account root). VPC endpoint policy enforces the same restriction at the network layer.
- `cloudwatch.tf` pre-creates log groups (one per instance) so instances don't need `CreateLogGroup` permission.
- `data.tf` provides AMI lookups and `scripts/my_ip_json.sh` injects the operator's current IP into SG/NACL rules.
- `templates/*.tpl` are userdata scripts consumed via `templatefile()` — each installs CloudWatch Agent + instance-specific setup.

## File Structure

- `terraform/*.tf` — resource definitions (one file per concern)
- `terraform/templates/*.tpl` — EC2 userdata scripts
- `terraform/scripts/my_ip_json.sh` — dynamic IP lookup for security rule whitelisting
- `terraform/variables.tf` — all input variables; sensitive values (`db_password`) marked sensitive
- `terraform.tfstate` is local and contains secrets (SSH key, DB password) — never commit it

## Conventions

- Resource naming uses `var.project_name` ("homelab") prefix
- One IAM role per instance, scoped to its own CloudWatch log group ARN
- Security groups reference other security groups (not CIDRs) for inter-instance access
- Userdata templates use `templatefile()` for variable injection
- SSH access follows bastion pattern: jump box is the only public SSH entry point

## Terraform Commands

```bash
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
terraform -chdir=terraform destroy
```

## Best Practices

- Never hardcode IPs, credentials, or ARNs — use variables, data sources, or references
- Keep each `.tf` file focused on a single concern; don't merge unrelated resources
- Security groups should use least-privilege: restrict by source SG, not `0.0.0.0/0`, unless public-facing
- IAM policies must be scoped to specific resource ARNs, not wildcards
- Mark sensitive variables with `sensitive = true`
- Test with `terraform plan` before applying; review the diff
- Do not add `terraform.tfstate`, `.terraform/`, or `.tfvars` files to git
