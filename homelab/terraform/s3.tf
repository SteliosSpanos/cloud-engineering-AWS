resource "aws_s3_bucket" "homelab" {
  bucket = "${var.project_name}-storage-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-storage"
  }
}

resource "aws_s3_bucket_versioning" "homelab" {
  bucket = aws_s3_bucket.homelab.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "homelab" {
  bucket = aws_s3_bucket.homelab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "homelab" {
  bucket = aws_s3_bucket.homelab.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "homelab" {
  bucket = aws_s3_bucket.homelab.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonSSLTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.homelab.arn,
          "${aws_s3_bucket.homelab.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.homelab_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = [
    aws_route_table.homelab_private_rt.id
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowHomelabBucket"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.homelab.arn,
          "${aws_s3_bucket.homelab.arn}/*"
        ]
      },
      {
        Sid       = "AllowAWSServiceBuckets"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          "arn:aws:s3:::aws-ssm-${var.region}/*",
          "arn:aws:s3:::amazon-ssm-${var.region}/*",
          "arn:aws:s3:::amazon-ssm-packages-${var.region}/*",
          "arn:aws:s3:::${var.region}-birdwatcher-prod/*",
          "arn:aws:s3:::aws-ssm-document-attachments-${var.region}/*",
          "arn:aws:s3:::aws-ssm-distributor-file-${var.region}/*",
          "arn:aws:s3:::patch-baseline-snapshot-${var.region}/*",
          "arn:aws:s3:::amazoncloudwatch-agent-${var.region}/*"
        ]
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "homelab" {
  bucket = aws_s3_bucket.homelab.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.homelab.arn
    }
    bucket_key_enabled = true
  }
}
