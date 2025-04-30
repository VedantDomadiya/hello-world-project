terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0" # Consider updating to ~> 5.0 if compatible
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1" # Add random provider
    }
  }
}

provider "aws" {
  region = var.aws_region
}