output "auth_backends" {
  description = "Authentication backend paths"
  value = {

    kubernetes = vault_auth_backend.kubernetes.path
  }
}

output "vault_policies" {
  description = "List of created Vault policies"
  value = {
    admins     = vault_policy.vault_admins.name
    developers = vault_policy.vault_developers.name
    devops     = vault_policy.vault_devops.name
    k8s_apps   = vault_policy.k8s_apps.name
  }
}

output "secret_engines" {
  description = "Configured secret engines"
  value = {
    for key, mount in vault_mount.kv_mounts : key => mount.path
  }
}
