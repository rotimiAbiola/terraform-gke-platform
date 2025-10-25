terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

# Random password for monitoring user
resource "random_password" "monitoring_password" {
  length           = 32
  special          = true
  override_special = "-_+.,"
  upper            = true
  lower            = true
  numeric          = true
}

# Create monitoring user in PostgreSQL
resource "google_sql_user" "monitoring" {
  name     = var.monitoring_username
  instance = var.postgres_instance_name
  password = random_password.monitoring_password.result
  project  = var.project_id
}

# Store monitoring credentials in Secret Manager
resource "google_secret_manager_secret" "monitoring_password" {
  secret_id = "${var.postgres_instance_name}-monitoring-password"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = "europe-west1"
      }
    }
  }

  labels = {
    app         = "postgres-monitoring"
    environment = "production"
  }
}

resource "google_secret_manager_secret_version" "monitoring_password" {
  secret      = google_secret_manager_secret.monitoring_password.id
  secret_data = random_password.monitoring_password.result
}

# Kubernetes Secret for postgres_exporter
resource "kubernetes_secret" "postgres_exporter" {
  metadata {
    name      = "postgres-exporter-secret"
    namespace = var.monitoring_namespace

    labels = {
      app = "postgres-exporter"
    }
  }

  data = {
    DATA_SOURCE_NAME = "postgresql://${google_sql_user.monitoring.name}:${urlencode(random_password.monitoring_password.result)}@${var.postgres_host}:5432/postgres?sslmode=require"
    # Individual components for flexibility
    POSTGRES_USER     = google_sql_user.monitoring.name
    POSTGRES_PASSWORD = random_password.monitoring_password.result
    POSTGRES_HOST     = var.postgres_host
    POSTGRES_PORT     = "5432"
    POSTGRES_DB       = "postgres"
  }

  type = "Opaque"
}

# Kubernetes ConfigMap with monitoring queries
resource "kubernetes_config_map" "postgres_queries" {
  metadata {
    name      = "postgres-exporter-queries"
    namespace = var.monitoring_namespace

    labels = {
      app = "postgres-exporter"
    }
  }

  data = {
    "queries.yaml" = templatefile("${path.module}/templates/queries.yaml", {})
  }
}

# Deploy postgres_exporter
resource "kubernetes_deployment" "postgres_exporter" {
  metadata {
    name      = "postgres-exporter"
    namespace = var.monitoring_namespace

    labels = {
      app = "postgres-exporter"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgres-exporter"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres-exporter"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9187"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        container {
          name  = "postgres-exporter"
          image = "quay.io/prometheuscommunity/postgres-exporter:v0.16.0"

          port {
            container_port = 9187
            name           = "metrics"
            protocol       = "TCP"
          }

          env {
            name = "DATA_SOURCE_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_exporter.metadata[0].name
                key  = "DATA_SOURCE_NAME"
              }
            }
          }

          env {
            name  = "PG_EXPORTER_EXTEND_QUERY_PATH"
            value = "/etc/postgres_exporter/queries.yaml"
          }

          env {
            name  = "PG_EXPORTER_DISABLE_DEFAULT_METRICS"
            value = "false"
          }

          env {
            name  = "PG_EXPORTER_DISABLE_SETTINGS_METRICS"
            value = "false"
          }

          env {
            name  = "PG_EXPORTER_CONSTANT_LABELS"
            value = "instance=${var.postgres_instance_name}"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "queries"
            mount_path = "/etc/postgres_exporter"
            read_only  = true
          }

          liveness_probe {
            http_get {
              path = "/metrics"
              port = 9187
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/metrics"
              port = 9187
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }

        volume {
          name = "queries"
          config_map {
            name = kubernetes_config_map.postgres_queries.metadata[0].name
          }
        }

        restart_policy = "Always"
      }
    }
  }
}

# Service for postgres_exporter
resource "kubernetes_service" "postgres_exporter" {
  metadata {
    name      = "postgres-exporter"
    namespace = var.monitoring_namespace

    labels = {
      app = "postgres-exporter"
    }

    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9187"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "postgres-exporter"
    }

    port {
      name        = "metrics"
      port        = 9187
      target_port = 9187
      protocol    = "TCP"
    }
  }
}

# ===========================================================================
# PostgreSQL Exporter ServiceMonitor
# ===========================================================================
# NOTE: This requires prometheus-operator CRDs to be installed first.
# Set enable_postgres_servicemonitor=false for initial deployment,
# then enable after prometheus-stack is deployed.
# ===========================================================================
resource "kubernetes_manifest" "postgres_exporter_servicemonitor" {
  count = var.enable_servicemonitor ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "postgres-exporter"
      namespace = var.monitoring_namespace
      labels = {
        app     = "postgres-exporter"
        release = "prometheus-stack"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "postgres-exporter"
        }
      }
      endpoints = [{
        port     = "metrics"
        interval = "30s"
        path     = "/metrics"
      }]
    }
  }
}

