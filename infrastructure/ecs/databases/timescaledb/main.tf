resource aws_ecs_task_definition timescaledb_task  {
  family                   = "${var.name_prefix}-timescaledb-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_main_task_cpu
  memory                   = var.ecs_main_task_memory

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "timescaledb"
      image     = "516371590104.dkr.ecr.eu-west-1.amazonaws.com/gis-timescale:1.0"
      cpu       = 0.5 * var.ecs_main_task_cpu
      memory    = 0.5 * var.ecs_main_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 5432
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.timescaledb_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "POSTGRES_USER", value = var.ecs_timescaledb_db_user },
        { name = "POSTGRES_PASSWORD", value = var.ecs_timescaledb_db_password },
        { name = "POSTGRES_DB", value = var.ecs_timescaledb_db_name }
      ]
    },
    {
      name      = "postgres_exporter"
      image     = "prometheuscommunity/postgres-exporter:latest"
      cpu       = 0.5 * var.ecs_main_task_cpu
      memory    = 0.5 * var.ecs_main_task_memory
      essential = false
      environment = [
        {
          name  = "DATA_SOURCE_NAME"
          value = "postgresql://${var.ecs_timescaledb_db_user}:${var.ecs_timescaledb_db_password}@${var.load_balancer_dns_name}:5432/database"
        }
      ],
      portMappings = [
        {
          containerPort = 9187
        }
      ]
    }
  ])
}

resource aws_ecs_service timescaledb_service  {
  name            = "${var.name_prefix}-timescaledb-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.timescaledb_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true


  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.timescaledb_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_timescaledb_target_group.arn
    container_name   = "timescaledb"
    container_port   = 5432
  }
}

resource aws_security_group timescaledb_security_group  {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
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

resource aws_efs_access_point timescaledb_etc_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/timescaledb/etc"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-timescaledb-etc-efs-access-point"
  }
}

resource aws_cloudwatch_log_group timescaledb_log_group  {
  name              = "/ecs/${var.name_prefix}-timescaledb"
  retention_in_days = 7
  tags = {
    Name = "${var.name_prefix}-timescaledb-log-group"
  }
}

resource aws_lb_target_group ecs_timescaledb_target_group  {
  name = "${var.name_prefix}-tsdb-tg"

  port        = "5432" # Timescale DB API
  protocol    = "TCP"
  target_type = "ip"

  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-tsdb-tg"
  }
}

resource aws_lb_listener timescaledb_nlb_listener  {
  load_balancer_arn = var.load_balancer_arn
  port = "5432" # Timescale DB
  protocol = "TCP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ecs_timescaledb_target_group.arn
  }
}