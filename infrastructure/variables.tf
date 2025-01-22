#
# Project and environment related information
#
locals {
  name_prefix = "${var.project}-${var.environment}" # This prefix is used for naming all resources in the project
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "gis-pov"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev" # Select 'prod' or 'dev'
}

variable "customer" {
  description = "Customer name"
  type        = string
  default     = "GIS"
}

#
# Tag definition
#
locals {
  tags = {
    Project     = "${var.project}"
    Environment = "${var.environment}"
    Customer    = "${var.customer}"
  }
}

#
# Master login information
#
# 'sensitive' flag hides variables from being exposed to the CLI, logs, etc.
#
# 2024/11/26 - NOTE FOR FUTURE REWORK - Additional measures to be taken to avoid exposure on source control.
#
locals {
  admin_user     = var.admin_user
  admin_password = var.admin_password
}

variable "admin_user" {
  description = "Admin username used in modules that need it to be declared"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "admin_password" {
  description = "Admin password used in modules that need it to be declared"
  type        = string
  default     = "Administrator1." # Use ate least: 12 characters, 1 capital letter, 1 lower letter, 1 digit, 1 special character
  sensitive   = true
}

#
# AWS region
#
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

#
# AWS availability zones
#
# Any amount of availability zones can be declared
# Module code adjusts in accordance to this
#
variable "availability_zones" {
  description = "AWS availability zones to use"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"] # Availability zones from 1 to n
}

#
# IP addresses
#
locals {
  # Count the total number of availability zones
  az_count = length(var.availability_zones)

  private_subnet_cidr = [
    for block in range(local.az_count) : cidrsubnet(var.base_cidr, 8, var.private_subnet_block_start + block)
  ]

}

variable "base_cidr" {
  description = "Base CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_block_start" {
  description = "The starting block for the first private subnet"
  type        = number
  default     = 101
}

#
# ECS Cluster resource definition
#
# - CPU
# - Memory
#
variable "ecs_main_task_cpu" {
  description = "CPU for ECS cluster main task"
  type        = number
  default     = 1024
}

variable "ecs_main_task_memory" {
  description = "Memory for ECS cluster main task"
  type        = number
  default     = 2048
}

#
# This domain will be considered issuing SSL certificate
#
# - Domain to be used
# - Validation by email
# 
variable "domain_name" {
  description = "Domain name for the project"
  type        = string
  default     = "gis.ie"
}

#
# Complete domain construction to issue SSL certificate
#
locals {
  subdomain_name        = "${var.project}-${var.environment}"
  certified_domain_name = "${local.subdomain_name}.${var.domain_name}" # This prefix is used for naming all resources in the project
}
