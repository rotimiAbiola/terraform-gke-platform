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

echo "✅ Generating terraform.tfvars with:"
echo "   project_id: ${GKE_PROJECT}"
echo "   region: ${GKE_REGION}"
echo "   domain_name: ${DOMAIN_NAME}"
echo "   github_org: ${GH_ORG}"
echo "   argocd_server_secret_key: [REDACTED]"

# Generate terraform.tfvars using environment variables provided by GitHub Actions
cat > terraform.tfvars <<EOF
project_id = "${GKE_PROJECT}"
# Domain Configuration
domain_name = "${DOMAIN_NAME}"
github_org  = "${GH_ORG}"
# Sensitive values
argocd_server_secret_key = "${ARGOCD_SERVER_SECRET_KEY}"
EOF

echo "✅ terraform.tfvars generated successfully"
exit 0
