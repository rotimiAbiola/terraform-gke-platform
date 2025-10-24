output "project_name" {
  description = "Name of the created ArgoCD project"
  value       = argocd_project.this.metadata[0].name
}

output "project_urn" {
  description = "URN of the created ArgoCD project"
  value       = argocd_project.this.metadata[0].uid
}

output "app_of_apps_name" {
  description = "Name of the app of apps application (null if not created)"
  value       = length(argocd_application.app_of_apps) > 0 ? argocd_application.app_of_apps[0].metadata[0].name : null
}

output "app_of_apps_status" {
  description = "Status of the app of apps application (null if not created)"
  value       = length(argocd_application.app_of_apps) > 0 ? argocd_application.app_of_apps[0].status : null
}

output "applications" {
  description = "Map of created applications (empty when using app of apps)"
  value       = {}
}

output "created_namespaces" {
  description = "List of created namespaces"
  value       = [for ns in kubernetes_namespace.app_namespaces : ns.metadata[0].name]
}

output "github_app_secret_name" {
  description = "Name of the GitHub App authentication secret"
  value       = var.github_app_private_key != "" ? kubernetes_secret.github_app_repo_creds[0].metadata[0].name : null
}
