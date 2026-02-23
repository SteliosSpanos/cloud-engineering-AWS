locals {
  tables = {
    "ContentCatalog" = { pk = "Id", pk_type = "N", rk = null, rk_type = null }
    "Forum"          = { pk = "Name", pk_type = "S", rk = null, rk_type = null }
    "Post"           = { pk = "ForumName", pk_type = "S", rk = "Subject", rk_type = "S" }
    "Comment"        = { pk = "Id", pk_type = "S", rk = "CommentDateTime", rk_type = "S" }
  }
}

resource "aws_dynamodb_table" "tables" {
  for_each       = local.tables
  name           = each.key
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1

  hash_key  = each.value.pk
  range_key = each.value.rk

  attribute {
    name = each.value.pk
    type = each.value.pk_type
  }

  dynamic "attribute" {
    for_each = each.value.rk != null ? [1] : []
    content {
      name = each.value.rk
      type = each.value.rk_type
    }
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.db_key.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-tables"
  }
}
