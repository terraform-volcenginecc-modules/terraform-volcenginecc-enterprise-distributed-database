variable "name_prefix" {
  type        = string
  description = "资源名前缀 / Resource prefix."
}
variable "project_name" {
  type        = string
  description = "TLS/VMP 归属企业项目 / Enterprise project for TLS/VMP."
}
variable "tls_log_ttl_days" {
  type        = number
  description = "日志保留天数 / Log retention in days."
}
variable "enable_vmp" {
  type        = bool
  description = "创建 VMP 工作区 / Create a VMP workspace."
}
variable "vmp_instance_type_id" {
  type        = string
  description = "VMP 规格 ID / VMP specification ID."
}
variable "tags" {
  type        = map(string)
  description = "资源标签 / Resource tags."
}
