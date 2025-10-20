output "cluster_name" {
  description = "The name of the cluster"
  value       = google_container_cluster.primary.name
}

output "endpoint" {
  description = "The IP address of the cluster master"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "ca_certificate" {
  description = "The public certificate of the cluster (base64)"
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive   = true
}