resource "aws_vpc_peering_connection" "ingestion" {
  count       = local.is_management_env ? 0 : 1
  peer_vpc_id = data.terraform_remote_state.aws_ingestion.outputs.ingestion_vpc.id
  vpc_id      = module.vpc.outputs.vpcs[local.secondary_role_index].id
  auto_accept = true
  tags        = merge(local.tags, { Name = var.name })
}

resource "aws_route" "ingest_prometheus" {
  count                     = local.is_management_env ? 0 : 1
  route_table_id            = data.terraform_remote_state.aws_ingestion.outputs.ingestion_subnets.rtb
  destination_cidr_block    = local.cidr_block[local.environment].mon-slave-vpc
  vpc_peering_connection_id = aws_vpc_peering_connection.ingestion[0].id
}

resource "aws_route" "prometheus_ingest" {
  count                     = local.is_management_env ? 0 : local.zone_count
  route_table_id            = module.vpc.outputs.private_route_tables[local.secondary_role_index][count.index]
  destination_cidr_block    = local.cidr_block_ingest_vpc
  vpc_peering_connection_id = aws_vpc_peering_connection.ingestion[0].id
}

resource "aws_security_group_rule" "k2hb_allow_ingress_prometheus" {
  count                    = local.is_management_env ? 0 : 1
  description              = "Allow prometheus ${var.secondary} to access ingest k2hb ec2 node metrics"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 9100
  to_port                  = 9100
  security_group_id        = data.terraform_remote_state.aws_ingest-consumers.outputs.security_group.k2hb_common
  source_security_group_id = aws_security_group.prometheus.id
}

resource "aws_security_group_rule" "prometheus_allow_egress_k2hb" {
  count                    = local.is_management_env ? 0 : 1
  description              = "Allow prometheus ${var.secondary} to access ingest k2hb ec2 node metrics"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 9100
  to_port                  = 9100
  security_group_id        = aws_security_group.prometheus.id
  source_security_group_id = data.terraform_remote_state.aws_ingest-consumers.outputs.security_group.k2hb_common
}
