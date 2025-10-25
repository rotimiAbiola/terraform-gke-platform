output "gateway_name" {
  description = "Name of the Gateway resource"
  value       = var.enable_gateway ? var.gateway_name : null
}

output "gateway_namespace" {
  description = "Namespace of the Gateway resource"
  value       = var.enable_gateway ? var.gateway_namespace : null
}

output "service_urls" {
  description = "Map of service names to their URLs"
  value = var.enable_gateway ? {
    for svc in local.enabled_services : svc.name => "https://${svc.hostname}.${var.domain_name}"
  } : {}
}

output "enabled_services" {
  description = "List of enabled services"
  value       = var.enable_gateway ? [for svc in local.enabled_services : svc.name] : []
}

output "reference_grant_namespaces" {
  description = "List of namespaces with ReferenceGrants"
  value       = var.enable_gateway ? var.reference_grant_namespaces : []
}
