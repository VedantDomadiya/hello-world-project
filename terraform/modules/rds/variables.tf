variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "hello-world"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_id" {
  description = "ID of the VPC where the RDS instance will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB Subnet Group"
  type        = list(string)
}

# variable "ecs_tasks_sg_id" {
#   description = "The ID of the Security Group used by ECS tasks to allow ingress from"
#   type        = string
# }

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database master username"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS instance in GB"
  type        = number
}

variable "db_engine" {
  description = "Database engine (e.g., postgres, mysql)"
  type        = string
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "db_multi_az" {
  description = "Specifies if the RDS instance is multi-AZ"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before deleting"
  type        = bool
  default     = true # Be cautious in production
}