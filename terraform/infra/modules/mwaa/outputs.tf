output "mwaa_environment_arn" {
  description = "ARN do ambiente MWAA"
  value       = aws_mwaa_environment.mwaa_env.arn
}

output "mwaa_webserver_url" {
  description = "URL do webserver do Airflow"
  value       = aws_mwaa_environment.mwaa_env.webserver_url
}

output "mwaa_security_group_id" {
  description = "ID do security group do MWAA"
  value       = aws_security_group.mwaa_sg.id
}
