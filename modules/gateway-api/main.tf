# Gateway API Resources
# This module manages Gateway, HTTPRoutes, ReferenceGrants, and ClientSettingsPolicy
# Requires: Gateway API CRDs (installed by NGINX Gateway Fabric or similar)

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

# Local values for filtering enabled services
locals {
  enabled_services = [for svc in var.services : svc if svc.enabled]
}

# Gateway - Main ingress gateway for the platform
resource "kubernetes_manifest" "platform_gateway" {
  count = var.enable_gateway ? 1 : 0

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = var.gateway_name
      namespace = var.gateway_namespace
    }
    spec = {
      gatewayClassName = var.gateway_class_name
      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          hostname = "*.${var.domain_name}"
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        },
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          hostname = "*.${var.domain_name}"
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              kind      = "Secret"
              name      = var.tls_secret_name
              namespace = var.tls_secret_namespace
            }]
          }
        }
      ]
    }
  }
}

# ReferenceGrants - Allow HTTPRoutes to reference Services in specified namespaces
resource "kubernetes_manifest" "reference_grants" {
  for_each = var.enable_gateway ? toset(var.reference_grant_namespaces) : []

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "allow-${each.key}-services"
      namespace = each.key
    }
    spec = {
      to = [{
        group = ""
        kind  = "Service"
      }]
      from = [{
        group     = "gateway.networking.k8s.io"
        kind      = "HTTPRoute"
        namespace = var.gateway_namespace
      }]
    }
  }
}

# ClientSettingsPolicy - NGINX-specific policy for large file uploads
resource "kubernetes_manifest" "client_settings_policy" {
  count = var.enable_gateway && var.gateway_class_name == "nginx" ? 1 : 0

  manifest = {
    apiVersion = "gateway.nginx.org/v1alpha1"
    kind       = "ClientSettingsPolicy"
    metadata = {
      name      = "large-file-upload-policy"
      namespace = var.gateway_namespace
    }
    spec = {
      targetRef = {
        group = "gateway.networking.k8s.io"
        kind  = "Gateway"
        name  = var.gateway_name
      }
      body = {
        maxSize = var.max_body_size
      }
    }
  }

  depends_on = [kubernetes_manifest.platform_gateway]
}

# HTTPRoute - TLS Redirect (HTTP to HTTPS) for each service
resource "kubernetes_manifest" "httproute_tls_redirect" {
  for_each = var.enable_gateway ? { for svc in local.enabled_services : svc.name => svc } : {}

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${each.value.name}-tls-redirect"
      namespace = var.gateway_namespace
    }
    spec = {
      parentRefs = [{
        name        = var.gateway_name
        sectionName = "http"
      }]
      hostnames = ["${each.value.hostname}.${var.domain_name}"]
      rules = [{
        filters = [{
          type = "RequestRedirect"
          requestRedirect = {
            scheme = "https"
            port   = 443
          }
        }]
      }]
    }
  }

  depends_on = [
    kubernetes_manifest.platform_gateway,
    kubernetes_manifest.reference_grants
  ]
}

# HTTPRoute - HTTPS routes for each service
resource "kubernetes_manifest" "httproute_https" {
  for_each = var.enable_gateway ? { for svc in local.enabled_services : svc.name => svc } : {}

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = each.value.name
      namespace = var.gateway_namespace
    }
    spec = {
      parentRefs = [{
        name        = var.gateway_name
        sectionName = "https"
      }]
      hostnames = ["${each.value.hostname}.${var.domain_name}"]
      rules = [{
        backendRefs = [{
          group     = ""
          kind      = "Service"
          name      = each.value.backend_service
          namespace = each.value.backend_namespace
          port      = each.value.backend_port
        }]
      }]
    }
  }

  depends_on = [
    kubernetes_manifest.platform_gateway,
    kubernetes_manifest.reference_grants
  ]
}
