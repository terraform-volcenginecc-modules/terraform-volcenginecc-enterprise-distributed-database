locals {
  keyring_name  = regex("keyrings/([^/]+)/keys/", var.kms_key_trn)[0]
  tags          = [for k, v in var.tags : { key = k, value = v }]
  kms_resources = var.kms_use_account_wide_resource ? ["*"] : [var.kms_key_trn]
}
resource "volcenginecc_iam_policy" "data_access" {
  policy_name = "${var.name_prefix}-data-policy"
  policy_type = "Custom"
  description = "Scoped TOS, TLS and KMS workload access"
  policy_document = jsonencode({
    Version = "1"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["tos:ListBucket"]
        Resource = [for name in values(var.bucket_names) : "trn:tos:::${name}"]
      },
      {
        Effect   = "Allow"
        Action   = ["tos:GetObject", "tos:PutObject"]
        Resource = [for name in values(var.bucket_names) : "trn:tos:::${name}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["tls:PutLogs", "tls:SearchLogs"]
        Resource = [for id in values(var.topic_ids) : "trn:tls:${var.region}:${var.account_id}:project/${var.tls_project_id}/topic/${id}"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = local.kms_resources
      }
    ]
  })
}
resource "volcenginecc_iam_role" "data_access" {
  role_name            = "${var.name_prefix}-data-role"
  display_name         = "DatabaseDataAccess"
  description          = "IRSA role restricted to one ServiceAccount"
  max_session_duration = 3600
  trust_policy_document = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = ["sts:AssumeRoleWithOIDC"]
      Principal = {
        Federated = [var.oidc.oidc_trn]
      }
      Condition = {
        StringEquals = {
          "oidc:iss" = var.oidc.issuer
          "oidc:aud" = var.oidc.audience
          "oidc:sub" = "system:serviceaccount:${var.workload_namespace}:${var.workload_service_account}"
        }
      }
    }]
  })
  policies = [{
    policy_name = volcenginecc_iam_policy.data_access.policy_name
    policy_type = "Custom"
  }]
  tags = local.tags
  lifecycle {
    precondition {
      condition     = try(length(var.oidc.oidc_trn) > 0 && length(var.oidc.issuer) > 0 && length(var.oidc.audience) > 0, false)
      error_message = "VKE must return an enabled IRSA provider, issuer and audience before this role can be created."
    }
  }
}
