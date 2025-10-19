#!/usr/bin/env bash
set -euo pipefail

# Generate terraform.tfvars using environment variables provided by GitHub Actions
cat > terraform.tfvars <<EOF
project_id = "${GKE_PROJECT}"
region = "${GKE_REGION}"
EOF

exit 0
