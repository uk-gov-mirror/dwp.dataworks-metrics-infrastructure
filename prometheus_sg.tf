resource "aws_security_group" "prometheus" {
  name        = "prometheus"
  description = "Rules necesary for pulling container image and accessing other prometheus instances"
  vpc_id      = module.vpc.outputs.vpcs[local.secondary_role_index].id
  tags        = merge(local.tags, { Name = "prometheus" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_prometheus_egress_https" {
  description       = "Allows ECS to pull container from S3"
  type              = "egress"
  to_port           = var.https_port
  protocol          = "tcp"
  prefix_list_ids   = [module.vpc.outputs.s3_prefix_list_ids[local.secondary_role_index]]
  from_port         = var.https_port
  security_group_id = aws_security_group.prometheus.id
}

resource "aws_security_group_rule" "allow_prometheus_egress_cloudwatch_exporter" {
  description              = "Allows prometheus to access exporter metrics"
  type                     = "egress"
  to_port                  = var.cloudwatch_exporter_port
  protocol                 = "tcp"
  from_port                = var.cloudwatch_exporter_port
  security_group_id        = aws_security_group.prometheus.id
  source_security_group_id = aws_security_group.cloudwatch_exporter.id
}

resource "aws_security_group_rule" "allow_prometheus_egress_adg_pushgateway" {
  count                    = local.is_management_env ? 0 : 1
  description              = "Allows prometheus to access ADG pushgateway"
  type                     = "egress"
  to_port                  = var.pushgateway_port
  protocol                 = "tcp"
  from_port                = var.pushgateway_port
  security_group_id        = aws_security_group.prometheus.id
  source_security_group_id = aws_security_group.adg_pushgateway[0].id
}

resource "aws_security_group_rule" "allow_prometheus_egress_pdm_exporter" {
  count                    = local.is_management_env ? 0 : 1
  description              = "Allows prometheus to access PDM exporter"
  type                     = "egress"
  to_port                  = var.json_exporter_port
  protocol                 = "tcp"
  from_port                = var.json_exporter_port
  security_group_id        = aws_security_group.prometheus.id
  source_security_group_id = aws_security_group.pdm_exporter[0].id
}

resource "aws_security_group_rule" "allow_prometheus_egress_hbase_exporter" {
  count                    = local.is_management_env ? 0 : 1
  description              = "Allows prometheus to access Hbase exporter"
  type                     = "egress"
  to_port                  = var.json_exporter_port
  protocol                 = "tcp"
  from_port                = var.json_exporter_port
  security_group_id        = aws_security_group.prometheus.id
  source_security_group_id = aws_security_group.hbase_exporter[0].id
}

resource "aws_security_group_rule" "prometheus_allow_egress_efs" {
  description              = "Allow prometheus to access efs mount target"
  from_port                = 2049
  protocol                 = "tcp"
  to_port                  = 2049
  type                     = "egress"
  security_group_id        = aws_security_group.prometheus.id
  source_security_group_id = aws_security_group.prometheus_efs.id
}