module "vpc" {
  source = "./vpc"

  name_prefix = local.name_prefix

  aws_region         = var.aws_region
  availability_zones = var.availability_zones

  base_cidr           = var.base_cidr
  private_subnet_cidr = local.private_subnet_cidr
}

module "alb" {
  source = "./alb"

  name_prefix = local.name_prefix

  vpc_id            = module.vpc.main_vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

module "efs" {
  source = "./efs"

  name_prefix = local.name_prefix

  vpc_id             = module.vpc.main_vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "ecs" {
  source = "./ecs"

  name_prefix = local.name_prefix
  aws_region  = var.aws_region

  ecs_main_task_cpu    = var.ecs_main_task_cpu
  ecs_main_task_memory = var.ecs_main_task_memory

  vpc_id             = module.vpc.main_vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  load_balancer_dns_name = module.alb.load_balancer_dns_name
  load_balancer_arn      = module.alb.load_balancer_arn

  main_efs_id = module.efs.main_efs_id
}

module "lambda" {
  source = "./lambda"

  name_prefix = local.name_prefix
  aws_region  = var.aws_region

  vpc_id             = module.vpc.main_vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  data_path = "${path.module}/../data"

  load_balancer_dns_name = module.alb.load_balancer_dns_name
  load_balancer_arn      = module.alb.load_balancer_arn
}
