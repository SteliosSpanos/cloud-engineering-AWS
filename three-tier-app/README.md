# Three-Tier Serverless Application

## Overview

A serverless three-tier web application on AWS, fully provisioned with Terraform. The frontend is a static site served through CloudFront, the backend is a Go Lambda function behind API Gateway, and the data layer is a DynamoDB table. The goal was to build a complete, working application where every layer (presentation, logic, and data) is a managed AWS service with no EC2 instances involved.

The application itself is simple: a user enters an ID, the frontend calls the API, the Lambda queries DynamoDB, and the result comes back. The value is in how the pieces connect. CloudFront uses Origin Access Control to reach S3 privately, API Gateway proxies requests to Lambda with CORS handled at both the gateway and function level, and Lambda's IAM role is scoped to a single `GetItem` operation on a single table. Each tier only knows about the tier directly below it.

Technologies used: Terraform, AWS S3, CloudFront, API Gateway, Lambda (Go), DynamoDB, IAM, CloudWatch.

---

## Architecture

![Architecture Diagram](assets/app.png)

The architecture has three distinct layers:

**Presentation tier**: Static HTML, CSS, and JavaScript files stored in an S3 bucket. CloudFront sits in front of S3 as the CDN, using Origin Access Control with SigV4 signing so the bucket stays fully private (all four public access block settings enabled). Users hit the CloudFront HTTPS URL. Custom error responses redirect 403 and 404 to `index.html` for SPA-style routing.

**Application tier**: API Gateway exposes a regional REST API with a `/users` resource. GET requests are proxied to a Lambda function via `AWS_PROXY` integration. An OPTIONS method with a MOCK integration handles CORS preflight. The Lambda function is written in Go, compiled to a custom `bootstrap` binary running on the `provided.al2023` runtime. It reads a `userId` query parameter, calls `GetItem` on DynamoDB, and returns the result as JSON with CORS headers.

**Data tier**: A DynamoDB table (`UserData`) with `userId` as the partition key, using on-demand billing (`PAY_PER_REQUEST`). No provisioned capacity to manage.

---

## Implementation Steps

### 1. S3 Bucket for Static Assets

The S3 bucket stores the frontend files (`index.html`, `style.css`, `script.js`). Versioning is enabled with a lifecycle rule that expires noncurrent versions after 30 days. Server-side encryption uses AES256. All public access is blocked and the only way to reach these files is through CloudFront, enforced by a bucket policy that allows `s3:GetObject` only from the specific CloudFront distribution ARN.

### 2. CloudFront Distribution

CloudFront serves the static site over HTTPS. Origin Access Control replaces the older Origin Access Identity approach, signing requests to S3 with SigV4. The managed `CachingOptimized` cache policy handles caching. Custom error responses map both 403 and 404 to `/index.html` with a 200 status code, which is the standard pattern for single-page applications where the frontend handles its own routing.

### 3. Lambda Function in Go

The backend is a single Go file (`lambda/main.go`). It initialises the DynamoDB client once in `init()`, then handles API Gateway proxy events. The function validates the `userId` query parameter, calls `GetItem`, and returns a JSON response with appropriate status codes (400 for missing parameter, 404 for no data, 500 for errors). CORS headers are set directly in the response. The binary is compiled with `GOOS=linux GOARCH=amd64` and Terraform packages it into a zip using `data.archive_file`.

### 4. API Gateway

A regional REST API with a `/users` resource. The GET method uses `AWS_PROXY` integration, which passes the full request to Lambda and lets Lambda control the response format. The OPTIONS method uses a MOCK integration that returns CORS headers (`Access-Control-Allow-Origin: *`, `Access-Control-Allow-Methods: GET,OPTIONS`) without invoking Lambda. The deployment uses a `sha1` trigger on all resource and integration IDs so it redeploys automatically when configuration changes. A `prod` stage is created for the deployment.

### 5. DynamoDB Table

A single table named `UserData` with a string partition key `userId`. On-demand billing means no capacity planning — DynamoDB scales automatically. The Lambda function only needs `GetItem`, and the IAM policy restricts it to exactly that.

### 6. IAM — Least Privilege

