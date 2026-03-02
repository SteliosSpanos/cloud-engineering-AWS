resource "aws_iam_role" "jump_box" {
  name               = "${var.project_name}-jump-box-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jump_box_cloudwatch" {
  role       = aws_iam_role.jump_box.name
  policy_arn = aws_iam_policy.jump_box_cloudwatch.arn
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
  policy_arn = aws_iam_policy.nat_instance_cloudwatch.arn
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
  policy_arn = aws_iam_policy.main_vm_cloudwatch.arn
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
  policy_arn = aws_iam_policy.web_app_cloudwatch.arn
}

resource "aws_iam_role_policy_attachment" "web_app_ssm" {
  role       = aws_iam_role.web_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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
      }
    ]
  })
}

resource "aws_iam_policy" "jump_box_cloudwatch" {
  name        = "${var.project_name}-jump-box-cloudwatch-policy"
  description = "Allow jump box to write to its own CloudWatch log group"

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
          aws_cloudwatch_log_group.jump_box.arn,
          "${aws_cloudwatch_log_group.jump_box.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "nat_instance_cloudwatch" {
  name        = "${var.project_name}-nat-instance-cloudwatch-policy"
  description = "Allow nat instance to write to its own CloudWatch log group"

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
          aws_cloudwatch_log_group.nat_instance.arn,
          "${aws_cloudwatch_log_group.nat_instance.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "main_vm_cloudwatch" {
  name        = "${var.project_name}-main-vm-cloudwatch-policy"
  description = "Allow main vm to write to its own CloudWatch log group"

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
          aws_cloudwatch_log_group.main_vm.arn,
          "${aws_cloudwatch_log_group.main_vm.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "web_app_cloudwatch" {
  name        = "${var.project_name}-web-app-cloudwatch-policy"
  description = "Allow web app to write to its own CloudWatch log group"

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
          aws_cloudwatch_log_group.web_app.arn,
          "${aws_cloudwatch_log_group.web_app.arn}:*"
        ]
      }
    ]
  })
}
