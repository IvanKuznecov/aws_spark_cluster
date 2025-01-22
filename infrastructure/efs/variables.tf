variable name_prefix  {
  description = "Name prefix for resources"
  type = string
}

variable vpc_id  {
  description = "Selected VPC id"
  type        = string
}

variable private_subnet_ids  {
  description = "Private subnets list"
  type        = list(string)
}