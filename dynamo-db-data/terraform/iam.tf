resource "aws_iam_policy" "dynamodb_read_write" {
  name        = "${var.project_name}-policy"
  description = "Allows read/write access to the students table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        Effect   = "Allow",
        Resource = [for table in aws_dynamodb_table.tables : table.arn]
      }
    ]
  })
}
