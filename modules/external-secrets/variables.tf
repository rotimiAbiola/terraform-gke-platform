variable "namespace" {
  description = "Kubernetes namespace where External Secrets Operator infrastructure will be deployed"
  type        = string
  default     = "external-secrets"
}

variable "vault_server_url" {
  description = "Vault server URL"
  type        = string
  default     = "http://vault.vault.svc.cluster.local:8200"
}

variable "vault_mount_path" {
  description = "Vault KV mount path"
  type        = string
  default     = "secret"
}

variable "vault_role" {
  description = "Vault Kubernetes auth role"
  type        = string
  default     = "k8s-apps"
}

variable "vault_auth_mount_path" {
  description = "Vault Kubernetes auth mount path"
  type        = string
  default     = "kubernetes"
}

variable "vault_audience" {
  description = "Audience for Vault service account token"
  type        = string
  default     = "vault"
}

variable "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore"
  type        = string
  default     = "vault-secret-store"
}

variable "service_account_name" {
  description = "Name of the service account for ESO Vault authentication"
  type        = string
  default     = "vault-auth-sa"
}

variable "target_namespaces" {
  description = "List of namespaces where ESO can create secrets"
  type        = list(string)
  default     = ["platform"]
}

variable "vault_kv_version" {
  description = "Vault KV secrets engine version"
  type        = string
  default     = "v2"

  validation {
    condition     = contains(["v1", "v2"], var.vault_kv_version)
    error_message = "Vault KV version must be either 'v1' or 'v2'."
  }
}
variable "enable_cluster_secret_store" {
  description = "Enable ClusterSecretStore creation (requires ESO CRDs)"
  type        = bool
  default     = false
}
