resource aws_ecs_task_definition telegraf_task  {
  family                   = "${var.name_prefix}-telegraf-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_main_task_cpu
  memory                   = var.ecs_main_task_memory

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "telegraf"
      image     = "telegraf:latest"
      cpu       = var.ecs_main_task_cpu / 2
      memory    = var.ecs_main_task_memory / 2
      essential = true
      environment = [
        { name = "INFLUXDB_URL", value = "http://${var.load_balancer_dns_name}:8086" },
        { name = "INFLUXDB_TOKEN", value = var.influxdb_token }, # If using InfluxDB v2
        { name = "INFLUXDB_ORG", value = var.influxdb_org },     # If using InfluxDB v2
        { name = "INFLUXDB_BUCKET", value = var.influxdb_bucket }, # If using InfluxDB v2
      ]
      volumesFrom = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.telegraf_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      command = [
        "--config",
        "/etc/telegraf/telegraf.conf"
      ]
      mountPoints = [
        {
          sourceVolume  = "telegraf-config"
          containerPath = "/etc/telegraf"
          readOnly      = true
        }
      ]
    }
  ])

  volume {
    name = "telegraf-config"
    efs_volume_configuration {
      file_system_id          = var.main_efs_id
      root_directory          = "/telegraf/config"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.telegraf_config_efs_access_point.id
        iam             = "ENABLED"
      }
    }
  }
}

resource aws_ecs_service telegraf_service  {
  name            = "${var.name_prefix}-telegraf-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.telegraf_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.telegraf_security_group.id]
    assign_public_ip = false
  }
}

resource aws_security_group telegraf_security_group  {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 1883
    to_port     = 1883
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict as needed
  }

  ingress {
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict as needed
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-telegraf-sg"
  }
}

resource aws_cloudwatch_log_group telegraf_log_group  {
  name              = "/ecs/${var.name_prefix}-telegraf"
  retention_in_days = 7
  tags = {
    Name = "${var.name_prefix}-telegraf-log-group"
  }
}

resource aws_efs_access_point telegraf_config_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/telegraf/config"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-telegraf-config-efs-access-point"
  }
}

resource aws_lb_listener mqtt_nlb_listener  {
  load_balancer_arn = var.load_balancer_arn
  port = "1883"
  protocol = "TCP"
  
  # ssl_policy      = "ELBSecurityPolicy-2016-08"
  # certificate_arn = aws_acm_certificate.ssl_certificate.arn

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ecs_mqtt_target_group.arn
  }
}