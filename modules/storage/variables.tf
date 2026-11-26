variable "name_prefix" {
  type        = string
  description = "桶名称前缀 / Bucket prefix."
}
variable "project_name" {
  type        = string
  description = "桶归属企业项目 / Enterprise project for buckets."
}
variable "bucket_suffix" {
  type        = string
  description = "全局唯一后缀 / Globally unique suffix."
}
variable "kms_key_trn" {
  type        = string
  description = "同地域 KMS 密钥 TRN / KMS key TRN in the same region."
}
variable "tags" {
  type        = map(string)
  description = "资源标签 / Resource tags."
}
