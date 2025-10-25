data "google_client_config" "default" {}

data "google_project" "current" {}

locals {
  monitoring_fqdn = "${var.monitoring_subdomain}.${var.domain_name}"
  argocd_fqdn     = var.argocd_url != "" ? var.argocd_url : "${var.argocd_subdomain}.${var.domain_name}"
  vault_fqdn      = "${var.vault_subdomain}.${var.domain_name}"

  argocd_github_org = var.argocd_github_org != "" ? var.argocd_github_org : var.github_org

  common_labels = {
    project     = var.project_id
    environment = "production"
    managed_by  = "terraform"
  }
}

# VPC Network
module "network" {
  source        = "./modules/network"
  project_id    = var.project_id
  region        = var.region
  network_name  = var.network_name
  subnet_config = var.subnet_config
}

# GKE Cluster
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

  depends_on = [module.network]
}

# PostgreSQL Database
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

  depends_on = [module.network]
}

# Private DNS for Internal Services
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

# Cloud Storage Bucket
module "storage" {
  source      = "./modules/storage"
  project_id  = var.project_id
  region      = var.region
  bucket_name = var.bucket_name
  environment = var.environment

  depends_on = [module.network]
}

# Helm Deployments (NGINX Gateway, ArgoCD, etc.)
module "helm" {
  source = "./modules/helm"

  cluster_endpoint       = module.cluster.endpoint
  cluster_ca_certificate = module.cluster.ca_certificate

  grafana_domain   = local.monitoring_fqdn
  grafana_root_url = "https://${local.monitoring_fqdn}"

  argocd_version              = "8.1.0"
  argocd_url                  = local.argocd_fqdn
  argocd_github_client_id     = var.argocd_github_client_id
  argocd_github_client_secret = var.argocd_github_client_secret
  argocd_github_org           = local.argocd_github_org
  argocd_server_secret_key    = var.argocd_server_secret_key

  depends_on = [module.cluster]
}

# HashiCorp Vault - KMS Resources for Auto-Unseal
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

# HashiCorp Vault (Helm Deployment via ArgoCD)
module "vault" {
  count  = var.enable_vault ? 1 : 0
  source = "./modules/argocd-helm-app"

  application_name = "vault"
  project          = "default"
  namespace        = "vault"
  create_namespace = true
  repository_url   = "https://helm.releases.hashicorp.com"
  chart_name       = "vault"
  chart_version    = "0.30.0"

  # Vault configuration values
  values = yamlencode({
    global = {
      enabled   = true
      namespace = "vault"
    }

    server = {
      # High Availability mode with 2 replicas and GCP KMS auto-unseal
      ha = {
        enabled  = true
        replicas = 2
        raft = {
          enabled   = true
          setNodeId = true
          config    = <<-EOT
            ui = true
            
            # API and Cluster addresses
            api_addr = "http://vault.vault.svc.cluster.local:8200"
            cluster_addr = "http://vault.vault.svc.cluster.local:8201"
            
            # Logging configuration
            log_level = "INFO"
            log_format = "json"
            
            listener "tcp" {
              tls_disable = 1  # Gateway handles TLS termination
              address = "[::]:8200"
              cluster_address = "[::]:8201"
              
              # Additional listener settings
              telemetry {
                unauthenticated_metrics_access = false
              }
            }
            
            storage "raft" {
              path = "/vault/data"
              node_id = "HOSTNAME"
              
              # Performance tuning
              performance_multiplier = 1
            }
            
            # GCP KMS Auto-Unseal
            seal "gcpckms" {
              project     = "agri-os-prod"
              region      = "europe-west1"
              key_ring    = "vault-unseal"
              crypto_key  = "vault-key"
            }
            
            service_registration "kubernetes" {}
            
            # Default lease settings
            default_lease_ttl = "168h"  # 7 days
            max_lease_ttl = "720h"      # 30 days
            
            # Telemetry configuration
            telemetry {
              prometheus_retention_time = "30s"
              disable_hostname = true
              usage_gauge_period = "10m"
              maximum_gauge_cardinality = 500
            }
          EOT
        }
      }

      # Resources
      resources = {
        requests = {
          memory = "256Mi"
          cpu    = "250m"
        }
        limits = {
          memory = "512Mi"
          cpu    = "500m"
        }
      }

      # Storage
      dataStorage = {
        enabled      = true
        size         = "10Gi"
        storageClass = "standard-rwo"
      }

      # Service Account for GCP KMS access
      serviceAccount = {
        annotations = var.enable_vault ? {
          "iam.gke.io/gcp-service-account" = google_service_account.vault_kms[0].email
        } : {}
      }

      # Service configuration
      service = {
        enabled    = true
        type       = "ClusterIP"
        port       = 8200
        targetPort = 8200
      }
    }

    # UI Configuration
    ui = {
      enabled     = true
      serviceType = "ClusterIP"
    }

    # Injector for automatic secret injection
    injector = {
      enabled  = true
      replicas = 1 # Single replica for consistency with single-node setup
      resources = {
        requests = {
          memory = "256Mi"
          cpu    = "250m"
        }
        limits = {
          memory = "512Mi"
          cpu    = "500m"
        }
      }
    }

    # CSI Provider disabled - using External Secrets Operator instead
    csi = {
      enabled = false
    }
  })

