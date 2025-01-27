resource "aws_security_group" "ucfs_claimant_api_pushgateway" {
  count       = local.is_management_env ? 0 : 1
  name        = "ucfs-pushgateway"
  description = "Rules necesary for pulling container image"
  vpc_id      = data.terraform_remote_state.ucfs-claimant.outputs.ucfs_claimant_api_vpc.vpc.id
  tags        = merge(local.tags, { Name = "ucfs-pushgateway" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_ucfs_claimant_api_pushgateway_egress_https" {
  count             = local.is_management_env ? 0 : 1
  description       = "Allows ECS to pull container from S3"
  type              = "egress"
  protocol          = "tcp"
  from_port         = var.https_port
  to_port           = var.https_port
  security_group_id = aws_security_group.ucfs_claimant_api_pushgateway[0].id
  prefix_list_ids   = [data.terraform_remote_state.ucfs-claimant.outputs.ucfs_claimant_api_vpc.prefix_list_ids.s3]
}

resource "aws_security_group_rule" "allow_prometheus_ingress_ucfs_claimant_api_pushgateway" {
  count                    = local.is_management_env ? 0 : 1
  description              = "Allows prometheus to access ucfs pushgateway"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.pushgateway_port
  to_port                  = var.pushgateway_port
  security_group_id        = aws_security_group.ucfs_claimant_api_pushgateway[0].id
  source_security_group_id = aws_security_group.prometheus.id
}

resource "aws_security_group_rule" "allow_ucfs_claimant_ingress_ucfs_claimant_api_pushgateway" {
  count             = local.is_management_env ? 0 : 1
  description       = "Allows ucfs claimant ireland vpc to access ucfs pushgateway"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = var.pushgateway_port
  to_port           = var.pushgateway_port
  security_group_id = aws_security_group.ucfs_claimant_api_pushgateway[0].id
  cidr_blocks       = [data.terraform_remote_state.ucfs-claimant.outputs.ucfs_claimant_vpc.cidr_block]
}
