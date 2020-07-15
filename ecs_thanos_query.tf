resource "aws_ecs_task_definition" "thanos_query" {
  count                    = local.is_management_env ? 1 : 0
  family                   = "thanos-query"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "4096"
  task_role_arn            = aws_iam_role.thanos_query[local.primary_role_index].arn
  execution_role_arn       = local.is_management_env ? data.terraform_remote_state.management.outputs.ecs_task_execution_role.arn : data.terraform_remote_state.common.outputs.ecs_task_execution_role.arn

  container_definitions = <<DEFINITION
[
  {
    "cpu": ${var.fargate_cpu},
    "image": "${data.terraform_remote_state.management.outputs.ecr_thanos_url}",
    "memory": ${var.fargate_memory},
    "name": "thanos-query",
    "networkMode": "awsvpc",
    "user": "nobody",
    "portMappings": [
      {
        "containerPort": ${var.thanos_port_http},
        "hostPort": ${var.thanos_port_http}
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.monitoring.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "thanos-query"
      }
    },
    "placementStrategy": [
      {
        "field": "attribute:ecs.availability-zone",
        "type": "spread"
      }
    ],
    "environment": [
      {
        "name": "THANOS_CONFIG_S3_BUCKET",
        "value": "${local.is_management_env ? data.terraform_remote_state.management.outputs.config_bucket.id : data.terraform_remote_state.common.outputs.config_bucket.id}"
      },
      {
        "name": "THANOS_CONFIG_S3_PREFIX",
        "value": "${var.name}/thanos"
      },
      {
        "name": "THANOS_MODE",
        "value": "query"
      },
      {
        "name": "STORE_HOSTNAMES",
        "value": "${join(" ", formatlist("${var.name}-${var.secondary}.%s.services.${var.parent_domain_name}", "${local.master_peerings[local.slave_peerings[local.environment]]}"))}"
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_service" "thanos_query" {
  count            = local.is_management_env ? 1 : 0
  name             = "thanos-query"
  cluster          = data.terraform_remote_state.management.outputs.ecs_cluster_main.id
  task_definition  = aws_ecs_task_definition.thanos_query[local.primary_role_index].arn
  platform_version = "1.4.0"
  desired_count    = 1
  launch_type      = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.thanos_query[0].id]
    subnets         = module.vpc.outputs.private_subnets[local.primary_role_index]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.thanos_query[local.primary_role_index].arn
    container_name   = "thanos-query"
    container_port   = var.prometheus_port
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.thanos_query[local.primary_role_index].arn
    container_name = "thanos-query"
  }
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
}

resource "aws_security_group" "thanos_query" {
  count       = local.is_management_env ? 1 : 0
  name        = "thanos-query"
  description = "Rules necesary for pulling container image and accessing other thanos instances"
  vpc_id      = module.vpc.outputs.vpcs[local.primary_role_index].id
  tags        = merge(local.tags, { Name = "thanos-query" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_thanos_query_egress_https" {
  count             = local.is_management_env ? 1 : 0
  description       = "Allows ECS to pull container from S3"
  type              = "egress"
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [module.vpc.outputs.s3_prefix_list_ids[local.primary_role_index]]
  from_port         = 443
  security_group_id = aws_security_group.thanos_query[0].id
}

resource "aws_security_group_rule" "allow_loadbalancer_ingress_thanos_query_http" {
  count                    = local.is_management_env ? 1 : 0
  description              = "Allows loadbalancer to access thanos user interface"
  type                     = "ingress"
  to_port                  = var.thanos_port_http
  protocol                 = "tcp"
  from_port                = var.thanos_port_http
  security_group_id        = aws_security_group.thanos_query[0].id
  source_security_group_id = aws_security_group.monitoring[0].id
}

resource "aws_security_group_rule" "allow_grafana_ingress_thanos_query_http" {
  count                    = local.is_management_env ? 1 : 0
  description              = "Allows grafana to access thanos query api"
  type                     = "ingress"
  to_port                  = var.thanos_port_http
  protocol                 = "tcp"
  from_port                = var.thanos_port_http
  security_group_id        = aws_security_group.thanos_query[0].id
  source_security_group_id = aws_security_group.grafana[0].id
}

resource "aws_security_group_rule" "allow_thanos_ruler_ingress_thanos_query_http" {
  count                    = local.is_management_env ? 1 : 0
  description              = "Allows thanos ruler to access thanos query"
  type                     = "ingress"
  to_port                  = var.thanos_port_http
  protocol                 = "tcp"
  from_port                = var.thanos_port_http
  security_group_id        = aws_security_group.thanos_query[0].id
  source_security_group_id = aws_security_group.thanos_ruler[0].id
}

resource "aws_iam_role" "thanos_query" {
  count              = local.is_management_env ? 1 : 0
  name               = "thanos-query"
  assume_role_policy = data.aws_iam_policy_document.thanos_query_assume_role.json
  tags               = merge(local.tags, { Name = "thanos-query" })
}

data "aws_iam_policy_document" "thanos_query_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "thanos_query_read_config_attachment" {
  count      = local.is_management_env ? 1 : 0
  role       = aws_iam_role.thanos_query[local.primary_role_index].name
  policy_arn = aws_iam_policy.thanos_query_read_config[local.primary_role_index].arn
}

resource "aws_iam_policy" "thanos_query_read_config" {
  count       = local.is_management_env ? 1 : 0
  name        = "ThanosQueryReadConfigPolicy"
  description = "Allow Thanos to read from config bucket"
  policy      = data.aws_iam_policy_document.thanos_query_read_config.json
}

data "aws_iam_policy_document" "thanos_query_read_config" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "${local.is_management_env ? data.terraform_remote_state.management.outputs.config_bucket.arn : data.terraform_remote_state.common.outputs.config_bucket.arn}",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${local.is_management_env ? data.terraform_remote_state.management.outputs.config_bucket.arn : data.terraform_remote_state.common.outputs.config_bucket.arn}/${var.name}/thanos/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "kms:Decrypt",
    ]

    resources = [
      "${local.is_management_env ? data.terraform_remote_state.management.outputs.config_bucket.cmk_arn : data.terraform_remote_state.common.outputs.config_bucket_cmk.arn}",
    ]
  }
}