variable "name_prefix" {
  type        = string
  description = "资源名前缀 / Resource prefix."
}
variable "project_name" {
  type        = string
  description = "已有企业项目 / Existing enterprise project."
}
variable "vpc_cidr" {
  type        = string
  description = "VPC IPv4 CIDR."
}
variable "topology" {
  type = list(object({
    zone      = string
    node_cidr = string
    pod_cidr  = string
  }))
  description = "三个可用区及子网 / Three AZs and their subnets."
  validation {
    condition     = length(var.topology) == 3 && length(distinct([for t in var.topology : t.zone])) == 3
    error_message = "Exactly three distinct AZs are required."
  }
}
variable "service_cidr" {
  type        = string
  description = "Kubernetes Service IPv4 CIDR."
}
variable "nat_spec" {
  type        = string
  description = "NAT 网关规格 / NAT specification."
}
variable "eip_bandwidth" {
  type        = number
  description = "EIP 带宽 Mbps / EIP bandwidth in Mbps."
}
variable "tags" {
  type        = map(string)
  description = "资源标签 / Resource tags."
}
