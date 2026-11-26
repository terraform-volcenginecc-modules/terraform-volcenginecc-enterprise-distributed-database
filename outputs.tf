output "network" {
  description = "VPC、子网和统一出口 / VPC, subnets and shared egress."
  value = {
    vpc_id          = module.network.vpc_id
    node_subnet_ids = module.network.node_subnet_ids
    pod_subnet_ids  = module.network.pod_subnet_ids
    nat_gateway_id  = module.network.nat_gateway_id
    eip_id          = module.network.eip_id
    eip_address     = module.network.eip_address
    snat_ids        = module.network.egress_ready
  }
}

output "storage" {
  description = "桶名及加密密钥标识，不包含凭证 / Bucket names and encryption key identifiers, without credentials."
  value = {
    buckets      = module.storage.bucket_names
    kms_key_id   = module.security.kms_key_id
    kms_key_trn  = module.security.kms_key_trn
    keyring_name = module.security.keyring_name
  }
}

output "cluster" {
  description = "集群、节点池、插件及 OIDC 配置 / Cluster, node pool, addons and OIDC configuration."
  value = {
    id           = module.vke.cluster_id
    node_pool_id = module.vke.node_pool_id
    addons       = module.vke.addon_ids
    oidc         = module.vke.oidc
    endpoints    = module.vke.endpoints
  }
}

output "observability" {
  description = "TLS 项目/主题和可选 VMP 工作区 / TLS project/topics and optional VMP workspace."
  value = {
    project_id   = module.observability.project_id
    topic_ids    = module.observability.topic_ids
    workspace_id = module.observability.workspace_id
  }
}

output "metadata" {
  description = "可选 RDS 输出；关闭时为 null / Optional RDS output; null when disabled."
  value       = module.metadata.database
}

output "workload_access" {
  description = "Pod 验证所需非机密参数 / Non-secret configuration for the Pod verification."
  value = {
    region          = var.region
    namespace       = var.workload_namespace
    service_account = var.workload_service_account
    role_trn        = module.security.role_trn
    kms_scope       = module.security.kms_resource_scope
    kms_key_id      = module.security.kms_key_id
    kms_key_trn     = module.security.kms_key_trn
    backup_bucket   = module.storage.bucket_names.backup
    topic_id        = module.observability.topic_ids.container
  }
}

output "expected_managed_resource_count" {
  description = "主 State 管理资源数量，不含外部 KMS Keyring/Key；两个 Required 插件为集群拥有 / Main-state resource count, excluding external KMS Keyring/Key; two Required addons are cluster-owned."
  value       = 34 + (var.enable_metadata_db ? 4 : 0) + (var.enable_vmp ? 1 : 0)
}
