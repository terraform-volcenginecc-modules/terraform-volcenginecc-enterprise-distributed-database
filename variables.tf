variable "region" {
  type        = string
  description = "目标地域 / Target region."
  default     = "cn-beijing"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z0-9-]+$", var.region))
    error_message = "Use a valid region identifier such as cn-beijing."
  }
}

variable "name_prefix" {
  type        = string
  description = "资源名称前缀 / Resource name prefix."
  default     = "enterprise-db"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name_prefix))
    error_message = "Use 3–20 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "project_name" {
  type        = string
  description = "已有企业项目 / Existing enterprise project."
  default     = "default"
}

variable "kms_key_id" {
  type        = string
  description = "用户预先创建且由主栈外部管理的 KMS Key UUID / UUID of the user-created KMS Key managed outside the main stack."
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.kms_key_id))
    error_message = "KMS key ID must be a UUID."
  }
}

variable "kms_key_trn" {
  type        = string
  description = "用户预先创建且由主栈外部管理的 KMS Key TRN / TRN of the user-created KMS Key managed outside the main stack."
  validation {
    condition     = can(regex("^trn:kms:[^:]+:[0-9]+:keyrings/[^/]+/keys/[^/]+$", var.kms_key_trn))
    error_message = "KMS key TRN must identify a named Key in a named Keyring."
  }
}

variable "tags" {
  type        = map(string)
  description = "支持标签的资源使用的额外标签 / Additional tags for resources supporting tags."
  default     = {}
}

variable "vpc_cidr" {
  type        = string
  description = "私有 IPv4 VPC 网段 / Private IPv4 VPC CIDR."
  default     = "10.80.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Provide a valid IPv4 CIDR."
  }
}

variable "topology" {
  type = list(object({
    zone      = string
    node_cidr = string
    pod_cidr  = string
  }))
  description = "按顺序指定三个不同可用区及节点/Pod 子网 / Three distinct AZs with node and Pod CIDRs."
  default = [
    { zone = "cn-beijing-a", node_cidr = "10.80.0.0/20", pod_cidr = "10.80.64.0/18" },
    { zone = "cn-beijing-b", node_cidr = "10.80.16.0/20", pod_cidr = "10.80.128.0/18" },
    { zone = "cn-beijing-d", node_cidr = "10.80.32.0/20", pod_cidr = "10.80.192.0/18" }
  ]
  validation {
    condition = length(var.topology) == 3 && length(distinct([for t in var.topology : t.zone])) == 3 && alltrue([
      for t in var.topology : can(cidrnetmask(t.node_cidr)) && can(cidrnetmask(t.pod_cidr))
    ])
    error_message = "Exactly three distinct AZs and six valid IPv4 subnet CIDRs are required."
  }
}

variable "service_cidr" {
  type        = string
  description = "与 VPC 不重叠的 Kubernetes Service 网段 / Kubernetes Service CIDR outside the VPC."
  default     = "172.30.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.service_cidr))
    error_message = "Provide a valid IPv4 CIDR."
  }
}

variable "nat_spec" {
  type        = string
  description = "NAT 网关规格 / NAT gateway specification."
  default     = "Small"
}

variable "eip_bandwidth" {
  type        = number
  description = "出口 EIP 带宽上限 Mbps / Egress EIP bandwidth cap in Mbps."
  default     = 20
  validation {
    condition     = var.eip_bandwidth >= 1 && var.eip_bandwidth <= 200 && floor(var.eip_bandwidth) == var.eip_bandwidth
    error_message = "Bandwidth must be an integer from 1 to 200."
  }
}

variable "bucket_suffix" {
  type        = string
  description = "用户提供的全局唯一桶名后缀 / User-supplied globally unique bucket suffix."
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,18}[a-z0-9]$", var.bucket_suffix))
    error_message = "Use 3–20 lowercase letters, digits or hyphens; start and end with a letter or digit."
  }
}

variable "account_id" {
  type        = string
  description = "部署账号 ID，用于限定 TLS TRN / Deploying account ID for scoped TLS TRNs."
  validation {
    condition     = can(regex("^[0-9]+$", var.account_id))
    error_message = "Provide the numeric deploying account ID."
  }
}

