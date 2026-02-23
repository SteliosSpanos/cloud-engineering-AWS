# Data in DynamoDB

## Overview

Amazon DynamoDB is AWS's fully managed NoSQL database service. Unlike relational databases, DynamoDB has no fixed schema: each item in a table can have a different set of attributes, as long as the primary key attributes are present. Tables are defined by their key structure, a partition key alone, or a partition key paired with a sort key, and everything else is schemaless. DynamoDB handles provisioning, replication across multiple Availability Zones, patching, and backups automatically. There is no database server to log into, no storage volume to size, and no engine version to patch.

I built this project to understand how DynamoDB's data model differs from relational databases in practice, not just in theory. The central question was: what does a real, multi-table schema look like in DynamoDB, and how does that shape the key design? Rather than using invented data, I loaded a realistic community platform dataset (forums, posts, comments, and a content catalog) so the access patterns and key choices reflect a genuine application structure rather than a toy example.

The project also provides a concrete demonstration of the `batch-write-item` workflow, which is the standard mechanism for bulk-loading data into DynamoDB. Understanding how items must be structured for BatchWriteItem, including the DynamoDB JSON type annotation format, is practical knowledge that applies immediately whenever DynamoDB needs to be seeded with initial data, whether in a development environment, a staging environment, or a data migration.

All four tables are provisioned through Terraform, which makes the schema reproducible and version-controlled. The IAM policy created alongside the tables reflects the principle of least privilege: only the five operations actually required for application use are permitted, scoped to the exact ARNs of the provisioned tables.

Technologies used: AWS DynamoDB, AWS CloudShell, IAM, Terraform, DynamoDB JSON, BatchWriteItem.

---

## Architecture

![Architecture Diagram](assets/dynamodb.png)

The sample data originates as a zip archive (`nextworksampledata.zip`) containing four JSON files pre-formatted for the DynamoDB `batch-write-item` API. AWS CloudShell provides a browser-based shell with AWS CLI pre-installed and pre-authenticated, which means there are no credentials to configure and no local environment to prepare. The JSON files are uploaded directly to CloudShell, and `aws dynamodb batch-write-item` commands load each file into its corresponding table.

Terraform manages the table definitions. Running `terraform apply` from the `terraform/` directory creates all four tables and the IAM policy in the target region. The Terraform configuration uses a `for_each` loop over a `locals` map to avoid repeating the table resource block four times — the same provisioning logic (billing mode, capacity, PITR) is applied uniformly, while the key schema differs per table.

---

## Implementation Steps

### 1. Table Schema Design

The four tables model a community platform with a content catalog. Their key structures reflect different access patterns:

| Table | Partition Key | Sort Key | Purpose |
|---|---|---|---|
| `ContentCatalog` | `Id` (Number) | — | Video and tutorial metadata |
| `Forum` | `Name` (String) | — | Forum categories |
| `Post` | `ForumName` (String) | `Subject` (String) | Posts within a forum |
| `Comment` | `Id` (String) | `CommentDateTime` (String) |  Comments on a post |

`ContentCatalog` uses a simple numeric ID as its partition key, making individual item lookups by ID a direct `GetItem` call. `Forum` uses the forum name as its partition key, which is natural because forum names are unique identifiers in a community platform.

`Post` uses a composite key: `ForumName` as the partition key and `Subject` as the sort key. This key design enables a `Query` call to retrieve all posts within a forum in a single request, without a full table scan. All posts for "I have a question" are co-located in the same partition, accessible by querying `ForumName = "I have a question"`.

`Comment` encodes the relationship between comments and posts in the partition key itself. The `Id` attribute is set to a composite string of the form `ForumName/Subject` (for example, `"I have a question/Location of Documentation/ IAM User Setup for the projects."`), and `CommentDateTime` is the sort key. This means all comments on a specific post are co-located in one partition, queryable by `Id = "<forum>/<subject>"` and sortable chronologically by the timestamp sort key.

### 2. Provisioning Tables with Terraform

The Terraform configuration lives in the `terraform/` directory. The table definitions are expressed as a `locals` map in `main.tf`, and a single `aws_dynamodb_table` resource uses `for_each` to iterate over them:

```hcl
locals {
  tables = {
    "ContentCatalog" = { pk = "Id", pk_type = "N", rk = null,              rk_type = null }
    "Forum"          = { pk = "Name", pk_type = "S", rk = null,            rk_type = null }
    "Post"           = { pk = "ForumName", pk_type = "S", rk = "Subject",  rk_type = "S"  }
    "Comment"        = { pk = "Id", pk_type = "S", rk = "CommentDateTime", rk_type = "S"  }
  }
}
```

Each table is created with `billing_mode = "PROVISIONED"` at 1 read capacity unit and 1 write capacity unit. Point-in-Time Recovery is enabled on every table. The `dynamic "attribute"` block conditionally adds the sort key attribute definition only for tables where `rk` is non-null, which is how the same resource block handles both simple and composite key tables.

