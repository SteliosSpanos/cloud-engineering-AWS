# Terraform Infrastructure — EC2 Web App with RDS PostgreSQL

## Overview

This directory contains the complete Terraform configuration for the EC2 and RDS PostgreSQL project. Terraform manages every AWS resource in the stack: the VPC and subnets, the Internet Gateway and route tables, the security groups and NACLs, the EC2 instance and its Elastic IP, and the RDS database with its subnet group and parameter group. Running `terraform apply` from this directory provisions the full environment from scratch. Running `terraform destroy` tears it all down cleanly in the correct dependency order.

I used Terraform for this project rather than the AWS Console for several reasons. First, reproducibility: the configuration defines the exact state of the infrastructure, so I can destroy and recreate it identically. Second, auditability: every resource is in version control, so there is a history of what was built and why. Third, the plan/apply workflow forces an explicit review step before any change takes effect. These properties matter even on solo learning projects—they are the habits that carry into production environments.

The configuration introduced several Terraform-specific patterns I had not used before: `templatefile()` for external bootstrap scripts, `aws_db_instance` and `aws_db_subnet_group` for managed database infrastructure, and implicit resource dependencies across files that Terraform resolves automatically.

## Structure

```
terraform/
├── providers.tf          # Terraform version constraints and provider configuration
├── variables.tf          # All input variable declarations with types and defaults
├── data.tf               # Data sources: AZs, AMI lookup, caller identity, external IP
├── network.tf            # VPC, subnets (public + two private), IGW, route table
├── security.tf           # Security groups (EC2 + RDS) and NACLs (public + private)
├── compute.tf            # EC2 instance, key pair, Elastic IP, user_data wiring
├── database.tf           # RDS instance, DB subnet group, parameter group
├── outputs.tf            # Exposed values: IPs, endpoint, SSH command, key path
├── terraform.tfvars      # Actual variable values — gitignored, never committed
├── scripts/
│   └── my_ip_json.sh     # Bash script that returns current public IP as JSON
└── templates/
    └── userdata.tpl      # EC2 bootstrap script template (Apache + PHP + DB config)
```

### File Descriptions

**`providers.tf`** declares the minimum Terraform version (`>= 1.0`) and pins the four providers used: `hashicorp/aws` (`~> 5.0`), `hashicorp/tls` (`~> 4.0`), `hashicorp/local` (`~> 2.0`), and `hashicorp/external` (`~> 2.0`). Pinning provider versions prevents upstream provider releases from silently changing behavior between runs.

**`variables.tf`** declares every input the configuration accepts. Required variables have no default and must be supplied via `terraform.tfvars`. Optional variables have defaults that can be overridden. The `db_password` variable is marked `sensitive = true`, which prevents Terraform from printing its value in plan or apply output.

**`data.tf`** defines four data sources that are computed at plan time rather than hardcoded. `aws_availability_zones` discovers available AZs in the configured region dynamically. `aws_ami` queries the latest Amazon Linux 2023 HVM x86_64 AMI so the configuration never drifts to an outdated AMI ID. `aws_caller_identity` retrieves the AWS account ID. `external` runs `scripts/my_ip_json.sh` to detect the current public IP for SSH restriction.

**`network.tf`** provisions the VPC with DNS support enabled, one public subnet in the first AZ, two private subnets in two separate AZs (required for the DB subnet group), an Internet Gateway, a public route table with a default route to the IGW, and a route table association connecting the public subnet to that route table. The private subnets have no route table association with the IGW, creating the network isolation the database requires.

**`security.tf`** defines two security groups and two NACLs. The EC2 security group permits SSH from my IP, HTTP and HTTPS from anywhere, and all outbound traffic. The database security group permits port 5432 inbound using `security_groups` (a security group reference) rather than `cidr_blocks`. The public NACL covers SSH, HTTP, HTTPS, and ephemeral ports bidirectionally. The private NACL covers only port 5432 inbound from the public subnet CIDR and ephemeral ports outbound back to the public subnet.

**`compute.tf`** generates a 4096-bit RSA key pair using the `tls` provider, registers the public key as an EC2 Key Pair, writes the private key to `.ssh/` with `0400` permissions using the `local` provider, provisions the EC2 instance with `templatefile()` wired to `templates/userdata.tpl`, and attaches an Elastic IP with `depends_on = [aws_internet_gateway.test_igw]`.

**`database.tf`** provisions the DB subnet group (spanning both private subnets), a parameter group for PostgreSQL 15, and the `aws_db_instance` itself with encryption enabled, public accessibility disabled, and credentials sourced from variables. The file also contains a detailed comment block explaining why Aurora PostgreSQL was considered and rejected, and what resources and attributes Aurora would require if someone wanted to use it instead.

**`outputs.tf`** exposes the VPC ID, subnet IDs, the instance's Elastic IP, the RDS endpoint, the SSH key path, and a ready-to-run SSH command string. These outputs are the primary interface between `terraform apply` and the next operational step.

**`scripts/my_ip_json.sh`** queries a public IP API and returns a JSON object `{"ip": "x.x.x.x"}` for consumption by the `external` data source. Terraform calls this script at every plan and apply, ensuring the current IP is always used without manual intervention.

