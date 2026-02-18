# -----------------------------------------------------------------------------
# WHY RDS POSTGRESQL INSTEAD OF AURORA POSTGRESQL
# -----------------------------------------------------------------------------
# The original design used Aurora PostgreSQL, which offers a distributed storage
# architecture, automatic replication across 3 AZs, and faster failover compared
# to standard RDS. However, Aurora has two key requirements that make it
# unsuitable for free tier / learning accounts:
#
#   1. It is NOT covered by the AWS free tier. Aurora requires a paid account or
#      a specific "Express" configuration (Serverless v2 with auto-pause) that
#      some account types restrict.
#
#   2. Provisioned Aurora instances (e.g. db.t3.medium) are more expensive and
#      cannot be stopped manually like regular RDS instances.
#
# -----------------------------------------------------------------------------
# TO USE AURORA INSTEAD: REQUIRED RESOURCES AND ATTRIBUTES
# -----------------------------------------------------------------------------
#
# Aurora uses a two-resource model: a CLUSTER (storage + config) and one or
# more INSTANCES (compute). Both are required — unlike RDS which is one resource.
# You also need a cluster-level parameter group instead of a DB parameter group.
#
# 1. aws_rds_cluster_parameter_group
#    Defines engine-level settings at the cluster layer.
#    Required attributes:
#      family = "aurora-postgresql15"   # must match engine version
#      name   = "<name>"
#
# 2. aws_rds_cluster
#    The cluster holds storage, credentials, networking, and engine config.
#    Required attributes:
#      cluster_identifier              = "<name>"
#      engine                          = "aurora-postgresql"
#      engine_version                  = "15.4"
#      database_name                   = "<db-name>"
#      master_username                 = "<username>"
#      master_password                 = "<password>"
#      db_subnet_group_name            = aws_db_subnet_group.<name>.name
#      vpc_security_group_ids          = [aws_security_group.<name>.id]
#      db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.<name>.name
#      storage_encrypted               = true
#      skip_final_snapshot             = true
#    For Serverless v2 Express (minimum cost on paid accounts):
#      serverlessv2_scaling_configuration {
#        min_capacity             = 0    # 0 enables auto-pause (Express mode)
#        max_capacity             = 1    # 1 ACU max to limit cost
#        seconds_until_auto_pause = 300  # pause after 5 min of inactivity
#      }
#
# 3. aws_rds_cluster_instance
#    The compute layer that connects to the cluster. Aurora requires at least one.
#    Required attributes:
#      cluster_identifier = aws_rds_cluster.<name>.id
#      engine             = aws_rds_cluster.<name>.engine
#      engine_version     = aws_rds_cluster.<name>.engine_version
#    For Serverless v2:
#      instance_class = "db.serverless"   # required when using serverlessv2_scaling_configuration
#    For provisioned (paid accounts, higher cost):
#      instance_class = "db.t3.medium"    # minimum supported class for Aurora PostgreSQL
#
# NOTE: The aws_db_subnet_group resource is shared between RDS and Aurora.
#       It requires subnet_ids from at least 2 different AZs — Aurora enforces
#       this strictly even if you only deploy one instance.
#
# NOTE: Terraform AWS provider >= 5.77 is required for min_capacity = 0
#       (Express mode). Older versions will ignore the flag and the AWS API
#       will reject the request with a FreeTierRestrictionError.
#
# -----------------------------------------------------------------------------
# For this learning project, RDS PostgreSQL (db.t3.micro) was used instead.
# It is free tier eligible (750 hrs/month, 20GB storage) and uses the same
# PostgreSQL engine, so the app connection logic is identical.
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "postgres" {
  name = "${var.project_name}-db-subnet-group"
  subnet_ids = [
    aws_subnet.test_private_subnet.id,
    aws_subnet.test_private_subnet_backup.id
  ]
}

resource "aws_db_parameter_group" "postgres" {
  family = "postgres15"
  name   = "${var.project_name}-db-pg"
}

resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "15.16"
  instance_class = "db.t3.micro"

  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.test_aurora_sg.id]
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
