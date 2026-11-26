output "keyring_name" {
  description = "从外部 Key TRN 提取的 KMS 密钥环名称 / KMS key ring name extracted from the external Key TRN."
  value       = local.keyring_name
}
output "kms_key_id" {
  description = "External KMS Key UUID."
  value       = var.kms_key_id
}
output "kms_key_trn" {
  description = "TOS SSE-KMS 使用的外部密钥 TRN / External Key TRN used by TOS SSE-KMS."
  value       = var.kms_key_trn
}
output "kms_resource_scope" {
  description = "KMS 数据权限范围 / KMS data permission scope."
  value       = var.kms_use_account_wide_resource ? "account_wide" : "exact_key"
}
output "role_trn" {
  description = "IRSA 数据访问角色 TRN / IRSA data access role TRN."
  value       = volcenginecc_iam_role.data_access.trn
}
