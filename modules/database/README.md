# Database Module - Dynamic Configuration Guide

## Overview

The database module supports dynamic creation of databases and users using lists. This makes it easy to add or remove databases and users without modifying the module code.

## Architecture

### What Gets Created

For each database and user you define:
- ✅ PostgreSQL database with configurable charset/collation
- ✅ Database user with auto-generated secure password
- ✅ Secret Manager secret storing the user's password
- ✅ Secret Manager version with the actual password value

### Auto-Generated Passwords

- Each user gets a unique 24-character password
- Passwords include uppercase, lowercase, numbers, and special characters
- Passwords are stored securely in Google Secret Manager
- Applications can retrieve passwords using Workload Identity

## Usage

### Basic Configuration (terraform.tfvars)

```hcl
# Ecommerce application databases
databases = [
  { name = "product-service" },
  { name = "order-service" },
  { name = "cart-service" },
  { name = "review-service" }
]

# Database users (one per service)
users = [
  { name = "product-user" },
  { name = "order-user" },
  { name = "cart-user" },
  { name = "review-user" }
]
```

### Advanced Configuration with Custom Charset/Collation

```hcl
databases = [
  { 
    name      = "product-service"
    charset   = "UTF8"
    collation = "en_US.UTF8"
  },
  {
    name      = "order-service"
    charset   = "UTF8"
    collation = "en_GB.UTF8"  # UK English collation
  }
]
```

### Adding a New Database and User

Simply append to the lists in `terraform.tfvars`:

```hcl
databases = [
  { name = "product-service" },
  { name = "order-service" },
  { name = "cart-service" },
  { name = "review-service" },
  { name = "notification-service" }  # New!
]

users = [
  { name = "product-user" },
  { name = "order-user" },
  { name = "cart-user" },
  { name = "review-user" },
  { name = "notification-user" }  # New!
]
```

Then run:
```bash
terraform plan
terraform apply
```

## Retrieving Database Credentials

### From Terraform Outputs

```bash
# Get all database names
terraform output -json postgres_instance | jq '.databases'

# Get all user secret IDs
terraform output -json postgres_instance | jq '.user_secret_ids'
```

### From Secret Manager (gcloud)

```bash
# List all database secrets
gcloud secrets list --filter="name:k8s-platform-postgresdb-*-password"

# Get a specific user's password
gcloud secrets versions access latest \
  --secret="k8s-platform-postgresdb-product-user-password"
```

### From Kubernetes (Using External Secrets Operator)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: product-db-credentials
  namespace: platform
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcpsm-secret-store
    kind: ClusterSecretStore
  target:
    name: product-db-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: k8s-platform-postgresdb-product-user-password
```

## Module Outputs

The database module now provides:

```hcl
# Map of database names
database_names = {
  "product-service" = "product-service"
  "order-service"   = "order-service"
  # ...
}

# Map of user names
user_names = {
  "product-user" = "product-user"
  "order-user"   = "order-user"
  # ...
}

# Map of secret IDs for each user
user_secret_ids = {
  "product-user" = "k8s-platform-postgresdb-product-user-password"
  "order-user"   = "k8s-platform-postgresdb-order-user-password"
  # ...
}

# Sensitive: Map of actual passwords
user_passwords = {
  "product-user" = "abc123..."
  # ...
}
```

## Connection Strings

### Format

```
postgresql://{user}:{password}@{host}:5432/{database}?sslmode=require
```

### Example for Product Service

```bash
# Host (from DNS module)
HOST="postgresql.platform.internal"

# Database
DATABASE="product-service"

# User
USER="product-user"

# Password (from Secret Manager)
PASSWORD=$(gcloud secrets versions access latest \
  --secret="k8s-platform-postgresdb-product-user-password")

# Connection string
echo "postgresql://${USER}:${PASSWORD}@${HOST}:5432/${DATABASE}?sslmode=require"
```

## Security Best Practices

### ✅ DO

- Use Workload Identity to access secrets from Kubernetes
- Rotate passwords regularly using Secret Manager versions
- Grant least-privilege access to each service (one user per service)
- Use private IP connectivity only
- Enable SSL/TLS for all connections

### ❌ DON'T

- Hardcode passwords in application code
- Share database users across multiple services
- Enable public IP access unless absolutely necessary
- Store passwords in environment variables in plain text
- Use the `postgres` admin user for application connections

## Troubleshooting

### Issue: "No declaration found for var.databases"

**Solution**: Ensure you've updated `variables.tf` in the root module with the new variable definitions.

### Issue: Passwords not accessible from Kubernetes

**Solution**: 
1. Verify Workload Identity is configured
2. Grant Secret Manager accessor role to the Kubernetes service account
3. Check External Secrets Operator is installed

### Issue: Database connection refused

**Solution**:
1. Verify private IP connectivity is enabled
2. Check VPC peering is established
3. Confirm application is in the correct VPC
4. Test DNS resolution: `nslookup postgresql.platform.internal`

## Adding More Applications

To add a new ecommerce service (e.g., `payment-service`):

1. **Update terraform.tfvars**:
```hcl
databases = [
  # ...existing entries
  { name = "payment-service" }
]

users = [
  # ...existing entries  
  { name = "payment-user" }
]
```

2. **Apply changes**:
```bash
terraform plan
terraform apply
```

3. **Retrieve credentials**:
```bash
gcloud secrets versions access latest \
  --secret="k8s-platform-postgresdb-payment-user-password"
```

4. **Update application deployment** with new connection details

## Questions?

See the main [README.md](../README.md) for general infrastructure documentation or check the [runbooks](../docs/runbooks/) for operational procedures.
