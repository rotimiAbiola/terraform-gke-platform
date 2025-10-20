# ArgoCD Helm Application Terraform Module
This Terraform module creates ArgoCD applications for deploying Helm charts. It provides a flexible and reusable way to manage Helm-based applications through ArgoCD with GitOps principles.

## Features

- Deploy any Helm chart through ArgoCD
- Configurable sync policies (automated, manual)
- Support for custom values files
- Namespace creation and management
- Ignore differences configuration
- Retry policies and backoff strategies
- Labels and annotations support
- Multiple deployment examples

## Usage

### Basic Example

```hcl
module "nginx_app" {
  source = "./argocd-helm-module"

  application_name = "nginx-example"
  namespace        = "nginx"
  repository_url   = "https://charts.bitnami.com/bitnami"
  chart_name       = "nginx"
  chart_version    = "15.4.0"

  values = <<-EOT
    replicaCount: 3
    service:
      type: ClusterIP
      port: 80
  EOT
}
```

### Advanced Example

```hcl
module "monitoring_stack" {
  source = "./argocd-helm-module"

  application_name = "prometheus-stack"
  project          = "monitoring"
  namespace        = "monitoring"
  repository_url   = "https://prometheus-community.github.io/helm-charts"
  chart_name       = "kube-prometheus-stack"

  sync_policy = {
    automated = {
      prune     = true
      self_heal = false
    }
    sync_options = ["CreateNamespace=true"]
  }

  ignore_differences = [
    {
      group = "apps"
      kind  = "Deployment"
      json_pointers = ["/spec/replicas"]
    }
  ]
}
```

## Requirements

- Terraform >= 1.0
- ArgoCD provider (argoproj-labs/argocd) >= 7.0
- Kubernetes provider >= 2.0
- Running ArgoCD instance
- Appropriate RBAC permissions

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| application_name | Name of the ArgoCD application | string | - | yes |
| namespace | Target namespace for the application | string | - | yes |
| repository_url | Helm repository URL | string | - | yes |
| chart_name | Name of the Helm chart | string | - | yes |
| chart_version | Version of the Helm chart | string | "" | no |
| values | Helm values as YAML string | string | "" | no |
| project | ArgoCD project name | string | "default" | no |
| sync_policy | ArgoCD sync policy configuration | object | see variables.tf | no |

## Outputs

| Name | Description |
|------|-------------|
| application_name | Name of the created ArgoCD application |
| target_namespace | Target namespace where the Helm chart is deployed |
| sync_status | Sync status of the application |
