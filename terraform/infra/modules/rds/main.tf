resource "random_password" "rds_password" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+{}[]:;<>,.?"
  upper            = true
  lower            = true
  numeric          = true
}


resource "aws_secretsmanager_secret" "rds_secret" {
  name = var.secret_name
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rds_secret_version" {
  secret_id     = aws_secretsmanager_secret.rds_secret.id
  secret_string = jsonencode({
    username = var.username
    password = random_password.rds_password.result
    host     = aws_rds_cluster.aurora_cluster.endpoint
    port     = aws_rds_cluster.aurora_cluster.port
    dbname   = var.db_name
  })
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "${var.db_name}-sg"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.db_name}-sg"
    Environment = "dev"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.db_name}-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_rds_cluster_parameter_group" "aurora_zero_etl_pg" {
  name        = "aurora-zero-etl-pg"
  family      = "aurora-postgresql16"
  description = "Parameter group for Aurora PostgreSQL with Zero-ETL enabled"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "aurora.enhanced_logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "aurora.logical_replication_backup"
    value        = "0"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "aurora.logical_replication_globaldb"
    value        = "0"
    apply_method = "pending-reboot"
  }
}

resource "aws_rds_cluster" "aurora_cluster" {
  engine               = var.engine
  engine_version       = var.engine_version
  cluster_identifier   = var.db_name
  master_username      = var.username
  master_password      = random_password.rds_password.result
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_zero_etl_pg.name
  skip_final_snapshot = true

  tags = {
    Name = var.db_name
    Environment = "dev"
  }
}


# Instância de cluster Aurora (Writer only)
resource "aws_rds_cluster_instance" "aurora_instance" {
  cluster_identifier      = aws_rds_cluster.aurora_cluster.cluster_identifier
  instance_class          = var.instance_class 
  engine                  = var.engine
  engine_version          = var.engine_version
  publicly_accessible     = var.publicly_accessible
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.db_name}-instance"
    Environment = "dev"
  }
}