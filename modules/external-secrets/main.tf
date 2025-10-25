resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = var.namespace
    labels = {
      "name" = var.namespace
    }
  }
}

resource "kubernetes_service_account" "vault_auth_sa" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    annotations = {
      "external-secrets.io/vault-role" = var.vault_role
    }
  }

  depends_on = [kubernetes_namespace.external_secrets]
}

# ===========================================================================
# ClusterSecretStore for Vault Integration
# ===========================================================================
# NOTE: This requires External Secrets Operator CRDs to be installed first.
# Set enable_cluster_secret_store=false for initial deployment,
# then enable after ESO helm chart is deployed.
# ===========================================================================
resource "kubernetes_manifest" "vault_secret_store" {
  count = var.enable_cluster_secret_store ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"

    metadata = {
      name = var.cluster_secret_store_name
    }

    spec = {
      provider = {
        vault = {
          server  = var.vault_server_url
          path    = var.vault_mount_path
          version = var.vault_kv_version

          auth = {
            kubernetes = {
              mountPath = var.vault_auth_mount_path
              role      = var.vault_role
              serviceAccountRef = {
                name      = kubernetes_service_account.vault_auth_sa.metadata[0].name
                namespace = var.namespace
                audiences = [var.vault_audience]
              }
            }
          }
        }
      }
    }
  }

  computed_fields = ["metadata.uid", "metadata.resourceVersion"]

  depends_on = [kubernetes_service_account.vault_auth_sa]
}

resource "kubernetes_role" "eso_management" {
  metadata {
    namespace = var.namespace
    name      = "external-secrets-management"
  }

  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["secretstores", "externalsecrets", "pushsecrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["externalsecrets", "externalsecrets/status", "externalsecrets/finalizers"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["pushsecrets", "pushsecrets/status", "pushsecrets/finalizers"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["clustersecretstores", "clustersecretstores/status", "clustersecretstores/finalizers"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  # Service account token creation for Vault auth
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts/token"]
    verbs      = ["create"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }
}

resource "kubernetes_role_binding" "eso_management" {
  metadata {
    name      = "external-secrets-management"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.eso_management.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_auth_sa.metadata[0].name
    namespace = var.namespace
  }
}

# Role for creating secrets in target namespaces
resource "kubernetes_role" "target_namespace_secrets" {
  for_each = toset(var.target_namespaces)

  metadata {
    namespace = each.key
    name      = "external-secrets-${each.key}"
  }

  # Create and manage secrets in target namespace
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }

  # Events for troubleshooting
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }
}

# RoleBinding for target namespaces
resource "kubernetes_role_binding" "target_namespace_secrets" {
  for_each = toset(var.target_namespaces)

  metadata {
    name      = "external-secrets-${each.key}"
    namespace = each.key
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.target_namespace_secrets[each.key].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_auth_sa.metadata[0].name
    namespace = var.namespace
  }
}
