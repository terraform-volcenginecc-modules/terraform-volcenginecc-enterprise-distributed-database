locals {
  tags = merge({ ManagedBy = "Terraform", Solution = "enterprise-distributed-database" }, var.tags)
}

module "network" {
  source        = "./modules/network"
  name_prefix   = var.name_prefix
  project_name  = var.project_name
  vpc_cidr      = var.vpc_cidr
  topology      = var.topology
  service_cidr  = var.service_cidr
  nat_spec      = var.nat_spec
  eip_bandwidth = var.eip_bandwidth
  tags          = local.tags
}

module "security" {
  source                        = "./modules/security"
  name_prefix                   = var.name_prefix
  region                        = var.region
  account_id                    = var.account_id
  kms_key_id                    = var.kms_key_id
  kms_key_trn                   = var.kms_key_trn
  kms_use_account_wide_resource = var.kms_use_account_wide_resource
  bucket_names                  = module.storage.bucket_names
  topic_ids                     = module.observability.topic_ids
  tls_project_id                = module.observability.project_id
  oidc                          = module.vke.oidc
  workload_namespace            = var.workload_namespace
  workload_service_account      = var.workload_service_account
  tags                          = local.tags
}

module "storage" {
  source        = "./modules/storage"
  name_prefix   = var.name_prefix
  project_name  = var.project_name
  bucket_suffix = var.bucket_suffix
  kms_key_trn   = module.security.kms_key_trn
  tags          = local.tags
}

module "observability" {
  source               = "./modules/observability"
  name_prefix          = var.name_prefix
  project_name         = var.project_name
  tls_log_ttl_days     = var.tls_log_ttl_days
  enable_vmp           = var.enable_vmp
  vmp_instance_type_id = var.vmp_instance_type_id
  tags                 = local.tags
}

module "metadata" {
  source                    = "./modules/metadata"
  enabled                   = var.enable_metadata_db
  name_prefix               = var.name_prefix
  project_name              = var.project_name
  vpc_id                    = module.network.vpc_id
  subnet_id                 = module.network.node_subnet_ids[0]
  zones                     = var.metadata_zones != null ? var.metadata_zones : [var.topology[0].zone, var.topology[1].zone]
  allow_list_cidrs          = [for t in var.topology : t.pod_cidr]
  node_spec                 = var.metadata_node_spec
  storage_type              = var.metadata_storage_type
  storage_gb                = var.metadata_storage_gb
  admin_name                = var.metadata_admin_name
  admin_password            = var.metadata_admin_password
  delete_protection_enabled = var.delete_protection_enabled
  tags                      = local.tags
}

resource "terraform_data" "vke_audit_cleanup" {
  input = {
    project_id = module.observability.project_id
    region     = var.region
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "/bin/sh scripts/运行生命周期.sh scripts/delete_vke_audit_topics.py"
    interpreter = ["/bin/sh", "-c"]
    environment = {
      TLS_PROJECT_ID    = self.input.project_id
      VOLCENGINE_REGION = self.input.region
    }
  }

  depends_on = [module.observability]
}

module "vke" {
  source                          = "./modules/vke"
  name_prefix                     = var.name_prefix
  project_name                    = var.project_name
  region                          = var.region
  node_subnet_ids                 = module.network.node_subnet_ids
  pod_subnet_ids                  = module.network.pod_subnet_ids
  egress_ready                    = module.network.egress_ready
  service_cidr                    = var.service_cidr
  image_id                        = var.image_id
  node_login_mode                 = var.node_login_mode
  ssh_key_pair_name               = var.ssh_key_pair_name == null ? null : (trimspace(var.ssh_key_pair_name) == "" ? null : var.ssh_key_pair_name)
  node_password                   = var.node_password
  instance_types                  = var.instance_types
  kubernetes_version              = var.kubernetes_version
  addon_versions                  = var.addon_versions
  required_addons_script          = abspath("${path.root}/scripts/reconcile_required_addons.py")
  required_addons_reconcile_nonce = var.required_addons_reconcile_nonce
  required_addons_timeout         = var.required_addons_timeout
  node_scaling                    = var.node_scaling
  delete_protection_enabled       = var.delete_protection_enabled
  tls_project_id                  = module.observability.project_id
  vmp_workspace_id                = module.observability.workspace_id
  tags                            = local.tags
  # VKE may create and own a NAT gateway when it observes no usable egress.
  # Keep cluster creation behind the complete Terraform-managed SNAT chain.
  depends_on = [
    module.network,
    terraform_data.vke_audit_cleanup,
  ]
}
