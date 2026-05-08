output "db_instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.postgres.id
}

output "db_endpoint" {
  description = "RDS instance endpoint."
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  description = "RDS instance port."
  value       = aws_db_instance.postgres.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.postgres.db_name
}

output "db_security_group_id" {
  description = "Security group protecting the RDS instance."
  value       = aws_security_group.rds.id
}

output "db_secret_arn" {
  description = "Secrets Manager ARN containing the database credentials and SQLAlchemy URL."
  value       = aws_secretsmanager_secret.db.arn
}

output "sqlalchemy_database_url" {
  description = "SQLAlchemy connection URL for the backend."
  value       = "postgresql+psycopg://${var.db_username}:${urlencode(random_password.db_password.result)}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}"
  sensitive   = true
}
