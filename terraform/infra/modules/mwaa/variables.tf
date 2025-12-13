variable "environment_name" {
  description = "Nome do ambiente para uso em tags e identificadores"
  type        = string
  default     = "mwaa-environment"
}

variable "s3_bucket_arn" {
  description = "ARN do bucket S3 para armazenar DAGs"
  type        = string
}

variable "airflow_version" {
  description = "Versao do Apache Airflow"
  type        = string
  default     = "2.10.3"
}

variable "environment_class" {
  description = "Classe do ambiente MWAA"
  type        = string
  default     = "mw1.small"
}

variable "min_workers" {
  description = "Numero minimo de workers"
  type        = number
  default     = 1
}

variable "max_workers" {
  description = "Numero maximo de workers"
  type        = number
  default     = 5
}

variable "webserver_access_mode" {
  description = "Modo de acesso ao WebServer"
  type        = string
  default     = "PUBLIC_ONLY"
}

variable "aws_profile" {
  description = "AWS CLI profile para upload de arquivos"
  type        = string
  default     = "default"
}

variable "vpc_id" {
  description = "VPC ID para o MWAA"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas para o MWAA"
  type        = list(string)
}
