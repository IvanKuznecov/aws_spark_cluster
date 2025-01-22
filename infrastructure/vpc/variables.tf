
variable name_prefix  {
  description = "Name prefix for resources"
  type = string
}

variable aws_region  {
  description = "AWS region"
  type        = string
}

variable availability_zones  {
  description = "AWS availability zones to use"
  type        = list(string)
}

variable base_cidr  {
  description = "Base CIDR block for the VPC"
  type        = string
}

variable private_subnet_cidr  {
  description = "Private subnet list"
  type = list(string)
}