output "cloudfront_url" {
  value       = "https://${aws_cloudfront_distribution.app.domain_name}"
  description = "CloudFront distribution URL"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.app.id
  description = "CloudFront distribution ID for chache invalidation"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.app.arn
  description = "S3 bucket ARN"
}

output "api_gateway_url" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/users"
  description = "API Gateway endpoint URL for /users"
}

output "table_arn" {
  value       = aws_dynamodb_table.user_data.arn
  description = "The ARN of the DynamoDB table"
}
