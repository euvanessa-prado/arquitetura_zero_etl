# Security Group para MWAA
resource "aws_security_group" "mwaa_sg" {
  name_prefix = "mwaa-sg-"
  description = "Security Group para MWAA"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir trafego interno entre os componentes do MWAA
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Permitir acesso ao webserver
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow HTTPS access to webserver from VPC"
  }

  # Permitir acesso ao banco de dados do Airflow (porta 5432)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow PostgreSQL access for Airflow metadata DB"
  }

  tags = {
    Name        = "mwaa-sg"
    Environment = "dev"
  }
}

# Obter a regiao atual
data "aws_region" "current" {}

# Endpoints VPC necessarios para MWAA
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.mwaa_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "mwaa-ecr-api-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.mwaa_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "mwaa-ecr-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.mwaa_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "mwaa-logs-endpoint"
  }
}

resource "aws_vpc_endpoint" "monitoring" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.mwaa_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "mwaa-monitoring-endpoint"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.mwaa_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "mwaa-sqs-endpoint"
  }
}

resource "aws_vpc_endpoint" "airflow_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.airflow.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.mwaa_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "mwaa-airflow-api-endpoint"
  }
}

resource "aws_vpc_endpoint" "airflow_env" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.airflow.env"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.mwaa_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "mwaa-airflow-env-endpoint"
  }
}

resource "aws_vpc_endpoint" "airflow_ops" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.airflow.ops"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.mwaa_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "mwaa-airflow-ops-endpoint"
  }
}
