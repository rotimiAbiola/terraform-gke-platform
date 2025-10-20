

variable "kubernetes_host" {
  description = "Kubernetes API server URL for Vault Kubernetes auth"
  type        = string
}

variable "allowed_k8s_namespaces" {
  description = "List of Kubernetes namespaces allowed to authenticate with Vault"
  type        = list(string)
  default     = ["platform", "default", "external-secrets-system"]
}

variable "vault_policy_names" {
  description = "Map of vault policy names"
  type = object({
    admins     = string
    developers = string
    devops     = string
    k8s_apps   = string
  })
  default = {
    admins     = "vault-admins"
    developers = "vault-developers"
    devops     = "vault-devops"
    k8s_apps   = "k8s-apps"
  }
}

variable "kubernetes_auth_config" {
  description = "Kubernetes authentication configuration"
  type = object({
    type                   = string
    path                   = string
    default_lease_ttl      = string
    max_lease_ttl          = string
    disable_iss_validation = bool
    issuer                 = string
  })
  default = {
    type                   = "kubernetes"
    path                   = "kubernetes"
    default_lease_ttl      = "1h"
    max_lease_ttl          = "24h"
    disable_iss_validation = true
    issuer                 = "https://kubernetes.default.svc.cluster.local"
  }
}

variable "k8s_role_config" {
  description = "Kubernetes role configuration"
  type = object({
    role_name                   = string
    bound_service_account_names = list(string)
    token_ttl                   = number
    token_max_ttl               = number
    audience                    = string
  })
  default = {
    role_name                   = "k8s-apps"
    bound_service_account_names = ["*"]
    token_ttl                   = 3600  # 1 hour
    token_max_ttl               = 86400 # 24 hours
    audience                    = "vault"
  }
}

variable "kv_mounts" {
  description = "KV mount configurations"
  type = map(object({
    path                      = string
    type                      = string
    version                   = string
    description               = string
    default_lease_ttl_seconds = number
    max_lease_ttl_seconds     = number
  }))
  default = {
    apps = {
      path                      = "secret"
      type                      = "kv"
      version                   = "2"
      description               = "KV v2 secrets engine for application secrets"
      default_lease_ttl_seconds = 3600  # 1 hour
      max_lease_ttl_seconds     = 86400 # 24 hours
    }
    infrastructure = {
      path                      = "infrastructure"
      type                      = "kv"
      version                   = "2"
      description               = "KV v2 secrets engine for infrastructure and Terraform secrets"
      default_lease_ttl_seconds = 3600  # 1 hour
      max_lease_ttl_seconds     = 86400 # 24 hours
    }
  }
}


