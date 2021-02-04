resource "aws_route53_record" "monitoring_loadbalancer_slave" {
  provider = aws.management_dns
  count    = local.is_management_env ? 0 : 1
  name     = join(".", [local.roles[local.secondary_role_index], local.fqdn])
  type     = "A"
  zone_id  = aws_service_discovery_private_dns_namespace.monitoring_slave.hosted_zone

  alias {
    evaluate_target_health = false
    name                   = aws_lb.monitoring_slave[0].dns_name
    zone_id                = aws_lb.monitoring_slave[0].zone_id
  }
}

resource "aws_route53_record" "prometheus_loadbalancer" {
  provider = aws.management_dns
  count    = local.is_management_env ? 0 : 1
  name     = "prometheus.${local.fqdn}"
  type     = "A"
  zone_id  = aws_service_discovery_private_dns_namespace.monitoring_slave.hosted_zone

  alias {
    evaluate_target_health = false
    name                   = aws_lb.monitoring_slave[0].dns_name
    zone_id                = aws_lb.monitoring_slave[0].zone_id
  }
}

resource "aws_acm_certificate" "monitoring_slave" {
  count                     = local.is_management_env ? 0 : 1
  domain_name               = local.fqdn
  validation_method         = "DNS"
  subject_alternative_names = ["prometheus.${local.fqdn}"]

  lifecycle {
    ignore_changes = [subject_alternative_names]
  }

  tags = merge(local.tags, { Name = var.name })
}

resource "aws_route53_record" "monitoring_slave" {
  provider        = aws.management_dns
  count           = local.is_management_env ? 0 : 1
  name            = tolist(aws_acm_certificate.monitoring_slave[local.secondary_role_index].domain_validation_options)[0].resource_record_name
  type            = tolist(aws_acm_certificate.monitoring_slave[local.secondary_role_index].domain_validation_options)[0].resource_record_type
  zone_id         = aws_service_discovery_private_dns_namespace.monitoring_slave.hosted_zone
  records         = [tolist(aws_acm_certificate.monitoring_slave[local.secondary_role_index].domain_validation_options)[0].resource_record_value]
  ttl             = 60
  allow_overwrite = true

}

resource "aws_route53_record" "prometheus" {
  provider        = aws.management_dns
  count           = local.is_management_env ? 0 : 1
  name            = tolist(aws_acm_certificate.monitoring_slave[local.secondary_role_index].domain_validation_options)[1].resource_record_name
  type            = tolist(aws_acm_certificate.monitoring_slave[local.secondary_role_index].domain_validation_options)[1].resource_record_type
  zone_id         = aws_service_discovery_private_dns_namespace.monitoring_slave.hosted_zone
  records         = [tolist(aws_acm_certificate.monitoring_slave[local.secondary_role_index].domain_validation_options)[1].resource_record_value]
  ttl             = 60
  allow_overwrite = true

}

resource "aws_acm_certificate_validation" "monitoring_slave" {
  count           = local.is_management_env ? 0 : 1
  certificate_arn = aws_acm_certificate.monitoring_slave[local.secondary_role_index].arn
  validation_record_fqdns = [
    aws_route53_record.monitoring_slave[local.secondary_role_index].fqdn,
    aws_route53_record.prometheus[local.secondary_role_index].fqdn
  ]
}

resource "aws_route53_zone" "monitoring_slave" {
  name = "${local.environment}.services.${var.parent_domain_name}"
  vpc {
    vpc_id = module.vpc.outputs.vpcs[0].id
  }
  tags = merge(local.tags, { Name = "${var.name}-${var.secondary}" })
  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_vpc_association_authorization" "monitoring_slave" {
  count   = local.is_management_env ? 0 : 1
  vpc_id  = local.is_management_env ? module.vpc.outputs.vpcs[0].id : data.terraform_remote_state.management_dmi.outputs.vpcs[0].id
  zone_id = aws_service_discovery_private_dns_namespace.monitoring_slave.hosted_zone
}

resource "aws_route53_zone_association" "monitoring_slave" {
  for_each   = local.is_management_env ? local.dns_zone_ids[local.environment] : {}
  provider   = aws.management_zone
  vpc_id     = module.vpc.outputs.vpcs[0].id
  zone_id    = each.value
  depends_on = [aws_route53_vpc_association_authorization.monitoring_slave]
}
