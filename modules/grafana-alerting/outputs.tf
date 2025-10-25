output "folder_uid" {
  description = "UID of the Grafana folder containing Platform alerts"
  value       = grafana_folder.platform_alerts.uid
}

output "folder_url" {
  description = "URL to the Grafana folder containing Platform alerts"
  value       = grafana_folder.platform_alerts.url
}

output "contact_point_name" {
  description = "Name of the Slack contact point for alerts"
  value       = grafana_contact_point.slack.name
}

output "alert_rules_summary" {
  description = "Summary of created alert rules"
  value = {
    latency_alerts = {
      p95 = length(var.platform_apps)
      p99 = length(var.platform_apps)
    }
    traffic_alerts = {
      drop = length(var.platform_apps)
    }
    error_alerts = {
      rate_5xx = length(var.platform_apps)
      rate_4xx = length(var.platform_apps)
    }
    saturation_alerts = {
      cpu           = length(var.platform_apps)
      memory        = length(var.platform_apps)
      pod_not_ready = length(var.platform_apps)
      pod_restarts  = length(var.platform_apps)
    }
    total_rules = length(var.platform_apps) * 9 # 9 rules per app
  }
}
