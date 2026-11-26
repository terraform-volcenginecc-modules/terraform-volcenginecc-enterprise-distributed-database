locals {
  tags = [for k, v in var.tags : { key = k, value = v }]
}
resource "volcenginecc_rdsmysql_allow_list" "pods" {
  count           = var.enabled ? 1 : 0
  allow_list_name = "${var.name_prefix}-pods"
  allow_list_desc = "Application Pod subnets only"
  allow_list_type = "IPv4"
  user_allow_list = var.allow_list_cidrs
  project_name    = var.project_name
}
resource "volcenginecc_rdsmysql_instance" "main" {
  count                  = var.enabled ? 1 : 0
  instance_name          = "${var.name_prefix}-metadata"
  project_name           = var.project_name
  instance_type          = "DoubleNode"
  db_engine_version      = "MySQL_8_0"
  vpc_id                 = var.vpc_id
  subnet_id              = var.subnet_id
  storage_space          = var.storage_gb
  storage_type           = var.storage_type
  deletion_protection    = var.delete_protection_enabled ? "Enabled" : "Disabled"
  allow_list_ids         = [volcenginecc_rdsmysql_allow_list.pods[0].allow_list_id]
  super_account_name     = var.admin_name
  super_account_password = var.admin_password
  tags                   = local.tags
  charge_detail = {
    charge_type = "PostPaid"
  }
  nodes = [
    { node_type = "Primary", node_spec = var.node_spec, zone_id = var.zones[0] },
    { node_type = "Secondary", node_spec = var.node_spec, zone_id = var.zones[1] }
  ]
  lifecycle {
    precondition {
      condition     = var.admin_password != null
      error_message = "Inject metadata_admin_password through a secret variable when metadata RDS is enabled."
    }
  }
}
resource "volcenginecc_rdsmysql_database" "metadata" {
  count              = var.enabled ? 1 : 0
  instance_id        = volcenginecc_rdsmysql_instance.main[0].instance_id
  name               = "enterprise_metadata"
  character_set_name = "utf8mb4"
}
resource "volcenginecc_rdsmysql_database" "monitoring" {
  count              = var.enabled ? 1 : 0
  instance_id        = volcenginecc_rdsmysql_instance.main[0].instance_id
  name               = "enterprise_monitoring"
  character_set_name = "utf8mb4"
  depends_on         = [volcenginecc_rdsmysql_database.metadata]
}
