output "application_name" {
  description = "Name of the created ArgoCD application"
  value       = argocd_application.helm_app.metadata[0].name
}

output "application_namespace" {
  description = "Namespace of the ArgoCD application"
  value       = argocd_application.helm_app.metadata[0].namespace
}

output "target_namespace" {
  description = "Target namespace where the Helm chart is deployed"
  value       = var.namespace
}

output "sync_status" {
  description = "Sync status of the application"
  value       = argocd_application.helm_app.status
}

output "application_uid" {
  description = "UID of the ArgoCD application"
  value       = argocd_application.helm_app.metadata[0].uid
}