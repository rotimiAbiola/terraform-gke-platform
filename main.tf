data "google_client_config" "default" {}

# Local computed values for better readability
locals {
  # Domain names for various services
  monitoring_fqdn = "${var.monitoring_subdomain}.${var.domain_name}"
  argocd_fqdn     = var.argocd_url != "" ? var.argocd_url : "${var.argocd_subdomain}.${var.domain_name}"
  vault_fqdn      = "${var.vault_subdomain}.${var.domain_name}"

  # GitHub organization (fallback to github_org variable)
  argocd_github_org = var.argocd_github_org != "" ? var.argocd_github_org : var.github_org

  # Common labels
  common_labels = {
    project     = var.project_id
    environment = "production"
    managed_by  = "terraform"
  }
}

# VPC Module
module "network" {
  source        = "./modules/network"
  project_id    = var.project_id
  region        = var.region
  network_name  = var.network_name
  subnet_config = var.subnet_config
}

# GKE Module
module "cluster" {
  source = "./modules/cluster"

  project_id   = var.project_id
  region       = var.region
  network_name = module.network.network_name
  subnet_name  = module.network.subnets["kubernetes"].name
  subnet_secondary_ranges = {
    pods     = module.network.subnets["kubernetes"].secondary_ip_range[0]
    services = module.network.subnets["kubernetes"].secondary_ip_range[1]
  }

  cluster_name               = var.cluster_name
  node_pools                 = var.node_pools
  master_ipv4_cidr           = var.master_ipv4_cidr
  master_authorized_networks = var.master_authorized_networks

  enable_private_endpoint = true
  enable_private_nodes    = true

  enable_etcd_encryption  = true
  kms_key_rotation_period = "7776000s"
}

# PostgreSQL Module
module "database" {
  source = "./modules/database"

  project_id      = var.project_id
  region          = var.region
  network_id      = module.network.network_id
  database_subnet = module.network.subnets["database"].name

  instance_name     = var.postgres_instance_name
  database_version  = var.postgres_version
  tier              = var.postgres_tier
  availability_type = var.postgres_availability_type
  disk_size         = var.postgres_disk_size

  databases = var.databases
  users     = var.users

  application_db_username = var.application_db_username
  db_charset              = "UTF8"
  db_collation            = "en_US.UTF8"

  authorized_networks = []
  enable_private_ip   = true
  private_network     = module.network.network_id

  enable_backup                 = true
  enable_point_in_time_recovery = true
  backup_location               = var.backup_region

  disk_autoresize = true
  ipv4_enabled    = false
}

# DNS Module - Private DNS for internal services
module "dns" {
  source = "./modules/dns"

  project_id          = var.project_id
  network_id          = module.network.network_id
  database_private_ip = module.database.private_ip_address

  dns_zone_name     = var.dns_zone_name
  dns_zone_domain   = var.dns_zone_domain
  database_dns_name = var.database_dns_name

  service_dns_records   = var.service_dns_records
  service_cname_records = var.service_cname_records

  depends_on = [module.database]
}

module "storage" {
  source      = "./modules/storage"
  project_id  = var.project_id
  region      = var.region
  bucket_name = var.bucket_name
  environment = var.environment
}

# GCP KMS for Vault Auto-Unseal
resource "google_kms_key_ring" "vault_unseal" {
  count    = var.enable_vault ? 1 : 0
  name     = "vault-unseal"
  location = var.region
}

resource "google_kms_crypto_key" "vault_key" {
  count           = var.enable_vault ? 1 : 0
  name            = "vault-key"
  key_ring        = google_kms_key_ring.vault_unseal[0].id
  rotation_period = "2592000s" # 30 days

  purpose = "ENCRYPT_DECRYPT"

  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Service Account for Vault to access KMS
resource "google_service_account" "vault_kms" {
  count        = var.enable_vault ? 1 : 0
  account_id   = "vault-kms"
  display_name = "Vault KMS Service Account"
  description  = "Service account for Vault to access GCP KMS for auto-unseal"
}

# IAM binding to allow Vault SA to use KMS key
resource "google_kms_crypto_key_iam_binding" "vault_kms" {
  count         = var.enable_vault ? 1 : 0
  crypto_key_id = google_kms_crypto_key.vault_key[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_service_account.vault_kms[0].email}",
  ]
}

# Additional IAM binding to allow Vault SA to read KMS key metadata
resource "google_kms_crypto_key_iam_binding" "vault_kms_viewer" {
  count         = var.enable_vault ? 1 : 0
  crypto_key_id = google_kms_crypto_key.vault_key[0].id
  role          = "roles/cloudkms.viewer"

  members = [
    "serviceAccount:${google_service_account.vault_kms[0].email}",
  ]
}

# Workload Identity binding for Vault service account
resource "google_service_account_iam_binding" "vault_workload_identity" {
  count              = var.enable_vault ? 1 : 0
  service_account_id = google_service_account.vault_kms[0].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[vault/vault]",
  ]
}

# GCP KMS for GKE etcd Encryption at Rest
resource "google_kms_key_ring" "gke_etcd" {
  name     = "gke-etcd-encryption"
  location = var.region
}

resource "google_kms_crypto_key" "gke_etcd_key" {
  name            = "gke-etcd-key"
  key_ring        = google_kms_key_ring.gke_etcd.id
  rotation_period = "7776000s" # 90 days

  purpose = "ENCRYPT_DECRYPT"

  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# IAM binding to allow GKE service account to use etcd encryption key
resource "google_kms_crypto_key_iam_binding" "gke_etcd_key" {
  crypto_key_id = google_kms_crypto_key.gke_etcd_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com",
  ]
}

# Data source to get current project number
data "google_project" "current" {}

# Helm Module - Deploy NGINX Gateway
module "helm" {
  source = "./modules/helm"

  cluster_endpoint       = module.cluster.endpoint
  cluster_ca_certificate = module.cluster.ca_certificate

  # Add depends_on to ensure GKE is fully ready
  depends_on = [
    module.cluster
  ]

  grafana_domain   = local.monitoring_fqdn
  grafana_root_url = "https://${local.monitoring_fqdn}"

  argocd_version              = "8.1.0"
  argocd_url                  = local.argocd_fqdn
  argocd_github_client_id     = var.argocd_github_client_id
  argocd_github_client_secret = var.argocd_github_client_secret
  argocd_github_org           = local.argocd_github_org
  argocd_server_secret_key    = var.argocd_server_secret_key
}
