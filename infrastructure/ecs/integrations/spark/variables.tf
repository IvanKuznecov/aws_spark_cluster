variable name_prefix  {
  description = "Name prefix for resources"
  type = string
}

variable aws_region  {
  description = "AWS region"
  type        = string
}

variable ecs_cluster_id  {
  description = "ECS Cluster ID"
  type        = string
}

variable vpc_id  {
  description = "Selected VPC id"
  type        = string
}

variable private_subnet_ids  {
  description = "Private subnets list"
  type        = list(string)
}

variable ecs_main_task_cpu  {
  description = "CPU for ECS cluster main task"
  type        = number
}

variable ecs_main_task_memory  {
  description = "Memory for ECS cluster main task"
  type        = number
}

variable load_balancer_dns_name  {
  description = "Load Balancer DNS Name"
  type = string
}

variable load_balancer_arn  {
  description = "Load Balancer ARN"
  type = string
}

variable main_efs_id  {
  description = "Main elastic file system Id"
  type = string
}

variable ecs_task_execution_role_arn  {
  description = "Task Execution Role ARN"
  type = string
}

variable ecs_task_role_arn  {
  description = "Task Role ARN"
  type = string
}

variable "spark_master_port" {
  description = "Port for Spark master"
  type        = number
  default     = 7077
}

variable "spark_webui_port" {
  description = "Port for Spark master WebUI"
  type        = number
  default     = 8080
}

variable "spark_api_port" {
  description = "Port for Spark REST API"
  type        = number
  default     = 6066
}

variable spark_history_port  {
  description = "Spark History Port"
  type = number
  default = 18080
}