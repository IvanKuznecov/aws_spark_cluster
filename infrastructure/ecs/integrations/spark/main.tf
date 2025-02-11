resource "aws_service_discovery_private_dns_namespace" "spark_ns" {
  name        = "spark.local"
  vpc         = var.vpc_id
  description = "Namespace for Spark Cluster"
}

resource "aws_service_discovery_service" "spark_master_sd" {
  name = "spark-master"
  namespace_id = aws_service_discovery_private_dns_namespace.spark_ns.id

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.spark_ns.id
    dns_records {
      type = "A"
      ttl  = 60
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource aws_ecs_task_definition spark_master_task  {
  family                   = "${var.name_prefix}-spark-master-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_main_task_cpu
  memory                   = var.ecs_main_task_memory

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "spark_master"
      image     = "bitnami/spark:latest"
      essential = true

      environment = [
        {
          "name": "SPARK_MASTER_PORT",
          "value": tostring(var.spark_master_port)
        },
        {
          "name": "SPARK_MASTER_WEBUI_PORT",
          "value": tostring(var.spark_webui_port)
        },
        {
          name  = "SPARK_MASTER_OPTS"
          value = "-Dspark.master.rest.enabled=true -Dspark.master.rest.port=${tostring(var.spark_api_port)}"
        },

        {
          "name": "SPARK_HISTORY_PORT",
          "value": tostring(var.spark_history_port)
        }
      ]

      # command = ["/opt/spark/bin/pyspark"] # "spark-submit /path/to/script.py" for job execution

      portMappings = [
        {
          containerPort = var.spark_master_port
          protocol      = "tcp"
        },
        {
          containerPort = var.spark_webui_port
          protocol      = "tcp"
        },
        {
          containerPort = var.spark_api_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.spark_master_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      mountpoints = [
        {
          sourceVolume = "spark-data"
          containerPath = "/spark"
          readonly = false
        }
      ]
    }
  ])

  volume {
    name = "spark-data"
    efs_volume_configuration {
      file_system_id          = var.main_efs_id
      root_directory          = "/spark"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.spark_etc_efs_access_point.id
        iam             = "ENABLED"
      }
    }
  }
}

resource aws_ecs_task_definition spark_worker_task  {
  family                   = "${var.name_prefix}-spark-worker-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_main_task_cpu
  memory                   = var.ecs_main_task_memory

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "spark_worker"
      image     = "bitnami/spark:latest"
      essential = true

      environment: [
        {
          "name": "SPARK_MODE",
          "value": "worker"
        },
        {
          "name": "SPARK_MASTER_URL",
          "value": "spark://spark-master.spark.local:${var.spark_master_port}"
        }
      ]

      # command = ["/opt/spark/bin/pyspark"] # "spark-submit /path/to/script.py" for job execution

      portMappings = [
        {
          containerPort = var.spark_master_port
          protocol      = "tcp"
        },
        {
          containerPort = var.spark_webui_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.spark_worker_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      mountpoints = [
        {
          sourceVolume = "spark-data"
          containerPath = "/spark"
          readonly = false
        }
      ]
    }
  ])

  volume {
    name = "spark-data"
    efs_volume_configuration {
      file_system_id          = var.main_efs_id
      root_directory          = "/spark"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.spark_etc_efs_access_point.id
        iam             = "ENABLED"
      }
    }
  }
}

resource aws_ecs_service spark_master_service  {
  name            = "${var.name_prefix}-spark-master-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.spark_master_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [aws_ecs_service.spark_worker_service]

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups = [aws_security_group.spark_security_group.id]    
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_spark_target_group_ui.arn
    container_name   = "spark_master"
    container_port   = var.spark_webui_port
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_spark_target_group_task.arn
    container_name   = "spark_master"
    container_port   = var.spark_master_port
  }

    load_balancer {
    target_group_arn = aws_lb_target_group.ecs_spark_target_group_api.arn
    container_name   = "spark_master"
    container_port   = var.spark_api_port
  }

  service_registries {
    registry_arn = aws_service_discovery_service.spark_master_sd.arn
  }
}

resource aws_ecs_service spark_worker_service  {
  name            = "${var.name_prefix}-spark-worker-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.spark_worker_task.arn
  desired_count   = 4
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups = [aws_security_group.spark_security_group.id]    
    assign_public_ip = false
  }

}

resource aws_security_group spark_security_group  {
  vpc_id = var.vpc_id

  ingress {
    from_port   = var.spark_webui_port # Spark UI port
    to_port     = var.spark_webui_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict as needed for production [Replace with your IP range]
  }

  ingress {
    from_port   = var.spark_master_port # Spark cluster port
    to_port     = var.spark_master_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict as needed for production [aws_security_group.spark_security_group.id]
  }

  ingress {
    from_port   = var.spark_api_port # Spark API endpoint
    to_port     = var.spark_api_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to specific IPs in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-spark-sg"
  }
}

resource aws_efs_access_point spark_etc_efs_access_point  {
  file_system_id = var.main_efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/spark/etc"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-spark-etc-efs-access-point"
  }
}

resource aws_cloudwatch_log_group spark_master_log_group  {
  name              = "/ecs/${var.name_prefix}-spark-master"
  retention_in_days = 7
  tags = {
    Name = "${var.name_prefix}-spark-master-log-group"
  }
}

resource aws_cloudwatch_log_group spark_worker_log_group  {
  name              = "/ecs/${var.name_prefix}-spark-worker"
  retention_in_days = 7
  tags = {
    Name = "${var.name_prefix}-spark-worker-log-group"
  }
}

resource "aws_lb_target_group" "ecs_spark_target_group_ui" {
  name        = "${var.name_prefix}-spark-ui-tg"
  port        = var.spark_webui_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id
}

resource "aws_lb_target_group" "ecs_spark_target_group_task" {
  name        = "${var.name_prefix}-spark-task-tg"
  port        = var.spark_master_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id
}

resource "aws_lb_target_group" "ecs_spark_target_group_api" {
  name        = "${var.name_prefix}-spark-api-tg"
  port        = var.spark_api_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id
}

resource "aws_lb_listener" "spark_listener_ui" {
  load_balancer_arn = var.load_balancer_arn
  port              = var.spark_webui_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_spark_target_group_ui.arn
  }
}

resource "aws_lb_listener" "spark_listener_task" {
  load_balancer_arn = var.load_balancer_arn
  port              = var.spark_master_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_spark_target_group_task.arn
  }
}

resource "aws_lb_listener" "spark_listener_api" {
  load_balancer_arn = var.load_balancer_arn
  port              = var.spark_api_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_spark_target_group_api.arn
  }
}