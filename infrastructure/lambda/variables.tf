variable name_prefix  {
  description = "Name prefix for resources"
  type = string
}

variable aws_region  {
  description = "AWS region"
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

variable load_balancer_dns_name  {
  description = "Load Balancer DNS Name"
  type = string
}

variable load_balancer_arn  {
  description = "Load Balancer ARN"
  type = string
}

#
# Path to connfig files and additional data. Must be changed to point to local folder.
#
variable data_path  {
  description = "Path to connfig files and additional data"
  type = string
}

variable lambda_bucket_name  {
  description = "S3 Bucket used by Lambda function"
  type = string
  default = "test-lambda-bucket"
}

variable lambda_code_file_key  {
  description = "S3 key for lambda function code"
  type = string
  default = "scripts/lambda_submit_spark_job.zip"
}
