# HashiCorp Vault Configuration Module
# This module configures Vault authentication methods, policies, and secret engines



# Admin policy for full Vault administration
resource "vault_policy" "vault_admins" {
  name = var.vault_policy_names.admins

  policy = <<EOT
# Full administrative access to Vault
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage auth methods
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage secret engines  
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# System administration
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

resource "vault_policy" "vault_developers" {
  name = var.vault_policy_names.developers

  policy = <<EOT
# Developer access - can read/write application secrets
path "secret/data/apps/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/apps/*" {
  capabilities = ["read", "list"]
}

# List secret engines
path "sys/mounts" {
  capabilities = ["read"]
}

# Read own token info
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Renew own token
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "vault_devops" {
  name = var.vault_policy_names.devops

  policy = <<EOT
# DevOps access - can manage infrastructure secrets and auth methods
path "secret/data/infrastructure/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "secret/metadata/infrastructure/*" {
  capabilities = ["read", "list"]
}

path "secret/data/apps/*" {
  capabilities = ["read", "list"]
}

# Manage auth methods
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage secret engines
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete"]
}

# Read system health and status
path "sys/health" {
  capabilities = ["read"]
}

path "sys/seal-status" {
  capabilities = ["read"]
}

# Manage policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read own token info
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Renew own token
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT
}

# Policy for Kubernetes applications to read secrets
resource "vault_policy" "k8s_apps" {
  name = var.vault_policy_names.k8s_apps

  policy = <<EOT
# Allow applications to read their own secrets (legacy templated path)
path "secret/data/apps/{{identity.entity.aliases.MOUNT_ACCESSOR.metadata.service_account_namespace}}/{{identity.entity.aliases.MOUNT_ACCESSOR.metadata.service_account_name}}/*" {
  capabilities = ["read"]
}

path "secret/metadata/apps/{{identity.entity.aliases.MOUNT_ACCESSOR.metadata.service_account_namespace}}/{{identity.entity.aliases.MOUNT_ACCESSOR.metadata.service_account_name}}/*" {
  capabilities = ["read", "list"]
}

# Allow apps to read shared secrets in their namespace (legacy)
path "secret/data/apps/{{identity.entity.aliases.MOUNT_ACCESSOR.metadata.service_account_namespace}}/shared/*" {
  capabilities = ["read"]
}

path "secret/metadata/apps/{{identity.entity.aliases.MOUNT_ACCESSOR.metadata.service_account_namespace}}/shared/*" {
  capabilities = ["read", "list"]
}

# Allow External Secrets Operator to read from platform/prod path
path "secret/data/platform/prod/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/platform/prod/*" {
  capabilities = ["read", "list"]
}

# Allow reading from infrastructure secrets for database passwords
path "secret/data/infrastructure/*" {
  capabilities = ["read"]
}

path "secret/metadata/infrastructure/*" {
  capabilities = ["read", "list"]
}

# Self-token management
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT
}



# Enable Kubernetes authentication method for apps
resource "vault_auth_backend" "kubernetes" {
  type = var.kubernetes_auth_config.type
  path = var.kubernetes_auth_config.path

  tune {
    default_lease_ttl = var.kubernetes_auth_config.default_lease_ttl
    max_lease_ttl     = var.kubernetes_auth_config.max_lease_ttl
  }
}

# Configure Kubernetes auth method
resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = var.kubernetes_host

  # Disable issuer validation to handle modern K8s service account tokens
  disable_iss_validation = var.kubernetes_auth_config.disable_iss_validation

  # Set issuer explicitly for better token validation
  issuer = var.kubernetes_auth_config.issuer
}

# Create a role for Kubernetes service accounts
resource "vault_kubernetes_auth_backend_role" "k8s_apps" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.k8s_role_config.role_name
  bound_service_account_names      = var.k8s_role_config.bound_service_account_names
  bound_service_account_namespaces = var.allowed_k8s_namespaces
  token_ttl                        = var.k8s_role_config.token_ttl
  token_max_ttl                    = var.k8s_role_config.token_max_ttl
  token_policies                   = [var.vault_policy_names.k8s_apps]

  # Enable identity templating for namespace/service account isolation
  audience = var.k8s_role_config.audience
}

# Enable KV secrets engines
resource "vault_mount" "kv_mounts" {
  for_each = var.kv_mounts

  path        = each.value.path
  type        = each.value.type
  options     = { version = each.value.version }
  description = each.value.description

  default_lease_ttl_seconds = each.value.default_lease_ttl_seconds
  max_lease_ttl_seconds     = each.value.max_lease_ttl_seconds
}


