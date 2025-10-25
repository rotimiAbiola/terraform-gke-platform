# Gateway API Module

This module manages Kubernetes Gateway API resources for exposing platform services via a unified ingress gateway.

## Features

- ✅ Gateway resource with HTTP and HTTPS listeners
- ✅ HTTPRoutes for ArgoCD, Grafana, Prometheus, and Vault
- ✅ Automatic HTTP to HTTPS redirects
- ✅ ReferenceGrants for cross-namespace service references
- ✅ ClientSettingsPolicy for NGINX (configurable max body size)
- ✅ Feature flags for each HTTPRoute
- ✅ Fully variable-driven (no hardcoded values)

## Requirements

- **Gateway API CRDs**: Must be installed (typically by NGINX Gateway Fabric, Istio, or similar)
- **TLS Secret**: Must exist in the specified namespace (e.g., `k8s-platform-tls`)
- **Services**: Backend services must be deployed before HTTPRoutes will work

## Usage

```hcl
module "gateway_api" {
  source = "./modules/gateway-api"

  domain_name = "example.com"
  
  # Enable Gateway and routes
  enable_gateway         = true
  enable_argocd_route    = true
  enable_grafana_route   = true
  enable_prometheus_route = true
  enable_vault_route     = true
  
  # Gateway configuration
  gateway_class_name     = "nginx"
  tls_secret_name        = "k8s-platform-tls"
  tls_secret_namespace   = "default"
  max_body_size          = "150m"
  
  depends_on = [module.helm] # Ensure NGINX Gateway is deployed first
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| domain_name | Base domain name for the platform | `string` | n/a | yes |
| enable_gateway | Enable Gateway API resources | `bool` | `false` | no |
| enable_argocd_route | Enable HTTPRoute for ArgoCD | `bool` | `true` | no |
| enable_grafana_route | Enable HTTPRoute for Grafana | `bool` | `true` | no |
| enable_prometheus_route | Enable HTTPRoute for Prometheus | `bool` | `true` | no |
| enable_vault_route | Enable HTTPRoute for Vault | `bool` | `false` | no |
| gateway_class_name | Gateway class name (nginx, istio, etc.) | `string` | `"nginx"` | no |
| tls_secret_name | Name of TLS secret for HTTPS | `string` | `"k8s-platform-tls"` | no |
| tls_secret_namespace | Namespace of TLS secret | `string` | `"default"` | no |
| gateway_name | Name of Gateway resource | `string` | `"k8s-platform-gateway"` | no |
| gateway_namespace | Namespace for Gateway | `string` | `"default"` | no |
| max_body_size | Max request body size | `string` | `"150m"` | no |

## Outputs

| Name | Description |
|------|-------------|
| gateway_name | Name of the Gateway resource |
| gateway_namespace | Namespace of the Gateway |
| argocd_url | ArgoCD URL |
| grafana_url | Grafana URL |
| prometheus_url | Prometheus URL |
| vault_url | Vault URL |

## Two-Phase Deployment

Due to CRD dependencies, use this two-phase approach:

### Phase 1: Deploy Gateway CRDs
```bash
# Deploy NGINX Gateway Fabric (or your Gateway controller)
terraform apply -target='module.helm'
```

### Phase 2: Enable Gateway Resources
```hcl
# In terraform.tfvars
enable_gateway = true
```

```bash
terraform apply
```

## Resources Created

When `enable_gateway = true`:

1. **Gateway** (`k8s-platform-gateway`)
   - HTTP listener (port 80) for redirects
   - HTTPS listener (port 443) with TLS termination

2. **ReferenceGrants** (3):
   - `allow-monitoring-services` (monitoring namespace)
   - `allow-argocd-services` (argocd namespace)
   - `allow-vault-services` (vault namespace, conditional)

3. **ClientSettingsPolicy** (NGINX only):
   - Configures max body size for large uploads

4. **HTTPRoutes** (8 total, 4 services × 2 routes each):
   - Each service gets HTTP→HTTPS redirect + HTTPS route
   - Services: ArgoCD, Grafana, Prometheus, Vault

## Service URLs

After deployment, access services at:

- **ArgoCD**: `https://argocd.{domain_name}`
- **Grafana**: `https://monitoring.{domain_name}`
- **Prometheus**: `https://prometheus.{domain_name}`
- **Vault**: `https://vault.{domain_name}`

## Notes

- All HTTPRoutes automatically redirect HTTP to HTTPS
- ReferenceGrants enable cross-namespace service references
- Each HTTPRoute has a dedicated enable variable
- ClientSettingsPolicy only applies to NGINX Gateway
- Gateway listeners accept all subdomains: `*.{domain_name}`