Before applying, create a `terraform.tfvars` file in the `terraform/` directory with your AWS CLI profile and target region:

```hcl
profile = "your-aws-profile"
region  = "eu-west-3"
```

Then initialise and apply:

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

Terraform will prompt for confirmation before creating any resources. After apply completes, the `table_arn` output lists the ARNs of all four tables.

### 3. Loading Sample Data via AWS CloudShell

The `terraform/data/nextworksampledata/` directory contains four JSON files pre-formatted for the `batch-write-item` API. Each file is keyed by the table name and contains an array of `PutRequest` objects, with item attributes annotated using DynamoDB's typed JSON format:

```json
{
  "Forum": [
    {
      "PutRequest": {
        "Item": {
          "Name":     { "S": "I have a question" },
          "Category": { "S": "NextWorkCommunity" },
          "Posts":    { "N": "2" },
          "Comments": { "N": "4" },
          "Views":    { "N": "1000" }
        }
      }
    }
  ]
}
```

The DynamoDB JSON format requires every attribute value to be wrapped in a type descriptor: `"S"` for String, `"N"` for Number (always expressed as a string literal), `"BOOL"` for Boolean, and `"L"` for a list. This differs from standard JSON and from the format DynamoDB returns when `--no-cli-pager` is not specified. BatchWriteItem accepts up to 25 items per call; the sample files are sized to fit within this limit.

To load the data using AWS CloudShell:

1. Open the AWS Console, select the same region used in `terraform.tfvars`, and launch CloudShell from the top navigation bar.
2. Upload each JSON file using the CloudShell Actions menu (Upload file).
3. Run `batch-write-item` for each table:

```bash
aws dynamodb batch-write-item \
  --request-items file://ContentCatalog.json \
  --region eu-west-3

aws dynamodb batch-write-item \
  --request-items file://Forum.json \
  --region eu-west-3

aws dynamodb batch-write-item \
  --request-items file://Post.json \
  --region eu-west-3

aws dynamodb batch-write-item \
  --request-items file://Comment.json \
  --region eu-west-3
```

A successful response returns an empty `UnprocessedItems` object (`{}`). If any items fail to write — for example, due to a capacity limit — they appear in `UnprocessedItems` and must be retried.

### 4. IAM Policy for Least-Privilege Access