  sync_policy = {
    automated = {
      prune       = true
      self_heal   = true
      allow_empty = false
    }
    sync_options = [
      "CreateNamespace=true",
      "ServerSideApply=true"
    ]
  }

  depends_on = [
    module.helm,
    google_service_account_iam_binding.vault_workload_identity
  ]
}

# Vault Configuration (Policies, Auth Methods, etc.)
module "vault_config" {
  count  = var.enable_vault && var.vault_root_token != "" ? 1 : 0
  source = "./modules/vault-config"

  kubernetes_host        = "https://kubernetes.default.svc.cluster.local:443"
  allowed_k8s_namespaces = ["platform", "vault", "default", "monitoring", "external-secrets"]

  depends_on = [module.vault]
}

# External Secrets Infrastructure (Namespace, ServiceAccount, RBAC)
module "external_secrets" {
  count  = var.enable_vault ? 1 : 0
  source = "./modules/external-secrets"

  namespace        = "external-secrets"
  vault_server_url = "http://vault.vault.svc.cluster.local:8200"
  vault_mount_path = "secret"
  vault_role       = "k8s-apps"

  # Target namespaces where ESO can create secrets
  target_namespaces = ["platform"]

  # ClusterSecretStore toggle
  enable_cluster_secret_store = var.enable_cluster_secret_store

  depends_on = [module.vault_config]
}

# External Secrets Operator (ESO Helm Deployment)
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

  depends_on = [module.external_secrets]
}

# Platform Applications (ArgoCD-managed GitOps apps)
module "platform_applications" {
  count  = var.github_app_id != "" ? 1 : 0
  source = "./modules/argocd-applications"

  project_name        = "platform"
  project_description = "Platform Applications"

  github_org = var.github_org

  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key

  app_of_apps_repo_url = var.platform_app_of_apps_repo_url
  app_of_apps_path     = "argocd-apps"
  app_of_apps_revision = "main"

  application_namespaces = [
    var.platform_namespace
  ]

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

  depends_on = [
    module.helm,
    module.vault_config,
    module.external_secrets,
    module.external_secrets_operator
  ]
}

# Prometheus Stack (Prometheus, Grafana, AlertManager)
module "prometheus-stack" {
  source = "./modules/argocd-helm-app"

  application_name = "prometheus-stack"
  project          = "default"
  namespace        = "monitoring"
  create_namespace = false
  repository_url   = "https://prometheus-community.github.io/helm-charts"
  chart_name       = "kube-prometheus-stack"
  chart_version    = "72.3.0"

