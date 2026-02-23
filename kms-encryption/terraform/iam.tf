resource "aws_iam_policy" "dynamodb_read_write" {
  name        = "${var.project_name}-policy"
  description = "Allows read/write access to the table"

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

resource "aws_iam_user" "test_user" {
  name = var.test_user_name
}

resource "aws_iam_user_policy_attachment" "test_user_dynamodb" {
  user       = aws_iam_user.test_user.name
  policy_arn = aws_iam_policy.dynamodb_read_write.arn
}
