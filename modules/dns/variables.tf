variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "dns_zone_name" {
  description = "The name of the DNS managed zone"
  type        = string
  default     = "platform-internal"
}

variable "dns_zone_domain" {
  description = "The DNS domain for the private zone (must end with a dot)"
  type        = string
  default     = "platform.internal."
}

variable "network_id" {
  description = "The ID of the VPC network"
  type        = string
}

variable "database_dns_name" {
  description = "The DNS name for the PostgreSQL database"
  type        = string
  default     = "postgresql.platform.internal."
}

variable "database_private_ip" {
  description = "The private IP address of the PostgreSQL database"
  type        = string
}

variable "service_dns_records" {
  description = "Map of additional service DNS A records"
  type = map(object({
    name       = string
    ip_address = string
  }))
  default = {}
}

variable "service_cname_records" {
  description = "Map of service CNAME records"
  type = map(object({
    name   = string
    target = string
  }))
  default = {}
}

