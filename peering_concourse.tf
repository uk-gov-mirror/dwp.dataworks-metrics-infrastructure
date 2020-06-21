resource "aws_vpc_peering_connection" "concourse" {
  count       = local.is_management_env ? 1 : 0
  peer_vpc_id = data.terraform_remote_state.aws_concourse.outputs.aws_vpc.id
  vpc_id      = module.vpc.outputs.vpcs[local.secondary_role_index].id
  auto_accept = true
}

resource "aws_route" "concourse_prometheus_secondary" {
  count                     = local.is_management_env ? length(data.terraform_remote_state.aws_concourse.outputs.route_tables) : 0
  route_table_id            = data.terraform_remote_state.aws_concourse.outputs.route_tables[count.index].id
  destination_cidr_block    = local.cidr_block[local.environment].mon-slave-vpc
  vpc_peering_connection_id = aws_vpc_peering_connection.concourse[0].id
}

resource "aws_route" "prometheus_secondary_concourse" {
  count                     = local.is_management_env ? local.zone_count : 0
  route_table_id            = module.vpc.outputs.private_route_tables[1][count.index]
  destination_cidr_block    = local.cidr_block_cicd_vpc[0]
  vpc_peering_connection_id = aws_vpc_peering_connection.concourse[0].id
}

resource "aws_security_group_rule" "concourse_allow_ingress_prometheus" {
  count                    = local.is_management_env ? 1 : 0
  description              = "Allow prometheus ${var.secondary} to access concourse metrics"
  from_port                = 9090
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.aws_concourse.outputs.concourse_web_sg
  to_port                  = 9090
  type                     = "ingress"
  source_security_group_id = aws_security_group.prometheus[1].id
}

resource "aws_security_group_rule" "prometheus_allow_egress_concourse" {
  count             = local.is_management_env ? 1 : 0
  type              = "egress"
  to_port           = 9090
  protocol          = "tcp"
  from_port         = 9090
  security_group_id = aws_security_group.prometheus[local.secondary_role_index].id
  cidr_blocks       = [local.cidr_block_cicd_vpc[0]]
}