The Lambda execution role has two inline policies. One grants CloudWatch Logs permissions (`CreateLogGroup`, `CreateLogStream`, `PutLogEvents`) for logging. The other grants `dynamodb:GetItem` on the specific table ARN. No wildcards on the DynamoDB policy, the Lambda can read from one table and nothing else.

---

## Security Considerations

- **S3 is never publicly accessible.** All four public access block settings are enabled. The only access path is through CloudFront via Origin Access Control, verified by the bucket policy checking the distribution ARN.

- **Lambda follows least privilege.** The IAM role permits exactly two things: writing logs and reading one DynamoDB table. No `dynamodb:*`, no `Resource: "*"`.

- **API Gateway has no authorization.** This is a learning project. In production, you would add Cognito, IAM auth, or a Lambda authorizer. The current setup is open to anyone who knows the URL.

- **CORS is handled at two levels.** The OPTIONS mock integration returns preflight headers from API Gateway. The Lambda function also sets `Access-Control-Allow-Origin: *` on every response. Both are needed — the preflight response comes from the gateway, the actual response headers come from Lambda.

- **CloudFront enforces HTTPS.** The viewer protocol policy is `redirect-to-https`, so HTTP requests are automatically upgraded.

---

## Cost Analysis

**CloudFront**: The free tier includes 1 TB of data transfer and 10 million requests per month. A learning project will not approach these limits.

**S3**: Storage for three small files is effectively free. The free tier covers 5 GB of standard storage, 20,000 GET requests, and 2,000 PUT requests.

**API Gateway**: The free tier includes 1 million REST API calls per month for the first 12 months. After that, $3.50 per million requests in `eu-west-3`.

**Lambda**: The free tier includes 1 million requests and 400,000 GB-seconds per month (perpetual, not just first 12 months). A 128 MB function with a 10-second timeout would need to run over 3 million seconds to exceed the free tier.

**DynamoDB**: On-demand pricing is $1.25 per million write request units and $0.25 per million read request units. The free tier covers 25 WRUs and 25 RRUs per second perpetually. For a demo with occasional manual requests, cost is zero.

**Summary**: This project runs entirely within the free tier for typical usage. If left idle, the only potential cost is CloudFront if the distribution receives unexpected traffic, but even that is covered by the free tier up to 1 TB/month.

---

## Key Takeaways

- **Serverless does not mean no infrastructure.** There are still S3 bucket policies, IAM roles, API Gateway resources, and CloudFront distributions to configure correctly. The operational burden shifts from managing servers to managing configuration and permissions.

- **Origin Access Control is the modern way to connect CloudFront to S3.** It replaces Origin Access Identity and uses SigV4 signing. The bucket policy references the CloudFront distribution ARN directly rather than a special OAI principal.

- **`AWS_PROXY` integration simplifies Lambda responses.** With proxy integration, the Lambda function controls the full HTTP response (status code, headers, body). Without it, you would need to configure method responses, integration responses, and mapping templates in API Gateway, significantly more configuration for the same result.

- **CORS requires handling at both preflight and response level.** The OPTIONS mock integration handles browser preflight requests at the gateway level. But the actual GET response also needs CORS headers, and with `AWS_PROXY` integration those must come from the Lambda function itself.

- **Go on Lambda with `provided.al2023` gives fast cold starts.** The custom runtime compiles to a single static binary. There is no language runtime to initialise (unlike Python, Node, or Java), so cold start times are minimal.

- **DynamoDB `PAY_PER_REQUEST` is ideal for unpredictable or low traffic.** No capacity planning, no throttling surprises, and no cost when idle. For a learning project or any workload with spiky traffic, on-demand billing avoids the complexity of provisioned capacity.

- **The `data.archive_file` data source keeps Lambda packaging inside Terraform.** Instead of building and zipping the binary externally, Terraform handles the zip creation. The `source_code_hash` ensures the function is updated whenever the binary changes.

- **API Gateway deployments need explicit triggers.** Without the `sha1` trigger on resource IDs, Terraform would not redeploy the API when methods or integrations change. The `create_before_destroy` lifecycle ensures no downtime during redeployment.
