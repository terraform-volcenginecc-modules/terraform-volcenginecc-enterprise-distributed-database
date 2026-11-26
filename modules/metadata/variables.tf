variable "enabled" {
  type        = bool
  description = "创建元数据 RDS / Create metadata RDS."
}
variable "name_prefix" {
  type        = string
  description = "资源名前缀 / Resource prefix."
}
variable "project_name" {
  type        = string
  description = "已有企业项目 / Existing enterprise project."
}
variable "vpc_id" {
  type        = string
  description = "VPC ID."
}
variable "subnet_id" {
  type        = string
  description = "主节点所在子网 / Primary node subnet."
}
variable "zones" {
  type        = list(string)
  description = "主备的两个不同可用区 / Two distinct primary/secondary AZs."
  validation {
    condition     = length(var.zones) == 2 && length(distinct(var.zones)) == 2
    error_message = "Primary and secondary must use different AZs."
  }
}
variable "allow_list_cidrs" {
  type        = list(string)
  description = "仅允许应用 Pod 网段 / Allowed application Pod CIDRs only."
}
variable "node_spec" {
  type        = string
  description = "RDS 节点规格 / RDS node specification."
}
variable "storage_type" {
  type        = string
  description = "RDS 存储类型 / RDS storage type."
}
variable "storage_gb" {
  type        = number
  description = "RDS 存储容量 GB / RDS storage capacity in GB."
}
variable "admin_name" {
  type        = string
  description = "数据库管理员名 / Database administrator name."
}
variable "admin_password" {
  type        = string
  description = "数据库机密密码 / Secret database password."
  sensitive   = true
}
variable "delete_protection_enabled" {
  type        = bool
  description = "删除保护 / Deletion protection."
}
variable "tags" {
  type        = map(string)
  description = "资源标签 / Resource tags."
}
