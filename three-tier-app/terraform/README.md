# Terraform — Three-Tier App Infrastructure

## Overview

This Terraform configuration provisions the entire serverless three-tier application on AWS. Each tier maps to a set of managed services: S3 and CloudFront for the presentation layer, API Gateway and Lambda for the application layer, and DynamoDB for the data layer. There are no servers to manage, no VPCs to configure, and no patching schedules to maintain.

The configuration is split across logical files — `s3.tf`, `cloudfront.tf`, `api_gateway.tf`, `lambda.tf`, `dynamodb.tf`, `iam.tf`, so each file corresponds to a specific tier or concern.

## File Structure

```
terraform/
├── app/                  # Frontend static assets (HTML, CSS, JS)
│   ├── index.html
│   ├── script.js
│   └── style.css
├── lambda/               # Go Lambda function source and compiled binary
│   ├── main.go
│   ├── bootstrap
│   ├── go.mod
│   └── go.sum
├── api_gateway.tf        # REST API, /users resource, CORS, deployment
├── cloudfront.tf         # CDN distribution with OAC for S3
├── data.tf               # Data sources (caller identity, archive for Lambda zip)
├── dynamodb.tf           # UserData table (PAY_PER_REQUEST)
├── iam.tf                # Lambda execution role, logging and DynamoDB policies
├── lambda.tf             # Lambda function and CloudWatch log group
├── outputs.tf            # CloudFront URL, API Gateway URL, ARNs
├── providers.tf          # AWS provider config (~> 5.0)
├── s3.tf                 # Bucket, versioning, encryption, lifecycle, static assets
├── variables.tf          # profile, region, project_name, table_name
└── terraform.tfvars      # Variable values (not committed)
```

## Usage

Before applying, create a `terraform.tfvars` with your values:

```hcl
profile    = "your-aws-profile"
region     = "eu-west-3"
```

The Lambda function must be compiled before `terraform apply` because Terraform packages the `bootstrap` binary into a zip:

```bash
cd lambda/
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go
cd ..
terraform init
terraform plan
terraform apply
```

After apply, Terraform outputs the CloudFront URL (frontend) and API Gateway URL (backend). Replace the `API_GATEWAY_URL` placeholder in `app/script.js` with the actual API Gateway URL, re-upload, and invalidate the CloudFront cache:

```bash
aws cloudfront create-invalidation --distribution-id <DIST_ID> --paths "/*"
```

To tear everything down:

```bash
terraform destroy
```

## Outputs

| Output                       | Description                |
| ---------------------------- | -------------------------- |
| `cloudfront_url`             | HTTPS URL for the frontend |
| `cloudfront_distribution_id` | For cache invalidation     |
| `s3_bucket_arn`              | S3 bucket ARN              |
| `api_gateway_url`            | Full `/users` endpoint URL |
| `table_arn`                  | DynamoDB table ARN         |
