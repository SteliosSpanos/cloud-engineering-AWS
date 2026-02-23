resource "aws_kms_key" "db_key" {
  description             = "KMS key for database encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.kms_policy.json
}
