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

# Create namespace if requested
resource "kubernetes_namespace" "target" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = merge(
      var.labels,
      {
        "argocd.argoproj.io/managed-by" = var.application_name
      }
    )
    annotations = var.annotations
  }
}

# ArgoCD Application
resource "argocd_application" "helm_app" {
  metadata {
    name      = var.application_name
    namespace = "argocd"
    labels = merge(
      var.labels,
      {
        "app.kubernetes.io/name"       = var.application_name
        "app.kubernetes.io/part-of"    = "argocd"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
    annotations = var.annotations
  }

  spec {
    project = var.project

    source {
      repo_url        = var.repository_url
      chart           = var.chart_name
      target_revision = var.chart_version != "" ? var.chart_version : "*"

      dynamic "helm" {
        for_each = var.values != "" ? [1] : []
        content {
          values = var.values
        }
      }
    }

    destination {
      server    = var.cluster_name == "in-cluster" ? "https://kubernetes.default.svc" : var.cluster_name
      namespace = var.namespace
    }

    sync_policy {
      dynamic "automated" {
        for_each = var.sync_policy.automated != null ? [var.sync_policy.automated] : []
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      sync_options = var.sync_policy.sync_options

      dynamic "retry" {
        for_each = var.sync_policy.retry != null ? [var.sync_policy.retry] : []
        content {
          limit = retry.value.limit
          dynamic "backoff" {
            for_each = retry.value.backoff != null ? [retry.value.backoff] : []
            content {
              duration     = backoff.value.duration
              factor       = backoff.value.factor
              max_duration = backoff.value.max_duration
            }
          }
        }
      }
    }

    dynamic "ignore_difference" {
      for_each = var.ignore_differences
      content {
        group               = ignore_difference.value.group
        kind                = ignore_difference.value.kind
        name                = ignore_difference.value.name
        namespace           = ignore_difference.value.namespace
        json_pointers       = ignore_difference.value.json_pointers
        jq_path_expressions = ignore_difference.value.jq_path_expressions
      }
    }
  }

  depends_on = [kubernetes_namespace.target]
}
