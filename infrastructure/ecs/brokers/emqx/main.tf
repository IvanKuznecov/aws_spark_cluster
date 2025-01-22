# EMQX Task and Service
resource aws_ecs_task_definition emqx_task  {
  family                   = "${var.name_prefix}-emqx-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 2 * var.ecs_main_task_cpu
  memory                   = 2 * var.ecs_main_task_memory

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "emqx"
      image     = "public.ecr.aws/emqx/emqx:5.8-elixir"
      essential = true
      portMappings = [
        {
          containerPort = 1883
        },
        {
          containerPort = 18083
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.emqx_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "EMQX_DASHBOARD__DEFAULT_PASSWORD", value = var.ecs_emqx_dashboard_password },
        { name = "EMQX_NAME", value = "emqx1" },
        { name = "EMQX_HOST", value = "emqx1.gis.ie" }
      ]
      mountpoints = [
        {
          sourceVolume = "emqx-data"
          containerPath = "/opt/emqx/data"
          readonly = false
        },
        {
          sourceVolume = "emqx-log"
          containerPath = "/opt/emqx/log"
          readonly = false
        }
      ]
    }
  ])
    volume {
      name = "emqx-data"
      efs_volume_configuration {
        file_system_id          = var.main_efs_id
        root_directory          = "/emqx/data"
        transit_encryption      = "ENABLED"
        authorization_config {
          access_point_id = aws_efs_access_point.emqx_data_efs_access_point.id
          iam             = "ENABLED"
        }
      }
  }
  volume {
      name = "emqx-log"
      efs_volume_configuration {
        file_system_id          = var.main_efs_id
        root_directory          = "/emqx/log"
        transit_encryption      = "ENABLED"
        authorization_config {
          access_point_id = aws_efs_access_point.emqx_log_efs_access_point.id
          iam             = "ENABLED"
        }
      }
  }
  volume {
      name = "emqx-etc"
      efs_volume_configuration {
        file_system_id          = var.main_efs_id
        root_directory          = "/emqx/etc"
        transit_encryption      = "ENABLED"
        authorization_config {
          access_point_id = aws_efs_access_point.emqx_etc_efs_access_point.id
          iam             = "ENABLED"
        }
      }
  }
}

resource aws_ecs_service emqx_service  {
  name            = "${var.name_prefix}-emqx-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.emqx_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [
      aws_security_group.mqtt_security_group.id,
      aws_security_group.emqx_security_group.id
    ]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_mqtt_target_group.arn
    container_name   = "emqx"
    container_port   = 1883
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_emqx_target_group.arn
    container_name   = "emqx"
    container_port   = 18083
  }
}

resource aws_security_group mqtt_security_group  {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 1883
    to_port     = 1883
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
    Name = "${var.name_prefix}-mqtt-sg"
  }
}

resource aws_security_group emqx_security_group  {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 18083
    to_port     = 18083
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
    Name = "${var.name_prefix}-emqx-sg"
  }
}

resource aws_efs_access_point emqx_data_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/emqx/data"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-emqx-data-efs-access-point"
  }
}

resource aws_efs_access_point emqx_log_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/emqx/log"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-emqx-log-efs-access-point"
  }
}

resource aws_efs_access_point emqx_etc_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/emqx/etc"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-emqx-etc-efs-access-point"
  }
}

resource aws_cloudwatch_log_group emqx_log_group  {
  name              = "/ecs/${var.name_prefix}-emqx"
  retention_in_days = 7
  tags = {
    Name = "${var.name_prefix}-emqx-log-group"
  }
}

resource aws_lb_target_group ecs_mqtt_target_group  {
  name = "${var.name_prefix}-mqtt-tg"

  port        = "1883" # MQTT port
  protocol    = "TCP"
  target_type = "ip"

  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-mqtt-tg"
  }
}

resource aws_lb_listener mqtt_nlb_listener  {
  load_balancer_arn = var.load_balancer_arn
  port = "1883" # MQTT Secure port 8883
  protocol = "TCP"
  # ssl_policy        = "ELBSecurityPolicy-2016-08"

  # certificate_arn = aws_acm_certificate.ssl_certificate.arn

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ecs_mqtt_target_group.arn
  }
}

# EMQX Config
resource aws_lb_target_group ecs_emqx_target_group  {
  name = "${var.name_prefix}-emqx-tg"

  port        = "18083" # EMQx dashboard
  protocol    = "TCP"
  target_type = "ip"

  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-emqx-tg"
  }
}

resource aws_lb_listener emqx_nlb_listener  {
  load_balancer_arn = var.load_balancer_arn
  port = "18083" # EMQx dashboard
  protocol = "TCP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ecs_emqx_target_group.arn
  }
}