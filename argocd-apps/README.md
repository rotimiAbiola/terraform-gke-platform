# ArgoCD Applications Directory

This directory contains ArgoCD Application manifests that define the applications to be deployed via GitOps. The infrastructure uses ArgoCD's "App of Apps" pattern, where this directory serves as the source for the main app-of-apps application.

## ⚠️ Important: Variable Replacement Required

**Before using these application manifests, you MUST replace all placeholder values with your actual configuration:**

- `YOUR_GITHUB_ORG`: Your GitHub organization or username (e.g., set via `github_org` in `terraform.tfvars`)
- `YOUR_APP_NAME`: Name of your application
- `YOUR_APP_REPO`: Repository name for your application
- Target branch/revision (e.g., `main`, `production`, `develop`)
- Target namespace (e.g., `platform`, `production`, `staging`)
- Environment labels (e.g., `production`, `staging`, `dev`)

**Use the `application.template.yaml` file as a starting point for new applications.**

## How It Works

1. **App of Apps Pattern**: The main ArgoCD application (`platform-app-of-apps`) points to this directory
2. **Automatic Discovery**: ArgoCD automatically discovers and deploys any YAML files in this directory (except `.template.yaml` files)
3. **GitOps Workflow**: Changes to applications are managed through Git commits and Pull Requests
4. **Automatic Deployment**: Once merged to main branch, ArgoCD automatically syncs and deploys the applications

## Current Applications

- **storefront-gateway**: Gateway for the storefront
- **storefront-app**: Frontend storefront application
- **product-service**: Product metadata and catalog service
- **order-service**: Order processing and activity service
- **cart-service**: Cart management backend
- **review-service**: Customer feedback and review service

## Application Structure

Each application manifest should follow this structure:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: your-app-name
  namespace: argocd
  labels:
    app.kubernetes.io/name: your-app-name
    app.kubernetes.io/part-of: platform
    app.kubernetes.io/managed-by: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Optional: control deployment order
