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

# Vault Configuration Module - Configure Vault for Kubernetes authentication
module "vault_config" {
  count  = var.enable_vault && var.vault_root_token != "" ? 1 : 0
  source = "./modules/vault-config"

  kubernetes_host        = "https://kubernetes.default.svc.cluster.local:443"
  allowed_k8s_namespaces = ["platform", "vault", "default", "monitoring", "external-secrets"]

  depends_on = [module.helm]
}

# External Secrets Infrastructure - Create namespace, service account, and RBAC
module "external_secrets" {
  count  = var.enable_vault ? 1 : 0
  source = "./modules/external-secrets"

  namespace        = "external-secrets"
  vault_server_url = "http://vault.vault.svc.cluster.local:8200"
  vault_mount_path = "secret"
  vault_role       = "k8s-apps"

  # Target namespaces where ESO can create secrets
  target_namespaces = ["platform"]

  depends_on = [
    module.vault_config
  ]
}

# External Secrets Operator ArgoCD Application - Deploy ESO Helm chart
module "external_secrets_operator" {
  count  = var.enable_vault ? 1 : 0
  source = "./modules/argocd-helm-app"

  application_name = "external-secrets-operator"
  chart_name       = "external-secrets"
  chart_version    = "0.10.4"
  repository_url   = "https://charts.external-secrets.io"
  namespace        = "external-secrets"
  create_namespace = false # Namespace is created by external_secrets module

  values = yamlencode({
    replicaCount = 2

    serviceAccount = {
      create = false
      name   = module.external_secrets[0].service_account_name
    }

    # Tolerations for spot nodes
    tolerations = [
      {
        key      = "cloud.google.com/gke-spot"
        operator = "Equal"
        value    = "true"
        effect   = "NoSchedule"
      },
      {
        operator = "Exists"
        effect   = "NoSchedule"
      },
      {
        operator = "Exists"
        effect   = "NoExecute"
      }
    ]

    webhook = {
      replicaCount = 2
      tolerations = [
        {
          key      = "cloud.google.com/gke-spot"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        },
        {
          operator = "Exists"
          effect   = "NoSchedule"
        },
        {
          operator = "Exists"
          effect   = "NoExecute"
        }
      ]
    }

    certController = {
      replicaCount = 2
      tolerations = [
        {
          key      = "cloud.google.com/gke-spot"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        },
        {
          operator = "Exists"
          effect   = "NoSchedule"
        },
        {
          operator = "Exists"
          effect   = "NoExecute"
        }
      ]
    }
  })

  depends_on = [
    module.external_secrets
  ]
}

# ArgoCD Applications Module - Platform Applications
module "platform_applications" {
  count  = var.github_app_id != "" ? 1 : 0
  source = "./modules/argocd-applications"

  # Project configuration
  project_name        = "platform"
  project_description = "Platform Applications"

  # GitHub organization (uses github_org variable)
  github_org = var.github_org

  # GitHub App authentication
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key

  # App of apps repository (optional - leave empty to manage directly with Terraform)
  app_of_apps_repo_url = var.platform_app_of_apps_repo_url
  app_of_apps_path     = "argocd-apps"
  app_of_apps_revision = "main"

  # Application namespaces to create automatically
  application_namespaces = [
    var.platform_namespace
  ]

  # Source repositories are automatically computed from github_org

  # Individual applications (empty when using app of apps pattern)
  applications = var.platform_applications

  # Default sync policy
  sync_policy = {
    automated = {
      prune       = true
      self_heal   = true
      allow_empty = false
    }
    sync_options = ["CreateNamespace=true", "ServerSideApply=true"]
    retry = {
      limit = 5
      backoff = {
        duration     = "5s"
        factor       = 2
        max_duration = "3m"
      }
    }
  }

  # CRITICAL: Ensure vault and external secrets are deployed first
  depends_on = [
    module.helm,
    module.vault_config,
    module.external_secrets,
    module.external_secrets_operator
  ]
}
