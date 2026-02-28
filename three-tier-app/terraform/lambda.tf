resource "aws_lambda_function" "get_user_data" {
  function_name = "${var.project_name}-get-user-data"
  filename      = data.archive_file.lambda_zip.output_path

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = ["x86_64"]

  role = aws_iam_role.lambda_role.arn

  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      REGION     = var.region
      TABLE_NAME = var.table_name
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "aws/lambda/${aws_lambda_function.get_user_data.function_name}"
  retention_in_days = 14
}
