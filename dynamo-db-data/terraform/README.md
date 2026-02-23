# Terraform — DynamoDB Tables

This Terraform configuration provisions four DynamoDB tables, an IAM policy scoped to those tables, and supporting infrastructure on AWS. It is designed to replicate a realistic forum/content dataset suitable for querying and access-pattern experimentation.

---

## What This Configuration Provisions

- **4 DynamoDB tables** (provisioned billing, 1 RCU / 1 WCU each, Point-in-Time Recovery enabled)
  - `ContentCatalog` — PK: `Id` (Number)
  - `Forum` — PK: `Name` (String)
  - `Post` — PK: `ForumName` (String), SK: `Subject` (String)
  - `Comment` — PK: `Id` (String), SK: `CommentDateTime` (String)
- **IAM policy** granting `PutItem`, `GetItem`, `UpdateItem`, `Query`, and `Scan` on all four table ARNs
- All resources are tagged with the `project_name` variable

---

## Prerequisites

| Requirement | Version / Notes |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.0 |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | Any recent v2 release |
| AWS credentials | A named profile configured via `aws configure` |
| AWS permissions | `dynamodb:CreateTable`, `dynamodb:DescribeTable`, `dynamodb:DeleteTable`, `dynamodb:UpdateContinuousBackups`, `dynamodb:TagResource`, `iam:CreatePolicy`, `iam:GetPolicy`, `iam:DeletePolicy` |

---

## File Structure

```
terraform/
├── providers.tf        # Terraform and AWS provider version constraints
├── variables.tf        # Input variable declarations
├── main.tf             # DynamoDB table resources (for_each over table definitions)
├── iam.tf              # IAM policy granting access to all four tables
├── outputs.tf          # Output: list of provisioned table ARNs
├── terraform.tfvars    # Your local variable values — gitignored, create manually
└── data/
    ├── nextworksampledata.zip   # Original sample data archive
    ├── ContentCatalog.json      # Sample items for the ContentCatalog table
    ├── Forum.json               # Sample items for the Forum table
    ├── Post.json                # Sample items for the Post table
    └── Comment.json             # Sample items for the Comment table
```

---

## Variables

| Name | Description | Required | Default |
|---|---|---|---|
| `profile` | AWS CLI named profile to use for authentication | Yes | — |
| `region` | AWS region in which to create all resources | Yes | — |
| `project_name` | Prefix applied to resource names and the `Project` tag | No | `"dynamo-db"` |

Create a `terraform.tfvars` file in this directory (it is gitignored) and set your values:

```hcl
profile = "your-aws-profile"
region  = "us-east-1"
```

---

## Outputs

| Name | Description |
|---|---|
| `table_arns` | List of ARNs for all four provisioned DynamoDB tables |

---

## Usage

```bash
# 1. Create your variable file
cat > terraform.tfvars <<EOF
profile = "your-aws-profile"
region  = "us-east-1"
EOF

# 2. Initialise the working directory
terraform init

# 3. Review the execution plan
terraform plan

# 4. Apply the configuration
terraform apply
```

Terraform will prompt for confirmation before making any changes. Review the plan output, then type `yes` to proceed.

---

## Loading Sample Data

The `data/` subdirectory contains JSON files extracted from `nextworksampledata.zip`. After `terraform apply` completes, you can load these files into their respective tables using the AWS CLI `batch-write-item` command.

Example for the `Forum` table:

```bash
aws dynamodb batch-write-item \
  --request-items file://data/Forum.json \
  --profile your-aws-profile \
  --region us-east-1
```

Repeat for `ContentCatalog.json`, `Post.json`, and `Comment.json`. The JSON files must follow the [BatchWriteItem request syntax](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchWriteItem.html), with each file keyed by its table name.

---

## Notes

- `terraform.tfvars` is listed in `.gitignore`. Never commit AWS profile names or region values that are environment-specific.
- All tables use **PROVISIONED** capacity at 1 RCU / 1 WCU. For production workloads, increase capacity or switch to `PAY_PER_REQUEST` billing in `main.tf`.
- Point-in-Time Recovery (PITR) is enabled on all tables by default.
- The IAM policy created by `iam.tf` is standalone and not attached to any role or user by this configuration. Attach it as needed after provisioning.
