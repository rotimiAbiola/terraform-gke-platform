variable "domain_name" {
  description = "The base domain name for the platform"
  type        = string
}

variable "enable_gateway" {
  description = "Enable Kubernetes Gateway API resources (Gateway, HTTPRoutes, ReferenceGrants)"
  type        = bool
  default     = false
}

variable "services" {
  description = <<-EOT
    List of services to expose via Gateway API HTTPRoutes.
    Each service will get HTTP→HTTPS redirect route + HTTPS route.
    Example:
    services = [
      {
        name              = "argocd"
        hostname          = "argocd"           # Will become argocd.{domain_name}
        backend_service   = "argocd-server"
        backend_namespace = "argocd"
        backend_port      = 443
        enabled           = true
      }
    ]
  EOT
  type = list(object({
    name              = string               # Unique identifier for this service route
    hostname          = string               # Subdomain (e.g., "argocd" → "argocd.{domain_name}")
    backend_service   = string               # Kubernetes Service name
    backend_namespace = string               # Namespace where the Service exists
    backend_port      = number               # Service port number
    enabled           = optional(bool, true) # Enable/disable this specific route
  }))
  default = []
}

variable "reference_grant_namespaces" {
  description = <<-EOT
    List of namespaces to create ReferenceGrants for.
    ReferenceGrants allow HTTPRoutes in gateway_namespace to reference Services in these namespaces.
    Example: ["monitoring", "argocd", "vault"]
  EOT
  type        = list(string)
  default     = []
}

variable "gateway_class_name" {
  description = "The Gateway class name to use (nginx, istio, etc.)"
  type        = string
  default     = "nginx"
}

variable "tls_secret_name" {
  description = "Name of the TLS secret for HTTPS termination"
  type        = string
  default     = "k8s-platform-tls"
}

variable "tls_secret_namespace" {
  description = "Namespace of the TLS secret"
  type        = string
  default     = "default"
}

variable "gateway_name" {
  description = "Name of the Gateway resource"
  type        = string
  default     = "k8s-platform-gateway"
}

variable "gateway_namespace" {
  description = "Namespace for the Gateway resource"
  type        = string
  default     = "default"
}

variable "max_body_size" {
  description = "Maximum request body size for file uploads"
  type        = string
  default     = "150m"
}
