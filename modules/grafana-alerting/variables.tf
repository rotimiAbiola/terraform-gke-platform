variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  sensitive   = true
}

variable "slack_channel" {
  description = "Slack channel for alerts (e.g., #platform-alerts)"
  type        = string
  default     = "#platform-alerts"
}

variable "platform_namespace" {
  description = "Kubernetes namespace where platform apps are deployed"
  type        = string
  default     = "platform"
}

variable "platform_apps" {
  description = "List of platform application names to monitor"
  type        = list(string)
  default = [
    "storefront-gateway",
    "storefront-app",
    "product-service",
    "order-service",
    "cart-service",
    "review-service"
  ]
}

variable "alert_thresholds" {
  description = "Threshold values for alerts"
  type = object({
    latency = object({
      p95_ms       = number # P95 latency in milliseconds
      p99_ms       = number # P99 latency in milliseconds
      duration_min = number # How long threshold must be exceeded (minutes)
    })
    errors = object({
      rate_percent = number # Error rate percentage
      duration_min = number # How long threshold must be exceeded (minutes)
    })
    saturation = object({
      cpu_percent    = number # CPU usage percentage
      memory_percent = number # Memory usage percentage
      duration_min   = number # How long threshold must be exceeded (minutes)
    })
    traffic = object({
      drop_percent = number # Traffic drop percentage
      duration_min = number # How long threshold must be exceeded (minutes)
    })
    availability = object({
      pod_ready_percent = number # Minimum percentage of ready pods
      duration_min      = number # How long threshold must be exceeded (minutes)
    })
  })
  default = {
    latency = {
      p95_ms       = 1000 # 1 second
      p99_ms       = 3000 # 3 seconds
      duration_min = 5
    }
    errors = {
      rate_percent = 5 # 5% error rate
      duration_min = 5
    }
    saturation = {
      cpu_percent    = 80
      memory_percent = 85
      duration_min   = 10
    }
    traffic = {
      drop_percent = 50 # 50% traffic drop
      duration_min = 5
    }
    availability = {
      pod_ready_percent = 50 # Less than 50% pods ready
      duration_min      = 3
    }
  }
}

variable "alert_evaluation_interval" {
  description = "How often to evaluate alert rules (e.g., 1m, 5m)"
  type        = string
  default     = "1m"
}

variable "alert_folder_name" {
  description = "Grafana folder name for platform alerts"
  type        = string
  default     = "Platform Alerts"
}

variable "prometheus_datasource_uid" {
  description = "Prometheus datasource UID in Grafana"
  type        = string
  default     = "prometheus"
}

variable "enable_postgres_monitoring" {
  description = "Enable PostgreSQL monitoring alerts"
  type        = bool
  default     = false
}

variable "enable_golden_signals" {
  description = "Enable Golden Signals alerts (latency, errors, traffic) - requires application instrumentation"
  type        = bool
  default     = false
}

################################################################################
# Runbook URL Variables
################################################################################

variable "runbook_url_high_latency" {
  description = "URL to runbook for high latency troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_traffic_drop" {
  description = "URL to runbook for traffic drop troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_high_error_rate" {
  description = "URL to runbook for high error rate troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_client_errors" {
  description = "URL to runbook for client errors (4xx) troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_high_cpu" {
  description = "URL to runbook for high CPU usage troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_high_memory" {
  description = "URL to runbook for high memory usage troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_pods_not_ready" {
  description = "URL to runbook for pods not ready troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_pod_restarts" {
  description = "URL to runbook for frequent pod restarts troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_postgres_high_connections" {
  description = "URL to runbook for PostgreSQL high connections troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_postgres_low_cache_hit" {
  description = "URL to runbook for PostgreSQL low cache hit ratio troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_postgres_slow_queries" {
  description = "URL to runbook for PostgreSQL slow queries troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_postgres_deadlocks" {
  description = "URL to runbook for PostgreSQL deadlocks troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_postgres_long_queries" {
  description = "URL to runbook for PostgreSQL long running queries troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_postgres_down" {
  description = "URL to runbook for PostgreSQL down/unreachable troubleshooting"
  type        = string
  default     = ""
}

variable "runbook_url_postgres_wraparound" {
  description = "URL to runbook for PostgreSQL transaction ID wraparound troubleshooting"
  type        = string
  default     = ""
}
