resource "aws_cloudwatch_log_group" "jump_box" {
  name              = "/${var.project_name}/jumb-box"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-jump-box-logs"
  }
}

resource "aws_cloudwatch_log_group" "nat_instance" {
  name              = "/${var.project_name}/nat-instance"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-nat-instance-logs"
  }
}

resource "aws_cloudwatch_log_group" "main_vm" {
  name              = "/${var.project_name}/main-vm"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-main-vm-logs"
  }
}

resource "aws_cloudwatch_log_group" "web_app" {
  name              = "/${var.project_name}/web-app"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-web-app-logs"
  }
}
