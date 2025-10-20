output "dns_zone_name" {
  description = "The name of the private DNS zone"
  value       = google_dns_managed_zone.private_zone.name
}

output "dns_zone_domain" {
  description = "The DNS domain of the private zone"
  value       = google_dns_managed_zone.private_zone.dns_name
}

output "database_dns_name" {
  description = "The DNS name for the PostgreSQL database"
  value       = trimsuffix(google_dns_record_set.database.name, ".")
}

output "database_fqdn" {
  description = "The fully qualified domain name for the PostgreSQL database"
  value       = google_dns_record_set.database.name
}

output "service_dns_records" {
  description = "Map of created service DNS records"
  value = {
    for k, v in google_dns_record_set.service_records : k => {
      name = trimsuffix(v.name, ".")
      fqdn = v.name
      ip   = v.rrdatas[0]
    }
  }
}

output "service_cname_records" {
  description = "Map of created service CNAME records"
  value = {
    for k, v in google_dns_record_set.service_cnames : k => {
      name   = trimsuffix(v.name, ".")
      fqdn   = v.name
      target = v.rrdatas[0]
    }
  }
}
