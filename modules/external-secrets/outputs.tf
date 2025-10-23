output "secret_store_name" {
  description = "Name of the Vault ClusterSecretStore (apply manually or uncomment kubernetes_manifest in main.tf after ESO installation)"
  value       = var.cluster_secret_store_name
  # When kubernetes_manifest.vault_secret_store is uncommented, use:
  # value = kubernetes_manifest.vault_secret_store.manifest.metadata.name
}

output "service_account_name" {
  description = "Name of the Vault auth service account"
  value       = kubernetes_service_account.vault_auth_sa.metadata[0].name
}

output "namespace" {
  description = "Namespace where external secrets resources are created"
  value       = var.namespace
}

output "target_namespaces" {
  description = "List of namespaces where ESO can create secrets"
  value       = var.target_namespaces
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore"
  value       = var.cluster_secret_store_name
}