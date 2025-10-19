# GKE Platform Infrastructure

Terraform configuration for a production-ready Google Kubernetes Engine (GKE) platform infrastructure on Google Cloud Platform.

## Infrastructure Overview

This repository provisions a complete cloud-native platform foundation on GCP, designed to host Kubernetes workloads with secure networking and GitOps capabilities.

### Core Components

**Networking**
- Custom VPC with globally-routed network (`k8s-platform-vpc`)
- Segregated subnets:
  - **Kubernetes subnet** (`10.0.0.0/20`) with secondary ranges for pods (`10.1.0.0/16`) and services (`10.20.0.0/20`)
  - **Database subnet** (`10.0.16.0/20`) for private database connectivity
- Private Service Connection for managed services (Cloud SQL, etc.)
- Cloud NAT for secure egress internet access
- VPC Flow Logs enabled for network observability
- Firewall rules for internal and SSH connectivity

**Platform Features**
- GitHub Actions CI/CD with Workload Identity Federation (OIDC)
- Automated Terraform plan on pull requests
- Automated Terraform apply on merge to `main`
- Centralized state management in Google Cloud Storage
- ArgoCD application manifests for GitOps deployment

### Target Region
`europe-west1` (Belgium)

## Prerequisites

- Google Cloud Project with billing enabled
- `gcloud` CLI authenticated
- Terraform >= 1.9.8
- GitHub repository with Actions enabled

## Local Development

### Authentication

Authenticate with your Google account for local development:

```powershell
gcloud auth application-default login --project=<your-project-id>
```

### Enable Required APIs

The following APIs must be enabled in your GCP project:

```powershell
gcloud services enable compute.googleapis.com \
  container.googleapis.com \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  --project=<your-project-id>
```

### Usage

```powershell
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply
```

## CI/CD Workflow

### Pull Request Workflow (`terraform-ci.yml`)
- Triggers on: Pull requests to `main` with Terraform file changes
- Actions:
  - Runs `terraform fmt` check
  - Runs `terraform validate`
  - Generates `terraform plan`
  - Posts plan results as PR comment

### Production Deployment (`terraform-prod.yaml`)
- Triggers on: Push to `main` or manual workflow dispatch
- Actions:
  - Runs `terraform plan`
  - **Automatically applies changes** if plan shows modifications
  - Uses GitHub Environment protection (`production`)
  - Uploads plan artifacts for audit trail

## Configuration

Copy `terraform.tfvars.example` to `terraform.tfvars` and customize:

```hcl
project_id   = "your-gcp-project-id"
region       = "europe-west1"
network_name = "k8s-platform-vpc"
```

> **Note:** `terraform.tfvars` is generated automatically in CI/CD from GitHub Secrets and Variables.

## GitHub Actions Setup

### Required Secrets
- `WIF_PROVIDER` - Workload Identity Provider resource name
- `SA_EMAIL` - Service account email for GitHub Actions
- `GKE_PROJECT` - GCP project ID

### Required Variables
- `GKE_REGION` - GCP region (default: `europe-west1`)

See [docs/TERRAFORM_CI_WIF_SETUP.md](docs/TERRAFORM_CI_WIF_SETUP.md) for detailed setup instructions.

## Repository Structure

```
.
├── main.tf                  # Root module - orchestrates infrastructure
├── variables.tf             # Input variable definitions
├── outputs.tf               # Output values
├── providers.tf             # Terraform and provider configuration
├── backend.tf               # Remote state configuration
├── modules/
│   └── network/            # VPC networking module
├── .github/
│   ├── workflows/          # CI/CD pipelines
│   └── scripts/            # Helper scripts (e.g., tfvars generation)
├── argocd-apps/            # ArgoCD Application manifests
├── manifests/              # Kubernetes manifests
└── docs/                   # Documentation and runbooks
```

## Security

- Uses Workload Identity Federation (no service account keys)
- Private Google Access enabled on all subnets
- VPC Flow Logs for audit and troubleshooting
- Cloud NAT for controlled egress
- GitHub Environment protection for production deployments

## Contributing

1. Create a feature branch
2. Make changes
3. Open a pull request (triggers Terraform plan)
4. Review plan output in PR comments
5. Merge to `main` (triggers automatic apply)

## License

MIT

## Maintainer

**Rotimi Abiola** ([@rotimiAbiola](https://github.com/rotimiAbiola))
