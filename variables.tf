variable "project_id" {
  description = "The GCP project ID to deploy resources in"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources in"
  type        = string
  default     = "europe-west1"
}

variable "network_name" {
  description = "Name for the VPC network"
  type        = string
  default     = "k8s-platform-vpc"
}

variable "subnet_config" {
  description = "Configuration for VPC subnets"
  type = map(object({
    cidr_range = string
    region     = string
    secondary_ranges = list(object({
      range_name    = string
      ip_cidr_range = string
    }))
  }))
  default = {
    kubernetes = {
      cidr_range = "10.0.0.0/20"
      region     = "europe-west1"
      secondary_ranges = [
        {
          range_name    = "pods"
          ip_cidr_range = "10.1.0.0/16"
        },
        {
          range_name    = "services"
          ip_cidr_range = "10.20.0.0/20"
        }
      ]
    },
    database = {
      cidr_range       = "10.0.16.0/20"
      region           = "europe-west1"
      secondary_ranges = []
    }
  }
}

# GKE Cluster Variables
variable "cluster_name" {
  description = "Name for the GKE cluster"
  type        = string
  default     = "k8s-platform-prod-cluster"
}

variable "master_ipv4_cidr" {
  description = "IP range for GKE masters"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks that can access the Kubernetes API server (empty = only accessible via private endpoint from within VPC)"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "node_pools" {
  description = "List of node pools for the GKE cluster"
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
  default = [
    # # Regular node pool for critical workloads (cronjobs, single-replica apps)
    {
      name         = "default-pool"
      machine_type = "e2-standard-2"
      min_count    = 1
      max_count    = 2
      disk_size_gb = 20
      disk_type    = "pd-standard"
      auto_repair  = true
      auto_upgrade = true
      preemptible  = false
      spot         = false
      labels = {
        "workload-type" = "critical"
      }
      taints = []
    },
    # Spot node pool for resilient multi-replica workloads
    {
      name         = "spot-instance-pool"
      machine_type = "e2-standard-2"
      min_count    = 1
      max_count    = 1
      disk_size_gb = 10
      disk_type    = "pd-standard"
      auto_repair  = true
      auto_upgrade = true
      preemptible  = false
      spot         = true
      labels = {
        "workload-type" = "resilient"
      }
      taints = [
        {
          key    = "cloud.google.com/gke-spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  ]
}

# PostgreSQL Variables
variable "postgres_instance_name" {
  description = "Name for the PostgreSQL instance"
  type        = string
  default     = "k8s-platform-postgresdb"
}

variable "postgres_version" {
  description = "PostgreSQL version to use"
  type        = string
  default     = "POSTGRES_17"
}

variable "postgres_tier" {
  description = "Machine type for the PostgreSQL instance"
  type        = string
  default     = "db-custom-2-4096" # 2 vCPUs, 4 GB RAM (PostgreSQL 17 requires minimum 3840MB)
}

variable "postgres_availability_type" {
  description = "Availability type for PostgreSQL (REGIONAL for high availability)"
  type        = string
  default     = "REGIONAL"
}

variable "postgres_disk_size" {
  description = "Disk size for PostgreSQL in GB"
  type        = number
  default     = 20
}

variable "postgres_db_name" {
  description = "Default database name"
  type        = string
  default     = "postgres"
}

variable "postgres_authorized_networks" {
  description = "List of CIDR blocks that can access the PostgreSQL instance"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "backup_region" {
  description = "The GCP region to store database backups in"
  type        = string
  default     = "europe-west3"
}

# Database and User Configuration
variable "databases" {
  description = "List of databases to create for the platform applications"
  type = list(object({
    name      = string
    charset   = optional(string, "UTF8")
    collation = optional(string, "en_US.UTF8")
  }))
  default = [
    { name = "product-service" },
    { name = "order-service" },
    { name = "cart-service" },
    { name = "review-service" }
  ]
}

variable "users" {
  description = "List of database users to create (passwords auto-generated and stored in Secret Manager)"
  type = list(object({
    name = string
  }))
  default = [
    { name = "product-user" },
    { name = "order-user" },
    { name = "cart-user" },
    { name = "review-user" }
  ]
}

variable "application_db_username" {
  description = "The name of the user that applications will use to access the database"
  type        = string
  default     = "k8s-platform-prod"
}

# DNS Variables
variable "dns_zone_name" {
  description = "The name of the private DNS zone for the platform"
  type        = string
  default     = "platform-internal"
}

variable "dns_zone_domain" {
  description = "The DNS domain for the private zone (must end with a dot) for the platform"
  type        = string
  default     = "platform.internal."
}

variable "database_dns_name" {
  description = "The DNS name for the PostgreSQL database (private)"
  type        = string
  default     = "postgresql.platform.internal."
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

variable "zone" {
  description = "The GCP zone for zonal resources"
  type        = string
  default     = "europe-west1-b"
}