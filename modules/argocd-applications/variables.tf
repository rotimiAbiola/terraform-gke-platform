variable "project_name" {
  description = "Name of the ArgoCD project"
  type        = string
  default     = "platform"
}

variable "project_description" {
  description = "Description of the ArgoCD project"
  type        = string
  default     = "Platform Applications"
}

variable "github_organization_url" {
  description = "Base URL for the GitHub organization (e.g., https://github.com/YourOrg). If not provided, will be constructed from github_org variable."
  type        = string
  default     = ""
}

variable "github_org" {
  description = "GitHub organization or username. Used to construct github_organization_url if not explicitly provided."
  type        = string
  default     = ""
}

variable "github_app_id" {
  description = "GitHub App ID for authentication"
  type        = string
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
}

variable "github_app_private_key" {
  description = "GitHub App Private Key (PEM format)"
  type        = string
  sensitive   = true
}

variable "source_repositories" {
  description = "List of source repositories that applications can be deployed from"
  type        = list(string)
  default     = ["*"]
}

variable "destinations" {
  description = "List of allowed destinations for applications"
  type = list(object({
    server    = string
    namespace = string
    name      = optional(string)
  }))
  default = [
    {
      server    = "https://kubernetes.default.svc"
      namespace = "*"
    }
  ]
}

variable "cluster_resource_allow_list" {
  description = "List of cluster-scoped resources that applications can manage"
  type = list(object({
    group = string
    kind  = string
  }))
  default = [
    {
      group = ""
      kind  = "Namespace"
    },
    {
      group = "rbac.authorization.k8s.io"
      kind  = "ClusterRole"
    },
    {
      group = "rbac.authorization.k8s.io"
      kind  = "ClusterRoleBinding"
    }
  ]
}

variable "namespace_resource_allow_list" {
  description = "List of namespace-scoped resources that applications can manage"
  type = list(object({
    group = string
    kind  = string
  }))
  default = [
    {
      group = "*"
      kind  = "*"
    }
  ]
}

variable "roles" {
  description = "RBAC roles for the project"
  type = list(object({
    name        = string
    description = string
    policies    = list(string)
    groups      = list(string)
  }))
  default = []
}

variable "orphaned_resources_warn" {
  description = "Whether to warn about orphaned resources"
  type        = bool
  default     = false
}

variable "application_namespaces" {
  description = "Set of namespaces to create for applications"
  type        = set(string)
  default     = []
}

variable "app_of_apps_repo_url" {
  description = "Repository URL for the app of apps configuration (leave empty to manage applications directly with Terraform)"
  type        = string
  default     = ""
}

variable "app_of_apps_path" {
  description = "Path within the repository for app of apps configuration"
  type        = string
  default     = "apps"
}

variable "app_of_apps_revision" {
  description = "Git revision for the app of apps"
  type        = string
  default     = "HEAD"
}

variable "sync_policy" {
  description = "Default sync policy for applications"
  type = object({
    automated = object({
      prune       = optional(bool, true)
      self_heal   = optional(bool, true)
      allow_empty = optional(bool, false)
    })
    sync_options = optional(list(string), ["CreateNamespace=true"])
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
      prune       = true
      self_heal   = true
      allow_empty = false
    }
    sync_options = ["CreateNamespace=true"]
  }
}

variable "applications" {
  description = "Map of applications to deploy"
  type = map(object({
    name            = string
    repo_url        = string
    path            = string
    target_revision = optional(string, "HEAD")

    destination = object({
      server    = optional(string, "https://kubernetes.default.svc")
      namespace = string
    })

    sync_policy = object({
      automated = optional(object({
        prune       = optional(bool, true)
        self_heal   = optional(bool, true)
        allow_empty = optional(bool, false)
      }))
      sync_options = optional(list(string), ["CreateNamespace=true"])
      retry = optional(object({
        limit = optional(number, 5)
        backoff = optional(object({
          duration     = optional(string, "5s")
          factor       = optional(number, 2)
          max_duration = optional(string, "3m")
        }))
      }))
    })

    # Helm configuration (optional)
    helm = optional(object({
      values      = optional(string)
      parameters  = optional(map(string))
      value_files = optional(list(string))
    }))

    # Kustomize configuration (optional)
    kustomize = optional(object({
      name_prefix   = optional(string)
      name_suffix   = optional(string)
      images        = optional(list(string))
      common_labels = optional(map(string))
    }))

    # Ignore differences (optional)
    ignore_differences = optional(list(object({
      group               = optional(string)
      kind                = optional(string)
      name                = optional(string)
      namespace           = optional(string)
      json_pointers       = optional(list(string))
      jq_path_expressions = optional(list(string))
    })))

    annotations = optional(map(string), {})
  }))
  default = {}
}