**`templates/userdata.tpl`** is a shell script template rendered by `templatefile()`. It installs Apache, PHP, and the PostgreSQL PHP extension; writes a `dbinfo.inc` configuration file with the database endpoint and credentials injected as template variables; and deploys `SamplePage.php`, a PHP page that connects to PostgreSQL via PDO, creates a sample table, inserts a row, and displays the five most recent rows.

## Key Resources

### `aws_db_instance` (database.tf)

The central resource for managed PostgreSQL. The key attributes for this project:

```hcl
resource "aws_db_instance" "postgres" {
  engine         = "postgres"
  engine_version = "15.16"
  instance_class = "db.t3.micro"

  allocated_storage = 20

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.test_aurora_sg.id]

  storage_encrypted   = true
  publicly_accessible = false   # default, but explicit
  skip_final_snapshot = true
}
```

`aws_db_instance` is the correct resource for standard RDS. Aurora uses `aws_rds_cluster` plus `aws_rds_cluster_instance` (two separate resources). Mixing them up produces errors that can be confusing to trace. `storage_encrypted = true` enables AES-256 encryption at rest via KMS. `skip_final_snapshot = true` is appropriate for learning environments—in production, always take a final snapshot before destroying a database.

The `endpoint` attribute returns `hostname:5432`. If only the hostname is needed (for the PHP PDO connection string, for instance), use `aws_db_instance.postgres.address` instead.

### `aws_db_subnet_group` (database.tf)

```hcl
resource "aws_db_subnet_group" "postgres" {
  subnet_ids = [
    aws_subnet.test_private_subnet.id,
    aws_subnet.test_private_subnet_backup.id
  ]
}
```

AWS requires a DB subnet group to reference subnets in at least two Availability Zones. This requirement applies regardless of whether Multi-AZ is enabled for the RDS instance. Without this, `terraform apply` fails with a validation error. The two private subnets in `network.tf` exist specifically to satisfy this requirement.

### `aws_instance` with `templatefile()` (compute.tf)

```hcl
resource "aws_instance" "test_instance" {
  user_data = templatefile("${path.module}/templates/userdata.tpl", {
    db_address  = aws_db_instance.postgres.address
    db_username = var.db_username
    db_password = var.db_password
    db_name     = var.db_name
  })
}
```

`templatefile()` reads `userdata.tpl` and substitutes `${db_address}`, `${db_username}`, `${db_password}`, and `${db_name}` with their values at plan time. This is significantly cleaner than inline heredocs in the HCL resource block, which become difficult to read and maintain as the script grows. The template file can be edited, syntax-highlighted, and version-controlled independently of the Terraform resource configuration.

The `aws_db_instance.postgres.address` reference creates an implicit dependency between the EC2 instance and the RDS database. Terraform builds a dependency graph from these references and ensures the RDS instance is fully provisioned and available before it renders the template and launches the EC2 instance. No explicit `depends_on` is needed.

### `aws_security_group` — Security Group Reference (security.tf)

```hcl
resource "aws_security_group" "test_aurora_sg" {
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.test_instance_sg.id]
  }
}
```

Using `security_groups` instead of `cidr_blocks` restricts database access to resources with the EC2 security group attached, regardless of their IP address. This is the correct pattern for intra-VPC database access.

### `aws_eip` with `depends_on` (compute.tf)

```hcl
resource "aws_eip" "test_instance" {
  domain   = "vpc"
  instance = aws_instance.test_instance.id
  depends_on = [aws_internet_gateway.test_igw]
}
```

The explicit `depends_on` ensures the Internet Gateway exists before Terraform allocates and associates the Elastic IP. Without the IGW, an EIP attached to an instance in a VPC is unreachable. The `instance` reference alone does not create a dependency on the IGW because those two resources have no direct attribute relationship—`depends_on` makes the implicit requirement explicit.

## Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `profile` | Yes | — | AWS CLI profile name |
| `region` | Yes | — | AWS region (e.g., `eu-west-3`) |
| `project_name` | Yes | — | Prefix for all resource names |
| `db_name` | Yes | — | PostgreSQL database name |
| `db_username` | Yes | — | RDS master username |
| `db_password` | Yes | — | RDS master password (sensitive) |
| `vpc_cidr` | No | `10.0.0.0/16` | VPC CIDR block |
| `public_subnet_cidr` | No | `10.0.1.0/24` | Public subnet CIDR |
| `private_subnet_cidr` | No | `10.0.2.0/24` | First private subnet CIDR |
| `private_subnet_cidr_backup` | No | `10.0.3.0/24` | Second private subnet CIDR |
| `instance_type` | No | `t3.micro` | EC2 instance type |

### Setting Variables

Create `terraform.tfvars` in this directory (it is gitignored and should never be committed):

```hcl
profile      = "your-aws-cli-profile"
region       = "eu-west-3"
project_name = "aurora-db-ec2"

db_name     = "myappdb"
db_username = "dbadmin"
db_password = "choose-a-strong-password"
```

