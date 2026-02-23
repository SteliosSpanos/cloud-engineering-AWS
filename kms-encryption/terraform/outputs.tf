output "table_arn" {
  value       = [for table in aws_dynamodb_table.tables : table.arn]
  description = "The ARN of the DynamoDB table"
}
