# 部署参数沿用已跑通的北京地域配置，使用新的资源名前缀与桶后缀。
# 平台通过环境变量注入 VOLCENGINE_ACCESS_KEY、VOLCENGINE_SECRET_KEY 及所需临时 Token。
# 创建和销毁时由脚本自动准备 Python 和依赖，无需设置额外运行环境参数。
region      = "cn-beijing"
name_prefix = "enterprise-db"
account_id  = "REPLACE_WITH_ACCOUNT_ID"
kms_key_id  = "REPLACE_WITH_EXTERNAL_KMS_KEY_UUID"
kms_key_trn = "trn:kms:cn-beijing:REPLACE_WITH_ACCOUNT_ID:keyrings/REPLACE_WITH_KEYRING/keys/REPLACE_WITH_KEY"
# KMS 沿用已跑通的账号级 GenerateDataKey/Decrypt 授权范围。
kms_use_account_wide_resource = true
bucket_suffix                 = "REPLACE_WITH_UNIQUE_SUFFIX"
image_id                      = "image-REPLACE_WITH_VERIFIED_IMAGE"
# 默认使用密码登录，凭据直接在本文件配置；仍支持切换为密钥对。
# 密钥对模式：node_login_mode = "key_pair"，填写 ssh_key_pair_name，node_password = null。
# 密码模式：node_login_mode = "password"，ssh_key_pair_name = null，填写 node_password 原始密码。
# 密码需为 8–30 位，至少包含大小写字母、数字、特殊字符中的三类，无需提前 Base64 编码。
node_login_mode    = "password"
ssh_key_pair_name  = null
node_password      = "REPLACE_WITH_NODE_PASSWORD"
instance_types     = ["ecs.g3i.xlarge"]
kubernetes_version = "1.32"

addon_versions = {
  core_dns              = "1.12.4"
  metrics_server        = "v0.7.1-vke.6"
  prometheus_agent      = "v3.10.0-vke.1.30"
  log_collector         = "v2.3.3"
  node_problem_detector = "v1.36.4-vke.1"
  csi_ebs               = "v1.6.0"
}

enable_metadata_db        = false
enable_vmp                = false
delete_protection_enabled = false

# 本次关闭 RDS；以下参数仅在 enable_metadata_db = true 时生效。
metadata_node_spec    = "rds.mysql.c.s.1c2g"
metadata_zones        = ["cn-beijing-a", "cn-beijing-b"]
metadata_storage_type = "CloudESSD_PL0"
metadata_storage_gb   = 100

# 本次关闭 VMP；开启时需填写该地域可用的规格 ID。
vmp_instance_type_id = ""

tags = {
  Environment = "test"
}
