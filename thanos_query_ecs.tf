resource "aws_ecs_task_definition" "thanos_query" {
  count                    = local.is_management_env ? 1 : 0
  family                   = "thanos-query"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.query_task_cpu[local.environment]
  memory                   = var.query_task_memory[local.environment]
  task_role_arn            = aws_iam_role.thanos_query[local.primary_role_index].arn
  execution_role_arn       = local.is_management_env ? data.terraform_remote_state.management.outputs.ecs_task_execution_role.arn : data.terraform_remote_state.common.outputs.ecs_task_execution_role.arn
  container_definitions    = "[${data.template_file.thanos_query_definition[local.primary_role_index].rendered}]"
  tags                     = merge(local.tags, { Name = var.name })
}

data "template_file" "thanos_query_definition" {
  count    = local.is_management_env ? 1 : 0
  template = file("${path.module}/container_definition.tpl")
  vars = {
    name          = "thanos-query"
    group_name    = "thanos"
    cpu           = var.query_cpu[local.environment]
    image_url     = format("%s:%s", data.terraform_remote_state.management.outputs.ecr_thanos_url, var.image_versions.thanos)
    memory        = var.query_memory[local.environment]
    user          = "nobody"
    ports         = jsonencode([var.thanos_port_http])
    ulimits       = jsonencode([var.ulimits])
    log_group     = aws_cloudwatch_log_group.monitoring_metrics.name
    region        = data.aws_region.current.name
    config_bucket = local.is_management_env ? data.terraform_remote_state.management.outputs.config_bucket.id : data.terraform_remote_state.common.outputs.config_bucket.id

    mount_points = jsonencode([])

    environment_variables = jsonencode([
      {
        "name" : "THANOS_MODE",
        "value" : "query"
      },
      {
        "name" : "STORE_HOSTNAMES",
        "value" : "${join(" ", concat(formatlist("${var.name}-${var.secondary}.%s.services.${var.parent_domain_name}", "${local.master_peerings[local.slave_peerings[local.environment]]}"), formatlist("thanos-store.%s.services.${var.parent_domain_name}", "${local.slave_peerings[local.environment]}")))}"
      },
      {
        "name" : "THANOS_QUERY_CONFIG_CHANGE_DEPENDENCY",
        "value" : "${md5(data.template_file.thanos_config.rendered)}"
      }
    ])
  }
}

resource "aws_ecs_service" "thanos_query" {
  count                              = local.is_management_env ? 1 : 0
  name                               = "thanos-query"
  cluster                            = aws_ecs_cluster.metrics_ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.thanos_query[local.primary_role_index].arn
  platform_version                   = var.platform_version
  desired_count                      = 1
  launch_type                        = "FARGATE"
  force_new_deployment               = true
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    security_groups = [aws_security_group.thanos_query[0].id, aws_security_group.monitoring_common[local.primary_role_index].id]
    subnets         = module.vpc.outputs.private_subnets[local.primary_role_index]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.thanos_query[local.primary_role_index].arn
    container_name   = "thanos-query"
    container_port   = var.thanos_port_http
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.thanos_query[local.primary_role_index].arn
    container_name = "thanos-query"
  }

  tags = merge(local.tags, { Name = var.name })
}

resource "aws_service_discovery_service" "thanos_query" {
  count = local.is_management_env ? 1 : 0
  name  = "thanos-query"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  tags = merge(local.tags, { Name = var.name })
}
