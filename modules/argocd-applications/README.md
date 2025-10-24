# ArgoCD Applications Module

This module creates an ArgoCD project and manages applications using either the "app of apps" pattern or direct Terraform management. It's designed to deploy applications from private GitHub repositories using GitHub App authentication.

## Features

- Creates an ArgoCD project with proper RBAC and resource policies
- Sets up GitHub App authentication for private repository access
- **Two deployment modes**:
  1. **Direct Terraform Management**: Applications managed directly by Terraform (recommended for simpler setups)
  2. **App of Apps Pattern**: Applications managed by a separate repository (traditional GitOps approach)
- Supports both Helm charts and Kustomize applications
- Creates necessary namespaces automatically
- Configurable sync policies and retry mechanisms

## Deployment Modes

### Mode 1: Direct Terraform Management (Recommended)

In this mode, you define your applications directly in Terraform variables. No separate repository is needed.

**Pros:**
- Simpler setup - no need for additional repositories
- All configuration in one place
- Direct control over application lifecycle
- Easier to get started

**Cons:**
- Less GitOps-native (applications not defined in Git)
- Changes require Terraform apply

### Mode 2: App of Apps Pattern (Advanced)

In this mode, applications are defined in a separate Git repository that ArgoCD monitors.

**Pros:**
- Pure GitOps approach
- Applications can be managed by different teams
- Changes don't require Terraform
- ArgoCD UI shows application hierarchy

**Cons:**
- Requires additional repository setup
- More complex initial configuration

## Usage - Direct Terraform Management

```hcl
module "argocd_applications" {
  source = "./modules/argocd-applications"

  # Project configuration
  project_name        = "platform"
  project_description = "Agriculture as a Service Applications"

  # GitHub App authentication
  github_organization_url     = "https://github.com/YourOrganization"
  github_app_id              = "123456"
  github_app_installation_id = "12345678"
  github_app_private_key     = file("path/to/github-app-private-key.pem")

  # Leave app_of_apps_repo_url empty for direct management
  app_of_apps_repo_url = ""

  # Application namespaces to create
  application_namespaces = [
    "api-gateway",
    "user-service",
    "notification-service"
  ]

  # Individual applications
  applications = {
    api-gateway = {
      name            = "api-gateway"
      repo_url        = "https://github.com/YourOrganization/api-gateway"
      path            = "k8s"
      target_revision = "main"
      destination = {
        namespace = "api-gateway"
      }
      sync_policy = {
        automated = {
          prune     = true
          self_heal = true
        }
      }
    }
    
    user-service = {
      name            = "user-service"
      repo_url        = "https://github.com/YourOrganization/user-service"
      path            = "helm-chart"
      target_revision = "main"
      destination = {
        namespace = "user-service"
      }
      helm = {
        values = yamlencode({
          image = {
            tag = "v1.0.0"
          }
          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        })
      }
      sync_policy = {
        automated = {
          prune     = true
          self_heal = true
        }
      }
    }
  }
}
```

## GitHub App Setup

1. Create a GitHub App in your organization:
   - Go to GitHub Organization Settings > Developer settings > GitHub Apps
   - Create a new GitHub App
   - Grant it repository permissions: Contents (Read), Metadata (Read)
   - Install the app on your organization
   - Generate a private key

2. Configure the module with your GitHub App credentials:
   - `github_app_id`: The App ID from the GitHub App settings
   - `github_app_installation_id`: The Installation ID from the installed app
   - `github_app_private_key`: The contents of the private key PEM file

## App of Apps Pattern

This module implements the "app of apps" pattern where:

1. A main ArgoCD application (app of apps) manages other applications
2. Individual applications are defined in a separate repository
3. The app of apps monitors this repository and creates/updates applications

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| argocd | ~> 7.0 |
| kubernetes | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| argocd | ~> 7.0 |
| kubernetes | ~> 2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the ArgoCD project | `string` | `"platform"` | no |
| project_description | Description of the ArgoCD project | `string` | `"Platform Applications"` | no |
| github_organization_url | Base URL for the GitHub organization | `string` | n/a | yes |
| github_app_id | GitHub App ID for authentication | `string` | n/a | yes |
| github_app_installation_id | GitHub App Installation ID | `string` | n/a | yes |
| github_app_private_key | GitHub App Private Key (PEM format) | `string` | n/a | yes |
| app_of_apps_repo_url | Repository URL for the app of apps configuration | `string` | n/a | yes |
| applications | Map of applications to deploy | `map(object)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| project_name | Name of the created ArgoCD project |
| app_of_apps_name | Name of the app of apps application |
| applications | Map of created applications |
| created_namespaces | List of created namespaces |
