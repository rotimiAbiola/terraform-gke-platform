# Grafana Folder for Platform Alerts
resource "grafana_folder" "platform_alerts" {
  title = var.alert_folder_name
}

# Contact Point - Slack
resource "grafana_contact_point" "slack" {
  name = "platform-slack-alerts"

  slack {
    url                     = var.slack_webhook_url
    recipient               = var.slack_channel
    text                    = <<-EOT
      🚨 *{{ .CommonLabels.alertname }}*
      {{ if .CommonLabels.app }}
      *App:* {{ .CommonLabels.app }}{{ end }}{{ if .CommonLabels.namespace }}
      *Namespace:* {{ .CommonLabels.namespace }}{{ end }}{{ if .CommonLabels.severity }}
      *Severity:* {{ .CommonLabels.severity }}{{ end }}
      
      *Summary:* {{ .CommonAnnotations.summary }}
      *Description:* {{ .CommonAnnotations.description }}
      
      *Status:* {{ .Status }}
      *Firing:* {{ .Alerts.Firing | len }}
        namespace = var.platform_namespace
      {{ range .Alerts }}
      • {{ if .Labels.pod }}{{ .Labels.pod }}{{ else if .Labels.database }}DB: {{ .Labels.database }}{{ if .Labels.instance }} | Instance: {{ .Labels.instance }}{{ end }}{{ else if .Labels.instance }}Instance: {{ .Labels.instance }}{{ end }} - {{ .Annotations.description }}
      {{ end }}
      <{{ .ExternalURL }}|View in Grafana>
    EOT
    title                   = "Platform Alert: {{ .CommonLabels.alertname }}"
    disable_resolve_message = false
  }
}

# Notification Policy - Routes all alerts to Slack
resource "grafana_notification_policy" "platform" {
  contact_point = grafana_contact_point.slack.name

  group_by        = ["alertname", "app", "namespace"]
  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"

  policy {
    matcher {
      label = "namespace"
      match = "="
      value = var.platform_namespace
    }
    contact_point   = grafana_contact_point.slack.name
    continue        = false
    group_by        = ["alertname", "app"]
    group_wait      = "10s"
    group_interval  = "5m"
    repeat_interval = "12h"
  }
}

# ============================================================================
# GOLDEN SIGNAL 1: LATENCY
# ============================================================================
# NOTE: Requires application instrumentation with Prometheus client
# These alerts require http_request_duration_seconds_bucket metrics
# Enable via enable_golden_signals=true after adding instrumentation

resource "grafana_rule_group" "latency" {
  count = var.enable_golden_signals ? 1 : 0

  name             = "Platform Latency"
  folder_uid       = grafana_folder.platform_alerts.uid
  interval_seconds = 60

  dynamic "rule" {
    for_each = var.platform_apps
    content {
      name      = "High P95 Latency - ${rule.value}"
      condition = "C"

      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "prometheus"
        model = jsonencode({
          expr          = <<-EOT
            histogram_quantile(0.95,
              sum(rate(http_request_duration_seconds_bucket{
                namespace="${var.platform_namespace}",
                app=~"${rule.value}.*"
              }[5m])) by (le, app, pod)
            ) * 1000
          EOT
          refId         = "A"
          intervalMs    = 1000
          maxDataPoints = 43200
        })
      }

      data {
        ref_id = "B"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "reduce"
          refId      = "B"
          expression = "A"
          reducer    = "mean"
          settings = {
            mode = "strict"
          }
        })
      }

      data {
        ref_id = "C"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "threshold"
          refId      = "C"
          expression = "B"
          conditions = [
            {
              evaluator = {
                params = [var.alert_thresholds.latency.p95_ms]
                type   = "gt"
              }
              operator = {
                type = "and"
              }
              query = {
                params = ["C"]
              }
              type = "query"
            }
          ]
        })
      }

      annotations = {
        summary     = "High P95 latency detected for ${rule.value}"
        description = "P95 latency for ${rule.value} is above ${var.alert_thresholds.latency.p95_ms}ms"
        runbook_url = var.runbook_url_high_latency
      }

      labels = {
        severity  = "warning"
        app       = rule.value
        namespace = var.platform_namespace
        signal    = "latency"
      }

      for            = "${var.alert_thresholds.latency.duration_min}m"
      no_data_state  = "NoData"
      exec_err_state = "Error"
    }
  }

  # Alert Rule: High P99 Latency (Critical)
  dynamic "rule" {
    for_each = var.platform_apps
    content {
      name      = "Critical P99 Latency - ${rule.value}"
      condition = "C"

      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "prometheus"
        model = jsonencode({
          expr          = <<-EOT
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket{
                namespace="${var.platform_namespace}",
                app=~"${rule.value}.*"
              }[5m])) by (le, app, pod)
            ) * 1000
          EOT
          refId         = "A"
          intervalMs    = 1000
          maxDataPoints = 43200
        })
      }

      data {
        ref_id = "B"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "reduce"
          refId      = "B"
          expression = "A"
          reducer    = "mean"
        })
      }

      data {
        ref_id = "C"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "threshold"
          refId      = "C"
          expression = "B"
          conditions = [
            {
              evaluator = {
                params = [var.alert_thresholds.latency.p99_ms]
                type   = "gt"
              }
            }
          ]
        })
      }

      annotations = {
        summary     = "Critical P99 latency detected for ${rule.value}"
        description = "P99 latency for ${rule.value} is above ${var.alert_thresholds.latency.p99_ms}ms"
        runbook_url = var.runbook_url_high_latency
      }

      labels = {
        severity  = "critical"
        app       = rule.value
        namespace = var.platform_namespace
        signal    = "latency"
      }

      for            = "${var.alert_thresholds.latency.duration_min}m"
      no_data_state  = "NoData"
      exec_err_state = "Error"
    }
  }
}

