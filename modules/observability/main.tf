locals {
  tags = [for k, v in var.tags : { key = k, value = v }]
}
resource "volcenginecc_tls_project" "main" {
  project_name     = "${var.name_prefix}-logs"
  description      = "Enterprise database logs"
  iam_project_name = var.project_name
  tags             = local.tags
}
resource "volcenginecc_tls_topic" "container" {
  project_id  = volcenginecc_tls_project.main.project_id
  topic_name  = "${var.name_prefix}-container"
  description = "Container runtime logs"
  shard_count = 1
  ttl         = var.tls_log_ttl_days
  tags        = local.tags
}
resource "volcenginecc_tls_topic" "audit" {
  project_id  = volcenginecc_tls_project.main.project_id
  topic_name  = "${var.name_prefix}-audit"
  description = "Application audit logs"
  shard_count = 1
  ttl         = var.tls_log_ttl_days
  tags        = local.tags
}
resource "volcenginecc_tls_index" "container" {
  topic_id = volcenginecc_tls_topic.container.topic_id
  full_text = {
    case_sensitive  = false
    delimiter       = ", '\";=()[]{}?@&<>/:"
    include_chinese = true
  }
}
resource "volcenginecc_vmp_workspace" "main" {
  count                     = var.enable_vmp ? 1 : 0
  name                      = "${var.name_prefix}-metrics"
  project_name              = var.project_name
  description               = "Enterprise database metrics"
  instance_type_id          = var.vmp_instance_type_id
  delete_protection_enabled = false
  public_access_enabled     = false
  auth_type                 = "None"
  tags                      = local.tags
  lifecycle {
    precondition {
      condition     = length(trimspace(var.vmp_instance_type_id)) > 0
      error_message = "An available VMP specification ID is required when VMP is enabled."
    }
  }
}
