resource aws_ecs_task_definition mqtt_collector_task  {
  family                   = "${var.name_prefix}-python-mqtt-collector-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_main_task_cpu
  memory                   = var.ecs_main_task_memory

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "python-mqtt-collector"
      image     = "516371590104.dkr.ecr.eu-west-1.amazonaws.com/mqtt-timescale-collector:1.3"
      essential = true
      portMappings = [
        {
          containerPort = 8000
        }
      ]
      logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = aws_cloudwatch_log_group.mqtt_collector_log_group.name
              awslogs-region        = var.aws_region
              awslogs-stream-prefix = "ecs"
            }
          }
      command     = ["python", "main.py"]
      environment = [
        { name = "LOAD_BALANCER_DNS", value = var.load_balancer_dns_name },
        { name = "POSTGRES_USER", value = var.ecs_timescaledb_db_user },
        { name = "POSTGRES_PASSWORD", value = var.ecs_timescaledb_db_password },
        { name = "POSTGRES_DB", value = var.ecs_timescaledb_db_name }
      ]
      linuxParameters = {
        initProcessEnabled = true
      }
      mountpoints = [
        {
          sourceVolume = "python-data"
          containerPath = "/data"
          readonly = false
        }
      ]
    }
  ])

  volume {
      name = "python-data"
      efs_volume_configuration {
        file_system_id          = var.main_efs_id
        root_directory          = "/python/data"
        transit_encryption      = "ENABLED"
        authorization_config {
          access_point_id = aws_efs_access_point.etc_efs_access_point.id
          iam             = "ENABLED"
        }
      }
  }
  depends_on = [
    aws_cloudwatch_log_group.mqtt_collector_log_group
  ]

}

resource aws_ecs_service mqtt_collector_service  {
  name            = "${var.name_prefix}-mqtt-collector-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.mqtt_collector_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.mqtt_collector_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_mqtt_collector_target_group.arn
    container_name   = "python-mqtt-collector"
    container_port   = 8000
  }

  depends_on = [
    aws_security_group.mqtt_collector_security_group,
    aws_lb_target_group.ecs_mqtt_collector_target_group
  ]
}

resource aws_security_group mqtt_collector_security_group  {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 8000
    to_port     = 8000
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
    Name = "${var.name_prefix}-timescaledb-sg"
  }
}

resource aws_efs_access_point etc_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/python/etc"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-python-etc-efs-access-point"
  }
}

resource aws_cloudwatch_log_group mqtt_collector_log_group  {
  name              = "/ecs/${var.name_prefix}-mqtt-collector"
  retention_in_days = 7
  tags = {
    Name = "${var.name_prefix}-mqtt-collector-log-group"
  }
}

resource aws_lb_target_group ecs_mqtt_collector_target_group  {
  name = "${var.name_prefix}-pymc-tg"

  port        = "8000" # Port configured in Python code
  protocol    = "TCP"
  target_type = "ip"

  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-pymc-tg"
  }
}

resource aws_lb_listener mqtt_collector_nlb_listener  {
  load_balancer_arn = var.load_balancer_arn
  port              = "8000" # Port configured in Python code
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_mqtt_collector_target_group.arn
  }
}