  values = yamlencode({
    prometheus = {
      prometheusSpec = {
        retention = "15d"
        replicas  = 2 # HA with 2 replicas
        resources = {
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "750m"
            memory = "700Mi"
          }
        }
        securityContext = {
          fsGroup      = 2000
          runAsNonRoot = true
          runAsUser    = 1000
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

        # Additional scrape configurations for Vault metrics
        additionalScrapeConfigs = [
          {
            job_name     = "vault"
            metrics_path = "/v1/sys/metrics"
            params = {
              format = ["prometheus"]
            }
            scheme = "http"
            static_configs = [
              {
                targets = ["vault.vault.svc.cluster.local:8200"]
              }
            ]
            scrape_interval = "30s"
            scrape_timeout  = "10s"

            # Relabel configurations
            relabel_configs = [
              {
                source_labels = ["__address__"]
                target_label  = "instance"
              },
              {
                target_label = "job"
                replacement  = "vault"
              }
            ]
          }
        ]
      }
    }

    # Disable Alertmanager
    alertmanager = {
      enabled = false
    }

    # Grafana configuration with domain settings
    grafana = {
      enabled = true
      persistence = {
        enabled          = true
        size             = "10Gi"
        storageClassName = "standard-rwo"
      }
      "grafana.ini" = {
        server = {
          domain   = var.grafana_domain
          root_url = var.grafana_root_url
        }
        "auth.github" = {
          enabled                    = true
          allow_sign_up              = true
          client_id                  = var.github_client_id
          client_secret              = "$__env{GITHUB_CLIENT_SECRET}"
          scopes                     = "user:email,read:org"
          auth_url                   = "https://github.com/login/oauth/authorize"
          token_url                  = "https://github.com/login/oauth/access_token"
          api_url                    = "https://api.github.com/user"
          allowed_organizations      = var.github_allowed_orgs
          allowed_domains            = var.github_allowed_domains
          team_ids                   = var.github_team_ids
          allow_assign_grafana_admin = true
          role_attribute_path        = length(var.github_allowed_orgs) > 0 ? "contains(groups[*], '@${var.github_allowed_orgs[0]}/admins') && 'Admin' || 'Editor'" : "'Editor'"
        }
        auth = {
          disable_login_form  = false
          oauth_auto_login    = false
          logout_redirect_url = "https://${var.grafana_domain}/login"
        }
        users = {
          auto_assign_org      = true
          auto_assign_org_id   = 1
          auto_assign_org_role = "Editor" # Default role for GitHub users
        }
      }

      # Environment variables for sensitive data
      env = {
        GITHUB_CLIENT_SECRET = var.github_client_secret
      }

      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [{
            name            = "default"
            orgId           = 1
            folder          = ""
            type            = "file"
            disableDeletion = false
            editable        = true
            options = {
              path = "/var/lib/grafana/dashboards"
            }
          }]
        }
      }
      # Additional datasources configuration
      additionalDataSources = [
        {
          name      = "Loki"
          type      = "loki"
          url       = "http://loki-stack.monitoring.svc.cluster.local:3100"
          access    = "proxy"
          isDefault = false
        }
      ]
    }

    nodeExporter = {
      enabled = true
    }

    kubeStateMetrics = {
      enabled = true
    }
  })

  sync_policy = {
    automated = {
      prune       = true
      self_heal   = true
      allow_empty = false
    }
    sync_options = [
      "CreateNamespace=true",
      "ServerSideApply=true"
    ]
  }

  depends_on = [module.helm]
}

# Loki Stack (Log Aggregation)
module "loki-stack" {
  source = "./modules/argocd-helm-app"

  application_name = "loki-stack"
  project          = "default"
  namespace        = "monitoring"
  create_namespace = false # Don't create namespace - it already exists
  repository_url   = "https://grafana.github.io/helm-charts"
  chart_name       = "loki"
  chart_version    = "6.16.0"