The `iam.tf` file creates a standalone IAM policy that grants the five operations required for application use of the four tables:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": ["<arn of each table>"]
    }
  ]
}
```

The `Resource` list is generated dynamically from the `aws_dynamodb_table.tables` resource using a `for` expression, so it automatically includes the ARNs of all four tables without hardcoding. The policy does not grant `DeleteItem`, `DescribeTable`, `CreateTable`, or any administrative action. It is created as a standalone policy and is not attached to any role or user by the Terraform configuration — attachment is a deliberate separate step that depends on the consuming workload.

---

## Security Considerations

**Least-privilege IAM policy.** The IAM policy grants exactly five DynamoDB actions: `PutItem`, `GetItem`, `UpdateItem`, `Query`, and `Scan`. Operations like `DeleteItem`, `CreateTable`, `DeleteTable`, and `DescribeTable` are not included. This matters because DynamoDB does not have a network perimeter in the traditional sense — any principal with valid credentials and the right IAM permissions can call the DynamoDB API over the public HTTPS endpoint. The IAM policy is the primary access control boundary, so scoping it precisely is the most important security decision in this project.

**Resource-scoped policy, not `*`.** The `Resource` list in the IAM policy is bound to the ARNs of the four specific tables provisioned by Terraform. A wildcard resource (`"Resource": "*"`) would grant the same five actions against every DynamoDB table in the account, including tables that may contain production data or sensitive records. Scoping to exact ARNs ensures that the policy cannot be repurposed to reach unintended tables.

**Point-in-Time Recovery enabled on all tables.** PITR maintains a continuous backup of each table for up to 35 days, allowing restoration to any second within that window. This is a data durability control rather than an access control, but it is a meaningful protection against accidental bulk deletes, which are easy to trigger with a mistaken `Scan` combined with `DeleteItem` in a loop. PITR cannot be disabled accidentally through the IAM policy because the policy grants no backup or restore actions.

**No internet-exposed credentials.** Data is loaded through AWS CloudShell, which authenticates using the console session's IAM identity. There are no long-lived access keys generated or used for the data loading step. CloudShell sessions are ephemeral, the environment is recycled after approximately 20 minutes of inactivity, so there is no persistent credential surface to manage.

**IAM policy is not attached by Terraform.** The standalone IAM policy is created but intentionally not attached to any role, user, or group by this configuration. Attachment is a separate step, which means the policy cannot accidentally grant access to unintended principals during provisioning. In a production environment, the correct pattern is to attach this policy to an IAM role and assign that role to the specific service (Lambda, ECS task, EC2 instance profile) that needs DynamoDB access.

---

## Cost Analysis

All four DynamoDB tables are provisioned at 1 RCU and 1 WCU each. At standard on-demand rates in `eu-west-3`, provisioned capacity costs approximately $0.000735 per RCU-hour and $0.000735 per WCU-hour. At 1 RCU and 1 WCU per table across four tables, the total capacity cost is roughly $0.0059 per hour, or approximately $4.30 per month if all four tables run continuously. For the AWS Free Tier (first 12 months), 25 RCUs and 25 WCUs of provisioned capacity are included at no charge, which covers this entire project with capacity to spare.

DynamoDB storage costs approximately $0.283 per GB-month in `eu-west-3`. The sample data loaded into these four tables is a few kilobytes in total, negligible against the free tier's 25 GB of storage included per month.

BatchWriteItem calls during data loading consume write capacity. Loading a handful of items into each table at 1 WCU barely registers against either the provisioned capacity or the free tier's 2.5 million write requests per month.

Point-in-Time Recovery has no additional per-table cost — PITR backup storage is charged only for the data actually stored in the continuous backup, at approximately $0.209 per GB-month. For the small dataset in this project, the cost is effectively zero.

The IAM policy itself has no cost. IAM resources are free.

Running `terraform destroy` removes all four tables and the IAM policy. Unlike RDS or EC2 instances, DynamoDB tables do not incur a minimum charge after deletion, the billing stops as soon as the table is removed. For a learning project, the most cost-conscious practice is to apply, experiment, and destroy within the same session.

---

## Key Takeaways

- **DynamoDB's schema is defined entirely by its key structure.** The only attributes that must be declared at table creation time are the partition key and sort key. All other attributes are written freely at the item level, with no table-level schema enforcement. This is fundamentally different from relational databases, where the column set is fixed at table creation.

- **Composite key design encodes access patterns.** The `Post` table uses `ForumName` as the partition key and `Subject` as the sort key so that all posts in a forum can be retrieved with a single `Query` call. The `Comment` table encodes the post reference directly into the `Id` partition key string. Key design in DynamoDB is not an afterthought — it determines which queries are efficient and which require a full table scan.

- **The `batch-write-item` API uses a typed JSON format.** Each attribute value must be wrapped in a type descriptor (`"S"`, `"N"`, `"BOOL"`, `"L"`, etc.). This format differs from both standard JSON and from the simplified output format of the AWS CLI's `--output json` flag. Understanding the distinction is necessary for writing valid request files and for interpreting DynamoDB responses.

- **`BatchWriteItem` has a 25-item limit per call.** Each call accepts at most 25 `PutRequest` or `DeleteRequest` objects. For larger datasets, the items must be batched across multiple calls. Items that fail to write (for example, due to throttling) are returned in `UnprocessedItems` and must be retried — the API does not automatically retry failed writes within a batch.

- **Provisioned capacity at 1 RCU/1 WCU is sufficient for low-throughput learning workloads, but it does throttle under burst.** If BatchWriteItem calls are issued faster than the provisioned write capacity allows, the excess requests are throttled and returned as unprocessed items. For bulk loading against provisioned tables, the safest approach is to stay within the table's write capacity or to temporarily switch to `PAY_PER_REQUEST` billing during the load, then revert.

- **Point-in-Time Recovery is a low-cost, high-value safety net.** PITR enables restoration to any second within a 35-day window and costs nothing for tables this small. Enabling it by default in the Terraform configuration means every table gets continuous backup automatically, without requiring any operational procedure to set up.

- **`for_each` over a locals map eliminates repetition in Terraform resource definitions.** Rather than writing four separate `aws_dynamodb_table` blocks, the single resource block iterates over the map and uses `each.key` and `each.value` to populate the name and key schema. The `dynamic "attribute"` block further handles the conditional sort key definition. This pattern scales cleanly, adding a fifth table requires only a new entry in the `locals` map.

- **A standalone IAM policy not attached to any principal is intentional, not incomplete.** Creating the policy separately from its attachment means the Terraform configuration can provision the data layer independently of the application layer. The consuming workload (whatever service or user needs DynamoDB access) attaches the policy when it is deployed, keeping infrastructure concerns separated.

- **CloudShell eliminates the local environment problem for one-off data operations.** Because CloudShell runs inside the AWS account and inherits the console session's identity, there are no credentials to configure, no CLI version to manage, and no local AWS profile to set up. For tasks like initial data loading that run once and do not need to be automated, CloudShell is the lowest-friction option.

- **Scoping the IAM policy `Resource` to exact table ARNs is not optional.** Using `"Resource": "*"` would grant the five DynamoDB actions against every table in the account. In an account with multiple projects or environments, that is an unacceptably broad permission. The Terraform `for` expression that builds the ARN list dynamically from the provisioned tables is both correct and maintainable, the list updates automatically if the table set changes.
