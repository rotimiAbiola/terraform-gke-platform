resource "random_pet" "bucket_id" {
}

resource "google_storage_bucket" "bucket_for_state" {
  name                        = "terraform-bucket-${random_pet.bucket_id.id}"
  location                    = var.region
  uniform_bucket_level_access = true
  project                     = var.project_id
  force_destroy               = true
}

terraform {
  backend "gcs" {
    bucket = "terraform-bucket-frank-serval"
    prefix = "terraform/prod/state"
  }
}
