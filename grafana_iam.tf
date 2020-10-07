resource "aws_iam_role" "grafana" {
  count              = local.is_management_env ? 1 : 0
  name               = "grafana"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume_role.json
  tags               = merge(local.tags, { Name = "grafana" })
}

data "aws_iam_policy_document" "grafana_assume_role" {
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

resource "aws_iam_role_policy_attachment" "grafana_read_config_attachment" {
  count      = local.is_management_env ? 1 : 0
  role       = aws_iam_role.grafana[local.primary_role_index].name
  policy_arn = aws_iam_policy.grafana_read_config[local.primary_role_index].arn
}

resource "aws_iam_policy" "grafana_read_config" {
  count       = local.is_management_env ? 1 : 0
  name        = "GrafanaReadConfigPolicy"
  description = "Allow Grafana to read from config bucket"
  policy      = data.aws_iam_policy_document.grafana_read_config.json
}

data "aws_iam_policy_document" "grafana_read_config" {
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
      "${local.is_management_env ? data.terraform_remote_state.management.outputs.config_bucket.arn : data.terraform_remote_state.common.outputs.config_bucket.arn}/${var.name}/grafana/*",
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