variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "data-handson-mds"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "bucket_raw_name" {
  description = "Name of the S3 bucket for raw data"
  type        = string
  default     = "cjmm-datalake-mds-raw"
}

variable "bucket_scripts_name" {
  description = "Name of the S3 bucket for scripts"
  type        = string
  default     = "cjmm-datalake-mds-configs"
}

variable "bucket_curated_name" {
  description = "Name of the S3 bucket for curated data"
  type        = string
  default     = "cjmm-datalake-mds-curated"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "DataHandsOn-MDS"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
