# Vault Configuration Module

This module configures HashiCorp Vault with GitHub authentication, policies, and secret engines for the Platform.

## Features

### Authentication
- **GitHub Auth Method**: Authenticate using GitHub organization and teams
- **Token Management**: Configurable TTL and renewable tokens

### Policies
- **vault-admins**: Full administrative access to Vault
- **vault-developers**: Read/write access to application secrets, read-only database credentials
- **vault-devops**: Infrastructure secrets management, auth method administration

### Secret Engines
- **KV v2 (secret/)**: Application secrets storage
- **KV v2 (infrastructure/)**: Infrastructure secrets storage  
- **Database**: Dynamic PostgreSQL credentials with different role levels

### Database Roles
- **readonly**: SELECT permissions on all tables
- **readwrite**: SELECT, INSERT, UPDATE, DELETE permissions

## Usage

```hcl
module "vault_config" {
  source = "./modules/vault-config"

  github_organization = "your-github-org"
  github_teams = {
    "admins" = {
      policy_name = "vault-admins"
      policies    = ["vault-admins"]
    }
    "developers" = {
      policy_name = "vault-developers"
      policies    = ["vault-developers"]
    }
  }

  database_host            = "postgresql.platform.internal"
  database_name            = "postgres"
  database_admin_username  = "postgres"
  database_admin_password  = "your-admin-password"
}
```

## Authentication Flow

1. **GitHub Login**: Users authenticate via `vault auth -method=github token=<github-token>`
2. **Team Mapping**: GitHub teams are automatically mapped to Vault policies
3. **Token Issuance**: Vault issues tokens with appropriate policies based on team membership

## GitHub Token Requirements

Users need a GitHub personal access token with these scopes:
- `read:org` - To read organization membership
- `user:email` - To read user email address

## Secret Paths

### Application Secrets
- `secret/data/apps/<service-name>/config` - Application configuration
- `secret/data/apps/<service-name>/credentials` - Service credentials

### Infrastructure Secrets
- `infrastructure/data/terraform/api-keys` - Terraform provider credentials
- `infrastructure/data/monitoring/tokens` - Monitoring system tokens
- `infrastructure/data/ci-cd/secrets` - CI/CD pipeline secrets

### Dynamic Database Credentials
- `database/creds/readonly` - Read-only database user
- `database/creds/readwrite` - Read-write database user

## Prerequisites

1. **Vault Initialized**: Vault must be initialized and unsealed
2. **Root Token**: Root token required for initial configuration
3. **GitHub Org**: GitHub organization with defined teams
4. **Database Access**: PostgreSQL admin credentials for dynamic user management

## Outputs

- `github_auth_backend_path`: GitHub auth method path
- `vault_policies`: Created policy names
- `secret_engines`: Configured secret engine paths
- `database_roles`: Available database role names
