output "ecr_repository_url" {
  description = "URL of the ECR repository created"
  value       = module.ecs.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster created"
  value       = module.ecs.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service created"
  value       = module.ecs.ecs_service_name
}

output "ecs_task_definition_family" {
  description = "Family name of the primary ECS task definition"
  value       = module.ecs.ecs_task_definition_family
}

output "rds_instance_endpoint" {
  description = "The connection endpoint of the RDS instance"
  value       = module.rds.db_instance_endpoint
}

output "rds_instance_port" {
  description = "The port of the RDS instance"
  value       = module.rds.db_instance_port
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = module.rds.db_secret_arn
  sensitive   = true
}

# Removed direct db_password output - use Secrets Manager ARN
# output "db_password" {
#   description = "The generated database password (use Secrets Manager!)"
#   value = module.rds.db_generated_password # Value comes from RDS module output
#   sensitive = true
# }

output "ecs_task_public_ip_example_command" {
  description = "Example command to get the public IP of a running task"
  value = module.ecs.ecs_task_public_ip_example_command
}

output "database_name" {
    description = "Name of database created"
    value = module.rds.db_name
}

output "database_username" {
    description = "Username of database created"
    value = module.rds.db_username
}