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