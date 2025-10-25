variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "postgres_instance_name" {
  description = "Name of the PostgreSQL Cloud SQL instance"
  type        = string
}

variable "postgres_host" {
  description = "PostgreSQL host (private IP or connection name)"
  type        = string
}

variable "monitoring_username" {
  description = "Username for PostgreSQL monitoring user"
  type        = string
  default     = "monitoring"
}

variable "monitoring_namespace" {
  description = "Kubernetes namespace where monitoring components are deployed"
  type        = string
  default     = "monitoring"
}

variable "enable_slow_query_monitoring" {
  description = "Enable slow query monitoring and logging"
  type        = bool
  default     = true
}

variable "slow_query_threshold_ms" {
  description = "Threshold in milliseconds for slow query logging"
  type        = number
  default     = 1000 # 1 second
}

variable "enable_connection_monitoring" {
  description = "Enable connection pool monitoring"
  type        = bool
  default     = true
}

variable "enable_bloat_monitoring" {
  description = "Enable table and index bloat monitoring"
  type        = bool
  default     = true
}

variable "enable_replication_monitoring" {
  description = "Enable replication lag monitoring (for replicas)"
  type        = bool
  default     = false
}

variable "enable_servicemonitor" {
  description = "Enable ServiceMonitor for postgres_exporter (requires prometheus-operator CRDs)"
  type        = bool
  default     = false
}
