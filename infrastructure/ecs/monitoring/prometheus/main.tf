# Prometheus Task and Service
resource aws_ecs_task_definition prometheus_task  {
  family                   = "${var.name_prefix}-prometheus-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_main_task_cpu
  memory                   = var.ecs_main_task_memory

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      essential = true
      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
                  }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.prometheus_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      mountpoints = [
        {
          sourceVolume = "prometheus-data"
          containerPath = "/prometheus"
          readonly = false
        }
      ]
    }
  ])

  volume {
    name = "prometheus-data"
    efs_volume_configuration {
      file_system_id          = var.main_efs_id
      root_directory          = "/prometheus"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.prometheus_etc_efs_access_point.id
        iam             = "ENABLED"
      }
    }
  }
}

resource aws_ecs_service prometheus_service  {
  name            = "${var.name_prefix}-prometheus-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.prometheus_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups = [aws_security_group.prometheus_security_group.id]    
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_prometheus_target_group.arn
    container_name   = "prometheus"
    container_port   = 9090
  }
}

resource aws_security_group prometheus_security_group  {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict as needed for production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-prometheus-sg"
  }
}

resource aws_efs_access_point prometheus_etc_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/prometheus/etc"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-prometheus-etc-efs-access-point"
  }
}

resource aws_cloudwatch_log_group prometheus_log_group  {
  name              = "/ecs/${var.name_prefix}-prometheus"
  retention_in_days = 7
  tags = {
    Name = "${var.name_prefix}-prometheus-log-group"
  }
}

resource aws_lb_target_group ecs_prometheus_target_group  {
  name = "${var.name_prefix}-prom-tg"

  port        = "9090" # Prometheus
  protocol    = "TCP"
  target_type = "ip"

  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-prom-tg"
  }
}

resource aws_lb_listener prometheus_nlb_listener  {
  load_balancer_arn = var.load_balancer_arn
  port = "9090" # Prometheus
  protocol = "TCP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ecs_prometheus_target_group.arn
  }
}