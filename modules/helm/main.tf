terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.34.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
  }
}

data "google_client_config" "default" {}

resource "helm_release" "nginx_gateway" {
  name             = "nginx-gateway"
  repository       = "oci://ghcr.io/nginx/charts/"
  chart            = "nginx-gateway-fabric"
  version          = "1.6.2" # Use a version compatible with v1alpha1 CRDs
  namespace        = "nginx-gateway"
  create_namespace = true

  # Wait for installation to complete
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  # Workaround for Helm provider 3.0.0 bug with description attribute
  lifecycle {
    ignore_changes = [description]
  }

  # Configure for HA and spot nodes
  values = [yamlencode({
    nginxGateway = {
      replicaCount = 2 # HA with 2 replicas

      # Tolerations for spot nodes
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
  })]
}
