output "project_id" {
  description = "TLS project ID."
  value       = volcenginecc_tls_project.main.project_id
}
output "topic_ids" {
  description = "应用日志及审计主题 ID / Application and audit topic IDs."
  value = {
    container = volcenginecc_tls_topic.container.topic_id
    audit     = volcenginecc_tls_topic.audit.topic_id
  }
  depends_on = [volcenginecc_tls_index.container]
}
output "workspace_id" {
  description = "可选 VMP workspace ID / Optional VMP workspace ID."
  value       = try(volcenginecc_vmp_workspace.main[0].workspace_id, null)
}
