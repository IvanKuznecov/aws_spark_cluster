resource aws_ecs_cluster cluster  {
  name = "${var.name_prefix}-cluster"
}

# Roles
resource aws_iam_role ecs_task_execution_role  {
  name = "${var.name_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-ecs-task-execution-role"
  }
}

resource aws_iam_role ecs_task_role  {
  name = "${var.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-ecs-task-role"
  }
}

# Policies
resource aws_iam_policy efs_access_policy  {
  name = "${var.name_prefix}-efs-access-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource aws_iam_policy ecs_task_execution_log_policy  {
  name = "${var.name_prefix}-ecs-task-execution-log-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource aws_iam_policy ecs_exec_policy  {
  name = "${var.name_prefix}-ecs-exec-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Resource = "*"
      }
    ]
  })
}

# Policy Attachements
resource aws_iam_role_policy_attachment ecs_task_execution_policy  {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource aws_iam_role_policy_attachment ecr_container_access  {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource aws_iam_role_policy_attachment efs_access_policy_attachment  {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.efs_access_policy.arn
}

resource aws_iam_role_policy_attachment ecs_task_execution_log_policy_attachment  {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_log_policy.arn
}

resource aws_iam_role_policy_attachment ecs_exec_policy_attachment  {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_exec_policy.arn
}

resource aws_iam_role_policy_attachment ssm_managed_instance_policy  {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# module emqx  {
#   source = "./brokers/emqx"

#   name_prefix = var.name_prefix
#   aws_region  = var.aws_region

#   ecs_main_task_cpu    = var.ecs_main_task_cpu
#   ecs_main_task_memory = var.ecs_main_task_memory

#   vpc_id                 = var.vpc_id
#   private_subnet_ids     = var.private_subnet_ids
#   load_balancer_dns_name = var.load_balancer_dns_name
#   load_balancer_arn      = var.load_balancer_arn

#   main_efs_id            = var.main_efs_id

#   ecs_cluster_id              = aws_ecs_cluster.cluster.id
#   ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
#   ecs_task_role_arn           = aws_iam_role.ecs_task_role.arn
# }

module nodered  {
  source = "./integrations/nodered"

  name_prefix = var.name_prefix
  aws_region  = var.aws_region

  ecs_main_task_cpu    = var.ecs_main_task_cpu
  ecs_main_task_memory = var.ecs_main_task_memory

  vpc_id                 = var.vpc_id
  private_subnet_ids     = var.private_subnet_ids
  load_balancer_dns_name = var.load_balancer_dns_name
  load_balancer_arn      = var.load_balancer_arn

  main_efs_id            = var.main_efs_id

  ecs_cluster_id              = aws_ecs_cluster.cluster.id
  ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  ecs_task_role_arn           = aws_iam_role.ecs_task_role.arn
}

module timescaledb  {
  source = "./databases/timescaledb"

  name_prefix = var.name_prefix
  aws_region  = var.aws_region

  ecs_main_task_cpu    = var.ecs_main_task_cpu
  ecs_main_task_memory = var.ecs_main_task_memory

  vpc_id                 = var.vpc_id
  private_subnet_ids     = var.private_subnet_ids
  load_balancer_dns_name = var.load_balancer_dns_name
  load_balancer_arn      = var.load_balancer_arn

  main_efs_id            = var.main_efs_id

  ecs_cluster_id              = aws_ecs_cluster.cluster.id
  ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  ecs_task_role_arn           = aws_iam_role.ecs_task_role.arn
}

module spark  {
  source = "./integrations/spark"

  name_prefix = var.name_prefix
  aws_region  = var.aws_region

  ecs_main_task_cpu    = var.ecs_main_task_cpu
  ecs_main_task_memory = var.ecs_main_task_memory

  vpc_id                 = var.vpc_id
  private_subnet_ids     = var.private_subnet_ids
  load_balancer_dns_name = var.load_balancer_dns_name
  load_balancer_arn      = var.load_balancer_arn

  main_efs_id            = var.main_efs_id

  ecs_cluster_id              = aws_ecs_cluster.cluster.id
  ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  ecs_task_role_arn           = aws_iam_role.ecs_task_role.arn
}

# module influxdb  {
#   source = "./databases/influxdb"

#   name_prefix = var.name_prefix
#   aws_region  = var.aws_region

#   ecs_main_task_cpu    = var.ecs_main_task_cpu
#   ecs_main_task_memory = var.ecs_main_task_memory

#   vpc_id                 = var.vpc_id
#   private_subnet_ids     = var.private_subnet_ids
#   load_balancer_dns_name = var.load_balancer_dns_name
#   load_balancer_arn      = var.load_balancer_arn

#   main_efs_id            = var.main_efs_id

#   ecs_cluster_id              = aws_ecs_cluster.cluster.id
#   ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
#   ecs_task_role_arn           = aws_iam_role.ecs_task_role.arn
# }

# module mqtt_timescale_collector  {
#   source = "./integrations/mqtt_timescale_collector"

#   name_prefix = var.name_prefix
#   aws_region  = var.aws_region

#   ecs_main_task_cpu    = var.ecs_main_task_cpu
#   ecs_main_task_memory = var.ecs_main_task_memory

#   vpc_id                 = var.vpc_id
#   private_subnet_ids     = var.private_subnet_ids
#   load_balancer_dns_name = var.load_balancer_dns_name
#   load_balancer_arn      = var.load_balancer_arn

#   main_efs_id            = var.main_efs_id

#   ecs_cluster_id              = aws_ecs_cluster.cluster.id
#   ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
#   ecs_task_role_arn           = aws_iam_role.ecs_task_role.arn
# }

# module prometheus  {
#   source = "./monitoring/prometheus"

#   name_prefix = var.name_prefix
#   aws_region  = var.aws_region

#   ecs_main_task_cpu    = var.ecs_main_task_cpu
#   ecs_main_task_memory = var.ecs_main_task_memory

#   vpc_id                 = var.vpc_id
#   private_subnet_ids     = var.private_subnet_ids
#   load_balancer_dns_name = var.load_balancer_dns_name
#   load_balancer_arn      = var.load_balancer_arn

#   main_efs_id            = var.main_efs_id

#   ecs_cluster_id              = aws_ecs_cluster.cluster.id
#   ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
#   ecs_task_role_arn           = aws_iam_role.ecs_task_role.arn
# }

# module grafana  {
#   source = "./visualisations/grafana"

#   name_prefix = var.name_prefix
#   aws_region  = var.aws_region

#   ecs_main_task_cpu    = var.ecs_main_task_cpu
#   ecs_main_task_memory = var.ecs_main_task_memory

#   vpc_id                 = var.vpc_id
#   private_subnet_ids     = var.private_subnet_ids
#   load_balancer_dns_name = var.load_balancer_dns_name
#   load_balancer_arn      = var.load_balancer_arn

#   main_efs_id            = var.main_efs_id

#   ecs_cluster_id              = aws_ecs_cluster.cluster.id
#   ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
#   ecs_task_role_arn           = aws_iam_role.ecs_task_role.arn
# }