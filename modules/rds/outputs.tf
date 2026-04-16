output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db.arn
}

output "db_endpoint" {
  description = "Hostname of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Port the DB is listening on"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Name of the initial database"
  value       = var.db_name
}
