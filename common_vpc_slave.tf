resource "aws_internet_gateway" "igw_slave" {
  count  = local.is_management_env ? 0 : 1
  vpc_id = module.vpc.outputs.vpcs[local.secondary_role_index].id
  tags   = merge(local.tags, { Name = "${var.name}-${var.secondary}" })
}

resource "aws_subnet" "public_slave" {
  count                = local.is_management_env ? 0 : local.zone_count
  cidr_block           = cidrsubnet(local.cidr_block_mon_master_vpc[0], var.subnets.public.newbits, var.subnets.public.netnum + count.index)
  vpc_id               = module.vpc.outputs.vpcs[local.secondary_role_index].id
  availability_zone_id = data.aws_availability_zones.current.zone_ids[count.index]
  tags                 = merge(local.tags, { Name = "${var.name}-${var.secondary}-public-${local.zone_names[count.index]}" })
}

resource "aws_route_table" "public_slave" {
  count  = local.is_management_env ? 0 : local.zone_count
  vpc_id = module.vpc.outputs.vpcs[local.secondary_role_index].id
  tags   = merge(local.tags, { Name = "${var.name}-${var.secondary}-public-${local.zone_names[count.index]}" })
}

resource "aws_route" "public_slave" {
  count                  = local.is_management_env ? 0 : local.zone_count
  route_table_id         = aws_route_table.public_slave[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_slave[local.secondary_role_index].id
}

resource "aws_route_table_association" "public_slave" {
  count          = local.is_management_env ? 0 : local.zone_count
  route_table_id = aws_route_table.public_slave[count.index].id
  subnet_id      = aws_subnet.public_slave[count.index].id
}

resource "aws_security_group" "internet_proxy_endpoint_slave" {
  count       = local.is_management_env ? 0 : 1
  name        = "proxy_vpc_endpoint"
  description = "Control access to the Internet Proxy VPC Endpoint"
  vpc_id      = module.vpc.outputs.vpcs[local.secondary_role_index].id
  tags        = merge(local.tags, { Name = var.name })
}

resource "aws_vpc_endpoint" "internet_proxy_slave" {
  count               = local.is_management_env ? 0 : 1
  vpc_id              = module.vpc.outputs.vpcs[local.secondary_role_index].id
  service_name        = data.terraform_remote_state.internet_egress.outputs.internet_proxy_service.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.internet_proxy_endpoint_slave[local.secondary_role_index].id]
  subnet_ids          = module.vpc.outputs.private_subnets[local.secondary_role_index]
  private_dns_enabled = false
  tags                = merge(local.tags, { Name = var.name })
}
