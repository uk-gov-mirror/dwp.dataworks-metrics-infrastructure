resource "aws_lb" "monitoring_slave" {
  count              = local.is_management_env ? 0 : 1
  name               = "${var.name}-${var.secondary}"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public_slave.*.id
  security_groups    = [aws_security_group.monitoring_slave[0].id]
  tags               = merge(local.tags, { Name = "${var.name}-${var.secondary}-lb" })

  access_logs {
    bucket  = data.terraform_remote_state.security-tools.outputs.logstore_bucket.id
    prefix  = "ELBLogs/${var.name}-${var.secondary}"
    enabled = true
  }
}

resource "aws_security_group" "monitoring_slave" {
  count  = local.is_management_env ? 0 : 1
  vpc_id = module.vpc.outputs.vpcs[local.secondary_role_index].id
  tags   = merge(local.tags, { Name = "${var.name}-${var.secondary}-lb" })

  lifecycle {
    create_before_destroy = true
  }
}

# resource "aws_security_group_rule" "allow_egress_prometheus" {
#   count                    = local.is_management_env ? 1 : 0
#   description              = "Allow loadbalancer to access prometheus user interface"
#   type                     = "egress"
#   to_port                  = var.prometheus_port
#   protocol                 = "tcp"
#   from_port                = var.prometheus_port
#   security_group_id        = aws_security_group.monitoring_slave[local.secondary_role_index].id
#   source_security_group_id = aws_security_group.prometheus[local.secondary_role_index].id
# }

# resource "aws_wafregional_web_acl_association" "lb_slave" {
#   count        = local.is_management_env ? 0 : 1
#   resource_arn = aws_lb.monitoring_slave[local.secondary_role_index].arn
#   web_acl_id   = module.waf.wafregional_web_acl_id
# }

# resource "aws_lb_listener" "monitoring_slave" {
#   count             = local.is_management_env ? 0 : 1
#   load_balancer_arn = aws_lb.monitoring_slave[0].arn
#   port              = var.https_port
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
#   certificate_arn   = aws_acm_certificate.monitoring_slave[0].arn

#   default_action {
#     type = "fixed-response"

#     fixed_response {
#       content_type = "text/plain"
#       message_body = "FORBIDDEN"
#       status_code  = "403"
#     }
#   }
# }

# resource "aws_lb_target_group" "prometheus" {
#   count       = local.is_management_env ? 0 : 1
#   name        = "prometheus-http"
#   port        = var.prometheus_port
#   protocol    = "HTTP"
#   vpc_id      = module.vpc.outputs.vpcs[local.secondary_role_index].id
#   target_type = "ip"

#   health_check {
#     port    = var.prometheus_port
#     path    = "/-/healthy"
#     matcher = "200"
#   }

#   stickiness {
#     enabled = true
#     type    = "lb_cookie"
#   }
#   tags = merge(local.tags, { Name = "prometheus" })
# }

# resource "aws_lb_listener_rule" "prometheus" {
#   count        = local.is_management_env ? 0 : 1
#   listener_arn = aws_lb_listener.monitoring_slave[local.secondary_role_index].arn

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.prometheus[local.secondary_role_index].arn
#   }

#   condition {
#     host_header {
#       values = [aws_route53_record.prometheus_loadbalancer[local.secondary_role_index].fqdn]
#     }
#   }
# }
