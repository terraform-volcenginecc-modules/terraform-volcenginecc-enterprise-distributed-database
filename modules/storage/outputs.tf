output "bucket_names" {
  description = "备份、归档、日志桶名称 / Backup, archive and log bucket names."
  value = {
    backup  = volcenginecc_tos_bucket.backup.name
    archive = volcenginecc_tos_bucket.archive.name
    logs    = volcenginecc_tos_bucket.logs.name
  }
  depends_on = [volcenginecc_tos_bucket_encryption.backup, volcenginecc_tos_bucket_encryption.logs]
}