variable "kms_use_account_wide_resource" {
  type        = bool
  description = "临时对 KMS GenerateDataKey/Decrypt 使用 Resource=*；false 恢复单 Key TRN / Temporarily use Resource=* for KMS GenerateDataKey/Decrypt; false restores the exact key TRN."
  default     = true
}

variable "image_id" {
  type        = string
  description = "目标地域支持所选 VKE 版本的 ECS 镜像 / Regional ECS image compatible with the chosen VKE version."
  validation {
    condition     = can(regex("^image-[a-z0-9]+$", var.image_id))
    error_message = "Provide a real regional image ID beginning with image-, followed by lowercase letters or digits."
  }
}

variable "node_login_mode" {
  type        = string
  description = "节点 ECS 登录方式：key_pair 或 password；不影响 kubeconfig / Node ECS login mode: key_pair or password; does not affect kubeconfig."
  default     = "password"
  nullable    = false
  validation {
    condition     = contains(["key_pair", "password"], var.node_login_mode)
    error_message = "node_login_mode must be key_pair or password."
  }
}

variable "ssh_key_pair_name" {
  type        = string
  description = "密钥模式必填的已有 ECS SSH 密钥对名称；密码模式留空，空字符串按 null 处理 / Existing ECS SSH key pair name required in key_pair mode; leave empty in password mode, empty strings are treated as null."
  default     = null
}

variable "node_password" {
  type        = string
  description = "密码模式的原始 root 密码，由模块做 Base64 编码；密钥模式设为 null / Raw root password in password mode, Base64-encoded by the module; null in key_pair mode."
  default     = null
  sensitive   = true
  # 在 VKE 节点池前置校验中检查规则，避免 Terraform 1.5 变量校验错误回显密码。
  # Validate in the VKE resource precondition: Terraform 1.5 variable errors can expose passwords.
}

variable "instance_types" {
  type        = list(string)
  description = "三个可用区均支持的 ECS 规格 / ECS types supported in all three AZs."
  default     = ["ecs.g3i.xlarge"]
  validation {
    condition     = length(var.instance_types) > 0 && alltrue([for t in var.instance_types : startswith(t, "ecs.")])
    error_message = "Supply at least one ECS instance type."
  }
}

variable "kubernetes_version" {
  type        = string
  description = "目标地域支持的 VKE 版本，IRSA 要求 >=1.24 / Supported VKE version; IRSA requires >=1.24."
  default     = "1.32"
  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version)) && try(tonumber(split(".", var.kubernetes_version)[1]) >= 24, false)
    error_message = "Use a supported 1.xx version at least 1.24."
  }
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
  description = "通过 VKE ListSupportedAddons 核实的六个插件版本 / Six addon versions verified with VKE ListSupportedAddons."
  validation {
    condition     = alltrue([for version in values(var.addon_versions) : can(regex("^v?[0-9]+\\.[0-9]+\\.[0-9]+", version))])
    error_message = "Supply six verified addon release versions, starting with X.Y.Z or vX.Y.Z."
  }
}

variable "required_addons_reconcile_nonce" {
  type        = string
  description = "修改此值可显式重跑 CoreDNS/metrics-server 协调 / Change to explicitly rerun CoreDNS/metrics-server reconciliation."
  default     = "v1"
  validation {
    condition     = length(trimspace(var.required_addons_reconcile_nonce)) > 0
    error_message = "Required addon reconciliation nonce must not be empty."
  }
}

variable "required_addons_timeout" {
  type        = number
  description = "CoreDNS/metrics-server 协调等待秒数 / CoreDNS/metrics-server reconciliation timeout in seconds."
  default     = 1200
  validation {
    condition     = var.required_addons_timeout >= 300 && var.required_addons_timeout <= 3600 && var.required_addons_timeout == floor(var.required_addons_timeout)
    error_message = "Required addon timeout must be an integer from 300 through 3600 seconds."
  }
}

