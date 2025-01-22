variable name_prefix  {
  description = "Name prefix for resources"
  type = string
}

variable vpc_id  {
  description = "Selected VPC id"
  type        = string
}

variable public_subnet_ids  {
  description = "Public subnets list"
  type        = list(string)
}

# variable domain_name  {
#   description = "Domain name for the project"
#   type        = string
# }

# variable certified_domain_name  {
#   description = "Domain name to be used for SSL certificate"
#   type        = string
# }