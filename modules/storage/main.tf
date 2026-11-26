locals {
  tags = [for k, v in var.tags : { key = k, value = v }]
}
resource "volcenginecc_tos_bucket" "backup" {
  name          = "${var.name_prefix}-backup-${var.bucket_suffix}"
  storage_class = "STANDARD"
  az_redundancy = "multi-az"
  tags          = local.tags
  project_name  = var.project_name
}
resource "volcenginecc_tos_bucket" "archive" {
  name          = "${var.name_prefix}-archive-${var.bucket_suffix}"
  storage_class = "ARCHIVE"
  az_redundancy = "single-az"
  tags          = local.tags
  project_name  = var.project_name
}
resource "volcenginecc_tos_bucket" "logs" {
  name          = "${var.name_prefix}-logs-${var.bucket_suffix}"
  storage_class = "STANDARD"
  az_redundancy = "multi-az"
  tags          = local.tags
  project_name  = var.project_name
}
resource "volcenginecc_tos_bucket_encryption" "backup" {
  name              = volcenginecc_tos_bucket.backup.name
  sse_algorithm     = "kms"
  kms_master_key_id = var.kms_key_trn
}
resource "volcenginecc_tos_bucket_encryption" "logs" {
  name              = volcenginecc_tos_bucket.logs.name
  sse_algorithm     = "kms"
  kms_master_key_id = var.kms_key_trn
}
