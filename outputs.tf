output "vpc_network" {
  description = "The VPC network"
  value       = module.network.network_name
}

output "kubernetes_cluster" {
  description = "GKE cluster details"
  value = {
    name           = module.cluster.cluster_name
    endpoint       = module.cluster.endpoint
    ca_certificate = module.cluster.ca_certificate
  }
  sensitive = true
}

output "postgres_instance" {
  description = "PostgreSQL instance details"
  value = {
    name            = module.database.instance_name
    private_ip      = module.database.private_ip_address
    connection_name = module.database.connection_name
    databases       = module.database.database_names
    users           = module.database.user_names
    user_secret_ids = module.database.user_secret_ids
  }
  sensitive = true
}

# DNS outputs
output "dns_configuration" {
  description = "DNS configuration details"
  value = {
    zone_name         = module.dns.dns_zone_name
    zone_domain       = module.dns.dns_zone_domain
    database_dns_name = module.dns.database_dns_name
    database_fqdn     = module.dns.database_fqdn
    service_records   = module.dns.service_dns_records
    cname_records     = module.dns.service_cname_records
  }
}

# Service URLs
output "service_urls" {
  description = "URLs for accessing deployed services"
  value = {
    argocd     = "https://${local.argocd_fqdn}"
    monitoring = "https://${local.monitoring_fqdn}"
    vault      = var.enable_vault ? "https://${local.vault_fqdn}" : null
  }
}

# IAP Connection Guide
output "cluster_access_guide" {
  description = "Guide for accessing the private GKE cluster via IAP"
  value       = <<-EOT
============================================
Private GKE Cluster Access via IAP
============================================

The cluster has a private endpoint. Use IAP to connect:

1. Connect to cluster:
   gcloud container clusters get-credentials ${module.cluster.cluster_name} \
     --region=${var.region} \
     --project=${var.project_id} \
     --internal-ip

2. Access via IAP tunnel (requires Compute Instance Admin role):
   gcloud compute start-iap-tunnel <bastion-vm-name> 22 \
     --local-host-port=localhost:8888 \
     --zone=${var.zone}

3. Or use Cloud Shell which has automatic access

Database: ${module.dns.database_fqdn} (private IP only)
============================================
EOT
}

output "helm_deployments" {
  description = "Status of Helm deployments"
  value = {
    nginx_gateway_fabric = module.helm.nginx_gateway_status
  }
}

output "storage" {
  description = "Storage configuration details"
  value = {
    gcs_bucket            = module.storage.gcs_bucket
    service_account_email = module.storage.service_account_email
  }
}