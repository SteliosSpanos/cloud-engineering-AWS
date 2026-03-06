locals {
  instance_log_groups = {
    jump_box     = aws_cloudwatch_log_group.jump_box.arn
    nat_instance = aws_cloudwatch_log_group.nat_instance.arn
    main_vm      = aws_cloudwatch_log_group.main_vm.arn
    web_app      = aws_cloudwatch_log_group.web_app.arn
  }
}

resource "aws_iam_role" "jump_box" {
  name               = "${var.project_name}-jump-box-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jump_box_cloudwatch" {
  role       = aws_iam_role.jump_box.name
  policy_arn = aws_iam_policy.cloudwatch["jump_box"].arn
}

resource "aws_iam_role_policy_attachment" "jump_box_ssm" {
  role       = aws_iam_role.jump_box.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jump_box" {
  name = "${var.project_name}-jump-box-profile"
  role = aws_iam_role.jump_box.name
}


resource "aws_iam_role" "nat_instance" {
  name               = "${var.project_name}-nat-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "nat_instance_cloudwatch" {
  role       = aws_iam_role.nat_instance.name
  policy_arn = aws_iam_policy.cloudwatch["nat_instance"].arn
}

resource "aws_iam_role_policy_attachment" "nat_instance_ssm" {
  role       = aws_iam_role.nat_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat_instance" {
  name = "${var.project_name}-nat-instance-profile"
  role = aws_iam_role.nat_instance.name
}


resource "aws_iam_role" "main_vm" {
  name               = "${var.project_name}-main-vm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "main_vm_s3" {
  role       = aws_iam_role.main_vm.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_role_policy_attachment" "main_vm_cloudwatch" {
  role       = aws_iam_role.main_vm.name
  policy_arn = aws_iam_policy.cloudwatch["main_vm"].arn
}

resource "aws_iam_role_policy_attachment" "main_vm_ssm" {
  role       = aws_iam_role.main_vm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "main_vm" {
  name = "${var.project_name}-main-vm-profile"
  role = aws_iam_role.main_vm.name
}


resource "aws_iam_role" "web_app" {
  name               = "${var.project_name}-web-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "web_app_cloudwatch" {
  role       = aws_iam_role.web_app.name
  policy_arn = aws_iam_policy.cloudwatch["web_app"].arn
}

resource "aws_iam_role_policy_attachment" "web_app_ssm" {
  role       = aws_iam_role.web_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "web_app_secrets" {
  role       = aws_iam_role.web_app.name
  policy_arn = aws_iam_policy.web_app_secrets.arn
}

resource "aws_iam_instance_profile" "web_app" {
  name = "${var.project_name}-web-app-profile"
  role = aws_iam_role.web_app.name
}

resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-policy"
  description = "Allow main VM to access homelab S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
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
        Sid    = "AllowKMSForS3"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.homelab.arn
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch" {
  for_each    = local.instance_log_groups
  name        = "${var.project_name}-${replace(each.key, "_", "-")}-cloudwatch-policy"
  description = "Allow ${replace(each.key, "_", " ")} to write to its own CloudWatch log group"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          each.value,
          "${each.value}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "web_app_secrets" {
  name        = "${var.project_name}-web-app-secrets-policy"
  description = "Allow web app to read RDS master password from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_db_instance.postgres.master_user_secret[0].secret_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          aws_kms_key.homelab.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "vpc_flow_log" {
  name = "${var.project_name}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "vpc_flow_log" {
  name = "${var.project_name}-vpc-flow-log-policy"
  role = aws_iam_role.vpc_flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.vpc_flow_log.arn,
          "${aws_cloudwatch_log_group.vpc_flow_log.arn}:*"
        ]
      }
    ]
  })
}

moved {
  from = aws_iam_policy.jump_box_cloudwatch
  to   = aws_iam_policy.cloudwatch["jump_box"]
}

moved {
  from = aws_iam_policy.nat_instance_cloudwatch
  to   = aws_iam_policy.cloudwatch["nat_instance"]
}

moved {
  from = aws_iam_policy.main_vm_cloudwatch
  to   = aws_iam_policy.cloudwatch["main_vm"]
}

moved {
  from = aws_iam_policy.web_app_cloudwatch
  to   = aws_iam_policy.cloudwatch["web_app"]
}
