output "database" {
  description = "RDS ID、白名单、连接信息和数据库名 / RDS ID, allowlist, connections and database names."
  value = var.enabled ? {
    instance_id   = volcenginecc_rdsmysql_instance.main[0].instance_id
    allow_list_id = volcenginecc_rdsmysql_allow_list.pods[0].allow_list_id
    addresses     = volcenginecc_rdsmysql_instance.main[0].address_objects
    names         = [volcenginecc_rdsmysql_database.metadata[0].name, volcenginecc_rdsmysql_database.monitoring[0].name]
  } : null
}
