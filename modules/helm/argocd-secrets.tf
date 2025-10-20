# ArgoCD Configuration Secret
resource "kubernetes_secret" "argocd_dex_config" {
  count = var.argocd_github_client_id != "" ? 1 : 0

  metadata {
    name      = "argocd-dex-config"
    namespace = "argocd"
  }

  data = {
    "dex.github.clientSecret" = var.argocd_github_client_secret
  }

  type = "Opaque"

  depends_on = [helm_release.argocd]
}
