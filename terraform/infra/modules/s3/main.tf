terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "s3_bucket_raw" {
  bucket = var.bucket_raw_name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-raw-${var.environment}"
    }
  )
}

resource "aws_s3_bucket" "s3_bucket_scripts" {
  bucket = var.bucket_scripts_name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-scripts-${var.environment}"
    }
  )
}

resource "aws_s3_bucket" "s3_bucket_curated" {
  bucket = var.bucket_curated_name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-curated-${var.environment}"
    }
  )
}