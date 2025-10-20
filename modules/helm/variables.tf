variable "cluster_endpoint" {
  description = "The IP address of the cluster master"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "The public certificate of the cluster (base64)"
  type        = string
}

variable "grafana_domain" {
  description = "External domain for Grafana"
  type        = string
}

variable "grafana_root_url" {
  description = "Root URL for Grafana"
  type        = string
}

# ArgoCD
# Variables for ArgoCD configuration
variable "argocd_url" {
  description = "Domain name for ArgoCD"
  type        = string
  default     = ""
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "8.1.0"
}

variable "argocd_storage_class" {
  description = "Storage class for ArgoCD persistent volumes"
  type        = string
  default     = "standard-rwo"
}

variable "argocd_redis_ha_enabled" {
  description = "Enable Redis HA for ArgoCD"
  type        = bool
  default     = true
}

variable "argocd_controller_replicas" {
  description = "Number of ArgoCD controller replicas"
  type        = number
  default     = 2
}

variable "argocd_server_replicas" {
  description = "Number of ArgoCD server replicas"
  type        = number
  default     = 2
}

variable "argocd_repo_server_replicas" {
  description = "Number of ArgoCD repo server replicas"
  type        = number
  default     = 2
}

# GitHub OAuth for ArgoCD Dex integration
variable "argocd_github_client_id" {
  description = "GitHub OAuth Client ID for ArgoCD Dex integration"
  type        = string
  default     = ""
}

variable "argocd_github_client_secret" {
  description = "GitHub OAuth Client Secret for ArgoCD Dex integration"
  type        = string
  sensitive   = true
  default     = ""
}

variable "argocd_github_org" {
  description = "GitHub organization for ArgoCD access"
  type        = string
  default     = "rotimiAbiola"
}

variable "argocd_server_secret_key" {
  description = "ArgoCD server secret key for JWT signing and session management"
  type        = string
  sensitive   = true
}