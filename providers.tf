terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.34.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "~> 7.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.1.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
  }
}

provider "google" {
  region  = var.region
  project = var.project_id
}

provider "random" {
}

provider "helm" {
  kubernetes = {
    host                   = "https://${module.cluster.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.cluster.ca_certificate)
  }
}

provider "kubernetes" {
  host                   = "https://${module.cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.cluster.ca_certificate)
}

provider "argocd" {
  server_addr = var.argocd_url != "" ? "${var.argocd_url}:443" : "${var.argocd_subdomain}.${var.domain_name}:443"
  insecure    = false
  grpc_web    = true

  username = var.argocd_username
  password = var.argocd_password
  # auth_token = var.argocd_auth_token
}

provider "vault" {
  address = "https://${var.vault_subdomain}.${var.domain_name}"
  token   = var.vault_root_token
}