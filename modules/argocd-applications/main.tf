terraform {
  required_providers {
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "~> 7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

locals {
  # Compute GitHub organization URL from github_org if not explicitly provided
  github_org_url = var.github_organization_url != "" ? var.github_organization_url : "https://github.com/${var.github_org}"

  # Compute source repositories wildcard pattern
  source_repos_pattern = var.github_org != "" && length(var.source_repositories) == 0 ? ["https://github.com/${var.github_org}/*"] : var.source_repositories
}

resource "argocd_project" "this" {
  metadata {
    name      = var.project_name
    namespace = "argocd"
    labels = {
      "app.kubernetes.io/name"       = var.project_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    description = var.project_description

    source_repos = local.source_repos_pattern

    # Destinations - allowed clusters and namespaces
    dynamic "destination" {
      for_each = var.destinations
      content {
        server    = destination.value.server
        namespace = destination.value.namespace
        name      = destination.value.name
      }
    }

    # RBAC policies for the project
    role {
      name        = "admin"
      description = "Project admin access"
      policies    = ["p, proj:${var.project_name}:admin, applications, *, ${var.project_name}/*, allow"]
      groups      = []
    }

    orphaned_resources {
      warn = true
    }
  }
}

# Create Repository Secret for GitHub App authentication
resource "kubernetes_secret" "github_app_repo_creds" {
  count = var.github_app_private_key != "" ? 1 : 0

  metadata {
    name      = "${var.project_name}-github-app-creds"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repo-creds"
      "app.kubernetes.io/managed-by"   = "terraform"
    }
  }

  type = "Opaque"

  data = {
    type                    = "git"
    url                     = local.github_org_url
    githubAppID             = var.github_app_id
    githubAppInstallationID = var.github_app_installation_id
    githubAppPrivateKey     = var.github_app_private_key
  }
}

# Create namespaces for applications if they don't exist
resource "kubernetes_namespace" "app_namespaces" {
  for_each = toset(var.application_namespaces)

  metadata {
    name = each.value
    labels = {
      "app.kubernetes.io/managed-by"  = "terraform"
      "argocd.argoproj.io/managed-by" = var.project_name
    }
  }
}

# App of Apps - Main application that manages all other applications
resource "argocd_application" "app_of_apps" {
  count = var.app_of_apps_repo_url != "" ? 1 : 0

  metadata {
    name      = "${var.project_name}-app-of-apps"
    namespace = "argocd"
    labels = {
      "app.kubernetes.io/name"       = "${var.project_name}-app-of-apps"
      "app.kubernetes.io/part-of"    = var.project_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    project = argocd_project.this.metadata[0].name

    source {
      repo_url        = var.app_of_apps_repo_url
      path            = var.app_of_apps_path
      target_revision = var.app_of_apps_revision
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "argocd"
    }

    sync_policy {
      automated {
        prune       = var.sync_policy.automated.prune
        self_heal   = var.sync_policy.automated.self_heal
        allow_empty = var.sync_policy.automated.allow_empty
      }

      sync_options = var.sync_policy.sync_options

      retry {
        limit = var.sync_policy.retry.limit
        backoff {
          duration     = var.sync_policy.retry.backoff.duration
          factor       = var.sync_policy.retry.backoff.factor
          max_duration = var.sync_policy.retry.backoff.max_duration
        }
      }
    }
  }
}