  values = yamlencode({
    deploymentMode = "SingleBinary"

    singleBinary = {
      replicas = 1
      persistence = {
        enabled      = true
        size         = "50Gi"
        storageClass = "standard-rwo"
      }
      resources = {
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "1Gi"
        }
      }
    }

    # Explicitly disable all simple scalable deployment mode components
    backend = {
      replicas = 0
    }
    read = {
      replicas = 0
    }
    write = {
      replicas = 0
    }
    ingester = {
      replicas = 0
    }
    distributor = {
      replicas = 0
    }
    querier = {
      replicas = 0
    }
    queryFrontend = {
      replicas = 0
    }
    indexGateway = {
      replicas = 0
    }
    compactor = {
      replicas = 0
    }
    gateway = {
      replicas = 0
    }

    # Loki core configuration
    loki = {
      auth_enabled  = false
      useTestSchema = true
      storage = {
        type = "filesystem"
      }
      limits_config = {
        retention_period           = "744h" # 31 days
        reject_old_samples         = true
        reject_old_samples_max_age = "168h" # 7 days
      }
      commonConfig = {
        replication_factor = 1
      }
    }

    # Loki Canary (testing) - deployed as DaemonSet
    lokiCanary = {
      enabled = true
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

    # Disable other components
    grafana-agent = {
      enabled = false
    }
    test = {
      enabled = false
    }
  })

  sync_policy = {
    automated = {
      prune       = true
      self_heal   = true
      allow_empty = false
    }
    sync_options = [
      "CreateNamespace=true",
      "ServerSideApply=true"
    ]
  }

  depends_on = [module.helm]
}

# Grafana Alloy (Metrics & Logs Collection)
module "grafana-alloy" {
  source = "./modules/argocd-helm-app"

  application_name = "grafana-alloy"
  project          = "default"
  namespace        = "monitoring"
  create_namespace = false # Don't create namespace - it already exists
  repository_url   = "https://grafana.github.io/helm-charts"
  chart_name       = "alloy"
  chart_version    = "0.11.0"

  # Grafana Alloy configuration for log collection
  values = yamlencode({
    alloy = {
      configMap = {
        create  = true
        content = <<-EOT
          // Grafana Alloy configuration for Kubernetes log collection
          
          // Discover Kubernetes pods and containers
          discovery.kubernetes "pods" {
            role = "pod"
            namespaces {
              own_namespace = false
              names = []
            }
          }
          
          // Relabel discovered targets to extract useful labels
          discovery.relabel "pod_logs" {
            targets = discovery.kubernetes.pods.targets
            
            // Only collect logs from pods with annotations
            rule {
              source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
              action        = "keep"
              regex         = "true"
            }
            
            // Extract namespace
            rule {
              source_labels = ["__meta_kubernetes_namespace"]
              target_label  = "namespace"
            }
            
            // Extract pod name
            rule {
              source_labels = ["__meta_kubernetes_pod_name"]
              target_label  = "pod"
            }
            
            // Extract container name
            rule {
              source_labels = ["__meta_kubernetes_pod_container_name"]
              target_label  = "container"
            }
            
            // Set the log path
            rule {
              source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
              target_label  = "__path__"
              separator     = "/"
              replacement   = "/var/log/pods/*$1/*.log"
            }
          }
          
          // Collect logs from all pods (not just annotated ones for broader coverage)
          discovery.relabel "all_pod_logs" {
            targets = discovery.kubernetes.pods.targets
            
            // Extract namespace
            rule {
              source_labels = ["__meta_kubernetes_namespace"]
              target_label  = "namespace"
            }
            
            // Extract pod name
            rule {
              source_labels = ["__meta_kubernetes_pod_name"]
              target_label  = "pod"
            }
            
            // Extract container name
            rule {
              source_labels = ["__meta_kubernetes_pod_container_name"]
              target_label  = "container"
            }
            
            // Set the log path
            rule {
              source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
              target_label  = "__path__"
              separator     = "/"
              replacement   = "/var/log/pods/*$1/*.log"
            }
          }
          
          // Scrape logs and send to Loki
          loki.source.kubernetes "pod_logs" {
            targets    = discovery.relabel.all_pod_logs.output
            forward_to = [loki.write.default.receiver]
          }
          
          // Configure Loki write endpoint
          loki.write "default" {
            endpoint {
              url = "http://loki-stack.monitoring.svc.cluster.local:3100/loki/api/v1/push"
            }
          }
        EOT
      }
    }

    controller = {
      type = "daemonset" # Deploy as DaemonSet to collect logs from all nodes
    }

    serviceAccount = {
      create = true
      name   = "grafana-alloy"
    }

    # RBAC permissions for Kubernetes discovery
    rbac = {
      create = true
    }

    # Resources for the Alloy pods
    resources = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "256Mi"
      }
    }