# ============================================================================
# GOLDEN SIGNAL 2: TRAFFIC
# ============================================================================
# NOTE: Requires application instrumentation with Prometheus client
# These alerts require http_requests_total metrics
# Enable via enable_golden_signals=true after adding instrumentation

resource "grafana_rule_group" "traffic" {
  count = var.enable_golden_signals ? 1 : 0

  name             = "Platform Traffic"
  folder_uid       = grafana_folder.platform_alerts.uid
  interval_seconds = 60

  # Alert Rule: Significant Traffic Drop
  dynamic "rule" {
    for_each = var.platform_apps
    content {
      name      = "Traffic Drop - ${rule.value}"
      condition = "C"

      data {
        ref_id = "A"
        relative_time_range {
          from = 3600
          to   = 0
        }
        datasource_uid = "prometheus"
        model = jsonencode({
          expr  = <<-EOT
            sum(rate(http_requests_total{
              namespace="${var.platform_namespace}",
              app=~"${rule.value}.*"
            }[5m])) by (app)
          EOT
          refId = "A"
        })
      }

      data {
        ref_id = "B"
        relative_time_range {
          from = 3600
          to   = 0
        }
        datasource_uid = "prometheus"
        model = jsonencode({
          expr  = <<-EOT
            sum(rate(http_requests_total{
              namespace="${var.platform_namespace}",
              app=~"${rule.value}.*"
            }[5m] offset 1h)) by (app)
          EOT
          refId = "B"
        })
      }

      data {
        ref_id = "C"
        relative_time_range {
          from = 3600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "math"
          refId      = "C"
          expression = "((B - A) / B) * 100"
        })
      }

      data {
        ref_id = "D"
        relative_time_range {
          from = 3600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "threshold"
          refId      = "D"
          expression = "C"
          conditions = [
            {
              evaluator = {
                params = [var.alert_thresholds.traffic.drop_percent]
                type   = "gt"
              }
            }
          ]
        })
      }

      annotations = {
        summary     = "Significant traffic drop for ${rule.value}"
        description = "Traffic has dropped by more than ${var.alert_thresholds.traffic.drop_percent}% compared to 1 hour ago"
        runbook_url = var.runbook_url_traffic_drop
      }

      labels = {
        severity  = "warning"
        app       = rule.value
        namespace = var.platform_namespace
        signal    = "traffic"
      }

      for            = "${var.alert_thresholds.traffic.duration_min}m"
      no_data_state  = "NoData"
      exec_err_state = "Error"
    }
  }
}

# ============================================================================
# GOLDEN SIGNAL 3: ERRORS
# ============================================================================
# NOTE: Requires application instrumentation with Prometheus client
# These alerts require http_requests_total metrics with status labels
# Enable via enable_golden_signals=true after adding instrumentation

