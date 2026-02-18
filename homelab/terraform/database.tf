resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.homelab_private_subnet.id]
}

resource "aws_db_parameter_group" "postgres" {
  family = "postgres15"
  name   = "${var.project_name}-db-pg"
}

resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "15.16"
  instance_class = var.db_instance_class

  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  storage_encrypted       = true
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = 1
  multi_az                = false

  tags = {
    Name = "${var.project_name}-db"
  }
}