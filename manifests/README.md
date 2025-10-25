# Kubernetes Manifests

This directory contains Kubernetes manifests that require manual application or are kept as reference files.

## ✅ Managed by Terraform

The following manifests have been **migrated to Terraform** and should **NOT** be applied manually:

### Gateway API Resources (managed by `modules/gateway-api`)
- ~~`gateway.yaml`~~ - Now in `module.gateway_api` (controlled by `enable_gateway` variable)
- ~~`reference-grant.yaml`~~ - Now in `module.gateway_api` (3 ReferenceGrants)
- ~~`client-settings-policy.yaml`~~ - Now in `module.gateway_api` (NGINX policy)
- ~~`httproutes/*.yaml`~~ - Now in `module.gateway_api` (ArgoCD, Grafana, Prometheus, Vault)

### Monitoring Resources
- ~~`vault-servicemonitor.yaml`~~ - Now in `main.tf` (controlled by `enable_vault_servicemonitor` variable)
- ~~`postgres-exporter-servicemonitor.yaml`~~ - Now in `modules/postgres-monitoring` (controlled by `enable_postgres_servicemonitor` variable)

### External Secrets Resources
- ~~`vault-cluster-secret-store.yaml`~~ - Now in `modules/external-secrets` (controlled by `enable_cluster_secret_store` variable)

## 📁 Remaining Manual Manifests

These manifests remain in this directory and should be applied manually or managed separately:

### `prometheus-postgres-rules.yaml`
- **Type**: PrometheusRule (PostgreSQL alert rules)
- **Status**: Manual apply required
- **When**: After Prometheus Operator is deployed
- **Apply**: `kubectl apply -f manifests/prometheus-postgres-rules.yaml`
- **Note**: Could be added to Terraform in future (requires prometheus-operator CRDs)

### `argocd-notifications-cm.yaml`
- **Type**: ConfigMap (ArgoCD Slack notifications)
- **Status**: User-customizable, manual apply
- **When**: After ArgoCD is deployed
- **Apply**: `kubectl apply -f manifests/argocd-notifications-cm.yaml`
- **Note**: Customize for your Slack/Teams/Discord webhook URLs

### `grafana-dashboard-postgresql.json`
- **Type**: Grafana Dashboard JSON
- **Status**: Manual import recommended
- **How**: Import via Grafana UI (Dashboards → Import → Upload JSON)
- **Note**: Can also be provisioned via Grafana ConfigMap/provisioning

### `certs/`
- **Type**: TLS certificates
- **Status**: Manual apply
- **Apply**: `kubectl create secret tls k8s-platform-tls --cert=certs/tls.crt --key=certs/tls.key -n default`
- **Note**: Required for Gateway HTTPS termination

## 🔧 How to Enable Terraform-Managed Resources

### Gateway API Resources

1. **Phase 1**: Deploy NGINX Gateway Fabric (provides CRDs)
   ```bash
   terraform apply -target='module.helm'
   ```

2. **Phase 2**: Enable Gateway resources
   ```hcl
   # In terraform.tfvars
   enable_gateway = true
   enable_argocd_route = true
   enable_grafana_route = true
   enable_prometheus_route = true
   enable_vault_route = true
   ```

   ```bash
   terraform apply
   ```

### ServiceMonitors

1. **Phase 1**: Deploy Prometheus Operator (provides ServiceMonitor CRDs)
   ```bash
   terraform apply -target='module.prometheus-stack'
   ```

2. **Phase 2**: Enable ServiceMonitors
   ```hcl
   # In terraform.tfvars
   enable_vault_servicemonitor = true
   enable_postgres_servicemonitor = true
   ```

   ```bash
   terraform apply
   ```

### ClusterSecretStore

1. **Phase 1**: Deploy External Secrets Operator (provides ClusterSecretStore CRDs)
   ```bash
   terraform apply -target='module.external_secrets'
   ```

2. **Phase 2**: Enable ClusterSecretStore
   ```hcl
   # In terraform.tfvars
   enable_cluster_secret_store = true
   ```

   ```bash
   terraform apply
   ```

## 📊 Migration Summary

| Manifest | Status | Managed By | Feature Flag |
|----------|--------|------------|--------------|
| `gateway.yaml` | ✅ **Migrated** | `module.gateway_api` | `enable_gateway` |
| `reference-grant.yaml` | ✅ **Migrated** | `module.gateway_api` | `enable_gateway` |
| `client-settings-policy.yaml` | ✅ **Migrated** | `module.gateway_api` | `enable_gateway` |
| `httproutes/*.yaml` (4 files) | ✅ **Migrated** | `module.gateway_api` | `enable_*_route` |
| `vault-servicemonitor.yaml` | ✅ **Migrated** | `main.tf` | `enable_vault_servicemonitor` |
| `postgres-exporter-servicemonitor.yaml` | ✅ **Migrated** | `modules/postgres-monitoring` | `enable_postgres_servicemonitor` |
| `vault-cluster-secret-store.yaml` | ✅ **Migrated** | `modules/external-secrets` | `enable_cluster_secret_store` |
| `prometheus-postgres-rules.yaml` | ⏳ **Manual** | N/A | N/A |
| `argocd-notifications-cm.yaml` | ⏳ **Manual** | N/A | N/A |
| `grafana-dashboard-postgresql.json` | ⏳ **Manual** | N/A | N/A |
| `certs/` | ⏳ **Manual** | N/A | N/A |

## 🎯 Benefits of Terraform Management

- ✅ **Single Source of Truth**: All infrastructure in code
- ✅ **GitOps Ready**: Changes tracked in version control
- ✅ **Automated Deployment**: No manual kubectl apply needed
- ✅ **Proper Dependencies**: Terraform ensures correct order
- ✅ **Feature Flags**: Easy enable/disable switches
- ✅ **Variable Substitution**: Domain names automatically templated

## 📚 Related Documentation

- [Gateway API Configuration](../docs/MANIFESTS_TERRAFORM_ANALYSIS.md)
- [Two-Phase Deployment Pattern](../README.md#two-phase-deployment)
- [Feature Flags Guide](../docs/FEATURE_FLAGS.md)
