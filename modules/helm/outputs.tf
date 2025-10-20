output "nginx_gateway_status" {
  description = "Status of NGINX Gateway Fabric deployment"
  value = {
    name      = helm_release.nginx_gateway.name
    namespace = helm_release.nginx_gateway.namespace
    version   = helm_release.nginx_gateway.version
    status    = helm_release.nginx_gateway.status
  }
}

#  Get the external IP of the Nginx Gateway LoadBalancer service
data "kubernetes_service" "nginx_gateway" {
  metadata {
    name      = "nginx-gateway"
    namespace = "nginx-gateway"
  }
  depends_on = [helm_release.nginx_gateway]
}

output "nginx_gateway_ip" {
  description = "External IP address of the Nginx Gateway"
  value       = try(data.kubernetes_service.nginx_gateway.status.0.load_balancer.0.ingress.0.ip, "pending")
}

#  Output the ArgoCD URL
output "argocd_url" {
  description = "ArgoCD server URL"
  value       = "https://${var.argocd_url}"
}
