#
#
# Network Load Balancer
#
#
# This module defines the configuration for an AWS Network Load Balancer (NLB)
# to manage traffic routing for MQTT and EMQX services. The module includes
# target groups, listeners, and security group rules to ensure proper routing
# of traffic to the respective ports.
#
# It is designed for applications requiring low-latency TCP-based communication,
# such as MQTT brokers and management interfaces. Users should ensure that the
# specified VPC and subnets align with their network architecture and that
# security group rules are appropriately restricted for production environments.
#

resource aws_alb network_load_balancer {
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.name_prefix}-nlb"
  }
}

# # Generate signed certificate
# resource aws_acm_certificate ssl_certificate {
#   domain_name = var.certified_domain_name

#   validation_method = "EMAIL"
#   validation_option {
#     domain_name       = var.certified_domain_name
#     validation_domain = var.domain_name
#   }


#   lifecycle {
#     create_before_destroy = true
#   }

#   tags = {
#     Name = "${name_prefix}-cert"
#   }

# }