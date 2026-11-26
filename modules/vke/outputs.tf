output "cluster_id" {
  description = "VKE cluster ID."
  value       = volcenginecc_vke_cluster.main.cluster_id
}
output "node_pool_id" {
  description = "VKE node pool ID."
  value       = volcenginecc_vke_node_pool.main.node_pool_id
}
output "oidc" {
  description = "集群实际 OIDC 配置 / Actual cluster OIDC configuration."
  value       = volcenginecc_vke_cluster.main.irsa_config
}
output "endpoints" {
  description = "私有 API Server 地址 / Private API Server endpoints."
  value       = volcenginecc_vke_cluster.main.cluster_config.api_server_endpoints
}
output "addon_ids" {
  description = "六个插件标识；Required 插件为只读回读 / Six addon identifiers; Required addons are read back."
  value = {
    core_dns              = data.volcenginecc_vke_addon.core_dns.id
    metrics_server        = data.volcenginecc_vke_addon.metrics_server.id
    prometheus_agent      = volcenginecc_vke_addon.prometheus.id
    log_collector         = volcenginecc_vke_addon.logs.id
    node_problem_detector = volcenginecc_vke_addon.npd.id
    csi_ebs               = volcenginecc_vke_addon.csi.id
  }
}
