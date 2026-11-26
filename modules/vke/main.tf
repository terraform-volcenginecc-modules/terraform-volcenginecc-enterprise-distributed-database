locals {
  tags = [for k, v in var.tags : { key = k, value = v }]
  node_login = {
    ssh_key_pair_name = var.node_login_mode == "key_pair" ? var.ssh_key_pair_name : null
    password          = var.node_login_mode == "password" ? (var.node_password == null ? null : base64encode(var.node_password)) : null
  }
  node_password_valid = var.node_password == null ? true : (
    length(var.node_password) >= 8 && length(var.node_password) <= 30 &&
    !startswith(var.node_password, "/") && !startswith(var.node_password, "$6$") &&
    can(regex("^[a-zA-Z0-9()`~!@#$%^&*_+=|{}\\[\\]:;'<>,.?/-]+$", var.node_password)) &&
    length([for pattern in ["[a-z]", "[A-Z]", "[0-9]", "[^a-zA-Z0-9]"] : pattern if can(regex(pattern, var.node_password))]) >= 3
  )
  required_addons = {
    core-dns = {
      version          = var.addon_versions.core_dns
      deploy_mode      = "Unmanaged"
      deploy_node_type = "Node"
    }
    metrics-server = {
      version          = var.addon_versions.metrics_server
      deploy_mode      = "Unmanaged"
      deploy_node_type = "Node"
    }
  }
}
resource "volcenginecc_vke_cluster" "main" {
  name                      = "${var.name_prefix}-vke"
  project_name              = var.project_name
  description               = "Enterprise distributed database infrastructure"
  kubernetes_version_create = var.kubernetes_version
  delete_protection_enabled = var.delete_protection_enabled
  cluster_config = {
    subnet_ids                             = var.node_subnet_ids
    api_server_public_access_enabled       = false
    resource_public_access_default_enabled = false
  }
  pods_config = {
    pod_network_mode = "VpcCniShared"
    vpc_cni_config = {
      subnet_ids        = var.pod_subnet_ids
      trunk_eni_enabled = false
    }
  }
  services_config = {
    service_cidrsv_4 = [var.service_cidr]
  }
  irsa_config = {
    enabled = true
  }
  logging_config = {
    log_project_id = var.tls_project_id
    log_setups = [{
      enabled  = true
      log_ttl  = 30
      log_type = "Audit"
    }]
  }
  monitoring_config = var.vmp_workspace_id == null ? null : {
    workspace_id                       = var.vmp_workspace_id
    enable_metrics_external_collection = true
  }
  tags = local.tags
  lifecycle {
    precondition {
      condition     = length(var.egress_ready) == 6 && alltrue([for id in var.egress_ready : length(id) > 0])
      error_message = "All six SNAT entries must be ready before creating the VKE cluster."
    }
  }
}
resource "volcenginecc_vke_node_pool" "main" {
  cluster_id = volcenginecc_vke_cluster.main.cluster_id
  name       = "${var.name_prefix}-pool"
  node_config = {
    instance_type_ids     = var.instance_types
    subnet_ids            = var.node_subnet_ids
    image_id              = var.image_id
    instance_charge_type  = "PostPaid"
    project_name          = var.project_name
    public_access_enabled = false
    system_volume = {
      size = 80
      type = "ESSD_PL0"
    }
    security = {
      login = local.node_login
    }
    tags = local.tags
  }
  auto_scaling = {
    enabled          = true
    min_replicas     = var.node_scaling.min
    desired_replicas = var.node_scaling.desired
    max_replicas     = var.node_scaling.max
    subnet_policy    = "ZoneBalance"
  }
  tags = local.tags
  lifecycle {
    # 扩缩容控制器管理实时 desired，Terraform 继续管理 min/max。
    # The autoscaler owns live desired; Terraform still manages min/max.
    ignore_changes = [auto_scaling.desired_replicas]
    precondition {
      condition = (
        var.node_login_mode == "key_pair"
        ? var.ssh_key_pair_name != null && var.node_password == null
        : var.node_password != null && var.ssh_key_pair_name == null
      )
      error_message = "Set only ssh_key_pair_name for key_pair mode, or only node_password for password mode; set the unused credential to null."
    }
    precondition {
      condition     = local.node_password_valid
      error_message = "node_password must contain 8–30 characters, at least three of lowercase/uppercase/digits/special characters, no unsupported characters, and must not start with / or $6$."
    }
    precondition {
      condition     = length(var.egress_ready) == 6 && alltrue([for id in var.egress_ready : length(id) > 0])
      error_message = "All six SNAT entries must be ready before provisioning workers."
    }
  }
}

