# Terraform — KMS Encryption

This Terraform configuration provisions a customer-managed AWS KMS key, four DynamoDB tables encrypted with that key, and an IAM user with scoped table access. It demonstrates the separation between DynamoDB-level permissions and KMS key permissions. A test user can read and write to the tables but cannot directly interact with the encryption key.

---

## What This Configuration Provisions

- **1 KMS customer-managed key** with automatic annual key rotation and a 7-day deletion window
- **4 DynamoDB tables** (provisioned billing, 1 RCU / 1 WCU each, server-side encryption via the KMS key, Point-in-Time Recovery enabled)
  - `ContentCatalog` — PK: `Id` (Number)
  - `Forum` — PK: `Name` (String)
  - `Post` — PK: `ForumName` (String), SK: `Subject` (String)
  - `Comment` — PK: `Id` (String), SK: `CommentDateTime` (String)
- **IAM policy** granting `PutItem`, `GetItem`, `UpdateItem`, `Query`, and `Scan` on all four table ARNs
- **IAM test user** with the above policy attached — no KMS permissions granted

---

## Prerequisites

| Requirement | Version / Notes |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.0 |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | Any recent v2 release |
| AWS named profile | A profile named `dev` configured via `aws configure` |
| AWS permissions | `kms:CreateKey`, `kms:PutKeyPolicy`, `kms:EnableKeyRotation`, `dynamodb:CreateTable`, `dynamodb:DescribeTable`, `dynamodb:DeleteTable`, `dynamodb:UpdateContinuousBackups`, `iam:CreateUser`, `iam:CreatePolicy`, `iam:AttachUserPolicy` |

---

## File Structure

```
terraform/
├── providers.tf        # Terraform and AWS provider version constraints
├── variables.tf        # Input variable declarations
├── terraform.tfvars    # Your local variable values (gitignored — create manually)
├── data.tf             # aws_caller_identity data source + KMS key policy document
├── kms.tf              # Customer-managed KMS key resource
├── main.tf             # DynamoDB table resources (for_each over table definitions)
├── iam.tf              # IAM policy, test IAM user, and policy attachment
└── outputs.tf          # Output: list of provisioned table ARNs
```

---

## Variables

| Name | Type | Description | Default | Required |
|---|---|---|---|---|
| `profile` | `string` | AWS CLI named profile to use for authentication | — | Yes |
| `region` | `string` | AWS region in which to create all resources | — | Yes |
| `project_name` | `string` | Prefix applied to resource names and tags | `"kms-encryption"` | No |
| `test_user_name` | `string` | Name of the IAM user created to demonstrate table access without KMS access | — | Yes |

The `terraform.tfvars` file in this directory is gitignored. The values shipped with this project are:

```hcl
profile        = "dev"
region         = "eu-west-3"
test_user_name = "test-dynamodb-user"
```

Adjust these to match your own AWS CLI profile and preferred region before deploying.

---

## Outputs

| Name | Description |
|---|---|
| `table_arn` | List of ARNs for all four provisioned DynamoDB tables |

---

## Deployment

```bash
# 1. Initialise the working directory and download the AWS provider
terraform init

# 2. Review the execution plan — no changes are made at this step
terraform plan

# 3. Apply the configuration and confirm with "yes" when prompted
terraform apply

# 4. Tear down all resources when finished
terraform destroy
```

> **Note:** `terraform destroy` schedules the KMS key for deletion. AWS enforces a mandatory waiting period before the key is permanently deleted — see [Cleanup](#cleanup) below.

---

## Key Design Decisions

### for_each pattern for DynamoDB tables

All four tables are defined as a single `aws_dynamodb_table` resource using `for_each` over a `locals` map. Each map entry holds the table's primary key name and type, and an optional sort key. A `dynamic "attribute"` block is used so that only tables with a sort key emit a second attribute definition. This approach keeps the code DRY and makes adding or removing a table a one-line change in `main.tf`.

```hcl
locals {
  tables = {
    "ContentCatalog" = { pk = "Id",        pk_type = "N", rk = null,              rk_type = null }
    "Forum"          = { pk = "Name",      pk_type = "S", rk = null,              rk_type = null }
    "Post"           = { pk = "ForumName", pk_type = "S", rk = "Subject",         rk_type = "S"  }
    "Comment"        = { pk = "Id",        pk_type = "S", rk = "CommentDateTime", rk_type = "S"  }
  }
}
```

### KMS key rotation

`enable_key_rotation = true` instructs AWS to automatically rotate the key material once per year. The original key ID and ARN remain unchanged after rotation, so no updates to the DynamoDB tables or any other dependent resources are required. Rotation is a low-cost, zero-downtime operation that limits the blast radius of a compromised key.

### Three-statement KMS key policy

The KMS key policy in `data.tf` uses three explicit statements rather than relying on the AWS default policy. This makes the intended access model clear and auditable:

| Statement SID | Principal | Purpose |
|---|---|---|
| `EnableIAMUserPermissions` | Account root (`arn:aws:iam::<account_id>:root`) | Ensures IAM policies in the account can be used to grant KMS access. Without this statement, no IAM policy can delegate key access. |
| `AllowKeyAdministrators` | Caller identity (the user running Terraform) | Grants full key lifecycle management — create, rotate, disable, schedule deletion, etc. |
| `AllowKeyUsers` | Caller identity (the user running Terraform) | Grants the cryptographic operations needed at runtime — `Encrypt`, `Decrypt`, `GenerateDataKey`, `ReEncrypt`, `DescribeKey`. |

The IAM test user created in `iam.tf` is intentionally absent from the KMS policy. This means the test user can call DynamoDB read/write APIs, but DynamoDB transparently handles the KMS calls on its behalf using the service principal, the test user never holds direct KMS permissions.

---

## Cleanup

To remove all provisioned resources, run:

```bash
terraform destroy
```

**KMS deletion window:** When Terraform destroys the KMS key it schedules it for deletion with a `deletion_window_in_days` value of `7`. The key will not be permanently deleted until that window expires. During this period:

- The key cannot be used for any cryptographic operations.
- The key can be cancelled from deletion via the AWS Console or CLI if needed.
- Any data that was encrypted solely by this key and not backed up elsewhere will be permanently unrecoverable once the deletion window expires.

To cancel a scheduled deletion before it takes effect:

```bash
aws kms cancel-key-deletion \
  --key-id <key-id> \
  --profile dev \
  --region eu-west-3
```