resource "grafana_rule_group" "errors" {
  count = var.enable_golden_signals ? 1 : 0

  name             = "Platform Errors"
  folder_uid       = grafana_folder.platform_alerts.uid
  interval_seconds = 60

  # Alert Rule: High Error Rate
  dynamic "rule" {
    for_each = var.platform_apps
    content {
      name      = "High Error Rate - ${rule.value}"
      condition = "C"

      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "prometheus"
        model = jsonencode({
          expr  = <<-EOT
            sum(rate(http_requests_total{
              namespace="${var.platform_namespace}",
              app=~"${rule.value}.*",
              status=~"5.."
            }[5m])) by (app)
            /
            sum(rate(http_requests_total{
              namespace="${var.platform_namespace}",
              app=~"${rule.value}.*"
            }[5m])) by (app)
            * 100
          EOT
          refId = "A"
        })
      }

      data {
        ref_id = "B"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "reduce"
          refId      = "B"
          expression = "A"
          reducer    = "mean"
        })
      }

      data {
        ref_id = "C"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "threshold"
          refId      = "C"
          expression = "B"
          conditions = [
            {
              evaluator = {
                params = [var.alert_thresholds.errors.rate_percent]
                type   = "gt"
              }
            }
          ]
        })
      }

      annotations = {
        summary     = "High error rate detected for ${rule.value}"
        description = "Error rate for ${rule.value} is above ${var.alert_thresholds.errors.rate_percent}%"
        runbook_url = var.runbook_url_high_error_rate
      }

      labels = {
        severity  = "critical"
        app       = rule.value
        namespace = var.platform_namespace
        signal    = "errors"
      }

      for            = "${var.alert_thresholds.errors.duration_min}m"
      no_data_state  = "NoData"
      exec_err_state = "Error"
    }
  }

  # Alert Rule: 4xx Error Rate (Client Errors)
  dynamic "rule" {
    for_each = var.platform_apps
    content {
      name      = "High 4xx Error Rate - ${rule.value}"
      condition = "C"

      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "prometheus"
        model = jsonencode({
          expr  = <<-EOT
            sum(rate(http_requests_total{
              namespace="${var.platform_namespace}",
              app=~"${rule.value}.*",
              status=~"5.."
            }[5m])) by (app)
            /
            sum(rate(http_requests_total{
              namespace="${var.platform_namespace}",
              app=~"${rule.value}.*"
            }[5m])) by (app)
            * 100
          EOT
          refId = "A"
        })
      }

      data {
        ref_id = "B"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "reduce"
          refId      = "B"
          expression = "A"
          reducer    = "mean"
        })
      }

      data {
        ref_id = "C"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "threshold"
          refId      = "C"
          expression = "B"
          conditions = [
            {
              evaluator = {
                params = [10] # 10% 4xx error rate
                type   = "gt"
              }
            }
          ]
        })
      }

      annotations = {
        summary     = "High 4xx error rate for ${rule.value}"
        description = "Client error rate (4xx) for ${rule.value} is above 10%"
        runbook_url = var.runbook_url_client_errors
      }

      labels = {
        severity  = "warning"
        app       = rule.value
        namespace = var.platform_namespace
        signal    = "errors"
      }

      for            = "${var.alert_thresholds.errors.duration_min}m"
      no_data_state  = "NoData"
      exec_err_state = "Error"
    }
  }
}

# ============================================================================
# GOLDEN SIGNAL 4: SATURATION
# ============================================================================
# NOTE: These alerts use Kubernetes metrics (kube-state-metrics, cAdvisor)
# and are kept ENABLED as they don't require application instrumentation

