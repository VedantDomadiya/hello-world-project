variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_count" {
  description = "Number of public subnets to create across AZs"
  type        = number
  default     = 2
}

variable "private_subnet_count" {
  description = "Number of private subnets to create across AZs (should match public for AZ coverage)"
  type        = number
  default     = 2
}