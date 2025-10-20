terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.34.0"
    }
  }
}

# Private DNS zone for internal services
resource "google_dns_managed_zone" "private_zone" {
  name        = var.dns_zone_name
  dns_name    = var.dns_zone_domain
  description = "Private DNS zone for internal services"
  project     = var.project_id

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = var.network_id
    }
  }

  labels = {
    environment = "production"
    team        = "platform"
    managed_by  = "terraform"
  }
}

# DNS A record for PostgreSQL database
resource "google_dns_record_set" "database" {
  name         = var.database_dns_name
  managed_zone = google_dns_managed_zone.private_zone.name
  type         = "A"
  ttl          = 300
  project      = var.project_id

  rrdatas = [var.database_private_ip]
}

# DNS A records for other services (optional)
resource "google_dns_record_set" "service_records" {
  for_each = var.service_dns_records

  name         = each.value.name
  managed_zone = google_dns_managed_zone.private_zone.name
  type         = "A"
  ttl          = 300
  project      = var.project_id

  rrdatas = [each.value.ip_address]
}

# CNAME records for service aliases (optional)
resource "google_dns_record_set" "service_cnames" {
  for_each = var.service_cname_records

  name         = each.value.name
  managed_zone = google_dns_managed_zone.private_zone.name
  type         = "CNAME"
  ttl          = 300
  project      = var.project_id

  rrdatas = [each.value.target]
}
