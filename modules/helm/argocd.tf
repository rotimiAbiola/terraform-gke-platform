# ArgoCD Helm Release
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = var.argocd_version
  timeout          = 600

  # Workaround for Helm provider 3.0.0 bug with description attribute
  lifecycle {
    ignore_changes = [description]
  }

  set = [
    # Global configuration
    {
      name  = "global.domain"
      value = var.argocd_url
    },

    # Server configuration - HA
    {
      name  = "server.replicas"
      value = tostring(var.argocd_server_replicas)
    },
    {
      name  = "server.autoscaling.enabled"
      value = "false"
    },

    # Server resources
    {
      name  = "server.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "server.resources.requests.memory"
      value = "128Mi"
    },
    {
      name  = "server.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "server.resources.limits.memory"
      value = "512Mi"
    },

    # Server service configuration
    {
      name  = "server.service.type"
      value = "ClusterIP"
    },

    # Server configuration for external access
    {
      name  = "server.extraArgs[0]"
      value = "--insecure"
    },
    {
      name  = "server.config.url"
      value = var.argocd_url
    },

    # Controller configuration - HA
    {
      name  = "controller.replicas"
      value = tostring(var.argocd_controller_replicas)
    },
    {
      name  = "controller.enableStatefulSet"
      value = "true"
    },

    # Controller resources
    {
      name  = "controller.resources.requests.cpu"
      value = "250m"
    },
    {
      name  = "controller.resources.requests.memory"
      value = "1Gi"
    },
    {
      name  = "controller.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "controller.resources.limits.memory"
      value = "2Gi"
    },

    # Repo Server configuration - HA
    {
      name  = "repoServer.replicas"
      value = tostring(var.argocd_repo_server_replicas)
    },
    {
      name  = "repoServer.autoscaling.enabled"
      value = "false"
    },

    # Repo Server resources
    {
      name  = "repoServer.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "repoServer.resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "repoServer.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "repoServer.resources.limits.memory"
      value = "1Gi"
    },

    # ApplicationSet Controller
    {
      name  = "applicationSet.enabled"
      value = "true"
    },
    {
      name  = "applicationSet.replicas"
      value = "2"
    },

    # Notifications Controller
    {
      name  = "notifications.enabled"
      value = "true"
    },

    # Redis HA configuration
    {
      name  = "redis-ha.enabled"
      value = tostring(var.argocd_redis_ha_enabled)
    },
    {
      name  = "redis.enabled"
      value = tostring(!var.argocd_redis_ha_enabled)
    },

    # Redis HA settings
    {
      name  = "redis-ha.haproxy.replicas"
      value = "3"
    },
    {
      name  = "redis-ha.haproxy.hardAntiAffinity"
      value = "true"
    },
    {
      name  = "redis-ha.redis.replicas"
      value = "3"
    },
    {
      name  = "redis-ha.sentinel.replicas"
      value = "3"
    },
    {
      name  = "redis-ha.hardAntiAffinity"
      value = "true"
    },

    # Redis HA resources
    {
      name  = "redis-ha.redis.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "redis-ha.redis.resources.requests.memory"
      value = "128Mi"
    },
    {
      name  = "redis-ha.redis.resources.limits.cpu"
      value = "250m"
    },
    {
      name  = "redis-ha.redis.resources.limits.memory"
      value = "256Mi"
    },

    # Redis HA persistence
    {
      name  = "redis-ha.persistentVolume.enabled"
      value = "true"
    },
    {
      name  = "redis-ha.persistentVolume.storageClass"
      value = var.argocd_storage_class
    },
    {
      name  = "redis-ha.persistentVolume.size"
      value = "8Gi"
    },

    # Dex (OIDC) - Enable for GitHub SSO
    {
      name  = "dex.enabled"
      value = var.argocd_github_client_id != "" ? "true" : "false"
    },
  ]

  # Dex configuration via values (only if GitHub OAuth is configured)
  values = var.argocd_github_client_id != "" ? [
    yamlencode({
      configs = {
        cm = {
          "url" = "https://${var.argocd_url}"
          # Remove OIDC config - let Dex handle all authentication
          "oidc.config" = ""
          # Dex configuration with GitHub connector
          "dex.config" = yamlencode({
            issuer = "https://${var.argocd_url}/api/dex"
            storage = {
              type = "memory"
            }
            web = {
              http = "0.0.0.0:5556"
            }
            staticClients = [
              {
                id     = "argocd"
                name   = "ArgoCD"
                secret = "argocd-secret"
              }
            ]
            connectors = [
              {
                type = "github"
                id   = "github"
                name = "GitHub"
                config = {
                  clientID     = var.argocd_github_client_id
                  clientSecret = "$oidc.github.clientSecret"
                  orgs = [
                    {
                      name = var.argocd_github_org
                      # Remove teams restriction to allow all org members
                      # Teams will be used for role mapping in RBAC policy
                    }
                  ]
                  teamNameField = "slug"
                  useLoginAsID  = false
                }
              }
            ]
          })
        }
        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv"     = <<EOF
# Default policy for all users - readonly access
p, role:readonly, applications, get, *, allow
p, role:readonly, applications, list, *, allow
p, role:readonly, repositories, get, *, allow
p, role:readonly, repositories, list, *, allow
p, role:readonly, certificates, get, *, allow
p, role:readonly, certificates, list, *, allow
p, role:readonly, clusters, get, *, allow
p, role:readonly, clusters, list, *, allow
p, role:readonly, logs, get, *, allow

# Admin role - full access
p, role:admin, applications, *, */*, allow
p, role:admin, certificates, *, *, allow
p, role:admin, clusters, *, *, allow
p, role:admin, repositories, *, *, allow
p, role:admin, logs, *, *, allow
p, role:admin, exec, *, *, allow

# Developer role - can sync and manage applications
p, role:developer, applications, get, *, allow
p, role:developer, applications, list, *, allow
p, role:developer, applications, sync, *, allow
p, role:developer, applications, action/*, *, allow
p, role:developer, repositories, get, *, allow
p, role:developer, repositories, list, *, allow
p, role:developer, logs, get, *, allow

# Group mappings - map GitHub teams to ArgoCD roles
g, ${var.argocd_github_org}:devops, role:admin
g, ${var.argocd_github_org}:admins, role:developer
g, ${var.argocd_github_org}:developers, role:developer

# Individual user mappings - add specific GitHub usernames here
# Replace with actual GitHub usernames for admin access
# g, another-username, role:admin
# g, developer-username, role:developer
EOF
        }
        secret = {
          # ArgoCD server secret - cryptographically secure random key
          "server.secretkey" = base64encode(var.argocd_server_secret_key)
          # OIDC client secret
          "oidc.github.clientSecret" = base64encode(var.argocd_github_client_secret)
        }
      }

      # Dex configuration
      dex = {
        enabled  = true
        replicas = 2
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
        tolerations = [
          {
            key      = "cloud.google.com/gke-spot"
            operator = "Equal"
            value    = "true"
            effect   = "NoSchedule"
          },
          {
            operator = "Exists"
            effect   = "NoSchedule"
          },
          {
            operator = "Exists"
            effect   = "NoExecute"
          }
        ]
      }

      # Controller tolerations
      controller = {
        tolerations = [
          {
            key      = "cloud.google.com/gke-spot"
            operator = "Equal"
            value    = "true"
            effect   = "NoSchedule"
          },
          {
            operator = "Exists"
            effect   = "NoSchedule"
          },
          {
            operator = "Exists"
            effect   = "NoExecute"
          }
        ]
      }

      # Repo Server tolerations
      repoServer = {
        tolerations = [
          {
            key      = "cloud.google.com/gke-spot"
            operator = "Equal"
            value    = "true"
            effect   = "NoSchedule"
          },
          {
            operator = "Exists"
            effect   = "NoSchedule"
          },
          {
            operator = "Exists"
            effect   = "NoExecute"
          }
        ]
      }

      # Server configuration - no additional OIDC config needed here
      # OIDC config is already defined in configs.cm above
      server = {
        # Server-specific configurations can go here if needed
      }
    })
  ] : []
}
