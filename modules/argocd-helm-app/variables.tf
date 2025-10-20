variable "application_name" {
  description = "Name of the ArgoCD application"
  type        = string
}

variable "project" {
  description = "ArgoCD project name"
  type        = string
  default     = "default"
}

variable "namespace" {
  description = "Target namespace for the application"
  type        = string
}

variable "cluster_name" {
  description = "Target cluster name"
  type        = string
  default     = "in-cluster"
}

variable "repository_url" {
  description = "Helm repository URL"
  type        = string
}

variable "chart_name" {
  description = "Name of the Helm chart"
  type        = string
}

variable "chart_version" {
  description = "Version of the Helm chart"
  type        = string
  default     = ""
}

variable "values" {
  description = "Helm values as YAML string"
  type        = string
  default     = ""
}

variable "sync_policy" {
  description = "ArgoCD sync policy configuration"
  type = object({
    automated = optional(object({
      prune       = optional(bool, true)
      self_heal   = optional(bool, true)
      allow_empty = optional(bool, false)
    }))
    sync_options = optional(list(string), [])
    retry = optional(object({
      limit = optional(number, 5)
      backoff = optional(object({
        duration     = optional(string, "5s")
        factor       = optional(number, 2)
        max_duration = optional(string, "3m")
      }))
    }))
  })
  default = {
    automated = {
      prune     = true
      self_heal = true
    }
  }
}

variable "ignore_differences" {
  description = "List of resource differences to ignore"
  type = list(object({
    group               = optional(string)
    kind                = optional(string)
    name                = optional(string)
    namespace           = optional(string)
    json_pointers       = optional(list(string))
    jq_path_expressions = optional(list(string))
  }))
  default = []
}

variable "labels" {
  description = "Labels to apply to the ArgoCD application"
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Annotations to apply to the ArgoCD application"
  type        = map(string)
  default     = {}
}

variable "create_namespace" {
  description = "Whether to create the target namespace"
  type        = bool
  default     = true
}