The `.gitignore` at the repository root includes `*.tfvars` to prevent credentials from being accidentally committed. Never add database credentials to `variables.tf` as default values—that would commit them to version control.

## Usage

### Prerequisites

- Terraform >= 1.0 installed
- AWS CLI configured with the profile specified in `terraform.tfvars`
- `terraform.tfvars` created with required variables (see above)

### Initialize

Downloads the four required providers (`aws`, `tls`, `local`, `external`) and initializes the working directory.

```bash
terraform init
```

### Preview Changes

Generates and displays an execution plan. Always review the plan before applying, particularly to verify the IP address in security group and NACL rules is correct.

```bash
terraform plan
```

### Apply

Provisions all resources. RDS takes seven to ten minutes to reach the `available` state—Terraform waits automatically. The SSH command and RDS endpoint are printed at the end.

```bash
terraform apply
```

### Retrieve Outputs

```bash
terraform output instance_public_ip   # Elastic IP of the EC2 instance
terraform output db_endpoint          # RDS endpoint (hostname:5432)
terraform output ssh_command          # Ready-to-run SSH command
terraform output ssh_key_path         # Path to the generated private key
```

### SSH into the Instance

```bash
ssh -i $(terraform output -raw ssh_key_path) ec2-user@$(terraform output -raw instance_public_ip)
```

### Test the Web Application

After apply completes and the EC2 instance has finished its first-boot bootstrap (allow one to two minutes for Apache and PHP to install), navigate to:

```
http://<instance_public_ip>/SamplePage.php
```

A successful response shows a PostgreSQL connection confirmation and the most recent rows from the sample table.

### Destroy

Removes all provisioned resources in the correct dependency order.

```bash
terraform destroy
```

Always run this when done to avoid ongoing charges, particularly for the RDS instance.

## Key Takeaways

- **`templatefile()` is the right tool for non-trivial user_data scripts.** An inline heredoc embedded in the `aws_instance` resource block becomes unmaintainable once the script exceeds a few lines. A separate `.tpl` file can be edited with syntax highlighting, tested independently, and version-controlled without touching the resource definition. The function substitutes `${variable}` placeholders at plan time using the map passed as the second argument.

- **user_data runs once at first boot only.** Modifying the template and running `terraform apply` does not update a running instance. The hash of the user_data content changes, which Terraform detects as a diff, but the existing instance ignores it. The instance must be replaced. Use `terraform apply -replace=aws_instance.<resource_name>` to force recreation without destroying the rest of the stack.

- **Implicit dependencies eliminate most `depends_on` usage.** When one resource references an attribute of another (such as `aws_instance` referencing `aws_db_instance.postgres.address` in `templatefile()`), Terraform infers the dependency automatically and sequences provisioning accordingly. `depends_on` is only needed when two resources must be sequenced but share no attribute reference—the Elastic IP and Internet Gateway relationship is the clearest example in this configuration.

- **Aurora requires a two-resource model; RDS requires one.** Aurora needs `aws_rds_cluster` plus `aws_rds_cluster_instance`, along with a cluster-level parameter group (`aws_rds_cluster_parameter_group`). Attempting to use `aws_db_instance` for Aurora or `aws_rds_cluster` for standard RDS produces provider validation errors. Know which resource model applies before writing the configuration.

- **Engine version availability is region-specific.** The same engine version may not be available across all AWS regions. Query available versions before hardcoding: `aws rds describe-db-engine-versions --engine postgres --region <region> --query 'DBEngineVersions[].EngineVersion'`. Hardcoding a version that does not exist in the target region produces a cryptic API error during apply.

- **The DB subnet group requires subnets in two AZs, always.** This is an AWS requirement that applies even when Multi-AZ is disabled and the RDS instance runs in a single AZ. The two private subnets exist specifically to satisfy this requirement. Attempting to create a DB subnet group with subnets in the same AZ fails with a validation error.

- **`aws_db_instance.endpoint` includes the port; `.address` does not.** The `endpoint` attribute returns `hostname:5432`, which is useful for display but not for use in a connection string where the port is specified separately. The `address` attribute returns just the hostname. Use `address` in application configuration and `endpoint` in outputs meant for human consumption.

- **Sensitive variables suppress output but do not protect state.** Marking `db_password` as `sensitive = true` prevents Terraform from printing the value in plan and apply output. However, the value is stored in plaintext in `terraform.tfstate`. Treat the state file with the same security rigor as the credentials themselves. For shared environments, use a remote backend with encryption and access controls.

- **Provider version pinning prevents silent drift.** Specifying `version = "~> 5.0"` for the AWS provider allows patch and minor updates within the 5.x series but prevents a major version upgrade from changing resource behavior unexpectedly. This is particularly important for long-lived configurations where providers may introduce breaking changes between major versions.

- **`terraform destroy` handles dependency ordering automatically.** Destroying resources manually from the console requires knowing the correct order (RDS before subnet group before subnets before VPC, for example). Terraform tracks the dependency graph and destroys resources in the correct reverse order. This is one of the most practical operational advantages of IaC over console-managed infrastructure.
