variable "cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "ecomm-dev"
}


variable "role_tags" {
  type        = map(string)
  description = "Role tags"
  default     = {}
}
#==============================================================================
# HELM CHART
#==============================================================================

variable "chart_name" {
  type        = string
  description = "External Secrets chart name"
  default     = "external-secrets"
}

variable "description" {
  type        = string
  description = "External Secrets chart description"
  default     = "External Secrets Operator is a Kubernetes operator that integrates external secret management"
}

variable "chart_version" {
  type        = string
  description = "External Secrets chart version"
  default     = "0.9.1"
}

variable "repository" {
  type        = string
  description = "External Secrets chart repository"
  default     = "https://charts.external-secrets.io"
}

variable "namespace" {
  type        = string
  description = "External namespace"
  default     = "external-secret-system"
}

variable "wait" {
  type        = bool
  description = "Wait for External Secrets to be ready"
  default     = true
}

variable "cleanup_on_fail" {
  type        = bool
  description = "Cleanup on fail"
  default     = true
}

variable "create_namespace" {
  type        = bool
  description = "Create namespace"
  default     = true
}

variable "max_history" {
  type        = number
  description = "Max history for External Secrets"
  default     = 5
}

variable "set_values" {
  type        = map(any)
  description = "External Secrets values"
  default = {
    values = {}
  }
}
