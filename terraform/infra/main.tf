/* ####COMANDO PARA EXECUCAO DO TERRAFORM
cd terraform/infra
terraform apply -var-file=envs/develop.tfvars
terraform init -backend-config="backends/develop.hcl"
terraform destroy -var-file=envs/develop.tfvars
*/

###############################################################################
#########             VPC E SUBNETS                               #############
###############################################################################
module "vpc" {
  source                = "./modules/vpc"
  project_name          =  var.project_name
  vpc_name              = "data-handson-mds-vpc-${var.environment}"
  vpc_cidr              = "10.0.0.0/16"
  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs  = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones    = ["us-east-1a", "us-east-1b"]
}

##############################################################################
########             S3 - DATA LAKE                              #############
##############################################################################
module "s3" {
  source = "./modules/s3"

  project_name        = var.project_name
  environment         = var.environment
  bucket_raw_name     = var.s3_bucket_raw
  bucket_scripts_name = var.s3_bucket_scripts
  bucket_curated_name = var.s3_bucket_curated
}

###############################################################################
#########             RDS - POSTGRES                              #############
###############################################################################
module "rds" {
  source = "./modules/rds"
  project_name         =  var.project_name
  db_name              = "transactional"
  username             = "datahandsonmds"
  secret_name          = "datahandsonmds-database-${var.environment}"
  allocated_storage    = 300
  engine               = "aurora-postgresql"
  engine_version       = "16.4"
  instance_class       = "db.t4g.large"
  publicly_accessible  = false
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids

  ingress_rules = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }
  ]
}


##############################################################################
########             REDSHIFT                                    #############
##############################################################################

module "redshift" {
  source              = "./modules/redshift"

  cluster_identifier  = "data-handson-mds"
  database_name       = "datahandsonmds"
  master_username     = "admin"
  node_type           = "ra3.large"
  cluster_type        = "single-node"
  number_of_nodes     = 1
  publicly_accessible = false
  subnet_ids          = module.vpc.private_subnet_ids
  vpc_id              = module.vpc.vpc_id
  allowed_ips         = ["10.0.0.0/16"]
}


##############################################################################
########             S3 - MWAA BUCKET                            #############
##############################################################################
resource "aws_s3_bucket" "mwaa_bucket" {
  bucket = "data-handson-mds-mwaa-${var.environment}"

  tags = {
    Name        = "data-handson-mds-mwaa-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "mwaa_bucket_versioning" {
  bucket = aws_s3_bucket.mwaa_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "mwaa_bucket_public_access" {
  bucket = aws_s3_bucket.mwaa_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

##############################################################################
########             AIRFLOW - MWAA                              #############
##############################################################################
module "mwaa" {
  source                = "./modules/mwaa"
  environment_name      = "datahandson-mds-mwaa-v2"
  s3_bucket_arn         = aws_s3_bucket.mwaa_bucket.arn
  airflow_version       = "2.10.3"
  environment_class     = "mw1.small"
  min_workers           = 1
  max_workers           = 2
  webserver_access_mode = "PUBLIC_ONLY"
  aws_profile           = "zero-etl-project"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
}
##############################################################################
########             INSTANCIAS EC2                              #############
##############################################################################
module "ec2_instance" {
  source              = "./modules/ec2"
  ami_id              = "ami-04b4f1a9cf54c11d0"
  instance_type       = "t3a.2xlarge"
  subnet_id           = module.vpc.public_subnet_ids[0]
  vpc_id              = module.vpc.vpc_id
  associate_public_ip = true
  instance_name       = "data-handson-mds-ec2-${var.environment}"

  user_data = templatefile("${path.module}/scripts/bootstrap/ec2_bootstrap.sh", {})

  ingress_rules = [
    # SSH - Opcional (comentar para usar SSM)
    # {
    #   from_port   = 22
    #   to_port     = 22
    #   protocol    = "tcp"
    #   cidr_blocks = ["0.0.0.0/0"]
    # },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}