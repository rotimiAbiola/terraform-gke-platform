module "monitoring_stack" {
  source = "../../"

  application_name = "prometheus-stack"
  project          = "monitoring"
  namespace        = "monitoring"
  repository_url   = "https://prometheus-community.github.io/helm-charts"
  chart_name       = "kube-prometheus-stack"
  chart_version    = "55.5.0"

  values = <<-EOT
    grafana:
      enabled: true
      adminPassword: changeme
      
    prometheus:
      prometheusSpec:
        retention: 30d
        storageSpec:
          volumeClaimTemplate:
            spec:
              storageClassName: fast-ssd
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: 50Gi
                  
    alertmanager:
      enabled: true
      config:
        global:
          smtp_smarthost: 'localhost:587'
        route:
          group_by: ['alertname']
          receiver: 'web.hook'
        receivers:
        - name: 'web.hook'
          webhook_configs:
          - url: 'http://webhook.example.com/'
  EOT

  sync_policy = {
    automated = {
      prune     = true
      self_heal = false # Disable self-heal for monitoring stack
    }
    sync_options = [
      "CreateNamespace=true",
      "ServerSideApply=true"
    ]
    retry = {
      limit = 3
      backoff = {
        duration     = "10s"
        factor       = 2
        max_duration = "5m"
      }
    }
  }

  ignore_differences = [
    {
      group = "apps"
      kind  = "Deployment"
      json_pointers = [
        "/spec/replicas"
      ]
    }
  ]

  labels = {
    environment = "production"
    team        = "sre"
    component   = "monitoring"
  }

  annotations = {
    "argocd.argoproj.io/sync-wave" = "1"
  }
}
