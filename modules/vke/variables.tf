variable "name_prefix" {
  type        = string
  description = "资源名前缀 / Resource prefix."
}
variable "project_name" {
  type        = string
  description = "已有企业项目 / Existing enterprise project."
}
variable "region" {
  type        = string
  description = "Required 插件协调使用的地域 / Region used by the Required-addon reconciler."
}
variable "node_subnet_ids" {
  type        = list(string)
  description = "三可用区节点子网 / Node subnets in three AZs."
}
variable "pod_subnet_ids" {
  type        = list(string)
  description = "三可用区 Pod 子网 / Pod subnets in three AZs."
}
variable "egress_ready" {
  type        = list(string)
  description = "完整 SNAT 链创建完成的依赖 / Dependency on the completed SNAT chain."
}
variable "service_cidr" {
  type        = string
  description = "Kubernetes Service CIDR."
}
variable "image_id" {
  type        = string
  description = "兼容 VKE 的地域镜像 / VKE-compatible regional image."
}
variable "node_login_mode" {
  type        = string
  description = "节点 ECS 登录方式 / Node ECS login mode."
  default     = "password"
  nullable    = false
  validation {
    condition     = contains(["key_pair", "password"], var.node_login_mode)
    error_message = "node_login_mode must be key_pair or password."
  }
}
variable "ssh_key_pair_name" {
  type        = string
  description = "密钥模式的已有 SSH 密钥对名称；密码模式为 null / Existing SSH key pair name in key_pair mode; null in password mode."
  default     = null
  validation {
    condition     = var.ssh_key_pair_name == null ? true : length(trimspace(var.ssh_key_pair_name)) > 0
    error_message = "ssh_key_pair_name must be null or a non-empty existing SSH key pair name."
  }
}
variable "node_password" {
  type        = string
  description = "原始 root 密码，仅密码模式使用；由模块编码 / Raw root password, used only in password mode and encoded by the module."
  default     = null
  sensitive   = true
  # 使用资源前置校验，避免 Terraform 1.5 的变量校验诊断回显机密。
  # Use a resource precondition to avoid secrets in Terraform 1.5 variable diagnostics.
}
variable "instance_types" {
  type        = list(string)
  description = "ECS 规格 / ECS instance types."
}
variable "kubernetes_version" {
  type        = string
  description = "VKE Kubernetes version."
}
variable "addon_versions" {
  type = object({
    core_dns              = string
    metrics_server        = string
    prometheus_agent      = string
    log_collector         = string
    node_problem_detector = string
    csi_ebs               = string
  })
  description = "经区域核实的插件版本 / Regionally verified addon versions."
}
variable "required_addons_script" {
  type        = string
  description = "必需插件协调脚本绝对路径 / Absolute path to the Required-addon reconciler."
}
variable "required_addons_reconcile_nonce" {
  type        = string
  description = "显式触发必需插件重新协调的令牌 / Token for an explicit Required-addon reconciliation rerun."
}
variable "required_addons_timeout" {
  type        = number
  description = "必需插件协调超时秒数 / Required-addon reconciliation timeout in seconds."
}
variable "node_scaling" {
  type        = object({ min = number, desired = number, max = number })
  description = "自动扩缩容边界 / Autoscaling bounds."
}
variable "delete_protection_enabled" {
  type        = bool
  description = "集群删除保护 / Cluster deletion protection."
}
variable "tls_project_id" {
  type        = string
  description = "TLS 项目 ID / TLS project ID."
}
variable "vmp_workspace_id" {
  type        = string
  description = "VMP 工作区 ID，关闭时 null / VMP workspace ID; null when disabled."
}
variable "tags" {
  type        = map(string)
  description = "资源标签 / Resource tags."
}
