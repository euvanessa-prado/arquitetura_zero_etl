

output "s3_bucket_raw_name" {
  value       = aws_s3_bucket.s3_bucket_raw.id
  description = "Name of the raw data S3 bucket"
}


output "s3_bucket_scripts_name" {
  value       = aws_s3_bucket.s3_bucket_scripts.id
  description = "Name of the scripts S3 bucket"
}

output "s3_bucket_curated_name" {
  value       = aws_s3_bucket.s3_bucket_curated.id
  description = "Name of the curated data S3 bucket"
}
