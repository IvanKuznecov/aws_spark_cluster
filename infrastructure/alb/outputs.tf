
output load_balancer_dns_name  {
    description = "Load Balancer DNS Name"
    value = aws_alb.network_load_balancer.dns_name
}

output load_balancer_arn  {
    description = "ECS target group for MQTT ARN"
    value = aws_alb.network_load_balancer.arn
}
