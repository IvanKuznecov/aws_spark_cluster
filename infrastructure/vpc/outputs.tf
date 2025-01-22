output main_vpc_id  {
  description = "Main VPC id"
  value       = aws_vpc.main_vpc.id
}

output private_subnet_ids  {
  description = "Private subnet list"
  value       = [for subnet in values(aws_subnet.private_subnet) : subnet.id]
}

output public_subnet_ids  {
  description = "Public subnet list"
  value       = [for subnet in values(aws_subnet.public_subnet) : subnet.id]
}