output "db_instance_endpoint" {
  description = "The connection endpoint for the database instance"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_port" {
  description = "The port on which the database instance is listening"
  value       = aws_db_instance.main.port
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

# Consider if outputting the generated password is truly necessary.
# Relying on the secret ARN is generally more secure.
output "db_generated_password" {
  description = "The randomly generated database password (stored in Secrets Manager)"
  value       = random_password.db_password.result
  sensitive   = true
}

output "rds_sg_id" {
  description = "The ID of the security group created for the RDS instance"
  value       = aws_security_group.rds.id
}

output "db_name" {
    description = "The name of the database"
    value = aws_db_instance.main.db_name
}

output "db_username" {
    description = "The master username for the database"
    value = aws_db_instance.main.username
}