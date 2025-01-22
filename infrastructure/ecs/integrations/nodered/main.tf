resource aws_ecs_task_definition nodered_task  {
  family                   = "${var.name_prefix}-nodered-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_main_task_cpu
  memory                   = var.ecs_main_task_memory

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "nodered"
      image     = "516371590104.dkr.ecr.eu-west-1.amazonaws.com/gis-nodered:1.6"
      essential = true
      portMappings = [
        {
          containerPort = 1880
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.nodered_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "LOAD_BALANCER_DNS_NAME", value = var.load_balancer_dns_name }
      ]
      mountpoints = [
        {
          sourceVolume = "nodered-data"
          containerPath = "/data"
          readonly = false
        }
      ]
    }
  ])

  volume {
    name = "nodered-data"
    efs_volume_configuration {
      file_system_id          = var.main_efs_id
      root_directory          = "/nodered"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.nodered_data_efs_access_point.id
        iam             = "ENABLED"
      }
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.nodered_log_group,
    aws_efs_access_point.nodered_data_efs_access_point
  ]
}

resource aws_ecs_service nodered_service  {
  name            = "${var.name_prefix}-nodered-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.nodered_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.nodered_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_nodered_target_group.arn
    container_name   = "nodered"
    container_port   = 1880
  }

  depends_on = [
    aws_security_group.nodered_security_group,
    aws_lb_target_group.ecs_nodered_target_group
  ]
}

resource aws_security_group nodered_security_group  {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 1880
    to_port     = 1880
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
    Name = "${var.name_prefix}-nodered-sg"
  }
}

resource aws_efs_access_point nodered_data_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/nodered"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-nodered-data-efs-access-point"
  }
}

resource aws_cloudwatch_log_group nodered_log_group  {
  name              = "/ecs/${var.name_prefix}-nodered"
  retention_in_days = 7
  tags = {
    Name = "${var.name_prefix}-nodered-log-group"
  }
}

resource aws_lb_target_group ecs_nodered_target_group  {
  name = "${var.name_prefix}-nred-tg"

  port        = "1880" # EMQx dashboard
  protocol    = "TCP"
  target_type = "ip"

  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name_prefix}nodered-tg"
  }
}

resource aws_lb_listener nodered_nlb_listener  {
  load_balancer_arn = var.load_balancer_arn
  port = "1880" # Node-Red UI
  protocol = "TCP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ecs_nodered_target_group.arn
  }
}