variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name to be used for tagging"
  type        = string
  default     = "hello-world"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

# --- New RDS Variables ---
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "webappdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin"
  # Note: Avoid default passwords. We'll generate one.
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro" # Choose an appropriate instance type
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS instance in GB"
  type        = number
  default     = 20
}

variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "postgres" # Or "mysql", etc.
}

variable "db_engine_version" {
    description = "Database engine version"
    type        = string
    default     = "17" # Use a relevant version for your engine
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432 # Default for PostgreSQL
  # default     = 3306 # Default for MySQL
}
# --- End New RDS Variables ---