# Required 插件由集群拥有：创建期协调、只读回读，销毁时随集群回收。
# The cluster owns Required addons: reconcile on create, read back, and reclaim with the cluster.
resource "terraform_data" "required_addons" {
  triggers_replace = [
    volcenginecc_vke_cluster.main.cluster_id,
    var.region,
    jsonencode(local.required_addons),
    var.required_addons_reconcile_nonce,
    filesha256(var.required_addons_script),
    filesha256("${dirname(var.required_addons_script)}/cloud_api.py"),
    filesha256("${dirname(var.required_addons_script)}/运行生命周期.sh"),
    filesha256("${dirname(var.required_addons_script)}/requirements.txt"),
    filesha256("${dirname(var.required_addons_script)}/preflight_runtime.py"),
  ]

  provisioner "local-exec" {
    command = "/bin/sh \"$LIFECYCLE_RUNNER\" \"$REQUIRED_ADDONS_SCRIPT\""
    environment = {
      LIFECYCLE_RUNNER           = "${dirname(var.required_addons_script)}/运行生命周期.sh"
      REQUIRED_ADDONS_CLUSTER_ID = volcenginecc_vke_cluster.main.cluster_id
      REQUIRED_ADDONS_JSON       = jsonencode(local.required_addons)
      REQUIRED_ADDONS_REGION     = var.region
      REQUIRED_ADDONS_SCRIPT     = var.required_addons_script
      REQUIRED_ADDONS_TIMEOUT    = tostring(var.required_addons_timeout)
    }
    interpreter = ["/bin/sh", "-c"]
  }

  depends_on = [volcenginecc_vke_node_pool.main]
}

data "volcenginecc_vke_addon" "core_dns" {
  id = "${volcenginecc_vke_cluster.main.cluster_id}|core-dns"

  lifecycle {
    postcondition {
      condition = (
        self.cluster_id == volcenginecc_vke_cluster.main.cluster_id &&
        self.name == "core-dns" &&
        self.version == local.required_addons["core-dns"].version &&
        self.deploy_mode == local.required_addons["core-dns"].deploy_mode &&
        self.deploy_node_type == local.required_addons["core-dns"].deploy_node_type &&
        self.status.phase == "Running"
      )
      error_message = "Required addon reconciliation did not produce the requested Running core-dns component."
    }
  }

  depends_on = [terraform_data.required_addons]
}

data "volcenginecc_vke_addon" "metrics_server" {
  id = "${volcenginecc_vke_cluster.main.cluster_id}|metrics-server"

  lifecycle {
    postcondition {
      condition = (
        self.cluster_id == volcenginecc_vke_cluster.main.cluster_id &&
        self.name == "metrics-server" &&
        self.version == local.required_addons["metrics-server"].version &&
        self.deploy_mode == local.required_addons["metrics-server"].deploy_mode &&
        self.deploy_node_type == local.required_addons["metrics-server"].deploy_node_type &&
        self.status.phase == "Running"
      )
      error_message = "Required addon reconciliation did not produce the requested Running metrics-server component."
    }
  }

  depends_on = [terraform_data.required_addons]
}

# 可卸载插件继续由 Terraform 管理并显式串行。
# Terraform continues to manage and serialize removable addons.
resource "volcenginecc_vke_addon" "prometheus" {
  cluster_id = volcenginecc_vke_cluster.main.cluster_id
  name       = "prometheus-agent"
  version    = var.addon_versions.prometheus_agent
  depends_on = [
    data.volcenginecc_vke_addon.core_dns,
    data.volcenginecc_vke_addon.metrics_server,
  ]
}
resource "volcenginecc_vke_addon" "logs" {
  cluster_id = volcenginecc_vke_cluster.main.cluster_id
  name       = "log-collector"
  version    = var.addon_versions.log_collector
  depends_on = [volcenginecc_vke_addon.prometheus]
}
resource "volcenginecc_vke_addon" "npd" {
  cluster_id = volcenginecc_vke_cluster.main.cluster_id
  name       = "node-problem-detector"
  version    = var.addon_versions.node_problem_detector
  depends_on = [volcenginecc_vke_addon.logs]
}
resource "volcenginecc_vke_addon" "csi" {
  cluster_id = volcenginecc_vke_cluster.main.cluster_id
  name       = "csi-ebs"
  version    = var.addon_versions.csi_ebs
  depends_on = [volcenginecc_vke_addon.npd]
}
