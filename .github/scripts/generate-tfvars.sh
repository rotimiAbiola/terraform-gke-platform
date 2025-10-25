#!/usr/bin/env bash
set -euo pipefail

# Validate required environment variables
if [ -z "${GKE_PROJECT:-}" ]; then
  echo "❌ ERROR: GKE_PROJECT environment variable is not set"
  echo "Please configure the GKE_PROJECT secret in GitHub repository settings"
  exit 1
fi

if [ -z "${DOMAIN_NAME:-}" ]; then
  echo "❌ ERROR: DOMAIN_NAME environment variable is not set"
  echo "Please configure the DOMAIN_NAME variable in GitHub repository settings"
  exit 1
fi

if [ -z "${GH_ORG:-}" ]; then
  echo "❌ ERROR: GH_ORG environment variable is not set"
  echo "Please configure the GH_ORG variable in GitHub repository settings"
  exit 1
fi

if [ -z "${ARGOCD_SERVER_SECRET_KEY:-}" ]; then
  echo "❌ ERROR: ARGOCD_SERVER_SECRET_KEY environment variable is not set"
  echo "Please configure the ARGOCD_SERVER_SECRET_KEY secret in GitHub repository settings"
  exit 1
fi

# Set defaults for optional variables
GKE_REGION="${GKE_REGION:-europe-west1}"
ENABLE_VAULT="${ENABLE_VAULT:-true}"

# Validate VAULT_ROOT_TOKEN if vault is enabled
if [ "${ENABLE_VAULT}" = "true" ] && [ -z "${VAULT_ROOT_TOKEN:-}" ]; then
  echo "❌ ERROR: VAULT_ROOT_TOKEN is required when ENABLE_VAULT=true"
  echo "Please configure the VAULT_ROOT_TOKEN secret in GitHub repository settings"
  echo "Or set ENABLE_VAULT variable to 'false' to disable Vault"
  exit 1
fi

echo "✅ Generating terraform.tfvars with:"
echo "   project_id: ${GKE_PROJECT}"
echo "   region: ${GKE_REGION}"
echo "   domain_name: ${DOMAIN_NAME}"
echo "   github_org: ${GH_ORG}"
echo "   enable_vault: ${ENABLE_VAULT}"
echo "   argocd_server_secret_key: [REDACTED]"
[ "${ENABLE_VAULT}" = "true" ] && echo "   vault_root_token: [REDACTED]"
[ -n "${GH_APP_ID:-}" ] && echo "   github_app_id: ${GH_APP_ID}"
[ -n "${GH_APP_INSTALLATION_ID:-}" ] && echo "   github_app_installation_id: ${GH_APP_INSTALLATION_ID}"
[ -n "${PLATFORM_APP_OF_APPS_REPO_URL:-}" ] && echo "   platform_app_of_apps_repo_url: ${PLATFORM_APP_OF_APPS_REPO_URL}"

# Generate terraform.tfvars using environment variables provided by GitHub Actions
cat > terraform.tfvars <<EOF
project_id = "${GKE_PROJECT}"

# Domain Configuration
domain_name = "${DOMAIN_NAME}"
github_org  = "${GH_ORG}"

# ArgoCD Configuration
argocd_server_secret_key = "${ARGOCD_SERVER_SECRET_KEY}"

# Vault Configuration
enable_vault = ${ENABLE_VAULT}
EOF

if [ "${ENABLE_VAULT}" = "true" ]; then
  cat >> terraform.tfvars <<EOF
vault_root_token = "${VAULT_ROOT_TOKEN}"
EOF
fi

if [ -n "${GH_APP_ID:-}" ]; then
  cat >> terraform.tfvars <<EOF

# GitHub App for ArgoCD (for private repo access)
github_app_id = "${GH_APP_ID}"
EOF
fi

if [ -n "${GH_APP_INSTALLATION_ID:-}" ]; then
  cat >> terraform.tfvars <<EOF
github_app_installation_id = "${GH_APP_INSTALLATION_ID}"
EOF
fi

if [ -n "${GH_APP_PRIVATE_KEY:-}" ]; then
  # GitHub App private key - preserve multiline format
  cat >> terraform.tfvars <<EOF
github_app_private_key = <<-EOK
${GH_APP_PRIVATE_KEY}
EOK
EOF
fi

if [ -n "${PLATFORM_APP_OF_APPS_REPO_URL:-}" ]; then
  cat >> terraform.tfvars <<EOF

# App of Apps Repository
platform_app_of_apps_repo_url = "${PLATFORM_APP_OF_APPS_REPO_URL}"
EOF
fi

# Add CRD-dependent feature flags (default disabled for initial deployment)
cat >> terraform.tfvars <<EOF

# ===========================================================================
# CRD-Dependent Features (Enable after initial deployment)
# ===========================================================================

# ServiceMonitor for Vault metrics (requires prometheus-operator CRDs)
enable_vault_servicemonitor = ${ENABLE_VAULT_SERVICEMONITOR:-false}

# ServiceMonitor for PostgreSQL metrics (requires prometheus-operator CRDs)
enable_postgres_servicemonitor = ${ENABLE_POSTGRES_SERVICEMONITOR:-false}

# ClusterSecretStore for External Secrets Operator (requires ESO CRDs)
enable_cluster_secret_store = ${ENABLE_CLUSTER_SECRET_STORE:-false}

# Golden Signals alerts for applications (requires app instrumentation)
enable_golden_signals_alerts = ${ENABLE_GOLDEN_SIGNALS_ALERTS:-false}
EOF

echo "✅ terraform.tfvars generated successfully"
exit 0
