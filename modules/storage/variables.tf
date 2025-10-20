variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for storage bucket"
}

variable "bucket_name" {
  type        = string
  description = "Name of the GCS bucket"
}

variable "environment" {
  type        = string
  description = "Environment name (used for service account naming)"
}
