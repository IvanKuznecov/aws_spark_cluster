# grafana Task and Service
resource aws_ecs_task_definition grafana_task  {
  family                   = "${var.name_prefix}-grafana-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_main_task_cpu
  memory                   = var.ecs_main_task_memory

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = "grafana/grafana:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.grafana_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      mountPoints = [
        {
          sourceVolume  = "grafana-data"
          containerPath = "/var/lib/grafana"
          readOnly      = false
        }
      ]
    }
  ])

  volume {
    name = "grafana-data"
    efs_volume_configuration {
      file_system_id          = var.main_efs_id
      root_directory          = "/grafana"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.grafana_efs_access_point.id
        iam             = "ENABLED"
      }
    }
  }
}

resource aws_ecs_service grafana_service  {
  name            = "${var.name_prefix}-grafana-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.grafana_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.grafana_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_grafana_target_group.arn
    container_name   = "grafana"
    container_port   = 3000
  }
}

resource aws_security_group grafana_security_group  {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
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
    Name = "${var.name_prefix}-grafana-sg"
  }
}

resource aws_efs_access_point grafana_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/grafana"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-grafana-efs-access-point"
  }
}

resource aws_cloudwatch_log_group grafana_log_group  {
  name              = "/ecs/${var.name_prefix}-grafana"
  retention_in_days = 7
  tags = {
    Name = "${var.name_prefix}-grafana-log-group"
  }
}

resource aws_lb_target_group ecs_grafana_target_group  {
  name = "${var.name_prefix}-graf-tg"

  port        = "3000" # Grafana default port
  protocol    = "TCP"
  target_type = "ip"

  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-graf-tg"
  }
}

resource aws_lb_listener grafana_nlb_listener  {
  load_balancer_arn = var.load_balancer_arn
  port              = "3000" # Grafana default port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_grafana_target_group.arn
  }
}