resource "grafana_rule_group" "saturation" {
  name             = "Platform Saturation"
  folder_uid       = grafana_folder.platform_alerts.uid
  interval_seconds = 60

  # Alert Rule: High CPU Usage
  dynamic "rule" {
    for_each = var.platform_apps
    content {
      name      = "High CPU Usage - ${rule.value}"
      condition = "C"

      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "prometheus"
        model = jsonencode({
          expr  = <<-EOT
            sum(rate(container_cpu_usage_seconds_total{
              namespace="${var.platform_namespace}",
              pod=~"${rule.value}.*",
              container!=""
            }[5m])) by (pod)
            /
            sum(kube_pod_container_resource_limits{
              namespace="${var.platform_namespace}",
              pod=~"${rule.value}.*",
              resource="cpu"
            }) by (pod)
            * 100
          EOT
          refId = "A"
        })
      }

      data {
        ref_id = "B"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "reduce"
          refId      = "B"
          expression = "A"
          reducer    = "mean"
        })
      }

      data {
        ref_id = "C"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "threshold"
          refId      = "C"
          expression = "B"
          conditions = [
            {
              evaluator = {
                params = [var.alert_thresholds.saturation.cpu_percent]
                type   = "gt"
              }
            }
          ]
        })
      }

      annotations = {
        summary     = "High CPU usage for ${rule.value}"
        description = "CPU usage for ${rule.value} is above ${var.alert_thresholds.saturation.cpu_percent}%"
        runbook_url = var.runbook_url_high_cpu
      }

      labels = {
        severity  = "warning"
        app       = rule.value
        namespace = var.platform_namespace
        signal    = "saturation"
      }

      for            = "${var.alert_thresholds.saturation.duration_min}m"
      no_data_state  = "NoData"
      exec_err_state = "Error"
    }
  }

  # Alert Rule: High Memory Usage
  dynamic "rule" {
    for_each = var.platform_apps
    content {
      name      = "High Memory Usage - ${rule.value}"
      condition = "C"

      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "prometheus"
        model = jsonencode({
          expr  = <<-EOT
            sum(container_memory_working_set_bytes{
              namespace="${var.platform_namespace}",
              pod=~"${rule.value}.*",
              container!=""
            }) by (pod)
            /
            sum(kube_pod_container_resource_limits{
              namespace="${var.platform_namespace}",
              pod=~"${rule.value}.*",
              resource="memory"
            }) by (pod)
            * 100
          EOT
          refId = "A"
        })
      }

      data {
        ref_id = "B"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "reduce"
          refId      = "B"
          expression = "A"
          reducer    = "mean"
        })
      }

      data {
        ref_id = "C"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "threshold"
          refId      = "C"
          expression = "B"
          conditions = [
            {
              evaluator = {
                params = [var.alert_thresholds.saturation.memory_percent]
                type   = "gt"
              }
            }
          ]
        })
      }

      annotations = {
        summary     = "High memory usage for ${rule.value}"
        description = "Memory usage for ${rule.value} is above ${var.alert_thresholds.saturation.memory_percent}%"
        runbook_url = var.runbook_url_high_memory
      }

      labels = {
        severity  = "warning"
        app       = rule.value
        namespace = var.platform_namespace
        signal    = "saturation"
      }

      for            = "${var.alert_thresholds.saturation.duration_min}m"
      no_data_state  = "NoData"
      exec_err_state = "Error"
    }
  }

  # Alert Rule: Pod Not Ready
  dynamic "rule" {
    for_each = var.platform_apps
    content {
      name      = "Pods Not Ready - ${rule.value}"
      condition = "C"

      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "prometheus"
        model = jsonencode({
          expr  = <<-EOT
            sum(kube_pod_status_ready{
              namespace="${var.platform_namespace}",
              pod=~"${rule.value}.*",
              condition="true"
            }) by (pod)
            /
            sum(kube_pod_status_ready{
              namespace="${var.platform_namespace}",
              pod=~"${rule.value}.*"
            }) by (pod)
            * 100
          EOT
          refId = "A"
        })
      }

      data {
        ref_id = "B"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "reduce"
          refId      = "B"
          expression = "A"
          reducer    = "last"
        })
      }

      data {
        ref_id = "C"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "threshold"
          refId      = "C"
          expression = "B"
          conditions = [
            {
              evaluator = {
                params = [var.alert_thresholds.availability.pod_ready_percent]
                type   = "lt"
              }
            }
          ]
        })
      }

      annotations = {
        summary     = "Pods not ready for ${rule.value}"
        description = "Less than ${var.alert_thresholds.availability.pod_ready_percent}% of pods are ready for ${rule.value}"
        runbook_url = var.runbook_url_pods_not_ready
      }

      labels = {
        severity  = "critical"
        app       = rule.value
        namespace = var.platform_namespace
        signal    = "saturation"
      }

      for            = "${var.alert_thresholds.availability.duration_min}m"
      no_data_state  = "Alerting"
      exec_err_state = "Error"
    }
  }

  # Alert Rule: Frequent Pod Restarts
  dynamic "rule" {
    for_each = var.platform_apps
    content {
      name      = "Frequent Pod Restarts - ${rule.value}"
      condition = "C"

      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "prometheus"
        model = jsonencode({
          expr  = <<-EOT
            sum(increase(kube_pod_container_status_restarts_total{
              namespace="${var.platform_namespace}",
              pod=~"${rule.value}.*"
            }[10m])) by (pod)
          EOT
          refId = "A"
        })
      }

      data {
        ref_id = "B"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "reduce"
          refId      = "B"
          expression = "A"
          reducer    = "max"
        })
      }

      data {
        ref_id = "C"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          type       = "threshold"
          refId      = "C"
          expression = "B"
          conditions = [
            {
              evaluator = {
                params = [3] # 3 restarts in 10 minutes
                type   = "gt"
              }
            }
          ]
        })
      }

      annotations = {
        summary     = "Frequent pod restarts for ${rule.value}"
        description = "${rule.value} pods are restarting frequently (>3 times in 10 minutes)"
        runbook_url = var.runbook_url_pod_restarts
      }

      labels = {
        severity  = "warning"
        app       = rule.value
        namespace = var.platform_namespace
        signal    = "saturation"
      }

      for            = "5m"
      no_data_state  = "NoData"
      exec_err_state = "Error"
    }
  }
}