variable "node_scaling" {
  type = object({
    min     = number
    desired = number
    max     = number
  })
  description = "自动扩缩容边界；desired 仅初始化使用 / Autoscaling bounds; desired is used only at creation."
  default     = { min = 3, desired = 3, max = 9 }
  validation {
    condition = var.node_scaling.min >= 3 && var.node_scaling.desired >= var.node_scaling.min && var.node_scaling.max >= var.node_scaling.desired && var.node_scaling.max <= 2000 && alltrue([
      for n in [var.node_scaling.min, var.node_scaling.desired, var.node_scaling.max] : n == floor(n)
    ])
    error_message = "Require integer counts: 3 <= min <= desired <= max <= 2000."
  }
}

variable "delete_protection_enabled" {
  type        = bool
  description = "VKE/RDS 删除保护，销毁前需原地关闭 / VKE/RDS deletion protection; disable with an update before destroy."
  default     = false
}

variable "workload_namespace" {
  type        = string
  description = "仅允许承担数据角色的命名空间 / Namespace allowed to assume the data role."
  default     = "database"
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.workload_namespace))
    error_message = "Use a Kubernetes DNS label."
  }
}

variable "workload_service_account" {
  type        = string
  description = "仅允许承担数据角色的 ServiceAccount / ServiceAccount allowed to assume the data role."
  default     = "data-access"
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.workload_service_account))
    error_message = "Use a Kubernetes DNS label."
  }
}

variable "tls_log_ttl_days" {
  type        = number
  description = "TLS 日志保留天数 / TLS log retention in days."
  default     = 30
  validation {
    condition     = var.tls_log_ttl_days >= 1 && var.tls_log_ttl_days <= 3650 && floor(var.tls_log_ttl_days) == var.tls_log_ttl_days
    error_message = "Retention must be an integer from 1 to 3650."
  }
}

variable "enable_vmp" {
  type        = bool
  description = "是否创建并关联 VMP 工作区 / Create and associate a VMP workspace."
  default     = false
}

variable "vmp_instance_type_id" {
  type        = string
  description = "启用 VMP 时必填的可用规格 ID / Available VMP specification ID, required when enabled."
  default     = ""
}

variable "enable_metadata_db" {
  type        = bool
  description = "是否创建双可用区 RDS 和两个数据库 / Create a dual-AZ RDS instance and two databases."
  default     = false
}

variable "metadata_node_spec" {
  type        = string
  description = "目标可用区支持的 RDS 节点规格 / RDS node specification supported in the target AZs."
  default     = "rds.mysql.c.s.1c2g"
}

variable "metadata_zones" {
  type        = list(string)
  description = "RDS 主备节点可用区；为空时使用拓扑前两个可用区 / RDS primary and secondary AZs; defaults to the first two topology AZs."
  default     = null
  validation {
    condition     = var.metadata_zones == null ? true : length(var.metadata_zones) == 2 && length(distinct(var.metadata_zones)) == 2
    error_message = "Metadata zones must contain exactly two distinct availability zones."
  }
}

variable "metadata_storage_type" {
  type        = string
  description = "RDS 存储类型 / RDS storage type."
  default     = "CloudESSD_PL0"
}

variable "metadata_storage_gb" {
  type        = number
  description = "RDS 存储容量 GB / RDS storage size in GB."
  default     = 100
}

variable "metadata_admin_name" {
  type        = string
  description = "RDS 高权限账号名称 / RDS administrative account name."
  default     = "db_admin"
}

variable "metadata_admin_password" {
  type        = string
  description = "RDS 密码；仅通过机密变量注入 / RDS password; inject through a secret variable only."
  sensitive   = true
  default     = null
  validation {
    condition = var.metadata_admin_password == null ? true : (
      length(var.metadata_admin_password) >= 8 && length(var.metadata_admin_password) <= 32 &&
      length(regexall("[^a-zA-Z0-9!@#$%^&*()_+\\-=,.&?|/]", var.metadata_admin_password)) == 0 &&
      sum([for pattern in ["[A-Z]", "[a-z]", "[0-9]", "[!@#$%^&*()_+\\-=,.&?|/]"] : length(regexall(pattern, var.metadata_admin_password)) > 0 ? 1 : 0]) >= 3
    )
    error_message = "Password must be 8–32 allowed characters and contain at least three character classes."
  }
}
