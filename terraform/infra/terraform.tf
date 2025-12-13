terraform {
  backend "s3" {
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    
  }
}

provider "aws" {
  region  = var.region
  profile = "zero-etl-project"
  default_tags {
    tags = {
      Project     = "DataHandsOn-MDS"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DataTeam"
      Application = "ModernDataStack"
    }
  }
}

