terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    virtualbox = {
      source = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
  }
}

variable "environment" {
  description = "Deployment environment (local or aws)"
  type        = string
  default     = "local"
}

locals {
  app_name = "infra-simulation-app"
  vpc_cidr = "10.0.0.0/16"
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
}