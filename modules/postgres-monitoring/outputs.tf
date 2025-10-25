output "monitoring_user" {
  description = "PostgreSQL monitoring username"
  value       = google_sql_user.monitoring.name
}

output "monitoring_password_secret_id" {
  description = "Secret Manager secret ID for monitoring password"
  value       = google_secret_manager_secret.monitoring_password.secret_id
}

output "postgres_exporter_service" {
  description = "Kubernetes service name for postgres_exporter"
  value       = kubernetes_service.postgres_exporter.metadata[0].name
}

output "postgres_exporter_endpoint" {
  description = "Prometheus scrape endpoint for postgres_exporter"
  value       = "http://${kubernetes_service.postgres_exporter.metadata[0].name}.${var.monitoring_namespace}.svc.cluster.local:9187/metrics"
}

output "connection_string" {
  description = "PostgreSQL connection string for monitoring (sensitive)"
  value       = "postgresql://${google_sql_user.monitoring.name}:${random_password.monitoring_password.result}@${var.postgres_host}:5432/postgres?sslmode=require"
  sensitive   = true
}
