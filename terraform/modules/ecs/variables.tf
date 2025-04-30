variable "project_name" {
  description = "Project name for tagging and naming resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where ECS resources will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ECS service network configuration"
  type        = list(string)
}

/*
variable "rds_sg_id" {
  description = "The ID of the Security Group used by the RDS instance"
  type        = string
}

variable "db_port" {
  description = "The port the database listens on (for security group rule)"
  type        = number
}
*/

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  type        = string
}

variable "container_image_uri" {
  description = "URI of the Docker image to deploy (e.g., from ECR)"
  type        = string
  # Example: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/hello-world-app:latest
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "desired_task_count" {
  description = "Number of tasks to run in the service"
  type        = number
  default     = 1
}

variable "assign_public_ip" {
  description = "Assign public IP to tasks (needed without a load balancer)"
  type        = bool
  default     = true
}