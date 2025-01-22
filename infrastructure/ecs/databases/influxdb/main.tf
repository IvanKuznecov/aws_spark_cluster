resource aws_ecs_task_definition influxdb_task  {
  family                   = "${var.name_prefix}-influxdb-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_main_task_cpu
  memory                   = var.ecs_main_task_memory

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "influxdb"
      image     = "influxdb:latest"
      cpu       = 0.5 * var.ecs_main_task_cpu
      memory    = 0.5 * var.ecs_main_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 8086
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.influxdb_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "INFLUXDB_ADMIN_USER", value = var.ecs_influxdb_admin_user },
        { name = "INFLUXDB_ADMIN_PASSWORD", value = var.ecs_influxdb_admin_password },
        { name = "INFLUXDB_USER", value = var.ecs_influxdb_user },
        { name = "INFLUXDB_USER_PASSWORD", value = var.ecs_influxdb_user_password },
        { name = "INFLUXDB_DB", value = var.ecs_influxdb_db_name }
      ]
      mountpoints = [
        {
          sourceVolume = "influxdb-data"
          containerPath = "/var/lib/influxdb"
          readonly = false
        }
      ]
    }
  ])

    volume {
    name = "influxdb-data"
    efs_volume_configuration {
      file_system_id          = var.main_efs_id
      root_directory          = "/influxdb"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.influxdb_efs_access_point.id
        iam             = "ENABLED"
      }
    }
  }
}

resource aws_ecs_service influxdb_service  {
  name            = "${var.name_prefix}-influxdb-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.influxdb_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.influxdb_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_influxdb_target_group.arn
    container_name   = "influxdb"
    container_port   = 8086
  }
}

resource aws_security_group influxdb_security_group  {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 8086
    to_port     = 8086
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
    Name = "${var.name_prefix}-influxdb-sg"
  }
}

resource aws_efs_access_point influxdb_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/var/lib/influxdb"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-influxdb-etc-efs-access-point"
  }
}

resource aws_cloudwatch_log_group influxdb_log_group  {
  name              = "/ecs/${var.name_prefix}-influxdb"
  retention_in_days = 7
  tags = {
    Name = "${var.name_prefix}-influxdb-log-group"
  }
}

resource aws_lb_target_group ecs_influxdb_target_group  {
  name = "${var.name_prefix}-infx-tg"

  port        = "8086" # InfluxDB Default Port
  protocol    = "TCP"
  target_type = "ip"

  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-influxdb-tg"
  }
}

resource aws_lb_listener ecs_influxdb_nlb_listener  {
  load_balancer_arn = var.load_balancer_arn
  port              = "8086" # InfluxDB Default Port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_influxdb_target_group.arn
  }
}