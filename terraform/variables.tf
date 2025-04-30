variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name to be used for tagging and resource naming"
  type        = string
  default     = "hello-world"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

# --- Network Module Variables ---
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# --- RDS Module Variables ---
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "webappdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS instance in GB"
  type        = number
  default     = 20
}

variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  # Updated default to a common PostgreSQL version. Adjust if using MySQL etc.
  default     = "17" # Example: check available versions for db.t3.micro in ap-south-1
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432 # Default for PostgreSQL
}

# --- ECS Module Variables ---
# The ECR repository URL depends on the account and region,
# so we construct it in main.tf using the ECR module output.
# We'll add a variable for the image tag.
variable "container_image_tag" {
  description = "Tag of the Docker image to deploy"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 80
}