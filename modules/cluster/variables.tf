variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for the cluster"
  type        = string
}

variable "network_name" {
  description = "The VPC network name"
  type        = string
}

variable "subnet_name" {
  description = "The subnetwork name"
  type        = string
}

variable "subnet_secondary_ranges" {
  description = "Secondary IP ranges for pods and services"
  type = object({
    pods = object({
      range_name = string
    })
    services = object({
      range_name = string
    })
  })
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "master_ipv4_cidr" {
  description = "The IP range for the GKE masters"
  type        = string
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks that can access the Kubernetes API. Empty list = fully private (recommended for production)"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [] # Default to fully private
}

variable "enable_private_endpoint" {
  description = "Whether the master's internal IP address is used as the cluster endpoint. If false, the master can be accessed publicly. Recommended: true for production"
  type        = bool
  default     = true # Default to private (secure)
}

variable "enable_private_nodes" {
  description = "Whether nodes have internal IP addresses only. Recommended: true"
  type        = bool
  default     = true
}

variable "enable_etcd_encryption" {
  description = "Enable etcd encryption at rest using Cloud KMS. Recommended: true for production"
  type        = bool
  default     = true
}

variable "kms_key_rotation_period" {
  description = "Rotation period for the KMS key in seconds. Default: 90 days (7776000s)"
  type        = string
  default     = "7776000s" # 90 days
}

variable "node_pools" {
  description = "List of node pools configurations"
  type = list(object({
    name         = string
    machine_type = string
    min_count    = number
    max_count    = number
    disk_size_gb = number
    disk_type    = string
    auto_repair  = bool
    auto_upgrade = bool
    preemptible  = bool
    spot         = optional(bool, false)
    labels       = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
}
