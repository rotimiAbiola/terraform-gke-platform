# DNS Module

This module creates a private DNS zone for internal services and sets up DNS records for the PostgreSQL database and other services.

## Features

- **Private DNS Zone**: Creates a private DNS zone for internal service resolution
- **Database DNS**: Maps PostgreSQL database to a friendly DNS name
- **Service Records**: Optional A records for other services
- **CNAME Records**: Optional CNAME records for service aliases

## Usage

```hcl
module "dns" {
  source = "./modules/dns"

  project_id            = var.project_id
  network_id           = module.network.network_id
  database_private_ip  = module.database.private_ip_address
  
  # Optional: Custom DNS configuration
  dns_zone_name     = "platform-internal"
  dns_zone_domain   = "platform.internal."
  database_dns_name = "postgresql.platform.internal."
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID | `string` | n/a | yes |
| network_id | The ID of the VPC network | `string` | n/a | yes |
| database_private_ip | The private IP address of the PostgreSQL database | `string` | n/a | yes |
| dns_zone_name | The name of the DNS managed zone | `string` | `"platform-internal"` | no |
| dns_zone_domain | The DNS domain for the private zone | `string` | `"platform.internal."` | no |
| database_dns_name | The DNS name for the PostgreSQL database | `string` | `"postgresql.platform.internal."` | no |
| service_dns_records | Map of additional service DNS A records | `map(object)` | `{}` | no |
| service_cname_records | Map of service CNAME records | `map(object)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| dns_zone_name | The name of the private DNS zone |
| dns_zone_domain | The DNS domain of the private zone |
| database_dns_name | The DNS name for the PostgreSQL database (without trailing dot) |
| database_fqdn | The fully qualified domain name for the PostgreSQL database |
| service_dns_records | Map of created service DNS records |
| service_cname_records | Map of created service CNAME records |

## Example: Database Access

After deploying this module, you can access the PostgreSQL database using:

```yaml
# In your ConfigMaps
DATABASE_HOST: "postgresql.platform.internal"
DATABASE_URL: "postgresql://user:password@postgresql.platform.internal:5432/dbname"
```

Instead of using IP addresses or complex connection names.
