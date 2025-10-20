terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.34.0"
    }
  }
}

# Create a service account for storage access
resource "google_service_account" "storage_sa" {
  account_id   = "${var.environment}-storage-access"
  display_name = "Storage Access Service Account for ${var.environment}"
  project      = var.project_id
}

resource "google_storage_bucket" "app_bucket" {
  name                        = var.bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
  enable_object_retention     = true # Match the actual GCP state: per_object_retention.mode = Enabled
  force_destroy               = false
  uniform_bucket_level_access = false
  public_access_prevention    = "inherited"

  # Preserve the existing hierarchical namespace setting
  hierarchical_namespace {
    enabled = false
  }

  # Preserve the existing soft delete policy
  soft_delete_policy {
    retention_duration_seconds = 604800 # 7 days
  }
}

resource "google_storage_bucket_iam_member" "sa_bucket_access" {
  bucket = google_storage_bucket.app_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.storage_sa.email}"
}



