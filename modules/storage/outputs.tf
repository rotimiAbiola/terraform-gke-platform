output "gcs_bucket" {
  value = google_storage_bucket.app_bucket.name
}

output "service_account_email" {
  value       = google_service_account.storage_sa.email
  description = "Email of the service account with storage access"
}

output "service_account_id" {
  value       = google_service_account.storage_sa.id
  description = "ID of the service account with storage access"
}

