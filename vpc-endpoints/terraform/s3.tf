resource "aws_s3_bucket" "test-bucket" {
  bucket = "${var.project_name}-storage-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-storage"
  }
}

resource "aws_s3_bucket_versioning" "test-bucket" {
  bucket = aws_s3_bucket.test-bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "test-bucket" {
  bucket = aws_s3_bucket.test-bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "test-bucket" {
  bucket = aws_s3_bucket.test-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.test-vpc.id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = [aws_route_table.test-route-table.id]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

resource "aws_s3_bucket_policy" "test-bucket" {
  bucket = aws_s3_bucket.test-bucket.id
  depends_on = [aws_s3_bucket_public_access_block.test-bucket]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyIfNotFromVPCEndpoint"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.test-bucket.arn,
          "${aws_s3_bucket.test-bucket.arn}/*"
        ]
        Condition = {
          StringNotEqualsIfExists = {
            "aws:sourceVpce" = aws_vpc_endpoint.s3.id
          }
          ArnNotLike = {
            "aws:PrincipalArn" = data.aws_caller_identity.current.arn
          }
        }
      }
    ]
  })
}