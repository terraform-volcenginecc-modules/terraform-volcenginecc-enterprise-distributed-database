variable "name_prefix" {
  type        = string
  description = "资源名前缀 / Resource prefix."
}
variable "region" {
  type        = string
  description = "TLS 地域 / TLS region."
}
variable "account_id" {
  type        = string
  description = "TLS 账号 ID / TLS account ID."
}
variable "kms_key_id" {
  type        = string
  description = "外部 KMS Key UUID / External KMS Key UUID."
}
variable "kms_key_trn" {
  type        = string
  description = "外部 KMS Key TRN / External KMS Key TRN."
}
variable "kms_use_account_wide_resource" {
  type        = bool
  description = "KMS 数据动作使用 Resource=* 临时绕过精确授权异常 / Use Resource=* for KMS data actions as a temporary exact-authorization workaround."
}
variable "bucket_names" {
  type        = map(string)
  description = "允许访问的三个桶 / Three permitted buckets."
}
variable "topic_ids" {
  type        = map(string)
  description = "允许访问的 TLS 主题 / Permitted TLS topics."
}
variable "tls_project_id" {
  type        = string
  description = "主题所属 TLS 项目 ID / TLS project containing the topics."
}
variable "oidc" {
  type = object({
    issuer   = string
    audience = string
    oidc_trn = string
  })
  description = "VKE 实际回读的 OIDC 配置 / OIDC configuration read from VKE."
}
variable "workload_namespace" {
  type        = string
  description = "可信命名空间 / Trusted namespace."
}
variable "workload_service_account" {
  type        = string
  description = "可信 ServiceAccount / Trusted ServiceAccount."
}
variable "tags" {
  type        = map(string)
  description = "资源标签 / Resource tags."
}
