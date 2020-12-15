data template_file "thanos_store" {
  template = file("${path.module}/config/thanos/bucket.yml")
  vars = {
    metrics_bucket = local.is_management_env ? aws_s3_bucket.monitoring[local.primary_role_index].id : data.terraform_remote_state.management_dmi.outputs.monitoring_bucket.id
    s3_endpoint    = "s3-${var.region}.amazonaws.com"
  }
}

resource "aws_s3_bucket_object" "thanos_store" {
  bucket     = local.is_management_env ? data.terraform_remote_state.management.outputs.config_bucket.id : data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "${var.name}/thanos/bucket.yml"
  content    = data.template_file.thanos_store.rendered
  kms_key_id = local.is_management_env ? data.terraform_remote_state.management.outputs.config_bucket.cmk_arn : data.terraform_remote_state.common.outputs.config_bucket_cmk.arn
  tags       = merge(local.tags, { Name = var.name })
}