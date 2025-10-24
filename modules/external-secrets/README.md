# External Secrets Module

This module creates and manages External Secrets Operator resources for HashiCorp Vault integration.

## Overview

This module provides a complete External Secrets Operator setup for connecting to HashiCorp Vault, including:

- **SecretStore**: Vault connection configuration with Kubernetes authentication
- **ExternalSecrets**: Automated secret synchronization for all Platform services
- **RBAC**: Service accounts and permissions for Vault authentication

## Architecture

```
External Secrets Operator
├── SecretStore (vault-secret-store)
│   ├── Vault Server: http://vault.vault.svc.cluster.local:8200
│   ├── Mount Path: secret (KV v2)
│   └── Auth Method: Kubernetes (k8s-apps role)
├── Service Account (vault-auth-sa)
│   └── RBAC: ClusterRole + ClusterRoleBinding
└── ExternalSecrets (6 services)
  ├── storefront-gateway-secrets
  ├── storefront-app-secrets
  ├── product-service-secrets
  ├── order-service-secrets
  ├── cart-service-secrets
  └── review-service-secrets
```

## Path Structure

The module expects the following Vault path structure:

### Application Secrets
- **Path**: `secret/data/platform/prod/{service-name}`
- **CLI Path**: `-mount="secret" "platform/prod/{service-name}"`
- **Services**: 
  - `storefront-gateway`
  - `storefront-app` 
  - `product-service`
  - `order-service`
  - `cart-service`
  - `review-service`

### Secret Properties
Each service secret contains:
- **jwt_secret_key**: JWT signing key for authentication
- **database_password**: Database password for the service
- **openai_api_key**: OpenAI API key (generative-ai-service only)

## Usage

```hcl
module "external-secrets" {
  source = "./modules/external-secrets"

  namespace         = "platform"
  vault_server_url  = "http://vault.vault.svc.cluster.local:8200"
  vault_mount_path  = "secret"
  vault_role        = "k8s-apps"
  
  workload_secrets = var.workload_secrets
  database_secrets = {
    postgres_host     = module.database.host
    postgres_port     = module.database.port
    postgres_database = module.database.database_name
    postgres_user     = module.database.application_user_name
  }

  depends_on = [
    argocd_application.external_secrets_operator,
    module.vault-config
  ]
}
```

## Requirements

| Name | Version |
|------|---------|
| kubernetes | >= 2.0 |
| external-secrets | >= 0.10.4 |

## Providers

| Name | Version |
|------|---------|
| kubernetes | >= 2.0 |

## Dependencies

- External Secrets Operator deployed via ArgoCD
- HashiCorp Vault with Kubernetes auth configured
- Vault policies and secret engines configured

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| namespace | Kubernetes namespace for external secrets | `string` | `"platform"` | no |
| vault_server_url | Vault server URL | `string` | `"http://vault.vault.svc.cluster.local:8200"` | no |
| vault_mount_path | Vault KV mount path | `string` | `"secret"` | no |
| vault_role | Vault Kubernetes auth role | `string` | `"k8s-apps"` | no |
| workload_secrets | Workload secrets configuration | `map(any)` | `{}` | no |
| database_secrets | Database secrets configuration | `map(any)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| secret_store_name | Name of the Vault SecretStore |
| service_account_name | Name of the Vault auth service account |
| external_secrets | List of created external secrets |

## Security

- **Kubernetes Authentication**: Uses Kubernetes service account tokens for Vault auth
- **Least Privilege**: Service account has minimal required permissions
- **Secure Defaults**: Uses non-root security contexts and read-only filesystems
- **Secret Rotation**: Supports 1-hour refresh intervals for secret updates

## Monitoring

- External Secrets Operator provides metrics for monitoring secret sync status
- Prometheus ServiceMonitor enabled for metrics collection
- Check ExternalSecret status: `kubectl get externalsecrets -n platform`

## Troubleshooting

### Common Issues

1. **SecretStore Connection Failed**
   ```bash
   kubectl describe secretstore vault-secret-store -n platform
   ```

2. **ExternalSecret Sync Failed**
   ```bash
   kubectl describe externalsecret iam-service-secrets -n platform
   ```

3. **Service Account Permissions**
   ```bash
   kubectl get clusterrolebinding vault-auth-binding -o yaml
   ```

### Verification

```bash
# Check External Secrets Operator status
kubectl get pods -n external-secrets-system

# Check SecretStore status
kubectl get secretstore -n platform

# Check ExternalSecret status
kubectl get externalsecret -n platform

# Verify created secrets
kubectl get secrets -n platform | grep service-secrets
```