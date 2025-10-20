module "nginx_app" {
  source = "../../"

  application_name = "nginx-example"
  namespace        = "nginx"
  repository_url   = "https://charts.bitnami.com/bitnami"
  chart_name       = "nginx"
  chart_version    = "15.4.0"

  values = <<-EOT
    replicaCount: 3
    
    service:
      type: ClusterIP
      port: 80
    
    ingress:
      enabled: true
      hostname: nginx.example.com
    
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
  EOT

  labels = {
    environment = "production"
    team        = "platform"
  }
}