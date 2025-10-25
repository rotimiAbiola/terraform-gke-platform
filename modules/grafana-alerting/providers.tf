terraform {
  required_version = ">= 1.3"
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.1.0"
    }
  }
}

# Provider configuration is inherited from root module