    # Mount log directories from the host
    extraVolumes = [
      {
        name = "varlog"
        hostPath = {
          path = "/var/log"
        }
      }
    ]

    extraVolumeMounts = [
      {
        name      = "varlog"
        mountPath = "/var/log"
        readOnly  = true
      }
    ]

    # Security context
    securityContext = {
      runAsUser  = 0 # Run as root to access log files
      runAsGroup = 0
      fsGroup    = 0
    }

    # Node selector to ensure it runs on all nodes
    nodeSelector = {}
    # Tolerations to run on ALL nodes including spot instances
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
  })

  sync_policy = {
    automated = {
      prune       = true
      self_heal   = true
      allow_empty = false
    }
    sync_options = [
      "CreateNamespace=true",
      "ServerSideApply=true"
    ]
  }

  depends_on = [module.loki-stack]
}

# Vault ServiceMonitor for Prometheus Metrics
# ===========================================================================
# NOTE: This requires prometheus-operator CRDs to be installed first.
# Set enable_vault_servicemonitor=false for initial deployment,
# then enable after prometheus-stack is deployed.
# ===========================================================================
resource "kubernetes_manifest" "vault_service_monitor" {
  count = var.enable_vault && var.enable_vault_servicemonitor ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "vault-metrics"
      namespace = "vault"
      labels = {
        "app.kubernetes.io/name"     = "vault"
        "app.kubernetes.io/instance" = "vault"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name"     = "vault"
          "app.kubernetes.io/instance" = "vault"
        }
      }
      endpoints = [
        {
          port     = "http"
          interval = "30s"
          path     = "/v1/sys/metrics"
          params = {
            format = ["prometheus"]
          }
          scheme      = "http"
          honorLabels = true
          relabelings = [
            {
              sourceLabels = ["__meta_kubernetes_endpoint_port_name"]
              action       = "keep"
              regex        = "http"
            },
            {
              sourceLabels = ["__meta_kubernetes_service_name"]
              targetLabel  = "service"
            },
            {
              sourceLabels = ["__meta_kubernetes_pod_name"]
              targetLabel  = "pod"
            },
            {
              sourceLabels = ["__meta_kubernetes_namespace"]
              targetLabel  = "namespace"
            },
            {
              targetLabel = "job"
              replacement = "vault"
            }
          ]
        }
      ]
      namespaceSelector = {
        matchNames = ["vault"]
      }
    }
  }

  depends_on = [
    module.vault,
    module.prometheus-stack
  ]
}

# Grafana Alerting (Golden Signals & Application Alerts)
module "grafana_alerting" {
  count  = var.enable_grafana_alerting ? 1 : 0
  source = "./modules/grafana-alerting"

  # Slack notification settings
  slack_webhook_url = var.slack_webhook_url
  slack_channel     = var.slack_channel

  # Platform application settings
  platform_namespace = var.platform_namespace
  platform_apps      = var.platform_apps

