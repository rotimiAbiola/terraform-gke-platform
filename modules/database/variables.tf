variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for the database"
  type        = string
}

variable "network_id" {
  description = "The VPC network ID"
  type        = string
}

variable "database_subnet" {
  description = "The subnet to place the database in"
  type        = string
}

variable "ipv4_enabled" {
  description = "Disable  or enable public IP"
  type        = bool
  default     = false
}

variable "instance_name" {
  description = "The name of the PostgreSQL instance"
  type        = string
}

variable "database_version" {
  description = "The PostgreSQL version"
  type        = string
}

variable "tier" {
  description = "The machine type for the database"
  type        = string
}

variable "availability_type" {
  description = "The availability type (REGIONAL for HA)"
  type        = string
}

variable "disk_size" {
  description = "The disk size in GB"
  type        = number
}

variable "db_charset" {
  description = "The charset for the database"
  type        = string
  default     = "UTF8"
}

variable "db_collation" {
  description = "The collation for the database"
  type        = string
  default     = "en_US.UTF8"
}

variable "authorized_networks" {
  description = "List of authorized networks for database access"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "deletion_protection_enabled" {
  description = "Prevents accidental deletion of database instance"
  type        = bool
  default     = false
}

variable "disk_autoresize" {
  description = "Enables vertical autoscaling for the database if set to true"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enables backup for the database if set to true"
  type        = bool
  default     = true
}

variable "backup_location" {
  description = "The location where backup will be stored"
  type        = string
  default     = "europe-west-3"
}

variable "enable_point_in_time_recovery" {
  description = "Enables point in time recovery for the database if set to true"
  type        = bool
  default     = true
}

variable "enable_private_ip" {
  description = "Whether to enable private IP for the instance"
  type        = bool
  default     = true
}

variable "private_network" {
  description = "The VPC network ID for private IP"
  type        = string
  default     = null
}

variable "databases" {
  description = "List of databases to create"
  type = list(object({
    name      = string
    charset   = optional(string, "UTF8")
    collation = optional(string, "en_US.UTF8")
  }))
  default = []
}

variable "users" {
  description = "List of database users to create (passwords will be auto-generated)"
  type = list(object({
    name = string
  }))
  default = []
}

variable "application_db_username" {
  description = "The name of the non-root user that applications will use to access the database"
  type        = string
}