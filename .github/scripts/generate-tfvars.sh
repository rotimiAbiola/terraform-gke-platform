#!/usr/bin/env bash
set -euo pipefail

# Validate required environment variables
if [ -z "${GKE_PROJECT:-}" ]; then
  echo "❌ ERROR: GKE_PROJECT environment variable is not set"
  echo "Please configure the GKE_PROJECT secret in GitHub repository settings"
  exit 1
fi

# Set defaults for optional variables
GKE_REGION="${GKE_REGION:-europe-west1}"
NETWORK_NAME="${NETWORK_NAME:-k8s-platform-vpc}"

echo "✅ Generating terraform.tfvars with:"
echo "   project_id: ${GKE_PROJECT}"
echo "   region: ${GKE_REGION}"
echo "   network_name: ${NETWORK_NAME}"

# Generate terraform.tfvars using environment variables provided by GitHub Actions
cat > terraform.tfvars <<EOF
project_id   = "${GKE_PROJECT}"
region       = "${GKE_REGION}"
network_name = "${NETWORK_NAME}"
EOF

echo "✅ terraform.tfvars generated successfully"
exit 0