  # PostgreSQL monitoring
  enable_postgres_monitoring = var.enable_postgres_monitoring
  prometheus_datasource_uid  = "prometheus" # Must match the UID in Grafana datasource provisioning

  # Golden Signals alerts toggle
  enable_golden_signals = var.enable_golden_signals_alerts

  # Alert thresholds (using defaults, can be customized)
  alert_thresholds = {
    latency = {
      p95_ms       = 1000 # 1 second
      p99_ms       = 3000 # 3 seconds
      duration_min = 5
    }
    errors = {
      rate_percent = 5 # 5% error rate
      duration_min = 5
    }
    saturation = {
      cpu_percent    = 80
      memory_percent = 85
      duration_min   = 10
    }
    traffic = {
      drop_percent = 50 # 50% traffic drop
      duration_min = 5
    }
    availability = {
      pod_ready_percent = 50 # Alert if less than 50% pods ready (allows scale-up and spot preemption recovery)
      duration_min      = 15 # Wait 15 minutes for GKE to provision new node and reschedule pods
    }
  }

  depends_on = [module.prometheus-stack]
}

# PostgreSQL Monitoring (Exporter & Dashboards)
module "postgres_monitoring" {
  count  = var.enable_postgres_monitoring ? 1 : 0
  source = "./modules/postgres-monitoring"

  project_id             = var.project_id
  postgres_instance_name = module.database.instance_name
  postgres_host          = module.database.private_ip_address
  monitoring_namespace   = "monitoring"
  monitoring_username    = var.postgres_monitoring_username

  # Query thresholds
  slow_query_threshold_ms = var.postgres_slow_query_threshold_ms

  # ServiceMonitor toggle
  enable_servicemonitor = var.enable_postgres_servicemonitor

  depends_on = [
    module.database,
    module.prometheus-stack
  ]
}

################################################################################
# LAYER 6: Ingress - Gateway API (HTTP/HTTPS Routes)
################################################################################
# ===========================================================================
# IMPORTANT: Two-phase deployment required!
# Phase 1: Deploy NGINX Gateway Fabric first:
#   terraform apply -target='module.helm'
# Phase 2: Enable Gateway resources:
#   Set enable_gateway=true in terraform.tfvars
#   terraform apply
#
# This avoids CRD dependency issues (Gateway API CRDs installed by NGINX helm chart)
# ===========================================================================
module "gateway_api" {
  source = "./modules/gateway-api"

  domain_name = var.domain_name

  # Enable Gateway (master switch)
  enable_gateway = var.enable_gateway

  # List of services to expose via HTTPRoutes
  # Each service gets HTTP→HTTPS redirect + HTTPS route automatically
  services = [
    {
      name              = "argocd"
      hostname          = "argocd"
      backend_service   = "argocd-server"
      backend_namespace = "argocd"
      backend_port      = 443
      enabled           = true
    },
    {
      name              = "grafana"
      hostname          = "monitoring"
      backend_service   = "kube-prometheus-stack-grafana"
      backend_namespace = "monitoring"
      backend_port      = 80
      enabled           = true
    },
    {
      name              = "prometheus"
      hostname          = "prometheus"
      backend_service   = "kube-prometheus-stack-prometheus"
      backend_namespace = "monitoring"
      backend_port      = 9090
      enabled           = true
    },
    {
      name              = "vault"
      hostname          = "vault"
      backend_service   = "vault"
      backend_namespace = "vault"
      backend_port      = 8200
      enabled           = var.enable_vault
    }
  ]

  # Namespaces that need ReferenceGrants (allow HTTPRoutes to reference Services)
  reference_grant_namespaces = concat(
    ["monitoring", "argocd"],
    var.enable_vault ? ["vault"] : []
  )

  # Gateway configuration
  gateway_class_name   = var.gateway_class_name
  tls_secret_name      = var.tls_secret_name
  tls_secret_namespace = "default"
  max_body_size        = var.max_body_size

  depends_on = [module.helm]
}
