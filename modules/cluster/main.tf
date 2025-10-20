terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.34.0"
    }
  }
}

# Get project number for KMS IAM binding
data "google_project" "project" {
  project_id = var.project_id
}

# KMS resources for etcd encryption (only created if enable_etcd_encryption = true)
resource "google_kms_key_ring" "gke_keyring" {
  count    = var.enable_etcd_encryption ? 1 : 0
  name     = "${var.cluster_name}-keyring"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "gke_etcd_key" {
  count           = var.enable_etcd_encryption ? 1 : 0
  name            = "${var.cluster_name}-etcd-key"
  key_ring        = google_kms_key_ring.gke_keyring[0].id
  rotation_period = var.kms_key_rotation_period
  purpose         = "ENCRYPT_DECRYPT"

  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Grant GKE service account permission to use the KMS key
resource "google_kms_crypto_key_iam_member" "gke_etcd_key_binding" {
  count         = var.enable_etcd_encryption ? 1 : 0
  crypto_key_id = google_kms_crypto_key.gke_etcd_key[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@container-engine-robot.iam.gserviceaccount.com"
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # We can't create a cluster with no node pool defined, but we want to use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Disable legacy APIs
  enable_legacy_abac = false

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Configure network
  network    = var.network_name
  subnetwork = var.subnet_name

  # Configure private cluster with configurable privacy settings
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr
  }

  # Configure IP allocation policy for pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = var.subnet_secondary_ranges.pods.range_name
    services_secondary_range_name = var.subnet_secondary_ranges.services.range_name
  }

  # Configure master authorized networks for secure API server access
  # Must be enabled if private endpoint is enabled
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Enable network policy for pod security
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Enable shielded nodes for security
  release_channel {
    channel = "REGULAR"
  }

  # Mandatory to reduce resource usage
  addons_config {
    http_load_balancing {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "02:00"
    }
  }

  lifecycle {
    ignore_changes = [
      node_pool,
    ]
  }

  secret_manager_config {
    enabled = false # Using External Secrets Operator with Vault instead
  }

  # Enable etcd encryption at rest with Cloud KMS (conditional)
  database_encryption {
    state    = var.enable_etcd_encryption ? "ENCRYPTED" : "DECRYPTED"
    key_name = var.enable_etcd_encryption ? google_kms_crypto_key.gke_etcd_key[0].id : null
  }

  # Ensure KMS IAM binding is created before cluster (if encryption enabled)
  depends_on = [
    google_kms_crypto_key_iam_member.gke_etcd_key_binding
  ]
}

# Node Pools
resource "google_container_node_pool" "pools" {
  for_each = { for np in var.node_pools : np.name => np }

  name     = each.value.name
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  # Enable auto-scaling
  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
  }

  # Node configuration
  node_config {
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    preemptible  = each.value.preemptible
    spot         = each.value.spot

    # Merge default labels with custom labels
    labels = merge(
      {
        environment = "production"
      },
      each.value.labels,
      each.value.spot ? {
        "cloud.google.com/gke-spot" = "true"
      } : {}
    )

    # Add taints for spot instances
    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    # Enable Workload Identity on nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Enable shielded nodes
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Google API access
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  management {
    auto_repair  = each.value.auto_repair
    auto_upgrade = each.value.auto_upgrade
  }

  # Upgrade strategy
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}