spec:
  project: platform
  source:
  repoURL: https://github.com/rotimiAbiola/your-app-repo
    targetRevision: production  # Use production branch
    path: k8s/*      # Directory containing Kubernetes manifests
    kustomize:
      commonLabels:
        app.kubernetes.io/version: latest
        environment: test
      namePrefix: test-         # Add prefix for test environment
      nameSuffix: -v1          # Add suffix for versioning
  destination:
    server: https://kubernetes.default.svc
    namespace: test            # Deploy to test namespace
  syncPolicy:
    automated:
      prune: true             # Remove resources not in Git
      selfHeal: true          # Auto-correct drift
      allowEmpty: false       # Don't sync empty directories
    syncOptions:
      - CreateNamespace=true  # Create namespace if it doesn't exist
      - ServerSideApply=true  # Use server-side apply
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10
```

## Adding a New Application

### Prerequisites

1. **Application Repository**: Your application must have Kubernetes manifests in a `k8s/` directory
2. **Kustomize Support**: Manifests should be compatible with Kustomize
3. **GitHub Access**: Repository must be accessible by the ArgoCD GitHub App

### Step-by-Step Process

1. **Create Application Manifest**:
   ```bash
   # Create a new file in this directory
   touch argocd-apps/your-app-name.yaml
   ```

2. **Define Application Configuration**:
   - Copy the template above
   - Update the `name`, `repoURL`, and other relevant fields
   - Ensure the `project` is set to `platform`
   - Set appropriate `namespace` (usually `platform` for platform application environment)

3. **Configure Source Repository**:
   - Ensure your app repo has a `k8s/` directory
   - Include all Kubernetes manifests (deployments, services, httproute, etc.)
   - Optionally include a `kustomization.yaml` file

4. **Create Pull Request**:
   - **REQUIRED**: All changes must go through Pull Request process
   - Create a descriptive PR title and description
   - Include details about the application being added
   - Tag relevant team members for review

5. **Review Process**:
   - At least one team member must approve
   - All CI checks must pass
   - Infrastructure team review required

6. **Deployment**:
   - Once merged to `main`, ArgoCD automatically detects the new application
   - The application will be deployed to the specified namespace
   - Check ArgoCD UI to monitor deployment status

## Application Configuration Guidelines

### Required Labels

```yaml
metadata:
  labels:
    app.kubernetes.io/name: your-app-name
    app.kubernetes.io/part-of: platform
    app.kubernetes.io/managed-by: argocd
```

### Naming Conventions

- **Application Name**: Use kebab-case (e.g., `user-service`, `api-gateway`)
- **File Name**: Match the application name (e.g., `user-service.yaml`)
- **Namespace**: Use `test` for test environment, `prod` for production

### Repository Requirements

Your application repository should have:

```
your-app-repo/
├── k8s/          # Required: Kubernetes manifests directory
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── kustomization.yaml   # Optional but recommended
├── src/                     # Your application source code
└── README.md
```

### Kustomize Configuration

If using Kustomize, your `k8s/kustomization.yaml` should include:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

commonLabels:
  app: your-app-name
  version: v1.0.0

namespace: test  # Will be overridden by ArgoCD
```

## GitOps Workflow

### For New Applications

1. **Development**: Create Kubernetes manifests in your app repository
2. **Testing**: Test manifests in a development cluster
3. **Integration**: Add ArgoCD application manifest to this directory
4. **Review**: Create PR and get approval from team
5. **Deployment**: Merge to main triggers automatic deployment

### For Application Updates

1. **Update Manifests**: Make changes in your application repository
2. **Automatic Sync**: ArgoCD detects changes and syncs automatically
3. **Manual Sync**: If needed, manually sync via ArgoCD UI

### For Application Configuration Changes

1. **Update Manifest**: Modify the application YAML in this directory
2. **Create PR**: Follow the same PR process
3. **Review & Merge**: Get approval and merge changes

## Important Guidelines

### Security

- **Never include secrets** in application manifests
- **Use Kubernetes secrets** or external secret management
- **Follow least privilege principle** for service accounts

### Best Practices

- **Use resource limits** in your deployments
- **Include health checks** (liveness and readiness probes)
- **Add monitoring annotations** for Prometheus scraping
- **Use proper labels** for resource organization

### Troubleshooting

1. **Check ArgoCD UI**: Monitor application status and sync events
2. **Review Logs**: Check ArgoCD and application logs
3. **Validate Manifests**: Ensure Kubernetes manifests are valid
4. **Check Permissions**: Verify ArgoCD has access to your repository

## 🔍 Monitoring Applications

### ArgoCD Dashboard

Access the ArgoCD dashboard at: `https://argocd.DOMAIN_NAME`

### Application Status

- **Healthy**: Application is running correctly
- **Progressing**: Deployment in progress
- **Degraded**: Issues with the application
- **Suspended**: Application sync is paused

### Common Issues

1. **Image Pull Errors**: Check if container images are accessible
2. **Resource Quotas**: Verify namespace has sufficient resources
3. **RBAC Issues**: Ensure proper service account permissions
4. **Network Policies**: Check if network policies allow traffic

## Contributing Guidelines

### Pull Request Requirements

- **All changes must go through PR process** - No direct commits to main
- **Descriptive title and description**
- **Reference any related issues**
- **Include testing information**
- **Get approval from infrastructure team**

### Code Review Checklist

- [ ] Application name follows naming conventions
- [ ] Required labels are present
- [ ] Repository URL is correct and accessible
- [ ] Target revision and path are appropriate
- [ ] Sync policy is configured correctly
- [ ] Documentation is updated if needed

### Testing

- **Local Validation**: Validate YAML syntax before submitting PR
- **Manifest Testing**: Test Kubernetes manifests in development environment
- **Integration Testing**: Verify application works with existing infrastructure